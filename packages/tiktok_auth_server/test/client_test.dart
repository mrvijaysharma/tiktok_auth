import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:tiktok_auth_server/tiktok_auth_server.dart';

final _now = DateTime.utc(2026, 9, 11, 12);

http.Response _json(Object body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: const {'content-type': 'application/json'},
);

const Map<String, Object> _tokenResponse = {
  'access_token': 'act.123',
  'expires_in': 86400,
  'open_id': 'open-1',
  'refresh_expires_in': 31536000,
  'refresh_token': 'rft.456',
  'scope': 'user.info.basic,video.list',
  'token_type': 'Bearer',
};

void main() {
  late List<http.Request> requests;

  TikTokOAuthClient client(http.Response Function(http.Request) respond) {
    requests = [];
    return TikTokOAuthClient(
      clientKey: 'awkey',
      clientSecret: 'secret',
      clock: () => _now,
      httpClient: MockClient((request) async {
        requests.add(request);
        return respond(request);
      }),
    );
  }

  group('exchangeCode', () {
    test('posts the PKCE code exchange and parses the tokens', () async {
      final tiktok = client((_) => _json(_tokenResponse));

      final tokens = await tiktok.exchangeCode(
        code: 'code-1',
        codeVerifier: 'verifier-1',
        redirectUri: 'https://example.com/tiktok/callback',
      );

      final request = requests.single;
      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        'https://open.tiktokapis.com/v2/oauth/token/',
      );
      expect(
        request.headers['content-type'],
        contains('x-www-form-urlencoded'),
      );
      expect(request.bodyFields, {
        'client_key': 'awkey',
        'client_secret': 'secret',
        'code': 'code-1',
        'grant_type': 'authorization_code',
        'redirect_uri': 'https://example.com/tiktok/callback',
        'code_verifier': 'verifier-1',
      });

      expect(tokens.accessToken, 'act.123');
      expect(tokens.refreshToken, 'rft.456');
      expect(tokens.openId, 'open-1');
      expect(tokens.scopes, {'user.info.basic', 'video.list'});
      expect(tokens.tokenType, 'Bearer');
      expect(tokens.accessTokenExpiresAt, _now.add(const Duration(days: 1)));
      expect(tokens.refreshTokenExpiresAt, _now.add(const Duration(days: 365)));
    });

    test('omits code_verifier for web codes', () async {
      final tiktok = client((_) => _json(_tokenResponse));
      await tiktok.exchangeCode(code: 'c', redirectUri: 'https://x.com/cb');
      expect(requests.single.bodyFields.containsKey('code_verifier'), isFalse);
    });

    test('throws TikTok OAuth errors', () async {
      final tiktok = client(
        (_) => _json({
          'error': 'invalid_grant',
          'error_description': 'Authorization code is expired.',
          'log_id': 'log-1',
        }, status: 400),
      );
      await expectLater(
        tiktok.exchangeCode(code: 'c', redirectUri: 'https://x.com/cb'),
        throwsA(
          isA<TikTokApiException>()
              .having((e) => e.error, 'error', 'invalid_grant')
              .having((e) => e.description, 'description', contains('expired'))
              .having((e) => e.logId, 'logId', 'log-1')
              .having((e) => e.statusCode, 'statusCode', 400),
        ),
      );
    });

    test('throws on non-JSON responses', () async {
      final tiktok = client((_) => http.Response('<html>', 502));
      await expectLater(
        tiktok.exchangeCode(code: 'c', redirectUri: 'https://x.com/cb'),
        throwsA(
          isA<TikTokApiException>()
              .having((e) => e.error, 'error', 'invalid_response')
              .having((e) => e.statusCode, 'statusCode', 502),
        ),
      );
    });

    test('throws when the access token is missing', () async {
      final tiktok = client((_) => _json({'open_id': 'x'}));
      await expectLater(
        tiktok.exchangeCode(code: 'c', redirectUri: 'https://x.com/cb'),
        throwsA(isA<TikTokApiException>()),
      );
    });
  });

  test('refresh posts the refresh grant', () async {
    final tiktok = client(
      (_) => _json({..._tokenResponse, 'refresh_token': 'rft.new'}),
    );
    final tokens = await tiktok.refresh('rft.old');
    expect(requests.single.bodyFields, {
      'client_key': 'awkey',
      'client_secret': 'secret',
      'grant_type': 'refresh_token',
      'refresh_token': 'rft.old',
    });
    expect(tokens.refreshToken, 'rft.new');
  });

  group('revoke', () {
    test('posts the token and accepts an empty response', () async {
      final tiktok = client((_) => http.Response('', 200));
      await tiktok.revoke('act.123');
      expect(
        requests.single.url.toString(),
        'https://open.tiktokapis.com/v2/oauth/revoke/',
      );
      expect(requests.single.bodyFields['token'], 'act.123');
    });

    test('throws TikTok errors', () async {
      final tiktok = client(
        (_) => _json({'error': 'invalid_request', 'log_id': 'l'}),
      );
      await expectLater(
        tiktok.revoke('bad'),
        throwsA(isA<TikTokApiException>()),
      );
    });
  });

  group('getUserInfo', () {
    test('requests the fields with the bearer token', () async {
      final tiktok = client(
        (_) => _json({
          'data': {
            'user': {
              'open_id': 'open-1',
              'union_id': 'union-1',
              'avatar_url': 'https://p16.tiktokcdn.com/a.jpg',
              'display_name': 'Vijay',
              'follower_count': 42,
              'is_verified': false,
            },
          },
          'error': {'code': 'ok', 'message': '', 'log_id': 'log-2'},
        }),
      );

      final user = await tiktok.getUserInfo(
        'act.123',
        fields: {
          TikTokUserField.openId,
          TikTokUserField.displayName,
          TikTokUserField.followerCount,
        },
      );

      final request = requests.single;
      expect(request.method, 'GET');
      expect(request.url.path, '/v2/user/info/');
      expect(
        request.url.queryParameters['fields'],
        'open_id,display_name,follower_count',
      );
      expect(request.headers['Authorization'], 'Bearer act.123');

      expect(user.openId, 'open-1');
      expect(user.unionId, 'union-1');
      expect(user.displayName, 'Vijay');
      expect(user.followerCount, 42);
      expect(user.isVerified, isFalse);
      expect(user.username, isNull);
      expect(user.raw['avatar_url'], 'https://p16.tiktokcdn.com/a.jpg');
    });

    test('defaults to the basic fields', () async {
      final tiktok = client(
        (_) => _json({
          'data': {'user': <String, Object?>{}},
          'error': {'code': 'ok'},
        }),
      );
      await tiktok.getUserInfo('act.123');
      expect(
        requests.single.url.queryParameters['fields'],
        'open_id,union_id,avatar_url,display_name',
      );
    });

    test('throws API errors', () async {
      final tiktok = client(
        (_) => _json({
          'data': <String, Object?>{},
          'error': {
            'code': 'scope_not_authorized',
            'message': 'The user did not authorize the scope.',
            'log_id': 'log-3',
          },
        }, status: 401),
      );
      await expectLater(
        tiktok.getUserInfo('act.123'),
        throwsA(
          isA<TikTokApiException>()
              .having((e) => e.error, 'error', 'scope_not_authorized')
              .having((e) => e.logId, 'logId', 'log-3')
              .having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });
  });

  group('TikTokTokens', () {
    final tokens = TikTokTokens.fromJson(_tokenResponse, receivedAt: _now);

    test('reports expiry with a safety margin', () {
      expect(tokens.isAccessTokenExpired(now: _now), isFalse);
      expect(
        tokens.isAccessTokenExpired(
          now: _now.add(const Duration(hours: 23, minutes: 56)),
        ),
        isTrue,
      );
    });

    test('redacts tokens in toString', () {
      expect(tokens.toString(), isNot(contains('act.123')));
      expect(tokens.toString(), isNot(contains('rft.456')));
      expect(tokens.toString(), contains('open-1'));
    });
  });

  test('TikTokApiException describes the failure', () {
    const exception = TikTokApiException(
      'invalid_grant',
      description: 'expired',
      logId: 'log-1',
      statusCode: 400,
    );
    expect(
      exception.toString(),
      'TikTokApiException(invalid_grant): expired [HTTP 400] [log_id: log-1]',
    );
  });

  test('close keeps an injected client open', () async {
    var closed = false;
    final inner = MockClient((_) async => _json(_tokenResponse));
    final tiktok = TikTokOAuthClient(
      clientKey: 'k',
      clientSecret: 's',
      httpClient: _TrackingClient(inner, onClose: () => closed = true),
    )..close();
    expect(closed, isFalse);
    await tiktok.refresh('r');
  });
}

class _TrackingClient extends http.BaseClient {
  _TrackingClient(this._inner, {required this.onClose});

  final http.Client _inner;
  final void Function() onClose;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request);

  @override
  void close() => onClose();
}

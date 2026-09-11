import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiktok_auth/testing.dart';
import 'package:tiktok_auth/tiktok_auth.dart';

const _config = TikTokAuthConfig(
  clientKey: 'awtestkey',
  redirectUri: 'https://example.com/tiktok/callback',
);

Matcher _throwsAuthError(TikTokAuthErrorCode code) => throwsA(
  isA<TikTokAuthException>().having((e) => e.code, 'code', code),
);

class _ThrowingPlatform extends TikTokAuthPlatform {
  @override
  Future<bool> isTikTokInstalled() =>
      throw PlatformException(code: 'boom', message: 'native failure');
}

class _UnimplementedPlatform extends TikTokAuthPlatform {}

void main() {
  late FakeTikTokAuthPlatform platform;
  late TikTokAuth auth;

  setUp(() {
    platform = FakeTikTokAuthPlatform();
    auth = TikTokAuth.withPlatform(platform);
  });

  group('initialize', () {
    test('stores a valid configuration', () async {
      expect(auth.isInitialized, isFalse);
      await auth.initialize(_config);
      expect(auth.isInitialized, isTrue);
      expect(auth.config, _config);
    });

    test('reports Dart-side problems without asking the platform', () async {
      platform.configurationProblems = ['should not be reached'];
      await expectLater(
        auth.initialize(
          const TikTokAuthConfig(clientKey: '', redirectUri: 'http://x.com'),
        ),
        throwsA(
          isA<TikTokAuthException>()
              .having((e) => e.code, 'code', TikTokAuthErrorCode.misconfigured)
              .having((e) => e.message, 'message', contains('clientKey'))
              .having((e) => e.message, 'message', contains('https'))
              .having(
                (e) => e.message,
                'message',
                isNot(contains('should not be reached')),
              ),
        ),
      );
      expect(auth.isInitialized, isFalse);
    });

    test('reports native problems', () async {
      platform.configurationProblems = [
        'Info.plist is missing TikTokClientKey',
      ];
      await expectLater(
        auth.initialize(_config),
        throwsA(
          isA<TikTokAuthException>().having(
            (e) => e.message,
            'message',
            contains('Info.plist is missing TikTokClientKey'),
          ),
        ),
      );
      expect(auth.isInitialized, isFalse);
    });

    test('reports unsupported platforms', () async {
      final unsupported = TikTokAuth.withPlatform(_UnimplementedPlatform());
      await expectLater(
        unsupported.initialize(_config),
        _throwsAuthError(TikTokAuthErrorCode.unsupported),
      );
    });
  });

  group('signIn', () {
    test('requires initialize', () {
      expect(
        auth.signIn(),
        _throwsAuthError(TikTokAuthErrorCode.notInitialized),
      );
    });

    test('requires at least one scope', () async {
      await auth.initialize(_config);
      expect(() => auth.signIn(scopes: {}), throwsArgumentError);
    });

    test('sends the request and returns the authorization', () async {
      await auth.initialize(_config);
      platform.respondWithSuccess(
        authCode: 'code-1',
        codeVerifier: 'verifier-1',
        grantedScopes: ['user.info.basic'],
        usedWebAuth: true,
      );

      final result = await auth.signIn(
        scopes: {TikTokScope.userInfoBasic, TikTokScope.videoList},
        preferWebAuth: true,
        disableAutoAuth: true,
        language: 'en',
      );

      final request = platform.requests.single;
      expect(request.clientKey, _config.clientKey);
      expect(request.redirectUri, _config.redirectUri);
      expect(request.scopes, ['user.info.basic', 'video.list']);
      expect(request.state, hasLength(43));
      expect(request.preferWebAuth, isTrue);
      expect(request.disableAutoAuth, isTrue);
      expect(request.language, 'en');

      expect(result.authCode, 'code-1');
      expect(result.codeVerifier, 'verifier-1');
      expect(result.grantedScopes, {TikTokScope.userInfoBasic});
      expect(result.hasScope(TikTokScope.videoList), isFalse);
      expect(result.redirectUri, _config.redirectUri);
      expect(result.usedWebAuth, isTrue);
    });

    test('defaults to user.info.basic', () async {
      await auth.initialize(_config);
      await auth.signIn();
      expect(platform.requests.single.scopes, ['user.info.basic']);
    });

    test('uses a fresh state for every attempt', () async {
      await auth.initialize(_config);
      await auth.signIn();
      await auth.signIn();
      expect(platform.requests[0].state, isNot(platform.requests[1].state));
    });

    test('rejects a response with a different state', () async {
      await auth.initialize(_config);
      platform.respondWith(
        (request) => const AuthorizeResult(
          authCode: 'code',
          codeVerifier: 'verifier',
          state: 'forged',
        ),
      );
      await expectLater(
        auth.signIn(),
        _throwsAuthError(TikTokAuthErrorCode.stateMismatch),
      );
    });

    test('rejects a response without state', () async {
      await auth.initialize(_config);
      platform.respondWith(
        (request) =>
            const AuthorizeResult(authCode: 'code', codeVerifier: 'verifier'),
      );
      await expectLater(
        auth.signIn(),
        _throwsAuthError(TikTokAuthErrorCode.stateMismatch),
      );
    });

    test('rejects a success without an auth code', () async {
      await auth.initialize(_config);
      platform.respondWith(
        (request) => AuthorizeResult(state: request.state, codeVerifier: 'v'),
      );
      await expectLater(
        auth.signIn(),
        _throwsAuthError(TikTokAuthErrorCode.failed),
      );
    });

    const errorMapping = {
      PlatformAuthErrorKind.cancelled: TikTokAuthErrorCode.cancelled,
      PlatformAuthErrorKind.denied: TikTokAuthErrorCode.denied,
      PlatformAuthErrorKind.misconfigured: TikTokAuthErrorCode.misconfigured,
      PlatformAuthErrorKind.alreadyInProgress:
          TikTokAuthErrorCode.alreadyInProgress,
      PlatformAuthErrorKind.network: TikTokAuthErrorCode.network,
      PlatformAuthErrorKind.failed: TikTokAuthErrorCode.failed,
    };
    for (final MapEntry(key: kind, value: code) in errorMapping.entries) {
      test('maps ${kind.name} to ${code.name}', () async {
        await auth.initialize(_config);
        platform.respondWithError(kind, nativeCode: '-4', description: 'why');
        await expectLater(
          auth.signIn(),
          throwsA(
            isA<TikTokAuthException>()
                .having((e) => e.code, 'code', code)
                .having((e) => e.nativeCode, 'nativeCode', '-4')
                .having((e) => e.description, 'description', 'why'),
          ),
        );
      });
    }

    test('rejects a second sign-in while one is running', () async {
      await auth.initialize(_config);
      final completer = Completer<AuthorizeResult>();
      platform.respondWith((_) => completer.future);

      final first = auth.signIn();
      await expectLater(
        auth.signIn(),
        _throwsAuthError(TikTokAuthErrorCode.alreadyInProgress),
      );

      completer.complete(
        const AuthorizeResult.error(PlatformAuthErrorKind.cancelled),
      );
      await expectLater(first, _throwsAuthError(TikTokAuthErrorCode.cancelled));

      platform.respondWithSuccess();
      await expectLater(auth.signIn(), completes);
    });

    test('allows a new sign-in after a failure', () async {
      await auth.initialize(_config);
      platform.respondWithError(PlatformAuthErrorKind.failed);
      await expectLater(auth.signIn(), throwsA(isA<TikTokAuthException>()));
      platform.respondWithSuccess();
      await expectLater(auth.signIn(), completes);
    });
  });

  group('isTikTokInstalled', () {
    test('asks the platform', () async {
      platform.tiktokInstalled = false;
      expect(await auth.isTikTokInstalled(), isFalse);
      platform.tiktokInstalled = true;
      expect(await auth.isTikTokInstalled(), isTrue);
    });

    test('wraps platform exceptions', () async {
      final throwing = TikTokAuth.withPlatform(_ThrowingPlatform());
      await expectLater(
        throwing.isTikTokInstalled(),
        throwsA(
          isA<TikTokAuthException>()
              .having((e) => e.code, 'code', TikTokAuthErrorCode.failed)
              .having((e) => e.nativeCode, 'nativeCode', 'boom')
              .having((e) => e.description, 'description', 'native failure'),
        ),
      );
    });
  });

  group('getPendingAuthorization', () {
    test('returns null when nothing is pending', () async {
      expect(await auth.getPendingAuthorization(), isNull);
    });

    test('returns a recovered authorization once', () async {
      platform.pendingResult = const AuthorizeResult(
        authCode: 'code',
        codeVerifier: 'verifier',
        state: 'stored-state',
        expectedState: 'stored-state',
        redirectUri: 'https://example.com/tiktok/callback',
        grantedScopes: ['user.info.basic'],
      );
      final recovered = await auth.getPendingAuthorization();
      expect(recovered?.authCode, 'code');
      expect(recovered?.redirectUri, 'https://example.com/tiktok/callback');
      expect(await auth.getPendingAuthorization(), isNull);
    });

    test('rejects a recovered authorization with a different state', () async {
      platform.pendingResult = const AuthorizeResult(
        authCode: 'code',
        codeVerifier: 'verifier',
        state: 'forged',
        expectedState: 'stored-state',
      );
      await expectLater(
        auth.getPendingAuthorization(),
        _throwsAuthError(TikTokAuthErrorCode.stateMismatch),
      );
    });

    test('rejects a recovered success without stored state', () async {
      platform.pendingResult = const AuthorizeResult(
        authCode: 'code',
        codeVerifier: 'verifier',
        state: 'state',
      );
      await expectLater(
        auth.getPendingAuthorization(),
        _throwsAuthError(TikTokAuthErrorCode.stateMismatch),
      );
    });

    test('throws for a recovered failure', () async {
      platform.pendingResult = const AuthorizeResult.error(
        PlatformAuthErrorKind.denied,
      );
      await expectLater(
        auth.getPendingAuthorization(),
        _throwsAuthError(TikTokAuthErrorCode.denied),
      );
    });
  });

  group('TikTokAuth.instance', () {
    tearDown(TikTokAuth.instance.debugReset);

    test('uses the registered platform implementation', () async {
      TikTokAuthPlatform.instance = platform;
      await TikTokAuth.instance.initialize(_config);
      await TikTokAuth.instance.signIn();
      expect(platform.requests, hasLength(1));
    });

    test('debugReset forgets the configuration', () async {
      TikTokAuthPlatform.instance = platform;
      await TikTokAuth.instance.initialize(_config);
      TikTokAuth.instance.debugReset();
      expect(TikTokAuth.instance.isInitialized, isFalse);
    });
  });

  group('toString', () {
    test('redacts secrets from authorizations', () {
      const authorization = TikTokAuthorization(
        authCode: 'secret-code',
        codeVerifier: 'secret-verifier',
        grantedScopes: {TikTokScope.userInfoBasic},
        redirectUri: 'https://example.com/cb',
        usedWebAuth: false,
      );
      expect(authorization.toString(), isNot(contains('secret')));
      expect(authorization.toString(), contains('user.info.basic'));
    });

    test('describes exceptions', () {
      const exception = TikTokAuthException(
        TikTokAuthErrorCode.denied,
        'Declined.',
        nativeCode: '-4',
        description: 'access_denied',
      );
      expect(
        exception.toString(),
        'TikTokAuthException(denied): Declined. TikTok says: access_denied '
        '[native code: -4]',
      );
    });
  });
}

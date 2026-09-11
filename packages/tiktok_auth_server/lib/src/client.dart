import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tiktok_auth_server/src/exception.dart';
import 'package:tiktok_auth_server/src/models.dart';

/// A client for TikTok's OAuth and user endpoints.
///
/// It needs your app's client secret, so use it only on a server.
///
/// ```dart
/// final tiktok = TikTokOAuthClient(
///   clientKey: 'awxxxxxxxx',
///   clientSecret: Platform.environment['TIKTOK_CLIENT_SECRET']!,
/// );
/// final tokens = await tiktok.exchangeCode(
///   code: authCode,
///   codeVerifier: codeVerifier,
///   redirectUri: redirectUri,
/// );
/// final user = await tiktok.getUserInfo(tokens.accessToken);
/// ```
class TikTokOAuthClient {
  /// Creates a client.
  ///
  /// Pass [httpClient] to reuse a client or to test; it is then not closed
  /// by [close]. [clock] returns the current time, for token expiry.
  TikTokOAuthClient({
    required this.clientKey,
    required String clientSecret,
    http.Client? httpClient,
    Uri? baseUri,
    DateTime Function()? clock,
  }) : _clientSecret = clientSecret,
       _http = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null,
       _clock = clock ?? DateTime.now,
       baseUri = baseUri ?? Uri.https('open.tiktokapis.com');

  /// The app's client key.
  final String clientKey;

  /// The API origin, `https://open.tiktokapis.com` by default.
  final Uri baseUri;

  final String _clientSecret;
  final http.Client _http;
  final bool _ownsHttpClient;
  final DateTime Function() _clock;

  /// Exchanges an authorization [code] for tokens.
  ///
  /// [redirectUri] must be the one used for the sign-in. [codeVerifier] is
  /// required for codes obtained by mobile and desktop apps, such as those
  /// returned by `package:tiktok_auth`.
  Future<TikTokTokens> exchangeCode({
    required String code,
    required String redirectUri,
    String? codeVerifier,
  }) => _token({
    'code': code,
    'grant_type': 'authorization_code',
    'redirect_uri': redirectUri,
    'code_verifier': ?codeVerifier,
  });

  /// Gets a new access token with [refreshToken].
  ///
  /// The response may contain a new refresh token. Store it, replacing the
  /// old one.
  Future<TikTokTokens> refresh(String refreshToken) => _token({
    'grant_type': 'refresh_token',
    'refresh_token': refreshToken,
  });

  /// Revokes [accessToken], signing the user out of your app on TikTok's
  /// side.
  Future<void> revoke(String accessToken) async {
    final response = await _http.post(
      baseUri.resolve('/v2/oauth/revoke/'),
      headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_key': clientKey,
        'client_secret': _clientSecret,
        'token': accessToken,
      },
    );
    if (response.body.trim().isNotEmpty) {
      _throwIfOAuthError(_decode(response), response.statusCode);
    }
    if (response.statusCode != 200) {
      throw TikTokApiException('http_error', statusCode: response.statusCode);
    }
  }

  /// Returns the profile of the user who owns [accessToken].
  ///
  /// Each field needs a scope; see [TikTokUserField]. Fields whose scope was
  /// not granted make TikTok reject the request.
  Future<TikTokUser> getUserInfo(
    String accessToken, {
    Set<TikTokUserField> fields = TikTokUserField.basic,
  }) async {
    final response = await _http.get(
      baseUri
          .resolve('/v2/user/info/')
          .replace(
            queryParameters: {
              'fields': fields.map((field) => field.value).join(','),
            },
          ),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    final json = _decode(response);
    final error = json['error'];
    if (error is Map<String, Object?>) {
      final code = error['code'] as String?;
      if (code != null && code != 'ok') {
        throw TikTokApiException(
          code,
          description: error['message'] as String?,
          logId: error['log_id'] as String?,
          statusCode: response.statusCode,
        );
      }
    }
    if (json case {'data': {'user': final Map<String, Object?> user}}) {
      return TikTokUser.fromJson(user);
    }
    throw TikTokApiException(
      'invalid_response',
      description: 'The response has no data.user object.',
      statusCode: response.statusCode,
    );
  }

  /// Closes the HTTP client, unless it was passed to the constructor.
  void close() {
    if (_ownsHttpClient) _http.close();
  }

  Future<TikTokTokens> _token(Map<String, String> fields) async {
    final response = await _http.post(
      baseUri.resolve('/v2/oauth/token/'),
      headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_key': clientKey,
        'client_secret': _clientSecret,
        ...fields,
      },
    );
    final json = _decode(response);
    _throwIfOAuthError(json, response.statusCode);
    if (json['access_token'] is! String) {
      throw TikTokApiException(
        'invalid_response',
        description: 'The response has no access_token.',
        statusCode: response.statusCode,
      );
    }
    return TikTokTokens.fromJson(json, receivedAt: _clock());
  }

  static void _throwIfOAuthError(Map<String, Object?> json, int statusCode) {
    final error = json['error'];
    if (error is String && error.isNotEmpty) {
      throw TikTokApiException(
        error,
        description: json['error_description'] as String?,
        logId: json['log_id'] as String?,
        statusCode: statusCode,
      );
    }
  }

  static Map<String, Object?> _decode(http.Response response) {
    try {
      final json = jsonDecode(response.body);
      if (json is Map<String, Object?>) return json;
    } on FormatException {
      // Reported below.
    }
    throw TikTokApiException(
      'invalid_response',
      description: 'Expected a JSON object from TikTok.',
      statusCode: response.statusCode,
    );
  }
}

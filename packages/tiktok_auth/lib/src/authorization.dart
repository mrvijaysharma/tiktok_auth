import 'package:flutter/foundation.dart';
import 'package:tiktok_auth/src/scope.dart';

/// The result of a successful TikTok sign-in.
///
/// It does **not** contain an access token. Exchanging [authCode] for tokens
/// requires your app's client secret, which must never ship inside an app.
/// Send [authCode], [codeVerifier] and [redirectUri] to your backend, and
/// call `POST https://open.tiktokapis.com/v2/oauth/token/` from there.
@immutable
class TikTokAuthorization {
  /// Creates an authorization.
  const TikTokAuthorization({
    required this.authCode,
    required this.codeVerifier,
    required this.grantedScopes,
    required this.redirectUri,
    required this.usedWebAuth,
  });

  /// The one-time authorization code. It expires after a few minutes.
  final String authCode;

  /// The PKCE code verifier generated for this sign-in. The token endpoint
  /// requires it as `code_verifier` for mobile apps.
  final String codeVerifier;

  /// The scopes the user granted. This can be fewer than you requested.
  final Set<TikTokScope> grantedScopes;

  /// The redirect URI used for this sign-in. The token endpoint requires it
  /// as `redirect_uri`.
  final String redirectUri;

  /// Whether the browser flow was used instead of the TikTok app.
  final bool usedWebAuth;

  /// Whether the user granted [scope].
  bool hasScope(TikTokScope scope) => grantedScopes.contains(scope);

  @override
  String toString() =>
      'TikTokAuthorization(authCode: <redacted>, codeVerifier: <redacted>, '
      'grantedScopes: $grantedScopes, redirectUri: $redirectUri, '
      'usedWebAuth: $usedWebAuth)';
}

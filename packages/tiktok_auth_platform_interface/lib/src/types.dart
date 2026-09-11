import 'package:flutter/foundation.dart';

/// Why a native authorization attempt did not produce an authorization code.
enum PlatformAuthErrorKind {
  /// No error. The result carries an authorization code.
  none,

  /// The user left the flow without deciding, for example by closing the
  /// browser, pressing back, or switching back to the app.
  cancelled,

  /// The user explicitly declined the authorization request.
  denied,

  /// The app, the device, or the TikTok developer portal is not configured
  /// correctly (redirect URI, client key, bundle ID, signing certificate...).
  misconfigured,

  /// Another authorization is already running.
  alreadyInProgress,

  /// A network error interrupted the web-based flow.
  network,

  /// Any other failure.
  failed,
}

/// Parameters for a single native authorization attempt.
@immutable
class AuthorizeRequest {
  /// Creates an authorization request.
  const AuthorizeRequest({
    required this.clientKey,
    required this.redirectUri,
    required this.scopes,
    required this.state,
    this.preferWebAuth = false,
    this.disableAutoAuth = false,
    this.language,
  });

  /// The client key of the app registered in the TikTok developer portal.
  final String clientKey;

  /// The https redirect URI registered in the TikTok developer portal.
  final String redirectUri;

  /// The scopes to request, for example `user.info.basic`.
  final List<String> scopes;

  /// An unguessable value that TikTok must echo back unchanged.
  final String state;

  /// Whether to use the browser flow even when the TikTok app is installed.
  final bool preferWebAuth;

  /// Whether to always show the consent screen, even for returning users.
  /// Not every platform supports it.
  final bool disableAutoAuth;

  /// Optional language for the consent screen, for example `en`. Not every
  /// platform supports it.
  final String? language;
}

/// The outcome of a native authorization attempt.
@immutable
class AuthorizeResult {
  /// Creates an authorization result.
  const AuthorizeResult({
    this.authCode,
    this.codeVerifier,
    this.state,
    this.expectedState,
    this.redirectUri,
    this.grantedScopes = const <String>[],
    this.usedWebAuth = false,
    this.errorKind = PlatformAuthErrorKind.none,
    this.nativeCode,
    this.errorDescription,
  });

  /// Creates a failed authorization result.
  const AuthorizeResult.error(
    PlatformAuthErrorKind kind, {
    String? nativeCode,
    String? errorDescription,
    bool usedWebAuth = false,
  }) : this(
         errorKind: kind,
         nativeCode: nativeCode,
         errorDescription: errorDescription,
         usedWebAuth: usedWebAuth,
       );

  /// The one-time authorization code, when [errorKind] is
  /// [PlatformAuthErrorKind.none].
  final String? authCode;

  /// The PKCE code verifier that belongs to [authCode].
  final String? codeVerifier;

  /// The `state` value TikTok returned.
  final String? state;

  /// The `state` value that was sent. Only set for results recovered after
  /// the app process was restarted, where the Dart side no longer knows it.
  final String? expectedState;

  /// The redirect URI used for the request.
  final String? redirectUri;

  /// The scopes the user granted. May be fewer than requested.
  final List<String> grantedScopes;

  /// Whether the browser-based flow was used instead of the TikTok app.
  final bool usedWebAuth;

  /// Why the attempt failed, or [PlatformAuthErrorKind.none] on success.
  final PlatformAuthErrorKind errorKind;

  /// The raw error code reported by the TikTok SDK, if any.
  final String? nativeCode;

  /// The human-readable error description reported by TikTok, if any.
  final String? errorDescription;

  /// Whether the attempt produced an authorization code.
  bool get isSuccess => errorKind == PlatformAuthErrorKind.none;

  @override
  String toString() =>
      'AuthorizeResult(errorKind: ${errorKind.name}, '
      'hasAuthCode: ${authCode != null}, usedWebAuth: $usedWebAuth, '
      'nativeCode: $nativeCode, errorDescription: $errorDescription)';
}

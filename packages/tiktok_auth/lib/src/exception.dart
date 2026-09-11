import 'package:flutter/foundation.dart';

/// Why a TikTok Login operation failed.
enum TikTokAuthErrorCode {
  /// The user left the flow without deciding, for example by closing the
  /// browser or switching back to the app. Usually handled silently.
  cancelled,

  /// The user declined the authorization request on the consent screen.
  denied,

  /// The app or its registration in the TikTok developer portal is not
  /// configured correctly: client key, redirect URI, Universal Links / App
  /// Links, bundle ID / package name or signing certificate.
  misconfigured,

  /// The `state` TikTok returned did not match the request. The response was
  /// discarded to protect against cross-site request forgery.
  stateMismatch,

  /// A sign-in was started while another one was still running.
  alreadyInProgress,

  /// `TikTokAuth.initialize` was not called before `signIn`.
  notInitialized,

  /// A network error interrupted the browser-based flow.
  network,

  /// TikTok Login is not available on the current platform.
  unsupported,

  /// Any other failure. See [TikTokAuthException.nativeCode] and
  /// [TikTokAuthException.description] for details.
  failed,
}

/// Thrown when a TikTok Login operation fails.
@immutable
class TikTokAuthException implements Exception {
  /// Creates an exception.
  const TikTokAuthException(
    this.code,
    this.message, {
    this.nativeCode,
    this.description,
  });

  /// Why the operation failed.
  final TikTokAuthErrorCode code;

  /// A developer-facing explanation, including a fix when one is known.
  final String message;

  /// The raw error code reported by the TikTok SDK, if any.
  final String? nativeCode;

  /// The error description reported by TikTok, if any.
  final String? description;

  @override
  String toString() {
    final buffer = StringBuffer('TikTokAuthException(${code.name}): $message');
    if (description != null) buffer.write(' TikTok says: $description');
    if (nativeCode != null) buffer.write(' [native code: $nativeCode]');
    return buffer.toString();
  }
}

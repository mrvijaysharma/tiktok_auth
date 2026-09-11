import 'package:flutter/foundation.dart';
import 'package:tiktok_auth/src/validation.dart' as validation;

/// App-wide TikTok Login configuration, passed to `TikTokAuth.initialize`.
///
/// Both values come from your app's page in the
/// [TikTok developer portal](https://developers.tiktok.com/apps).
@immutable
class TikTokAuthConfig {
  /// Creates a configuration.
  const TikTokAuthConfig({required this.clientKey, required this.redirectUri});

  /// The longest redirect URI TikTok accepts, exclusive.
  static const int maxRedirectUriLength = validation.maxRedirectUriLength;

  /// The app's client key. It is not a secret.
  ///
  /// On iOS the TikTok SDK reads the key from `TikTokClientKey` in
  /// Info.plist. This value must match it, which `initialize` checks.
  final String clientKey;

  /// The https redirect URI registered for your app in the TikTok developer
  /// portal, for example `https://example.com/tiktok/callback`.
  ///
  /// It must be a verified Universal Link (iOS) and App Link (Android) for
  /// your app, so that TikTok can return to it.
  final String redirectUri;

  /// Returns the problems with this configuration that can be detected
  /// without the native project. An empty list means none were found.
  List<String> validate() => [
    ...validation.clientKeyProblems(clientKey),
    ...validation.redirectUriProblems(redirectUri),
  ];

  @override
  bool operator ==(Object other) =>
      other is TikTokAuthConfig &&
      other.clientKey == clientKey &&
      other.redirectUri == redirectUri;

  @override
  int get hashCode => Object.hash(clientKey, redirectUri);

  @override
  String toString() =>
      'TikTokAuthConfig(clientKey: $clientKey, redirectUri: $redirectUri)';
}

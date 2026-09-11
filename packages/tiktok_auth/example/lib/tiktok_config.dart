import 'package:tiktok_auth/tiktok_auth.dart';

/// TikTok Login configuration for this example.
///
/// Pass your own values without editing code:
///
/// ```bash
/// flutter run \
///   --dart-define=TIKTOK_CLIENT_KEY=awxxxxxxxx \
///   --dart-define=TIKTOK_REDIRECT_URI=https://your.domain/tiktok/callback
/// ```
///
/// The same values must also be set in:
/// - `ios/Runner/Info.plist` (`TikTokClientKey` and `CFBundleURLSchemes`),
/// - `android/app/build.gradle.kts` (`tiktokRedirectHost`/`tiktokRedirectPath`).
const tiktokConfig = TikTokAuthConfig(
  clientKey: String.fromEnvironment(
    'TIKTOK_CLIENT_KEY',
    defaultValue: 'YOUR_TIKTOK_CLIENT_KEY',
  ),
  redirectUri: String.fromEnvironment(
    'TIKTOK_REDIRECT_URI',
    defaultValue: 'https://example.com/tiktok/callback',
  ),
);

## 0.1.0 (unreleased)

* Initial release.
* TikTok Login Kit on Android (TikTok OpenSDK 2.4.0) and iOS (TikTok OpenSDK 2.5.0).
* PKCE code verifier and CSRF `state` handled automatically.
* Typed `TikTokScope`, `TikTokAuthorization` and `TikTokAuthException` API.
* Configuration validation in `TikTokAuth.initialize`.
* `package:tiktok_auth/testing.dart` with `FakeTikTokAuthPlatform`.
* `dart run tiktok_auth:doctor` checks Info.plist, entitlements, manifest
  placeholders, `apple-app-site-association` and `assetlinks.json`, and prints
  signing key fingerprints. It also flags placeholder client keys such as
  `YOUR_TIKTOK_CLIENT_KEY`.

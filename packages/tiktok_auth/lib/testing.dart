/// Test helpers for apps that use `package:tiktok_auth`.
///
/// Replace the platform implementation with `FakeTikTokAuthPlatform` to test
/// sign-in flows without a device or a TikTok account.
library;

export 'package:tiktok_auth_platform_interface/tiktok_auth_platform_interface.dart'
    show
        AuthorizeRequest,
        AuthorizeResult,
        PlatformAuthErrorKind,
        TikTokAuthPlatform;

export 'src/testing/fake_tiktok_auth_platform.dart';

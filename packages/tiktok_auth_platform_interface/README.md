# tiktok_auth_platform_interface

A common platform interface for the [`tiktok_auth`](https://pub.dev/packages/tiktok_auth)
plugin.

App developers should depend on `tiktok_auth`, not on this package.

## Implementing a platform

Extend `TikTokAuthPlatform` (do not `implement` it), override its methods, and
register your implementation:

```dart
class TikTokAuthMyPlatform extends TikTokAuthPlatform {
  static void registerWith() {
    TikTokAuthPlatform.instance = TikTokAuthMyPlatform();
  }

  @override
  Future<AuthorizeResult> authorize(AuthorizeRequest request) async {
    // ...
  }
}
```

`authorize` must always complete, including when the user cancels, and must
return the PKCE code verifier together with the auth code.

Prefer non-breaking changes (such as adding a method) to this interface over
breaking changes.

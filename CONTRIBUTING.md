# Contributing

Thanks for helping make `tiktok_auth` better.

## Setup

```bash
flutter pub get                 # resolves the whole workspace
dart run melos run analyze --no-select
dart run melos run test:flutter --no-select
```

## Layout

- `packages/tiktok_auth`: the app-facing API and the example app.
- `packages/tiktok_auth_platform_interface`: the interface implementations extend.
- `packages/tiktok_auth_android`: Kotlin, built on TikTok OpenSDK for Android.
- `packages/tiktok_auth_ios`: Swift, built on TikTok OpenSDK for iOS.

## Platform channels

Channels are generated with [Pigeon](https://pub.dev/packages/pigeon). The
schemas live in `tool/pigeon`, outside the workspace, so that the packages
still resolve on the minimum Flutter version. After changing
`tool/pigeon/android.dart` or `tool/pigeon/ios.dart`, run:

```bash
dart run melos run pigeon --no-select
```

Keep the two schemas identical unless a platform needs something the other
does not. CI fails if the generated files are out of date.

## Native tests

- Kotlin: `cd packages/tiktok_auth/example/android && ./gradlew :tiktok_auth_android:testDebugUnitTest`
- Swift: open `packages/tiktok_auth/example/ios/Runner.xcworkspace` and run the
  tests of the `Runner` scheme (Product > Test), or from that folder:
  `xcodebuild test -workspace Runner.xcworkspace -scheme Runner -destination 'platform=iOS Simulator,name=<an iPhone simulator>'`.
  Run `flutter build ios --simulator --debug` in the example first.

With Flutter versions that use CocoaPods instead of Swift Package Manager
(3.41 by default), `flutter pub get` adds a `Podfile` and `#include?` lines to
`example/ios/Flutter/*.xcconfig`. Don't commit those changes.

## Before a release

Run the [manual QA checklist](docs/qa-checklist.md) on real devices.

## Reporting bugs

Include the platform, OS version, TikTok app version (or "not installed"),
the full `TikTokAuthException.toString()` output, and whether the redirect
domain's `.well-known` files are reachable.

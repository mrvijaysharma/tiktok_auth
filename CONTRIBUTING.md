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

Channels are generated with [Pigeon](https://pub.dev/packages/pigeon). After
changing `pigeons/messages.dart` in a platform package, run:

```bash
dart run melos run pigeon --no-select
```

Keep the Android and iOS Pigeon files identical unless a platform needs
something the other does not.

## Native tests

- Kotlin: `cd packages/tiktok_auth/example/android && ./gradlew :tiktok_auth_android:testDebugUnitTest`
- Swift: run the `RunnerTests` scheme of `packages/tiktok_auth/example/ios`.

## Before a release

Run the [manual QA checklist](docs/qa-checklist.md) on real devices.

## Reporting bugs

Include the platform, OS version, TikTok app version (or "not installed"),
the full `TikTokAuthException.toString()` output, and whether the redirect
domain's `.well-known` files are reachable.

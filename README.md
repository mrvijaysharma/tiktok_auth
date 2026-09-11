# tiktok_auth

[![CI](https://github.com/mrvijaysharma/tiktok_auth/actions/workflows/ci.yaml/badge.svg)](https://github.com/mrvijaysharma/tiktok_auth/actions/workflows/ci.yaml)
[![pub package](https://img.shields.io/pub/v/tiktok_auth.svg)](https://pub.dev/packages/tiktok_auth)

Monorepo for **`tiktok_auth`**, an unofficial Flutter plugin for
[TikTok Login Kit](https://developers.tiktok.com/doc/login-kit-overview).

| Package | Purpose |
|---|---|
| [`tiktok_auth`](packages/tiktok_auth) | App-facing API. Add this to your app. |
| [`tiktok_auth_platform_interface`](packages/tiktok_auth_platform_interface) | Common interface for platform implementations. |
| [`tiktok_auth_android`](packages/tiktok_auth_android) | Android implementation (TikTok OpenSDK 2.4.0). |
| [`tiktok_auth_ios`](packages/tiktok_auth_ios) | iOS implementation (TikTok OpenSDK 2.5.0; SPM + CocoaPods). |
| [`tiktok_auth_server`](packages/tiktok_auth_server) | Pure-Dart backend helper: code exchange, refresh, revoke, user info. See also [docs/backend.md](docs/backend.md) for Node/Firebase. |

- Testing a full sign-in on a real device: [docs/real-device-testing.md](docs/real-device-testing.md)
- Backend code exchange (Dart, Node/Firebase, Supabase): [docs/backend.md](docs/backend.md)
- Manual QA checklist: [docs/qa-checklist.md](docs/qa-checklist.md)

## Development

This repo is a [pub workspace](https://dart.dev/tools/pub/workspaces) managed
with [melos](https://pub.dev/packages/melos).

```bash
flutter pub get                 # resolves every package at once
dart run melos run analyze      # strict analysis
dart run melos run format       # formatting check
dart run melos run test:flutter # Flutter package tests
dart run melos run test:dart    # pure Dart package tests
dart run melos run pigeon       # regenerate platform channels
```

See [NOTICE](NOTICE) for trademark and TikTok OpenSDK licence information.

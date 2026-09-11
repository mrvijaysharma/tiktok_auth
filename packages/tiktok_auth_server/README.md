# tiktok_auth_server

Server-side helpers for [TikTok Login Kit](https://developers.tiktok.com/doc/login-kit-overview),
in pure Dart. It works with Dart Frog, Shelf, Serverpod or any other Dart
backend.

It is the other half of [`tiktok_auth`](https://pub.dev/packages/tiktok_auth).
The app signs the user in and gets an authorization code; your server
exchanges the code for tokens. That step needs your client secret, which must
never ship inside an app.

> **Unofficial.** Not affiliated with or endorsed by TikTok.

## Usage

```dart
import 'dart:io';

import 'package:tiktok_auth_server/tiktok_auth_server.dart';

final tiktok = TikTokOAuthClient(
  clientKey: 'YOUR_CLIENT_KEY',
  clientSecret: Platform.environment['TIKTOK_CLIENT_SECRET']!,
);

// Values sent by the app (TikTokAuthorization from package:tiktok_auth).
final tokens = await tiktok.exchangeCode(
  code: body['code'],
  codeVerifier: body['codeVerifier'],
  redirectUri: body['redirectUri'],
);

final user = await tiktok.getUserInfo(
  tokens.accessToken,
  fields: {TikTokUserField.openId, TikTokUserField.displayName},
);
```

- Use `tokens.openId` as the user's ID in your system.
- Store `tokens.refreshToken` if you call TikTok APIs later.
- `refresh()` may return a **new** refresh token. Always store the newest one.
- Failures throw `TikTokApiException`. It carries TikTok's `error`,
  `description` and `logId`; include the `logId` when contacting TikTok support.

## Security checklist

- Only accept `redirectUri` values you registered. Don't trust whatever the
  client sends.
- Exchange each code once. Codes expire after a few minutes.
- Never return the client secret or the refresh token to the app unless you
  need to.

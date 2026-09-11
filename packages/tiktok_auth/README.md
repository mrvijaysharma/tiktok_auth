# tiktok_auth

[![pub package](https://img.shields.io/pub/v/tiktok_auth.svg)](https://pub.dev/packages/tiktok_auth)
[![CI](https://github.com/mrvijaysharma/tiktok_auth/actions/workflows/ci.yaml/badge.svg)](https://github.com/mrvijaysharma/tiktok_auth/actions/workflows/ci.yaml)

Sign users in with **TikTok** in Flutter apps on Android and iOS.

`tiktok_auth` wraps the official
[TikTok OpenSDK](https://developers.tiktok.com/doc/login-kit-overview) Login Kit
and handles the details that usually break TikTok login:

- ✅ **Official SDKs.** iOS 2.5.0 (Swift Package Manager and CocoaPods) and
  Android 2.4.0.
- ✅ **PKCE and CSRF `state` handled for you.** You get the auth code *and*
  the code verifier your backend needs.
- ✅ **No AppDelegate, SceneDelegate or MainActivity changes.** The plugin
  registers its own lifecycle hooks and callback activity.
- ✅ **Never hangs.** Backing out of TikTok or the browser completes with
  `TikTokAuthErrorCode.cancelled`.
- ✅ **Setup mistakes are caught early.** `initialize()` reports a missing
  Info.plist key, a wrong redirect URI and similar problems in plain words.
- ✅ **Typed API.** `TikTokScope`, `TikTokAuthorization`, `TikTokAuthException`,
  plus a fake for your own tests.

> **Unofficial.** Not affiliated with or endorsed by TikTok.

| Platform | Support |
|---|---|
| Android | API 24+ |
| iOS | 15.0+ |
| Web, macOS, Windows, Linux | Planned |

## How TikTok Login works

```
app ──signIn()──▶ TikTok app (or a secure browser tab if it isn't installed)
app ◀── auth code ── via your https redirect URI (Universal Link / App Link)
app ──auth code + code verifier──▶ YOUR BACKEND ──▶ TikTok token endpoint
```

Your backend performs the token exchange because it needs your **client
secret**, which must never ship inside an app.

## Setup

### 1. Register your app with TikTok

1. In the [TikTok developer portal](https://developers.tiktok.com/apps),
   create an app and add **Login Kit**.
2. Under **iOS**, register your bundle ID.
3. Under **Android**, register your package name and signing certificate
   fingerprints. Add the debug key, your release key **and** the Google Play
   App Signing key.
4. Add your redirect URI, for example `https://example.com/tiktok/callback`.
   It must be `https`, static (no query or `#`), and on a domain you control.
5. Use **Sandbox** mode and add your own TikTok account as a target user
   while developing.

### 2. Verify your domain for your app

TikTok returns to your app by opening the redirect URI, so it must be a
Universal Link (iOS) and App Link (Android). Host these two files on the
redirect domain, over https, with no redirects:

`https://example.com/.well-known/apple-app-site-association`

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["TEAMID.com.example.app"],
        "components": [{ "/": "/tiktok/callback*" }]
      }
    ]
  }
}
```

`https://example.com/.well-known/assetlinks.json`

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.example.app",
      "sha256_cert_fingerprints": ["AB:CD:...:EF"]
    }
  }
]
```

### 3. Android

In `android/app/build.gradle.kts`, tell the plugin the host and path of your
redirect URI. Write the path **without** the leading slash:

```kotlin
android {
    defaultConfig {
        // For https://example.com/tiktok/callback
        manifestPlaceholders["tiktokRedirectHost"] = "example.com"
        manifestPlaceholders["tiktokRedirectPath"] = "tiktok/callback"
    }
}
```

If these don't match the redirect URI, `initialize()` throws a
`misconfigured` error that shows the exact values to use.

The plugin adds the App Link callback activity and the `<queries>` entries
needed to detect the TikTok app. It also makes the TikTok Maven repository
(`https://artifact.bytedance.com/repository/AwemeOpenSDK`) available to your
build.

### 4. iOS

1. Add these keys to `ios/Runner/Info.plist`, replacing `YOUR_CLIENT_KEY`:

   ```xml
   <key>TikTokClientKey</key>
   <string>YOUR_CLIENT_KEY</string>
   <key>LSApplicationQueriesSchemes</key>
   <array>
     <string>tiktokopensdk</string>
     <string>snssdk1180</string>
     <string>snssdk1233</string>
   </array>
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleURLSchemes</key>
       <array>
         <string>YOUR_CLIENT_KEY</string>
       </array>
     </dict>
   </array>
   ```

2. In Xcode, add the **Associated Domains** capability to the Runner target
   with `applinks:example.com`. This requires a paid Apple Developer account.

### 5. Sign in

```dart
import 'package:tiktok_auth/tiktok_auth.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TikTokAuth.instance.initialize(
    const TikTokAuthConfig(
      clientKey: 'YOUR_CLIENT_KEY',
      redirectUri: 'https://example.com/tiktok/callback',
    ),
  );
  runApp(const MyApp());
}

Future<void> signInWithTikTok() async {
  try {
    final auth = await TikTokAuth.instance.signIn(
      scopes: {TikTokScope.userInfoBasic},
    );
    await myBackend.loginWithTikTok(
      code: auth.authCode,
      codeVerifier: auth.codeVerifier,
      redirectUri: auth.redirectUri,
    );
  } on TikTokAuthException catch (e) {
    if (e.code == TikTokAuthErrorCode.cancelled) return; // user backed out
    showError(e.message);
  }
}
```

### 6. Exchange the code on your backend

```bash
curl -X POST 'https://open.tiktokapis.com/v2/oauth/token/' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode "client_key=$CLIENT_KEY" \
  --data-urlencode "client_secret=$CLIENT_SECRET" \
  --data-urlencode "code=$CODE" \
  --data-urlencode 'grant_type=authorization_code' \
  --data-urlencode "redirect_uri=$REDIRECT_URI" \
  --data-urlencode "code_verifier=$CODE_VERIFIER"
```

The response contains `access_token` (valid for 24 hours), `refresh_token`
(365 days), `open_id` and `scope`. When you refresh, always store the returned
`refresh_token`: TikTok may rotate it.

### 7. Check your setup

Most TikTok Login problems are setup problems. Add your values to
`pubspec.yaml`:

```yaml
tiktok_auth:
  client_key: YOUR_CLIENT_KEY
  redirect_uri: https://example.com/tiktok/callback
```

Then run the doctor from your app's directory:

```bash
dart run tiktok_auth:doctor
```

It checks:
- **iOS:** Info.plist keys, the Associated Domains entitlement, and your
  `apple-app-site-association` file.
- **Android:** the manifest placeholders and your `assetlinks.json` file.

It also prints the SHA-256 and MD5 fingerprints of your debug and release keys
so you can register them with TikTok. It exits with code 1 when it finds an
error, so you can run it in CI. Use `--offline` to skip the network checks.

## Errors

`signIn()` throws a `TikTokAuthException`. Its `code` is one of:

| Code | Meaning |
|---|---|
| `cancelled` | The user closed TikTok or the browser without deciding. |
| `denied` | The user declined on the consent screen. |
| `misconfigured` | Client key, redirect URI, Universal/App Links, bundle ID, package name or certificate mismatch. The message says what is wrong. |
| `stateMismatch` | TikTok's response failed the CSRF check and was discarded. |
| `alreadyInProgress` | `signIn()` was called while another sign-in was running. |
| `notInitialized` | `initialize()` was not called. |
| `network` | The browser flow lost connectivity. |
| `unsupported` | The platform is not supported yet. |
| `failed` | Anything else. See `nativeCode` and `description`. |

## Testing your app

```dart
import 'package:tiktok_auth/testing.dart';
import 'package:tiktok_auth/tiktok_auth.dart';

setUp(() {
  TikTokAuthPlatform.instance = FakeTikTokAuthPlatform()
    ..respondWithSuccess(authCode: 'test-code');
  TikTokAuth.instance.debugReset();
});
```

Use `respondWithError(PlatformAuthErrorKind.cancelled)` and similar to test
failure paths.

## Troubleshooting

- **TikTok opens but never returns to the app.** The redirect URI is not a
  verified Universal Link / App Link. Check the two files from step 2. On
  Android, run
  `adb shell pm get-app-links com.example.app` and look for `verified`.
- **Error 10033 "App certificate does not match configurations" (Android).**
  Register the SHA-256 and MD5 fingerprints of every key that signs your app:
  debug, release and Google Play App Signing.
- **The browser opens even though TikTok is installed (iOS).** Check
  `LSApplicationQueriesSchemes` in Info.plist.

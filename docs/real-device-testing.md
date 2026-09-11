# Testing a full sign-in on a real device

A real TikTok sign-in needs four things:

- **A TikTok developer app** with Login Kit. Sandbox mode is fine.
- **An https domain you control.** It hosts the redirect URI and the files that
  prove the domain belongs to your app.
- **An Android phone.** The TikTok app is optional; without it the browser
  sign-in is used.
- **For iOS only:** a paid Apple Developer team, needed for Universal Links.

If TikTok is blocked where you are, turn on a VPN on the computer you use for
the developer portal and on the phone.

## 1. Host the verification files

Any https domain works. A free option is a GitHub Pages user site,
`https://<username>.github.io`:

1. Create a public repository named exactly `<username>.github.io`.
2. Add these files:
   - `.nojekyll`: an empty file. Without it, Pages does not publish
     `.well-known`.
   - `.well-known/assetlinks.json` for Android (below).
   - `.well-known/apple-app-site-association` for iOS (below). It has no file
     extension.
3. In the repository, go to **Settings > Pages** and deploy from the `main`
   branch, root folder.

Your redirect URI is then `https://<username>.github.io/tiktok/callback`.

**`assetlinks.json`.** Get the SHA-256 from the "Android signing certificates"
section of `dart run tiktok_auth:doctor --offline`:

```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "dev.tiktokauth.example",
    "sha256_cert_fingerprints": ["<SHA-256 of your debug key>"]
  }
}]
```

**`apple-app-site-association`:**

```json
{"applinks": {"details": [{
  "appIDs": ["<TEAMID>.dev.tiktokauth.example"],
  "components": [{"/": "/tiktok/callback*"}]
}]}}
```

## 2. Create the TikTok app

In the [TikTok developer portal](https://developers.tiktok.com/apps):

1. Create an app, add **Login Kit**, and keep it in **Sandbox**. If the portal
   asks, add the TikTok account you will test with as a test user.
2. Add the platforms:
   - **Android:** package name `dev.tiktokauth.example`, plus your signing key
     signature. The doctor prints both SHA-256 and MD5; use the format the
     portal asks for.
   - **iOS:** bundle ID `dev.tiktokauth.example`.
3. Set the redirect URI to `https://<username>.github.io/tiktok/callback`.
4. Copy the **client key**. Keep the client secret for your server only.

## 3. Configure the example app

In `packages/tiktok_auth/example`:

| File | Set |
|---|---|
| `lib/tiktok_config.dart` | `clientKey` and `redirectUri` |
| `pubspec.yaml`, in the `tiktok_auth:` section | the same two values, which the doctor reads |
| `android/app/build.gradle.kts` | `tiktokRedirectHost = "<username>.github.io"` and `tiktokRedirectPath = "tiktok/callback"` |
| `ios/Runner/Info.plist` | `TikTokClientKey` and the client key URL scheme |
| In Xcode: Runner > Signing & Capabilities | your team, and Associated Domains `applinks:<username>.github.io` |

## 4. Check, then run

```bash
dart run tiktok_auth:doctor
```

Fix everything it reports. On Android, confirm the phone has verified the
domain:

```bash
adb shell pm verify-app-links --re-verify dev.tiktokauth.example
```

```bash
adb shell pm get-app-links dev.tiktokauth.example
```

The domain should show `verified`. Then run `flutter run` and sign in. The app
shows the authorization code. Exchange it on a server with
[`tiktok_auth_server`](../packages/tiktok_auth_server) or
[docs/backend.md](backend.md). Never put the client secret in the app.

Finally, work through [qa-checklist.md](qa-checklist.md).

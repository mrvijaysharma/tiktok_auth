# `tiktok_auth` — Plan for the best TikTok Login package for Flutter

_Research date: 2026-09-11. Sources: TikTok developer docs, the official open-source SDKs
(`github.com/tiktok/tiktok-opensdk-ios` and `github.com/tiktok/tiktok-opensdk-android`),
pub.dev, and GitHub issues._

---

## 1. Reality check: what exists today

There **are** already TikTok login packages on pub.dev. However, none of them is good, so the
opportunity is real. We are not building the *first* one; we are building the **first
maintained, well-engineered** one.

| Package | Latest | Adoption | Problems |
|---|---|---|---|
| `tiktok_sdk_v2` | 0.0.3 (~15 months old) | 6 likes, ~38 downloads/week | Unverified publisher. 6 open issues: crash after upgrade (#10), iOS error (#8), Android crash (#9), **"can't redirect back to app"** (#6, #11). Requires manual AppDelegate edits. No PKCE docs. |
| `tiktok_login_flutter` | 1.0.0 (3 years old) | 13 likes | Abandoned; predates the v2 SDKs. |
| `tiktok_sdk_login_share` | 1.0.2 | 0 likes | Unverified; no PKCE/state docs. |
| `tiktok_api` | 0.0.13 (2 years old) | 4 likes | Self-described "still in development", Android WIP, iOS alpha. |

The same pain points show up in the **official** native SDK repos too:
- Android #54, #50, #52, #47: "Chrome tab doesn't redirect back to app".
- Android #5: error 10033 "App certificate does not match configurations".
- iOS #28: web auth is used even when `isWebAuth = false`.

**Conclusion:** almost every failure is a *configuration* problem (App Links / Universal Links /
signatures / redirect URI), not a code problem. The best package wins by making configuration
**automatic where possible and verifiable where not**.

Package names checked on pub.dev and still free: `tiktok_auth`, `sign_in_with_tiktok`,
`tiktok_login`, `tiktok_sign_in`, `flutter_tiktok_auth`, `tiktok_login_kit`.

---

## 2. How TikTok Login actually works (verified from SDK source)

```
Flutter app ──signIn()──▶ native SDK ──▶ TikTok app installed?
                                           ├─ yes → TikTok app consent screen
                                           └─ no  → iOS: ASWebAuthenticationSession
                                                    Android: Chrome Custom Tab
          ◀── auth code + granted scopes ◀─ redirect via https Universal Link / App Link
Flutter app ──(authCode, codeVerifier)──▶ YOUR BACKEND
YOUR BACKEND ──POST open.tiktokapis.com/v2/oauth/token/ (client_key, client_secret,
               code, grant_type=authorization_code, redirect_uri, code_verifier)
             ◀── access_token (24h), refresh_token (365d), open_id, scope
```

### Key facts that shape the design

| Fact | Source | Impact |
|---|---|---|
| Token exchange **requires `client_secret`** even with PKCE | Token docs | The package must **never** exchange the code on-device. It returns `authCode` + `codeVerifier` for your server. |
| PKCE challenge = **hex-encoded SHA-256** (not base64url) | `PKCE.swift`, `PKCEUtils.kt`, desktop docs | Any pure-Dart flow (web/desktop) must use hex, or TikTok rejects it. |
| iOS SDK generates the verifier itself (`authRequest.pkce.codeVerifier`, read-only) | `TikTokAuthRequest.swift` | Native code must *return* the verifier to Dart; Dart cannot choose it on iOS. |
| Android: Dart/Kotlin must supply `codeVerifier` in `AuthRequest` | `AuthRequest.kt` | Generate it with `PKCEUtils.generateCodeVerifier()` and return it. |
| iOS `TikTokAuthRequest` must be **strongly retained** until the callback | `deinit` removes the request | A classic bug: if the request is deallocated, the callback never arrives. |
| iOS web fallback callback scheme = `<clientKey>://response.bridge.tiktok.com/oauth` | `TikTokInfo.swift` | This is why the client key must be registered in `CFBundleURLSchemes`. |
| Android `AuthMethod.TikTokApp` auto-falls back to Chrome Tab if TikTok isn't installed | `AuthApi.kt` | There's a single entry point, plus an optional "force web" flag. |
| Android matches the redirect with `startsWith(redirectUri)`; iOS with `hasPrefix` | SDK source | A trailing `/` mismatch silently breaks the login. Validate this. |
| Android sends the app's SHA-256 signing cert with every request | `WebAuthHelper.kt` | The portal signature must match the debug, release **and Play App Signing** keys. |
| Redirect URI must be `https`, static, no `#`, < 512 chars, max 10 per app | Web docs | Validate at `initialize()`. |
| Refresh token may **rotate** on refresh | Token docs | Document this for backends. |
| TikTok is not OIDC (no `id_token`) | Docs | Firebase/Supabase need a custom-token flow, not a built-in provider. |

### Native SDK versions to target
- **iOS:** `TikTokOpenAuthSDK` + `TikTokOpenSDKCore` **2.5.0**. Available via SPM and CocoaPods;
  iOS 12+ (our minimum is Flutter's own minimum). Ships a Privacy Manifest.
- **Android:** `com.tiktok.open.sdk:tiktok-open-sdk-auth` + `-core` **2.4.0** from
  `https://artifact.bytedance.com/repository/AwemeOpenSDK`.
  - Bytecode-diffed: 2.4.0 is **identical to 2.3.0** except the version string.
  - "2.3.1" (GitHub release notes) was never published to Maven.
  - The POMs declare **no dependencies**, so we must add `androidx.browser` ourselves.
  - **Decision:** use 2.4.0, pinned. See IMPLEMENTATION_PLAN.md.
- **License:** both SDKs allow redistribution "in connection with TikTok services" with the
  copyright notice kept. That makes vendoring legal if we ever need it (see §9).

---

## 3. What makes ours "the best": differentiators

1. **Zero AppDelegate / MainActivity edits.**
   - iOS: the plugin registers as an application **and** scene lifecycle delegate and calls
     `TikTokURLHandler.handleOpenURL` itself.
   - Android: the plugin ships its own `TikTokAuthCallbackActivity` with an App Link intent-filter
     driven by **manifest placeholders**, the way `flutter_appauth` does it:
     ```kotlin
     // android/app/build.gradle.kts
     defaultConfig {
         manifestPlaceholders["tiktokRedirectHost"] = "example.com"
         manifestPlaceholders["tiktokRedirectPath"] = "/tiktok/callback"
     }
     ```
   - This also keeps the callback away from `MainActivity`, which avoids clashes with Flutter's
     built-in deep linking, go_router, and `app_links`.
2. **Automatic `<queries>`** for `com.zhiliaoapp.musically`, `com.ss.android.ugc.trill`, and
   Custom Tabs. These are merged from the plugin manifest, so users add nothing.
3. **PKCE + CSRF `state` handled for you.** The package generates a cryptographically random
   `state`, verifies it on return, and returns the `codeVerifier`.
4. **Never hangs.** The existing packages' futures hang forever when the user backs out of
   the Custom Tab or app-switches back (tiktok_sdk_v2 #11). We detect "app resumed with no
   callback" and complete with `TikTokAuthErrorCode.cancelled`.
5. **Survives process death.** Low-memory Android devices kill the app while TikTok is open.
   The pending `state`/`codeVerifier` is persisted, and `getPendingResult()` recovers the result
   after a relaunch.
6. **`dart run tiktok_auth:doctor`**: a CLI that checks the #1 cause of every open issue.
   - Info.plist: `TikTokClientKey`, `LSApplicationQueriesSchemes`
     (`tiktokopensdk`, `snssdk1180`, `snssdk1233`), and the client-key URL scheme.
   - `Runner.entitlements`: `applinks:<host>`.
   - Fetches `https://<host>/.well-known/apple-app-site-association` and checks the
     `TEAMID.bundleId` and path.
   - Fetches `https://<host>/.well-known/assetlinks.json` and checks the package name plus
     SHA-256 fingerprints.
   - Prints the local debug/release keystore **MD5 + SHA-256** to paste into the TikTok portal.
     Reminds you about the Play App Signing key (the fix for error 10033).
   - Validates the redirect URI: https, no `#`, length, consistent trailing slash.
7. **Typed, modern Dart API.** Typed scopes, a typed error enum, full dartdoc, and a fake for
   app developers' tests (`package:tiktok_auth/testing.dart`).
8. **Backend + Firebase/Supabase recipes.**
   - A small pure-Dart `tiktok_auth_server` package for the token exchange, refresh, revoke, and
     `/v2/user/info/`.
   - Copy-paste Cloud Function examples (Node): exchange code →
     `createCustomToken('tiktok:' + open_id)` → `signInWithCustomToken`.
9. **All platforms eventually:** Android and iOS first, then web and desktop (desktop Login Kit
   uses a loopback redirect + PKCE, which is possible in pure Dart).
10. **Verified publisher, 160/160 pub points, CI, semver, CHANGELOG, issue templates** that ask
    for `doctor` output.

---

## 4. Architecture

A federated plugin in one monorepo, using **Dart pub workspaces**. This is the same structure
as `google_sign_in`.

```
tiktok_auth/                        (repo root, pub workspace)
├── packages/
│   ├── tiktok_auth/                ← app-facing package users depend on
│   │   ├── lib/tiktok_auth.dart
│   │   ├── lib/testing.dart        ← FakeTikTokAuth for users' tests
│   │   ├── bin/doctor.dart         ← `dart run tiktok_auth:doctor`
│   │   └── example/                ← full demo app
│   ├── tiktok_auth_platform_interface/
│   ├── tiktok_auth_android/        ← Kotlin, wraps official SDK
│   ├── tiktok_auth_ios/            ← Swift, SPM (Package.swift) + CocoaPods (podspec)
│   ├── tiktok_auth_web/            ← phase 3
│   ├── tiktok_auth_desktop/        ← phase 3 (pure Dart loopback + PKCE)
│   └── tiktok_auth_server/         ← pure Dart backend helper (no Flutter dependency)
├── docs/                           ← setup guides, troubleshooting, Firebase recipe
├── .github/workflows/ci.yaml
└── PLAN.md
```

- **Dart ↔ native:** use **Pigeon** for type-safe channels. No hand-written string method names.
- **Toolchain:** the current `flutter create --template=plugin` (Flutter 3.47) gives
  `build.gradle.kts`, `compileSdk 36`, `minSdk 24`, JVM 17, Kotlin 2.4, and `ios/<name>/Package.swift`.
  We start from that template.
- **iOS package managers:** ship both SPM and CocoaPods. SPM is Flutter's direction; CocoaPods
  stays for existing apps.

---

## 5. Public Dart API (draft)

```dart
import 'package:tiktok_auth/tiktok_auth.dart';

// 1. Once, at startup.
await TikTokAuth.instance.initialize(
  const TikTokAuthConfig(
    clientKey: 'awxxxxxxxxxxxx',                            // from TikTok portal
    redirectUri: 'https://example.com/tiktok/callback',     // registered in portal
  ),
);

// 2. Sign in.
try {
  final auth = await TikTokAuth.instance.signIn(
    scopes: {TikTokScope.userInfoBasic, TikTokScope.userInfoProfile},
    // optional:
    preferWebAuth: false,       // force browser even if TikTok app is installed
    disableAutoAuth: false,     // always show consent screen
    language: 'en',
  );

  // 3. Send to YOUR backend (needs client_secret, so never do this on-device).
  await myApi.loginWithTikTok(
    code: auth.authCode,
    codeVerifier: auth.codeVerifier,
    redirectUri: auth.redirectUri,
  );
  print(auth.grantedScopes);    // user may grant fewer scopes than requested
} on TikTokAuthException catch (e) {
  switch (e.code) {
    case TikTokAuthErrorCode.cancelled:   /* user backed out, silent */ break;
    case TikTokAuthErrorCode.denied:      /* user tapped "Cancel" */ break;
    case TikTokAuthErrorCode.stateMismatch:
    case TikTokAuthErrorCode.invalidRedirect:
    case TikTokAuthErrorCode.notConfigured:
    case TikTokAuthErrorCode.alreadyInProgress:
    case TikTokAuthErrorCode.unsupported:
    case TikTokAuthErrorCode.network:
    case TikTokAuthErrorCode.unknown:
      showError(e.message);       // includes native code + TikTok error_description
  }
}

// Extras
await TikTokAuth.instance.isTikTokInstalled();
await TikTokAuth.instance.getPendingResult();   // after process death
```

Model types:
- `TikTokAuthorization`: `authCode`, `codeVerifier`, `state`, `grantedScopes`, `redirectUri`,
  `usedWebAuth`.
- `TikTokScope`: constants `userInfoBasic`, `userInfoProfile`, `userInfoStats`, `videoList`,
  `videoUpload`, `videoPublish`, plus `TikTokScope.custom('...')` so we don't block new scopes.
- `TikTokAuthException(code, message, nativeCode, details)`: maps
  - iOS `TikTokAuthResponseErrorCode` (0, −1, −2 cancelled, −3, −4 denied, −5, −8, 10005), and
  - Android `authError` / `errorCode`, including 10033 → a message pointing at signature setup.

---

## 6. Native implementation details

### iOS (`tiktok_auth_ios`, Swift)
- Depend on `TikTokOpenAuthSDK` + `TikTokOpenSDKCore` 2.5.0 in both `Package.swift` and `.podspec`.
- In `register(with:)`, call `registrar.addApplicationDelegate(self)` and add the scene-delegate
  registration used by Flutter's UIScene lifecycle. Implement:
  - `application(_:open:options:)`,
  - `application(_:continue:restorationHandler:)`, and
  - `scene(_:openURLContexts:)` / `scene(_:continue:)`.
  Each forwards to `TikTokURLHandler.handleOpenURL`. **Only claim URLs that match our redirect
  URI or `<clientKey>://`**, so other deep links still reach the app.
- Keep the `TikTokAuthRequest` in a property until the completion fires. Reject concurrent calls.
- Set `request.state`, then read `request.pkce.codeVerifier` and return it to Dart.
- On `applicationDidBecomeActive` with a pending request and no callback, wait a short grace
  period, then complete as `cancelled`. Native flow only; ASWebAuthenticationSession reports
  cancellation itself.
- Note: if `TikTokClientKey` is missing from Info.plist, the web fallback silently breaks.
  Check it in `initialize()` and throw `notConfigured`.

### Android (`tiktok_auth_android`, Kotlin)
- `implementation("com.tiktok.open.sdk:tiktok-open-sdk-auth:<pinned>")` (`-core` comes transitively).
- **Maven repo problem:** the ByteDance repo must be visible to the *app* project. The plugin's
  Gradle file adds it via `rootProject.allprojects { repositories { maven(...) } }`. The README
  documents the manual line as a fallback (for `FAIL_ON_PROJECT_REPOS` setups).
- The plugin implements `ActivityAware`, `PluginRegistry.NewIntentListener`, and
  `ActivityResultListener`. It handles **all three return paths**:
  1. `onActivityResult`, because the SDK uses `startActivityForResult` for the native flow.
  2. `onNewIntent` / the launch intent.
  3. Our `TikTokAuthCallbackActivity`, a transparent, `exported`, `autoVerify="true"` activity
     whose intent-filter uses `${tiktokRedirectHost}` / `${tiktokRedirectPath}`. It forwards
     the data URI to the plugin, then brings the Flutter activity to the front.
- Generate the verifier with `PKCEUtils.generateCodeVerifier()`. Build
  `AuthRequest(clientKey, scope, redirectUri, codeVerifier, state=…, autoAuthDisabled, language)`.
  Call `authApi.authorize(req, if (preferWeb) ChromeTab else TikTokApp)`.
- Parse with `authApi.getAuthResponseFromIntent(intent, redirectUri)`.
- Persist `{state, codeVerifier, redirectUri}` in `SharedPreferences` while pending, for
  process-death recovery. Clear it on completion.
- Resume-without-result detection, the same as iOS.
- Test on Xiaomi/Oppo/Vivo ROMs (tiktok_sdk_v2 #6: "Chinese OEM phones can't return").

---

## 7. What the package user must still do (and our docs must make painless)

1. Create a TikTok developer app. Add **Login Kit**. Register the iOS bundle ID and Android
   package name + signature(s). Register the https redirect URI. Use Sandbox + target users
   while testing, then submit for review.
2. Host two files on the redirect domain. Firebase Hosting or Cloudflare Pages is easiest:
   - `/.well-known/apple-app-site-association`
   - `/.well-known/assetlinks.json`
3. **iOS:** add the Info.plist keys (the doctor prints the exact XML) and the Associated Domains
   capability `applinks:<host>`.
4. **Android:** set two `manifestPlaceholders`.
5. **Backend:** exchange the code (a Dart / Node / Python snippet for each).
6. Run `dart run tiktok_auth:doctor` and see everything green.

If Flutter deep linking or go_router is enabled, document that the callback path must be
ignored by the router. On Android our separate callback activity avoids this. On iOS the plugin
consumes the URL before Flutter's router sees it.

---

## 8. Roadmap

### Phase 0: Groundwork (1–2 days)
- [ ] TikTok developer account + app with Login Kit; Sandbox with your own test account.
- [ ] Buy/choose a domain. It is used for the redirect URI, well-known files, the docs site,
      **and** pub.dev verified publisher (verified through Google Search Console DNS).
- [ ] GitHub repo, pub workspace scaffold, CI skeleton, LICENSE (BSD-3-Clause, plus TikTok SDK
      notice in NOTICE).
- [ ] Decide the Android SDK version (2.3.1 vs 2.4.0) after a quick smoke test.

### Phase 1: MVP `0.1.0` (Android + iOS)
- [ ] Platform interface + Pigeon definitions.
- [ ] iOS implementation (SPM + CocoaPods, lifecycle delegates, strong ref, state, verifier).
- [ ] Android implementation (placeholders, callback activity, 3 return paths).
- [ ] Typed errors, scope types, `isTikTokInstalled()`.
- [ ] Example app + a tiny backend stub showing the full exchange and `/v2/user/info/`.
- [ ] README with a 5-minute setup; `CHANGELOG.md`; dartdoc on every public API.
- [ ] Publish `0.1.0`.

### Phase 2: "Best package" features (`0.2`–`0.5`)
- [ ] `doctor` CLI.
- [ ] Never-hang cancellation + process-death recovery (`getPendingResult`).
- [ ] `package:tiktok_auth/testing.dart` fake.
- [ ] `tiktok_auth_server` (exchange, refresh with rotation, revoke, user info).
- [ ] Firebase Auth + Supabase recipes.
- [ ] Troubleshooting page mapped to real errors (10033, redirect not returning, etc.).

### Phase 3: `1.0.0`
- [ ] Web: redirect/popup to `https://www.tiktok.com/v2/auth/authorize/` (web has no PKCE; the
      server holds the secret).
- [ ] macOS/Windows/Linux: loopback `http://127.0.0.1:<port>/callback/`, PKCE with **hex**
      S256.
- [ ] Verified publisher, 160/160 pub points, API frozen, 1.0 release.

### Phase 4: Optional
- [ ] Share Kit as a **separate** package (`tiktok_share`), so the auth package stays small.
- [ ] Official "Continue with TikTok" button, **only** if TikTok's brand guidelines allow it.

---

## 9. Quality, testing, CI

- **Dart unit tests:** state/verifier logic, error mapping, redirect-URI validation, PKCE hex
  challenge, doctor parsers (Info.plist, manifest, AASA, assetlinks).
- **Native unit tests:** Kotlin (JUnit/Robolectric) for intent parsing and resume-cancel logic;
  XCTest for URL matching and error mapping.
- **Manual test matrix** (real TikTok login can't be reliably automated):

  | | TikTok installed | Not installed (web) |
  |---|---|---|
  | Approve / Deny / Back out | Android + iOS | Android + iOS |
  | Cold start / process death | Android | Android |
  | Fewer scopes granted | both | both |
  | Chinese OEM ROM | Android | Android |

- **CI (GitHub Actions):**
  - `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test`.
  - Build example APK + iOS (`--no-codesign`) with SPM **and** CocoaPods.
  - `pana` score gate.
  - `dart pub publish --dry-run`.
  - Renovate/Dependabot to watch the native SDK versions.
- **Plan B for Android distribution:** if `artifact.bytedance.com` proves unreliable (Android
  issue #55, "failed download"), vendor the auth+core SDK sources. The license allows it; keep
  the notice.

---

## 10. Risks and open decisions

| Item | Recommendation |
|---|---|
| Package name | **`tiktok_auth`** (matches this folder). `sign_in_with_tiktok` is the alternative, mirroring `sign_in_with_apple`. Both free. |
| "TikTok" trademark | Add "Unofficial; not affiliated with TikTok" to the README and pubspec description. Don't ship TikTok logos without checking the brand guidelines. |
| Android SDK 2.4.0 has no changelog | Pin exactly; test before choosing. |
| TikTok is region-blocked (e.g. India) | Portal and web-auth testing need a VPN on the dev machine **and** the test device. The native-app flow needs the TikTok app, which may not be installable from local stores. Budget time for test-device setup. |
| TikTok app review for Login Kit | Start the review early; Sandbox mode covers development. |
| Scope creep (Share Kit) | Keep it out of v1. |

---

## 11. Immediate next steps

1. Confirm the name + license (§10).
2. Scaffold the pub workspace with the federated packages from the Flutter 3.47 plugin template.
3. Write the Pigeon interface and the Dart API from §5.
4. Implement iOS, then Android, against a real TikTok Sandbox app.

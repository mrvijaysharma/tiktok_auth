# `tiktok_auth` — Implementation Plan

This is the *how*. The *why* (research, competitors, SDK facts) is in [PLAN.md](PLAN.md).
Every version and API below was checked on 2026-09-11 against the local Flutter 3.47 SDK,
pub.dev, and the official TikTok SDK binaries and source.

---

## 0. Locked decisions

| Topic | Decision | Reason |
|---|---|---|
| Package name | `tiktok_auth` | Chosen by owner; free on pub.dev |
| Structure | Federated plugin in one **pub workspace** monorepo | Same structure as `google_sign_in`; lets web/desktop be added cleanly |
| Monorepo tooling | Dart pub workspaces + **melos 8.7** (scripts, versioning) | melos 8 sits on top of pub workspaces |
| Dart ↔ native | **Pigeon 28.1** (type-safe; no string method names) | Pigeon 28 needs Dart ≥ 3.11 |
| Minimum SDK | Dart `^3.11.0`, Flutter `>=3.41.0` | 3.41 is the oldest verified version with `addSceneDelegate`. Try lowering in CI later. |
| iOS | iOS **15.0**, Swift 5.9, **SPM + CocoaPods** | Matches the Flutter 3.47 plugin template |
| iOS TikTok SDK | `TikTokOpenAuthSDK` + `TikTokOpenSDKCore` **2.5.0** | Latest release; ships a Privacy Manifest |
| Android | `minSdk 24`, `compileSdk 36`, JVM 17, Kotlin 2.4, AGP 9.1 | Matches the Flutter 3.47 plugin template |
| Android TikTok SDK | `com.tiktok.open.sdk:tiktok-open-sdk-{core,auth}:2.4.0` | Bytecode-diffed: **identical to 2.3.0** except the version string. "2.3.1" was never published. |
| Android extra deps | We **must** declare `androidx.browser` (+ Parcelize runtime if R8 asks) | The TikTok POMs declare **zero** dependencies, but the bytecode uses `androidx.browser.customtabs` and `kotlinx.parcelize` |
| Lints | `very_good_analysis` 11 | Strict lints give max pub points and fewer bugs |
| Tests | `flutter_test`, `mocktail`; JUnit5 + Mockito (template); XCTest | |
| License | **BSD-3-Clause** + `NOTICE` for the TikTok SDK licence | Flutter-ecosystem standard |
| Internal namespace | `dev.tiktokauth` (Android/Swift packages) | Internal only; safe to change before 1.0 |
| v0.x scope | **Android + iOS Login only**; web/desktop in 1.0; Share Kit never in this package | Ship a small, solid core first |

---

## Progress (updated 2026-09-11)

| Milestone | Status |
|---|---|
| M0 Scaffold | ✅ Done: git repo, pub workspace + melos, 4 packages from the Flutter 3.47 templates, CI workflow |
| M1 Dart core | ✅ Done: API, platform interface, test fake, 83 Dart tests passing, strict lints clean |
| M2 Android | ✅ Verified: debug APK and **R8 release APK** build, 7/7 Kotlin unit tests pass, and the merged manifest has the correct App Link intent-filter and `<queries>` |
| M3 iOS | ✅ Verified: the example builds for the iOS 26.5 simulator (SPM, TikTok SDK 2.5.0), 16/16 XCTests pass, and there are no Swift warnings (every app and scene lifecycle hook is connected). |
| End-to-end | ✅ The example shows "TikTok Login is configured" on the iPhone 17 Pro (iOS 26.5) simulator and on the Pixel 10 Pro emulator. This exercises plugin registration, Pigeon, the native config checks, and the Android App Link filter. On Android, backing out of the browser flow completed `signIn()` with `cancelled` (no hang). |
| M4 Real devices | 🟡 The Android browser path is verified on a vivo I2508 (Android 16, with VPN). TikTok's real sign-in page opens in a Custom Tab. Pressing Back returns `cancelled` after exactly the 500 ms grace period. A forged callback during a sign-in shows `stateMismatch` in the same app screen and closes the tab. **Found and fixed:** a redirect delivered in a separate task (the TikTok-app path) opened a second `MainActivity`, because Flutter sets `taskAffinity=""`. The callback now targets the app's existing task through `ActivityManager.AppTask`. A full login still needs the TikTok developer app and the redirect domain; see [docs/real-device-testing.md](docs/real-device-testing.md). |
| M7 Doctor | ✅ Done, pulled forward: `dart run tiktok_auth:doctor`. It has no new dependencies except `crypto`, 30 tests, and was verified against the example app (it reads the real keystore via keytool). |
| M8 Server | ✅ Done, pulled forward: `tiktok_auth_server` with PKCE code exchange, refresh (keeps the rotated refresh token), revoke and typed `/v2/user/info/`, plus 15 tests. `docs/backend.md` adds raw HTTP, Node/Firebase custom-token and Supabase guidance. |
| Publish readiness | ✅ `flutter pub publish --dry-run` gives 0 warnings for all 5 packages. This fixed a missing `meta` dependency in the Android and iOS packages (Pigeon's generated code imports it); only pub.dev's validation catches that. CI now runs the dry-run. |
| New laptop (MacBook Air, 2026-09-13) | ✅ Verified on fresh GitHub clones. All 186 tracked files are byte-identical to the local copy. Dart checks and 128 tests pass on Flutter 3.47.0 and 3.41.0. Both Android APKs build, the 7 Kotlin tests pass, and the iOS build passes its 16 XCTests. The history contains no private or AI-attribution content. Follow-up fixes: the doctor now flags placeholder client keys, CI runs the XCTests, and CONTRIBUTING is corrected. Still open for the owner: back up these private docs privately, and check that the global Flutter `ios-signing-cert` is theirs. |
| GitHub | ✅ Public at github.com/mrvijaysharma/tiktok_auth (commits `4cda87f` and `642bd74`), authored with the GitHub noreply email. `PLAN.md` and this file stay local through `.gitignore`. All 6 CI jobs pass, including Flutter 3.41.0 after Pigeon moved to `tool/pigeon` (it needs a newer `meta` than 3.41 pins). Formatting is checked on the latest Flutter only, and CI fails if the Pigeon bindings are out of date. |

Implementation notes for M2:
- Android App Link paths are given **without** the leading slash
  (`tiktokRedirectPath = "tiktok/callback"`). AAPT validates the plugin
  manifest before the placeholders are replaced, so the `/` is written in the
  manifest itself.
- The plugin's unit tests run with `isIncludeAndroidResources = false`, so
  they don't need the app-only placeholders.

### Design changes made during implementation

- **Android: activity that owns the attempt (AppAuth pattern).** `TikTokAuthActivity`
  launches the TikTok app or Custom Tab itself. Responses arrive through its
  `onActivityResult` / `onNewIntent`, and cancellation is detected exactly when it
  resumes without a response. This replaces the host-activity listeners and the
  resume-timer heuristic.
  - Reason: the Flutter 3.47 template sets `taskAffinity=""` on `MainActivity`,
    so "bring MainActivity to front" from a callback activity could create a
    second instance.
  - `TikTokAuthCallbackActivity` handles both cases: same-task redirects (Custom
    Tab) and new-task redirects (launched by the TikTok app).
- **Android: coroutines dependency.** `kotlinx-coroutines-android` is required
  because Pigeon 28 generates `suspend` Kotlin host methods, run on
  `Dispatchers.Main`.
- **Android: missing SDK dependencies.** `androidx.browser` is declared by us,
  because the TikTok SDK POMs declare no dependencies. `-dontwarn kotlinx.parcelize.**`
  is added as a consumer R8 rule.
- **Earlier robustness work.** Never-hang cancellation and process-death recovery
  (`PendingAuthStore` on both platforms) were pulled forward from M6 into M2/M3.
- **iOS options.** The iOS SDK has no `language` / `disableAutoAuth` options. They
  are documented as Android-only.
- **iOS lifecycle.** The plugin uses `addApplicationDelegate` and `addSceneDelegate`,
  including cold start through `scene(_:willConnectTo:options:)`. It claims only
  URLs that match the redirect URI or `<clientKey>://`.
- **Platform error codes.** The SDK error codes differ by platform (Android: −2
  denied, −3 cancelled; iOS: −2 cancelled, −4 denied). Each platform is mapped
  separately.
- **Server package deferred.** `tiktok_auth_server` is removed from the workspace
  until M8, so no empty package is ever published.

---

## 1. Repository layout

```
tiktok_auth/                                  ← git root (this folder)
├── pubspec.yaml                              ← workspace root + melos config
├── analysis_options.yaml                     ← very_good_analysis
├── LICENSE  NOTICE  README.md  CONTRIBUTING.md  PLAN.md  IMPLEMENTATION_PLAN.md
├── .github/
│   ├── workflows/ci.yaml                     ← analyze, test, build, pana
│   ├── workflows/publish.yaml                ← tag → pub.dev (OIDC automated publishing)
│   └── ISSUE_TEMPLATE/bug.yml                ← requires `doctor` output
├── docs/
│   ├── setup-tiktok-portal.md
│   ├── setup-ios.md  setup-android.md  setup-domain.md   ← AASA + assetlinks hosting
│   ├── backend.md                            ← Dart/Node/Python token exchange
│   ├── firebase.md  supabase.md
│   ├── troubleshooting.md                    ← maps real errors (10033, no-return…) to fixes
│   └── qa-checklist.md                       ← manual device test matrix
└── packages/
    ├── tiktok_auth/                          ← APP-FACING
    │   ├── lib/tiktok_auth.dart              ← exports
    │   ├── lib/testing.dart                  ← FakeTikTokAuth for users' tests
    │   ├── lib/src/tiktok_auth.dart          ← TikTokAuth singleton
    │   ├── lib/src/config.dart               ← TikTokAuthConfig + validation
    │   ├── lib/src/scope.dart                ← TikTokScope
    │   ├── lib/src/authorization.dart        ← TikTokAuthorization
    │   ├── lib/src/exception.dart            ← TikTokAuthException + TikTokAuthErrorCode
    │   ├── lib/src/state.dart                ← secure random state + constant-time compare
    │   ├── bin/doctor.dart                   ← `dart run tiktok_auth:doctor`
    │   ├── lib/src/doctor/…                  ← checks (plist, entitlements, manifest, AASA, assetlinks, keytool)
    │   ├── example/                          ← demo app (+ example/server for local exchange)
    │   └── test/
    ├── tiktok_auth_platform_interface/
    │   ├── lib/tiktok_auth_platform_interface.dart
    │   ├── lib/src/tiktok_auth_platform.dart ← abstract TikTokAuthPlatform (PlatformInterface)
    │   ├── lib/src/types.dart                ← AuthorizeRequest, AuthorizeResult, PlatformAuthError
    │   └── test/
    ├── tiktok_auth_android/
    │   ├── pigeons/messages.dart
    │   ├── lib/tiktok_auth_android.dart      ← TikTokAuthAndroid extends TikTokAuthPlatform
    │   ├── lib/src/messages.g.dart           ← generated
    │   └── android/
    │       ├── build.gradle.kts
    │       └── src/main/
    │           ├── AndroidManifest.xml       ← <queries> + callback activity (placeholders)
    │           └── kotlin/dev/tiktokauth/android/
    │               ├── TikTokAuthPlugin.kt
    │               ├── AuthCoordinator.kt
    │               ├── TikTokAuthCallbackActivity.kt
    │               ├── PendingAuthStore.kt
    │               ├── ErrorMapper.kt
    │               └── Messages.g.kt         ← generated
    ├── tiktok_auth_ios/
    │   ├── pigeons/messages.dart
    │   ├── lib/tiktok_auth_ios.dart          ← TikTokAuthIOS extends TikTokAuthPlatform
    │   └── ios/
    │       ├── tiktok_auth_ios.podspec
    │       └── tiktok_auth_ios/
    │           ├── Package.swift
    │           └── Sources/tiktok_auth_ios/
    │               ├── TikTokAuthPlugin.swift
    │               ├── AuthCoordinator.swift
    │               ├── URLRouter.swift
    │               ├── ConfigValidator.swift
    │               ├── PendingAuthStore.swift
    │               ├── ErrorMapper.swift
    │               ├── Messages.g.swift      ← generated
    │               └── PrivacyInfo.xcprivacy ← UserDefaults (CA92.1)
    ├── tiktok_auth_server/                   ← pure Dart; no Flutter dependency
    │   └── lib/src/{client.dart, models.dart, errors.dart}
    ├── tiktok_auth_web/                      ← M9
    └── tiktok_auth_desktop/                  ← M9 (macOS/Windows/Linux, loopback + PKCE)
```

---

## 2. Public Dart API (final shape for 0.1.0)

```dart
// Configure once.
await TikTokAuth.instance.initialize(const TikTokAuthConfig(
  clientKey: 'awxxxxxxxx',
  redirectUri: 'https://example.com/tiktok/callback',
));

// Sign in.
final TikTokAuthorization auth = await TikTokAuth.instance.signIn(
  scopes: {TikTokScope.userInfoBasic},
  preferWebAuth: false,     // Android: ChromeTab; iOS: isWebAuth
  disableAutoAuth: false,   // always show consent screen
  language: null,           // e.g. 'en'
);
// auth.authCode, auth.codeVerifier, auth.grantedScopes, auth.redirectUri, auth.usedWebAuth

// Helpers.
await TikTokAuth.instance.isTikTokInstalled();
await TikTokAuth.instance.getPendingAuthorization(); // result recovered after process death (M6)
```

```dart
enum TikTokAuthErrorCode {
  cancelled,          // user closed browser / came back without deciding
  denied,             // user tapped "Cancel"/"Deny" on consent
  misconfigured,      // bad redirect URI, missing plist keys, signature mismatch (10033)…
  stateMismatch,      // CSRF check failed
  alreadyInProgress,  // signIn() called while one is running
  notInitialized,     // initialize() not called
  network,            // web auth network failure
  failed,             // anything else; see nativeCode/details
}

class TikTokAuthException implements Exception {
  final TikTokAuthErrorCode code;
  final String message;          // human readable + fix hint when known
  final String? nativeCode;      // raw SDK error code / error string
  final String? description;     // TikTok error_description
}
```

**Scopes:** `TikTokScope` is a small value class with constants `userInfoBasic`,
`userInfoProfile`, `userInfoStats`, `videoList`, `videoUpload`, `videoPublish`, plus
`TikTokScope.custom('x.y')`. That way we never block new scopes.

**Who owns what:**
- **State** is generated in Dart with `Random.secure()` (32 bytes, base64url), then compared in
  Dart. It's one implementation, and unit-testable.
- **Code verifier** is owned by the native side, because the iOS SDK generates it internally.
  Android generates it with `PKCEUtils.generateCodeVerifier()`. Both return it in the result.
- **`initialize()` validation in Dart:** `https`, no `#`, < 512 chars, non-empty client key.
  Then native validation (§4, §5). Any problem throws `misconfigured` with a fix hint.

---

## 3. Pigeon contract (same in both platform packages)

```dart
class PlatformAuthRequest {
  PlatformAuthRequest({required this.clientKey, required this.redirectUri, required this.scopes,
    required this.state, required this.preferWebAuth, required this.disableAutoAuth, this.language});
  String clientKey; String redirectUri; List<String> scopes; String state;
  bool preferWebAuth; bool disableAutoAuth; String? language;
}

enum PlatformErrorKind { none, cancelled, denied, misconfigured, alreadyInProgress, network, failed }

class PlatformAuthResult {
  String? authCode; String? codeVerifier; String? state; String? expectedState;
  List<String>? grantedScopes; bool usedWebAuth;
  PlatformErrorKind errorKind; String? nativeCode; String? errorDescription;
}

@HostApi()
abstract class TikTokAuthHostApi {
  List<String> validateConfiguration(String clientKey, String redirectUri); // [] = OK
  bool isTikTokInstalled();
  @async PlatformAuthResult authorize(PlatformAuthRequest request);
  PlatformAuthResult? takePendingResult();  // process-death recovery (M6)
}
```

Errors come back as **data**, not as a `PlatformException`, so the mapping is typed end to end.

---

## 4. Android design (`tiktok_auth_android`)

### Gradle
```kotlin
// Make the ByteDance repo visible to the *app* (TikTok artifacts resolve there).
rootProject.allprojects {
    repositories { maven("https://artifact.bytedance.com/repository/AwemeOpenSDK") }
}
dependencies {
    implementation("com.tiktok.open.sdk:tiktok-open-sdk-core:2.4.0")
    implementation("com.tiktok.open.sdk:tiktok-open-sdk-auth:2.4.0")
    implementation("androidx.browser:browser:<latest stable>")   // POM omits it
    // + kotlin-parcelize-runtime only if R8/Runtime proves it's needed (spike)
}
```
**Spike S1 (first task of M2)** checks two things:
- The `rootProject.allprojects` injection works with the Flutter 3.47 app template.
- A `--release` (R8) build of the example has no missing classes.

If the injection fails, the fallback is to document one line for the app's `build.gradle.kts`.
If the ByteDance repo proves unreliable, Plan B is to vendor the TikTok Kotlin sources (the
licence allows it).

### Manifest (merged into the app automatically)
```xml
<queries>
  <package android:name="com.zhiliaoapp.musically"/>
  <package android:name="com.ss.android.ugc.trill"/>
  <intent><action android:name="android.support.customtabs.action.CustomTabsService"/></intent>
</queries>
<application>
  <activity android:name="dev.tiktokauth.android.TikTokAuthCallbackActivity"
      android:exported="true" android:noHistory="true" android:excludeFromRecents="true"
      android:theme="@android:style/Theme.Translucent.NoTitleBar">
    <intent-filter android:autoVerify="true">
      <action android:name="android.intent.action.VIEW"/>
      <category android:name="android.intent.category.DEFAULT"/>
      <category android:name="android.intent.category.BROWSABLE"/>
      <data android:scheme="https" android:host="${tiktokRedirectHost}"
            android:pathPrefix="${tiktokRedirectPath}"/>
    </intent-filter>
  </activity>
</application>
```
The user adds only:
`manifestPlaceholders += mapOf("tiktokRedirectHost" to "example.com", "tiktokRedirectPath" to "/tiktok/callback")`.

**Spike S2:** can the library supply safe defaults, so an unconfigured app still builds and
`initialize()` reports `misconfigured`? If not, the build fails with a clear message, the way
`flutter_appauth` does.

### Classes
- **`TikTokAuthPlugin`**: implements `FlutterPlugin`, `ActivityAware`, `TikTokAuthHostApi`,
  `NewIntentListener`, and `ActivityResultListener`. It re-attaches on config changes.
- **`AuthCoordinator`**: a process-wide singleton.
  - Holds the single in-flight request (`alreadyInProgress` otherwise).
  - Completes exactly once, whichever return path arrives first.
- **Return paths handled:**
  1. `onActivityResult`: the SDK launches the TikTok app with `startActivityForResult(…, 0)`.
     We claim the result only if `getAuthResponseFromIntent` parses it, because request code 0
     may belong to others.
  2. `onNewIntent`.
  3. `TikTokAuthCallbackActivity`: parses the App Link and hands the result to the coordinator.
     It then starts the host activity with `CLEAR_TOP | SINGLE_TOP`, which dismisses the Custom
     Tab, and finishes. This is the AppAuth pattern, and it also keeps the callback away from
     Flutter's deep-link router.
- **Never-hang (M6):** when the host activity resumes while a request is pending, wait a grace
  period (default 1 s, configurable). If there is still no result → `cancelled`.
- **`PendingAuthStore`** (M6): `SharedPreferences` holding
  `{expectedState, codeVerifier, redirectUri, startedAt}` while pending, so a relaunch after
  process death can finish the auth through `takePendingResult()`.
- **`validateConfiguration`**:
  - The redirect host/path matches the merged-manifest placeholders.
  - The callback activity is resolvable for the redirect URI.
- **`ErrorMapper`**: maps SDK `errorCode` / `authError` / `authErrorDescription` →
  `PlatformErrorKind`. Exact constants are read from `com.tiktok.open.sdk.core.constants.Constants`
  during M2. 10033 → `misconfigured` with a "register SHA-256/MD5 of debug, release **and Play
  App Signing** keys" hint.

---

## 5. iOS design (`tiktok_auth_ios`)

### Packaging
```swift
// Package.swift (swift-tools 5.9, platforms .iOS("15.0"))
dependencies: [
  .package(name: "FlutterFramework", path: "../FlutterFramework"),
  .package(url: "https://github.com/tiktok/tiktok-opensdk-ios", from: "2.5.0"),
],
targets: [.target(name: "tiktok_auth_ios", dependencies: [
  .product(name: "FlutterFramework", package: "FlutterFramework"),
  .product(name: "TikTokOpenAuthSDK", package: "tiktok-opensdk-ios"),
  .product(name: "TikTokOpenSDKCore", package: "tiktok-opensdk-ios"),
], resources: [.process("PrivacyInfo.xcprivacy")])]
```
The podspec mirrors this: `s.dependency 'TikTokOpenAuthSDK', '~> 2.5'` and
`'TikTokOpenSDKCore', '~> 2.5'`, with `s.platform = :ios, '15.0'`.

### Classes
- **`TikTokAuthPlugin`**: calls `registrar.addApplicationDelegate(self)` **and**
  `registrar.addSceneDelegate(self)`. Both are verified present in Flutter 3.41 and 3.47.
  It implements:
  - `application(_:open:options:)` and `application(_:continue:restorationHandler:)`,
  - `scene(_:openURLContexts:)` and `scene(_:continueUserActivity:)`, and
  - `scene(_:willConnectTo:options:)`, which covers a **cold start** via a universal link.
- **`URLRouter`**: claims a URL (returns `true`) **only** if it starts with the configured
  `redirectUri` or `<clientKey>://`. Every other deep link still reaches the app and its router.
  Claimed URLs go to `TikTokURLHandler.handleOpenURL`.
- **`AuthCoordinator`**:
  - Keeps the `TikTokAuthRequest` **strongly referenced** until the completion fires (the SDK
    drops the callback on `deinit`).
  - Sets `request.state`, `isWebAuth = preferWebAuth`, and scopes.
  - Reads `request.pkce.codeVerifier` into the result.
- **Never-hang (M6):** `sceneDidBecomeActive` / `applicationDidBecomeActive` with a pending
  native-app request and no callback → `cancelled` after the grace period.
  `ASWebAuthenticationSession` already reports cancellation.
- **`ConfigValidator`**: `TikTokClientKey` in Info.plist equals the Dart client key. (The iOS SDK
  reads the key **from Info.plist**, not from Dart.) It also checks:
  - `LSApplicationQueriesSchemes` ⊇ `tiktokopensdk`, `snssdk1180`, `snssdk1233`;
  - `CFBundleURLSchemes` contains the client key;
  - where readable, the `com.apple.developer.associated-domains` entitlement contains
    `applinks:<host>`.
- **`PendingAuthStore`** (M6): `UserDefaults`. On relaunch, parse the URL with the SDK's public
  `TikTokAuthResponse(fromURL:redirectURI:)` and pair it with the stored verifier.
- **`ErrorMapper`**: `0`→none, `-2`→cancelled, `-4`→denied, `-5`→failed(unsupported),
  `-8`→network, `10005`→misconfigured, `-1/-3/100000`→failed.

---

## 6. `doctor` CLI (M7)

`dart run tiktok_auth:doctor` reads config from the app's `pubspec.yaml`:
```yaml
tiktok_auth:
  client_key: awxxxxxxxx
  redirect_uri: https://example.com/tiktok/callback
```
**Checks** (✓ / ✗ + exact fix snippet; non-zero exit code on errors, so it's CI-friendly):
1. Redirect URI rules: https, no `#`, < 512 chars, trailing-slash consistency.
2. `ios/Runner/Info.plist`: `TikTokClientKey`, query schemes, URL scheme.
3. `ios/Runner/*.entitlements`: `applinks:<host>`. `project.pbxproj`: `DEVELOPMENT_TEAM` + bundle ID.
4. `GET https://<host>/.well-known/apple-app-site-association`: valid JSON, served without
   redirects, contains `TEAMID.bundleId` and a path matching the redirect path.
5. `android/app/build.gradle(.kts)`: placeholders present and matching the redirect URI;
   `applicationId`.
6. `GET https://<host>/.well-known/assetlinks.json`: package name + SHA-256 fingerprints.
   Compare against `keytool -list -v` of the debug keystore (and release keystore if
   `key.properties` exists).
7. Print the **MD5 + SHA-256** to paste into the TikTok portal, and remind the user to add the
   **Play App Signing** key from Play Console.

Dependencies (pure Dart, not in the compiled app): `args`, `http`, `xml`, `yaml`, `path`.

---

## 7. `tiktok_auth_server` (M8)

```dart
final client = TikTokOAuthClient(clientKey: '...', clientSecret: env['TIKTOK_SECRET']!);
final tokens = await client.exchangeCode(code: c, codeVerifier: v, redirectUri: r);
final fresh  = await client.refresh(tokens.refreshToken);  // may ROTATE the refresh token
await client.revoke(tokens.accessToken);
final user   = await client.getUserInfo(tokens.accessToken,
    fields: {UserField.openId, UserField.unionId, UserField.displayName, UserField.avatarUrl});
```
- Endpoints: `POST /v2/oauth/token/`, `POST /v2/oauth/revoke/`, `GET /v2/user/info/`
  (form-encoded, typed errors with `log_id`).
- Docs add Node (Firebase Cloud Function → `createCustomToken('tiktok:' + open_id)`) and
  Python snippets. The Firebase and Supabase guides use this flow, because TikTok has no
  `id_token`.

---

## 8. Milestones (in build order)

| # | Milestone | Deliverable / acceptance criteria | Est. |
|---|---|---|---|
| **M0** | Scaffold | `git init`; workspace root; 4 packages generated from the Flutter 3.47 plugin template; lints; melos scripts (`analyze`, `test`, `pigeon`, `format`); CI green on empty packages | 0.5 d |
| **M1** | Dart core | Platform interface + types; `TikTokAuth` API (§2); config validation; state gen/verify; error mapping; `FakeTikTokAuth`; **≥ 95% unit-test coverage** | 1–2 d |
| **M2** | Android | Spikes S1/S2; Pigeon; plugin + coordinator + callback activity; all 3 return paths; `validateConfiguration`; Kotlin unit tests; release (R8) build passes | 2–3 d |
| **M3** | iOS | SPM + CocoaPods; app + scene delegates incl. cold start; URL router; strong-ref coordinator; config validator; XCTests; both build modes pass | 2–3 d |
| **M4** | Example + real E2E | Example app (config status, sign-in, result, optional local exchange server); full manual QA matrix on real devices with TikTok Sandbox | 1–2 d |
| **M5** | Release 0.1.0 | README (5-min setup), docs/, CHANGELOGs, dartdoc 100%, `pana` 160/160 locally, publish all packages in dependency order | 1 d |
| **M6** | Robustness | Never-hang cancellation; process-death recovery on both platforms; Chinese-OEM ROM test → 0.2.0 | 2–3 d |
| **M7** | `doctor` CLI | All checks in §6 with tests on fixture projects → 0.3.0 | 2–3 d |
| **M8** | Server + recipes | `tiktok_auth_server` 0.1.0; Firebase/Supabase/Node/Python guides → 0.4.0 | 2 d |
| **M9** | Web + desktop → **1.0.0** | Web redirect/popup (no PKCE on web); desktop loopback `127.0.0.1:<port>` + PKCE (**hex** SHA-256, `S256`); verified publisher; API freeze | 1–2 wk |

**0.1.0 in about 2 weeks, 1.0.0 in about 5–6 weeks** (one developer).

---

## 9. Quality gates (enforced in CI)

- **Every PR:** `dart format --set-exit-if-changed`, `flutter analyze` (very_good_analysis,
  zero warnings), `flutter test --coverage`.
- **Flutter version matrix:** 3.41.x (minimum) and stable.
- **Android:** `flutter build apk --release` of the example, which catches R8/missing-class
  problems, plus Gradle unit tests.
- **iOS (macOS runner):** `flutter build ios --no-codesign` twice, with SPM enabled and with
  CocoaPods, plus XCTests.
- **Publishing:** `pana` score gate (fail below 160) and `dart pub publish --dry-run` for every
  package.
- **Dependency watch:** Renovate/Dependabot for `tiktok-opensdk-ios` tags and the ByteDance
  Maven version.
- **Release:** a git tag `tiktok_auth-v0.1.0` triggers GitHub Actions automated publishing
  (OIDC; no stored secrets).

---

## 10. Things only you (the owner) can do, needed before M4

1. **TikTok developer app** with Login Kit and **Sandbox** + your own TikTok account as a target
   user. Register:
   - iOS bundle ID `dev.tiktokauth.example`,
   - Android package `dev.tiktokauth.example` + debug SHA-256/MD5 (I'll print it in M2),
   - redirect URI `https://<your-domain>/tiktok/callback`.
2. **A domain** plus free hosting (Firebase Hosting or Cloudflare Pages) for
   `/.well-known/apple-app-site-association` and `/.well-known/assetlinks.json`. I'll generate
   both files. The same domain later becomes the pub.dev **verified publisher**.
3. **Apple Developer Program (paid)**. The Associated Domains capability (universal links)
   does not work with a free account.
4. **Test devices** with the TikTok app installed and a VPN (TikTok is region-blocked on your
   network), so we can test both the native-app flow and the no-app web flow.
5. **GitHub repo** `tiktok_auth` and a **pub.dev** account.

M0–M3 do **not** need any of this. I can build all of it now, and you can do these in parallel.

---

## 11. Risks and mitigations

| Risk | Mitigation |
|---|---|
| ByteDance Maven repo is slow or unavailable | Spike S1; Plan B is to vendor the Kotlin SDK sources (licence permits) |
| TikTok's POM has no dependencies | Declare `androidx.browser` ourselves; R8 release build in CI |
| Future TikTok SDK changes redirect behaviour | Pin exact versions; Renovate PRs + manual QA checklist before bumping |
| Apps using go_router / `app_links` / Flutter deep linking | Android: separate callback activity. iOS: claim only matching URLs before the router sees them. Documented. |
| Resume-cancel fires too early on slow devices | Configurable grace period; a late result after cancel is ignored safely |
| Trademark ("TikTok" in name) | "Unofficial, not affiliated with TikTok" in README and pubspec; no TikTok logos |
| Flutter < 3.41 users | CI trial on 3.38; lower the floor if it compiles |

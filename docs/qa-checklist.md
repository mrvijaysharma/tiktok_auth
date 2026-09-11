# Manual QA checklist

TikTok Login cannot be automated end to end, so run this checklist on real
devices before every release and after every TikTok SDK update.

## Setup

- A TikTok developer app in **Sandbox** mode with Login Kit, and your TikTok
  account added as a target user.
- The example app configured with that app's client key and redirect URI.
- The redirect domain serving valid `apple-app-site-association` and
  `assetlinks.json` files.
- One Android and one iOS device **with** the TikTok app and one of each
  **without** it (or uninstall between runs).
- Where TikTok is region-blocked, a VPN on the test devices.

Record the device, OS version, TikTok app version and result for each row.

## Matrix

| # | Scenario | TikTok app | Expected |
|---|---|---|---|
| 1 | Approve | installed | `TikTokAuthorization` with code, verifier, scopes; `usedWebAuth == false` |
| 2 | Approve | not installed | Same as 1 with `usedWebAuth == true` |
| 3 | Approve with `preferWebAuth: true` | installed | Browser flow; `usedWebAuth == true` |
| 4 | Tap Cancel / Deny on the consent screen | installed | `denied` (or `cancelled` if TikTok reports it so) |
| 5 | Tap Cancel / Deny on the consent screen | not installed | `denied` |
| 6 | Close the browser / press back without deciding | not installed | `cancelled` within ~1 s |
| 7 | Switch back to the app without deciding | installed | `cancelled` within ~1 s |
| 8 | Request `user.info.basic` + an unapproved scope | either | Error from TikTok, mapped to `misconfigured` |
| 9 | Call `signIn()` twice quickly | either | Second call throws `alreadyInProgress` |
| 10 | Wrong client key in Info.plist (iOS) | either | `initialize()` throws `misconfigured` naming the key |
| 11 | Wrong `tiktokRedirectHost` (Android) | either | `initialize()` throws `misconfigured` naming the placeholders |
| 12 | Android: enable "Don't keep activities", approve | installed and not installed | App restarts; `getPendingAuthorization()` returns the result |
| 13 | Android: release build signed with a key not in the portal | installed | `misconfigured` mentioning the certificate (10033) |
| 14 | Rotate the device during the flow | either | Flow completes normally |
| 15 | App that uses go_router deep links | either | Callback URL does not open a route |
| 16 | Press Back immediately after tapping sign-in, before TikTok or the browser appears | either | `cancelled` right away; the app never waits |
| 17 | Open the app from a notification or a deep link, then sign in with the TikTok app | Android | The result appears in the same app screen, and no second copy of the app is opened |
| 18 | During a sign-in, send a forged callback: `adb shell "am start -n <applicationId>/dev.tiktokauth.android.TikTokAuthCallbackActivity -a android.intent.action.VIEW -d 'https://<host>/<path>?code=x&state=y'"` | Android | `stateMismatch` error in the same app screen; the browser tab closes |

## Android OEM builds

Repeat rows 1, 2 and 6 on at least one Xiaomi, Oppo or Vivo device. These
ROMs are known to block returning from other apps (see tiktok_sdk_v2 issue #6).

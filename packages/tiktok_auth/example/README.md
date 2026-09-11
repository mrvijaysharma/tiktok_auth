# tiktok_auth example

A minimal app that signs in with TikTok and shows the returned authorization.

## Run it with your own TikTok app

1. Complete the setup in the [tiktok_auth README](../README.md): register the
   app in the TikTok developer portal and host the two `.well-known` files.
2. Replace the placeholders:
   - `YOUR_TIKTOK_CLIENT_KEY` in `ios/Runner/Info.plist` (two places),
   - `tiktokRedirectHost` / `tiktokRedirectPath` in
     `android/app/build.gradle.kts`,
   - the Associated Domains capability of the Runner target in Xcode.
3. Run:

   ```bash
   flutter run \
     --dart-define=TIKTOK_CLIENT_KEY=awxxxxxxxx \
     --dart-define=TIKTOK_REDIRECT_URI=https://your.domain/tiktok/callback
   ```

The example uses bundle ID / application ID `dev.tiktokauth.example`. Change it
to one you registered in the TikTok developer portal.

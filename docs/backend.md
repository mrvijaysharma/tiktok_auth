# Backend: exchanging the TikTok code

`tiktok_auth` returns an authorization code, not an access token. Your server
exchanges the code, because the exchange needs your **client secret**. The app
sends three values from `TikTokAuthorization`: `authCode`, `codeVerifier` and
`redirectUri`.

## Dart backends

Use [`tiktok_auth_server`](../packages/tiktok_auth_server):

```dart
final tokens = await TikTokOAuthClient(
  clientKey: 'YOUR_CLIENT_KEY',
  clientSecret: Platform.environment['TIKTOK_CLIENT_SECRET']!,
).exchangeCode(code: code, codeVerifier: codeVerifier, redirectUri: redirectUri);
```

## Any language (raw HTTP)

```
POST https://open.tiktokapis.com/v2/oauth/token/
Content-Type: application/x-www-form-urlencoded

client_key=...&client_secret=...&code=...&grant_type=authorization_code
&redirect_uri=...&code_verifier=...
```

The response has `access_token` (24 h), `refresh_token` (365 d), `open_id`,
`scope`, `expires_in` and `refresh_expires_in`. Errors have `error`,
`error_description` and `log_id`.

## Firebase Authentication

TikTok is not an OpenID Connect provider (it returns no `id_token`), so
Firebase cannot use it as a built-in provider. Instead, exchange the code in a
Cloud Function and mint a Firebase custom token.

**Cloud Function (Node.js):**

```js
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");

admin.initializeApp();
const TIKTOK_CLIENT_SECRET = defineSecret("TIKTOK_CLIENT_SECRET");
const TIKTOK_CLIENT_KEY = "YOUR_CLIENT_KEY";
const REDIRECT_URI = "https://example.com/tiktok/callback";

exports.signInWithTikTok = onCall(
  { secrets: [TIKTOK_CLIENT_SECRET] },
  async (request) => {
    const { code, codeVerifier } = request.data;
    const response = await fetch("https://open.tiktokapis.com/v2/oauth/token/", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        client_key: TIKTOK_CLIENT_KEY,
        client_secret: TIKTOK_CLIENT_SECRET.value(),
        code,
        grant_type: "authorization_code",
        redirect_uri: REDIRECT_URI,
        code_verifier: codeVerifier,
      }),
    });
    const tokens = await response.json();
    if (tokens.error) {
      throw new HttpsError("permission-denied", tokens.error_description || tokens.error);
    }
    const firebaseToken = await admin.auth().createCustomToken(`tiktok:${tokens.open_id}`);
    return { firebaseToken };
  },
);
```

**App:**

```dart
final auth = await TikTokAuth.instance.signIn();
final result = await FirebaseFunctions.instance
    .httpsCallable('signInWithTikTok')
    .call({'code': auth.authCode, 'codeVerifier': auth.codeVerifier});
await FirebaseAuth.instance.signInWithCustomToken(
  result.data['firebaseToken'] as String,
);
```

The redirect URI is fixed on the server rather than taken from the request,
so a caller cannot swap it.

## Supabase

Do the same exchange in an Edge Function. Then create or look up the user
keyed by `open_id` with the service-role client, and return a session to the
app.

// A minimal backend endpoint body: exchange the values sent by the app for
// tokens, then read the user's profile.
//
// Run with: TIKTOK_CLIENT_SECRET=... dart run example/tiktok_auth_server_example.dart
import 'dart:io';

import 'package:tiktok_auth_server/tiktok_auth_server.dart';

Future<void> main() async {
  final tiktok = TikTokOAuthClient(
    clientKey: 'YOUR_CLIENT_KEY',
    clientSecret: Platform.environment['TIKTOK_CLIENT_SECRET'] ?? '',
  );

  try {
    // In a real server these come from the app's request body:
    // TikTokAuthorization.authCode, .codeVerifier and .redirectUri.
    final tokens = await tiktok.exchangeCode(
      code: 'AUTH_CODE_FROM_THE_APP',
      codeVerifier: 'CODE_VERIFIER_FROM_THE_APP',
      redirectUri: 'https://example.com/tiktok/callback',
    );

    final user = await tiktok.getUserInfo(tokens.accessToken);
    stdout.writeln('Signed in ${user.displayName} (${tokens.openId})');

    // Store tokens.refreshToken securely if you call TikTok APIs later.
    // Refreshing may return a new refresh token; always keep the newest.
  } on TikTokApiException catch (error) {
    stderr.writeln('TikTok rejected the request: $error');
    exitCode = 1;
  } finally {
    tiktok.close();
  }
}

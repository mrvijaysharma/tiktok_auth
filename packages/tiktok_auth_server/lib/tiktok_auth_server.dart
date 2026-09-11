/// Server-side helpers for TikTok Login Kit.
///
/// Exchange the authorization code returned by `package:tiktok_auth` for
/// tokens, refresh and revoke them, and read the user's profile. Use it only
/// on a server: it needs your app's client secret.
library;

export 'src/client.dart';
export 'src/exception.dart';
export 'src/models.dart';

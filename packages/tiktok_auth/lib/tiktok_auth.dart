/// Sign users in with TikTok on Android and iOS.
///
/// Start with `TikTokAuth.instance.initialize`, then call
/// `TikTokAuth.instance.signIn` and send the returned authorization code to
/// your backend.
library;

export 'src/authorization.dart';
export 'src/config.dart';
export 'src/exception.dart';
export 'src/scope.dart';
export 'src/tiktok_auth.dart';

// Pigeon schema of tiktok_auth_android. Keep it identical to ios.dart apart
// from the options. Regenerate with: dart run melos run pigeon --no-select
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: '../../packages/tiktok_auth_android/lib/src/messages.g.dart',
    kotlinOut:
        '../../packages/tiktok_auth_android/android/src/main/kotlin/dev/tiktokauth/android/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'dev.tiktokauth.android'),
    copyrightHeader: 'copyright.txt',
    dartPackageName: 'tiktok_auth_android',
  ),
)
enum PlatformErrorKind {
  success,
  cancelled,
  denied,
  misconfigured,
  alreadyInProgress,
  network,
  failed,
}

class PlatformAuthRequest {
  PlatformAuthRequest({
    required this.clientKey,
    required this.redirectUri,
    required this.scopes,
    required this.state,
    required this.preferWebAuth,
    required this.disableAutoAuth,
    this.language,
  });

  String clientKey;
  String redirectUri;
  List<String> scopes;
  String state;
  bool preferWebAuth;
  bool disableAutoAuth;
  String? language;
}

class PlatformAuthResult {
  PlatformAuthResult({
    required this.errorKind,
    required this.usedWebAuth,
    required this.grantedScopes,
    this.authCode,
    this.codeVerifier,
    this.state,
    this.expectedState,
    this.redirectUri,
    this.nativeCode,
    this.errorDescription,
  });

  PlatformErrorKind errorKind;
  bool usedWebAuth;
  List<String> grantedScopes;
  String? authCode;
  String? codeVerifier;
  String? state;
  String? expectedState;
  String? redirectUri;
  String? nativeCode;
  String? errorDescription;
}

@HostApi()
abstract class TikTokAuthHostApi {
  List<String> validateConfiguration(String clientKey, String redirectUri);

  bool isTikTokInstalled();

  @async
  PlatformAuthResult authorize(PlatformAuthRequest request);

  PlatformAuthResult? takePendingResult();
}

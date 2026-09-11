import 'package:flutter/foundation.dart';
import 'package:tiktok_auth_ios/src/messages.g.dart';
import 'package:tiktok_auth_platform_interface/tiktok_auth_platform_interface.dart';

/// The iOS implementation of [TikTokAuthPlatform], built on the TikTok
/// OpenSDK Login Kit.
class TikTokAuthIOS extends TikTokAuthPlatform {
  /// Creates the iOS implementation.
  TikTokAuthIOS({@visibleForTesting TikTokAuthHostApi? api})
    : _api = api ?? TikTokAuthHostApi();

  final TikTokAuthHostApi _api;

  /// Registers this class as the default [TikTokAuthPlatform].
  static void registerWith() {
    TikTokAuthPlatform.instance = TikTokAuthIOS();
  }

  @override
  Future<List<String>> validateConfiguration({
    required String clientKey,
    required String redirectUri,
  }) => _api.validateConfiguration(clientKey, redirectUri);

  @override
  Future<bool> isTikTokInstalled() => _api.isTikTokInstalled();

  @override
  Future<AuthorizeResult> authorize(AuthorizeRequest request) async {
    final result = await _api.authorize(
      PlatformAuthRequest(
        clientKey: request.clientKey,
        redirectUri: request.redirectUri,
        scopes: request.scopes,
        state: request.state,
        preferWebAuth: request.preferWebAuth,
        disableAutoAuth: request.disableAutoAuth,
        language: request.language,
      ),
    );
    return result.toAuthorizeResult();
  }

  @override
  Future<AuthorizeResult?> takePendingResult() async =>
      (await _api.takePendingResult())?.toAuthorizeResult();
}

extension on PlatformAuthResult {
  AuthorizeResult toAuthorizeResult() => AuthorizeResult(
    authCode: authCode,
    codeVerifier: codeVerifier,
    state: state,
    expectedState: expectedState,
    redirectUri: redirectUri,
    grantedScopes: grantedScopes,
    usedWebAuth: usedWebAuth,
    errorKind: switch (errorKind) {
      PlatformErrorKind.success => PlatformAuthErrorKind.none,
      PlatformErrorKind.cancelled => PlatformAuthErrorKind.cancelled,
      PlatformErrorKind.denied => PlatformAuthErrorKind.denied,
      PlatformErrorKind.misconfigured => PlatformAuthErrorKind.misconfigured,
      PlatformErrorKind.alreadyInProgress =>
        PlatformAuthErrorKind.alreadyInProgress,
      PlatformErrorKind.network => PlatformAuthErrorKind.network,
      PlatformErrorKind.failed => PlatformAuthErrorKind.failed,
    },
    nativeCode: nativeCode,
    errorDescription: errorDescription,
  );
}

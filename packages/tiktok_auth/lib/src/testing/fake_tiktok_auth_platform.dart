import 'dart:async';

import 'package:tiktok_auth_platform_interface/tiktok_auth_platform_interface.dart';

/// Signature of a callback that decides the outcome of a fake sign-in.
typedef FakeAuthorizeResponder =
    FutureOr<AuthorizeResult> Function(AuthorizeRequest request);

/// An in-memory [TikTokAuthPlatform] for widget and unit tests.
///
/// ```dart
/// setUp(() {
///   TikTokAuthPlatform.instance = FakeTikTokAuthPlatform()
///     ..respondWithSuccess(authCode: 'test-code');
///   TikTokAuth.instance.debugReset();
/// });
/// ```
///
/// By default every sign-in succeeds.
class FakeTikTokAuthPlatform extends TikTokAuthPlatform {
  /// Creates a fake platform.
  FakeTikTokAuthPlatform({
    this.tiktokInstalled = true,
    List<String>? configurationProblems,
  }) : configurationProblems = configurationProblems ?? <String>[];

  /// The value returned by [isTikTokInstalled].
  bool tiktokInstalled;

  /// The problems returned by [validateConfiguration].
  List<String> configurationProblems;

  /// The value returned (once) by [takePendingResult].
  AuthorizeResult? pendingResult;

  /// Every request passed to [authorize], oldest first.
  final List<AuthorizeRequest> requests = <AuthorizeRequest>[];

  FakeAuthorizeResponder _responder = _success();

  /// Makes every following sign-in succeed.
  ///
  /// [grantedScopes] defaults to the requested scopes.
  void respondWithSuccess({
    String authCode = 'fake-auth-code',
    String codeVerifier = 'fake-code-verifier',
    List<String>? grantedScopes,
    bool usedWebAuth = false,
  }) {
    _responder = _success(
      authCode: authCode,
      codeVerifier: codeVerifier,
      grantedScopes: grantedScopes,
      usedWebAuth: usedWebAuth,
    );
  }

  /// Makes every following sign-in fail with [kind].
  void respondWithError(
    PlatformAuthErrorKind kind, {
    String? nativeCode,
    String? description,
  }) {
    _responder = (_) => AuthorizeResult.error(
      kind,
      nativeCode: nativeCode,
      errorDescription: description,
    );
  }

  /// Decides the outcome of every following sign-in with [responder].
  ///
  /// The responder may return a `Future`, for example to keep a sign-in
  /// pending until a test completes it.
  // A setter would hide that this replaces previous behaviour.
  // ignore: use_setters_to_change_properties
  void respondWith(FakeAuthorizeResponder responder) {
    _responder = responder;
  }

  @override
  Future<List<String>> validateConfiguration({
    required String clientKey,
    required String redirectUri,
  }) async => List<String>.of(configurationProblems);

  @override
  Future<bool> isTikTokInstalled() async => tiktokInstalled;

  @override
  Future<AuthorizeResult> authorize(AuthorizeRequest request) async {
    requests.add(request);
    return _responder(request);
  }

  @override
  Future<AuthorizeResult?> takePendingResult() async {
    final result = pendingResult;
    pendingResult = null;
    return result;
  }

  static FakeAuthorizeResponder _success({
    String authCode = 'fake-auth-code',
    String codeVerifier = 'fake-code-verifier',
    List<String>? grantedScopes,
    bool usedWebAuth = false,
  }) {
    return (request) => AuthorizeResult(
      authCode: authCode,
      codeVerifier: codeVerifier,
      state: request.state,
      redirectUri: request.redirectUri,
      grantedScopes: grantedScopes ?? request.scopes,
      usedWebAuth: usedWebAuth,
    );
  }
}

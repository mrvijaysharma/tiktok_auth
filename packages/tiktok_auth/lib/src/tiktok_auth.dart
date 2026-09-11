import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tiktok_auth/src/authorization.dart';
import 'package:tiktok_auth/src/config.dart';
import 'package:tiktok_auth/src/exception.dart';
import 'package:tiktok_auth/src/scope.dart';
import 'package:tiktok_auth/src/state.dart';
import 'package:tiktok_auth_platform_interface/tiktok_auth_platform_interface.dart';

/// Entry point for TikTok Login.
///
/// ```dart
/// await TikTokAuth.instance.initialize(const TikTokAuthConfig(
///   clientKey: 'awxxxxxxxxxxxxxx',
///   redirectUri: 'https://example.com/tiktok/callback',
/// ));
///
/// final auth = await TikTokAuth.instance.signIn(
///   scopes: {TikTokScope.userInfoBasic},
/// );
/// // Send auth.authCode, auth.codeVerifier and auth.redirectUri to your
/// // backend, which exchanges them for tokens.
/// ```
class TikTokAuth {
  TikTokAuth._(this._platformOverride);

  /// Creates an instance that talks to [platform] instead of the registered
  /// platform implementation.
  @visibleForTesting
  TikTokAuth.withPlatform(TikTokAuthPlatform platform) : this._(platform);

  /// The shared instance.
  static final TikTokAuth instance = TikTokAuth._(null);

  final TikTokAuthPlatform? _platformOverride;
  TikTokAuthConfig? _config;
  bool _signInInProgress = false;

  TikTokAuthPlatform get _platform =>
      _platformOverride ?? TikTokAuthPlatform.instance;

  /// The configuration passed to [initialize], or `null` before that.
  TikTokAuthConfig? get config => _config;

  /// Whether [initialize] completed successfully.
  bool get isInitialized => _config != null;

  /// Validates [config] and the native project setup, then stores [config]
  /// for [signIn].
  ///
  /// Throws a [TikTokAuthException] with [TikTokAuthErrorCode.misconfigured]
  /// listing every problem found, for example a missing Info.plist key or an
  /// http redirect URI. Call it once, early, for example in `main()`.
  Future<void> initialize(TikTokAuthConfig config) async {
    final problems = config.validate();
    if (problems.isEmpty) {
      problems.addAll(
        await _guard(
          () => _platform.validateConfiguration(
            clientKey: config.clientKey,
            redirectUri: config.redirectUri,
          ),
        ),
      );
    }
    if (problems.isNotEmpty) {
      throw TikTokAuthException(
        TikTokAuthErrorCode.misconfigured,
        'TikTok Login is not configured correctly:\n'
        '${problems.map((problem) => '  • $problem').join('\n')}',
      );
    }
    _config = config;
  }

  /// Signs the user in with TikTok and returns an authorization code for
  /// your backend.
  ///
  /// Opens the TikTok app when it is installed, otherwise a secure browser
  /// tab. Set [preferWebAuth] to always use the browser.
  ///
  /// On Android only, set [disableAutoAuth] to always show the consent screen
  /// and [language] (for example `en`) to choose its language. The TikTok iOS
  /// SDK has no equivalent options, so they are ignored on iOS.
  ///
  /// Throws a [TikTokAuthException] on failure. Check
  /// [TikTokAuthException.code] for [TikTokAuthErrorCode.cancelled] to
  /// ignore users who simply backed out.
  Future<TikTokAuthorization> signIn({
    Set<TikTokScope> scopes = const {TikTokScope.userInfoBasic},
    bool preferWebAuth = false,
    bool disableAutoAuth = false,
    String? language,
  }) async {
    final config = _config;
    if (config == null) {
      throw const TikTokAuthException(
        TikTokAuthErrorCode.notInitialized,
        'Call TikTokAuth.instance.initialize() before signIn().',
      );
    }
    if (scopes.isEmpty) {
      throw ArgumentError.value(scopes, 'scopes', 'Request at least one scope');
    }
    if (_signInInProgress) {
      throw const TikTokAuthException(
        TikTokAuthErrorCode.alreadyInProgress,
        'A TikTok sign-in is already in progress.',
      );
    }

    _signInInProgress = true;
    try {
      final state = generateState();
      final result = await _guard(
        () => _platform.authorize(
          AuthorizeRequest(
            clientKey: config.clientKey,
            redirectUri: config.redirectUri,
            scopes: [for (final scope in scopes) scope.value],
            state: state,
            preferWebAuth: preferWebAuth,
            disableAutoAuth: disableAutoAuth,
            language: language,
          ),
        ),
      );
      return _toAuthorization(
        result,
        expectedState: state,
        fallbackRedirectUri: config.redirectUri,
      );
    } finally {
      _signInInProgress = false;
    }
  }

  /// Whether a TikTok app that supports Login Kit is installed.
  ///
  /// Sign-in works either way; without the app, a browser tab is used.
  Future<bool> isTikTokInstalled() => _guard(_platform.isTikTokInstalled);

  /// Returns a sign-in result that arrived while the app process was not
  /// running, or `null` if there is none.
  ///
  /// On memory-constrained Android devices the system may stop your app
  /// while the user is in TikTok. Call this once at startup to finish such
  /// sign-ins. Throws a [TikTokAuthException] if the recovered attempt
  /// failed.
  Future<TikTokAuthorization?> getPendingAuthorization() async {
    final result = await _guard(_platform.takePendingResult);
    if (result == null) return null;
    final expectedState = result.expectedState;
    if (result.isSuccess && expectedState == null) {
      throw TikTokAuthException(
        TikTokAuthErrorCode.stateMismatch,
        'The recovered TikTok sign-in has no stored state and was discarded.',
        nativeCode: result.nativeCode,
      );
    }
    return _toAuthorization(
      result,
      expectedState: expectedState ?? '',
      fallbackRedirectUri: _config?.redirectUri ?? '',
    );
  }

  /// Forgets the configuration and any in-progress flag.
  @visibleForTesting
  void debugReset() {
    _config = null;
    _signInInProgress = false;
  }

  TikTokAuthorization _toAuthorization(
    AuthorizeResult result, {
    required String expectedState,
    required String fallbackRedirectUri,
  }) {
    if (!result.isSuccess) throw _exceptionFor(result);

    if (!constantTimeEquals(result.state, expectedState)) {
      throw TikTokAuthException(
        TikTokAuthErrorCode.stateMismatch,
        'The state returned by TikTok did not match the request. The response '
        'was discarded to protect against cross-site request forgery.',
        nativeCode: result.nativeCode,
      );
    }

    final authCode = result.authCode;
    final codeVerifier = result.codeVerifier;
    if (authCode == null ||
        authCode.isEmpty ||
        codeVerifier == null ||
        codeVerifier.isEmpty) {
      throw TikTokAuthException(
        TikTokAuthErrorCode.failed,
        'TikTok did not return an authorization code.',
        nativeCode: result.nativeCode,
        description: result.errorDescription,
      );
    }

    return TikTokAuthorization(
      authCode: authCode,
      codeVerifier: codeVerifier,
      grantedScopes: {
        for (final scope in result.grantedScopes)
          if (scope.trim().isNotEmpty) TikTokScope.custom(scope),
      },
      redirectUri: result.redirectUri ?? fallbackRedirectUri,
      usedWebAuth: result.usedWebAuth,
    );
  }

  static TikTokAuthException _exceptionFor(AuthorizeResult result) {
    final (code, message) = switch (result.errorKind) {
      PlatformAuthErrorKind.cancelled => (
        TikTokAuthErrorCode.cancelled,
        'The user cancelled TikTok sign-in.',
      ),
      PlatformAuthErrorKind.denied => (
        TikTokAuthErrorCode.denied,
        'The user declined the TikTok authorization request.',
      ),
      PlatformAuthErrorKind.misconfigured => (
        TikTokAuthErrorCode.misconfigured,
        'TikTok rejected the request because the app is not configured '
            'correctly. Check the client key, redirect URI, bundle ID / '
            'package name and signing certificates registered in the TikTok '
            'developer portal, and that the redirect URI is a verified '
            'Universal Link / App Link.',
      ),
      PlatformAuthErrorKind.alreadyInProgress => (
        TikTokAuthErrorCode.alreadyInProgress,
        'A TikTok sign-in is already in progress.',
      ),
      PlatformAuthErrorKind.network => (
        TikTokAuthErrorCode.network,
        'A network error interrupted TikTok sign-in.',
      ),
      PlatformAuthErrorKind.failed || PlatformAuthErrorKind.none => (
        TikTokAuthErrorCode.failed,
        'TikTok sign-in failed.',
      ),
    };
    return TikTokAuthException(
      code,
      message,
      nativeCode: result.nativeCode,
      description: result.errorDescription,
    );
  }

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
      // The platform interface reports unsupported platforms by throwing
      // UnimplementedError, so it is part of the contract here.
      // ignore: avoid_catching_errors
    } on UnimplementedError catch (error) {
      throw TikTokAuthException(
        TikTokAuthErrorCode.unsupported,
        'TikTok Login is not supported on this platform yet.',
        description: error.message,
      );
    } on PlatformException catch (error) {
      throw TikTokAuthException(
        TikTokAuthErrorCode.failed,
        'The native TikTok Login plugin reported an error.',
        nativeCode: error.code,
        description: error.message,
      );
    }
  }
}

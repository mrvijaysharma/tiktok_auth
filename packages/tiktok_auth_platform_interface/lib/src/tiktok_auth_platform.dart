import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:tiktok_auth_platform_interface/src/types.dart';

/// The interface that platform implementations of `tiktok_auth` must extend.
///
/// Platform implementations should `extend` this class rather than
/// `implement` it, so that new methods added here do not break them.
abstract class TikTokAuthPlatform extends PlatformInterface {
  /// Constructs a [TikTokAuthPlatform].
  TikTokAuthPlatform() : super(token: _token);

  static final Object _token = Object();

  static TikTokAuthPlatform _instance = _UnsupportedTikTokAuthPlatform();

  /// The implementation used by `package:tiktok_auth`.
  ///
  /// Defaults to one that throws [UnimplementedError] on every call, which
  /// the app-facing package reports as an unsupported platform.
  static TikTokAuthPlatform get instance => _instance;

  /// Registers a platform implementation.
  ///
  /// Implementations call this from their `registerWith()` method.
  static set instance(TikTokAuthPlatform instance) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }

  /// Checks the native project configuration for [clientKey] and
  /// [redirectUri].
  ///
  /// Returns human-readable problems. An empty list means no problem was
  /// found. Implementations must only report definite problems.
  Future<List<String>> validateConfiguration({
    required String clientKey,
    required String redirectUri,
  }) {
    throw UnimplementedError(
      'validateConfiguration() has not been implemented.',
    );
  }

  /// Whether a TikTok app that supports Login Kit is installed.
  Future<bool> isTikTokInstalled() {
    throw UnimplementedError('isTikTokInstalled() has not been implemented.');
  }

  /// Runs one authorization attempt.
  ///
  /// Completes with an [AuthorizeResult] in every case, including user
  /// cancellation. It must never stay pending forever.
  Future<AuthorizeResult> authorize(AuthorizeRequest request) {
    throw UnimplementedError('authorize() has not been implemented.');
  }

  /// Returns and clears a result that arrived while the app process was not
  /// running, or `null` if there is none.
  Future<AuthorizeResult?> takePendingResult() {
    throw UnimplementedError('takePendingResult() has not been implemented.');
  }
}

class _UnsupportedTikTokAuthPlatform extends TikTokAuthPlatform {}

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tiktok_auth_ios/src/messages.g.dart';
import 'package:tiktok_auth_ios/tiktok_auth_ios.dart';
import 'package:tiktok_auth_platform_interface/tiktok_auth_platform_interface.dart';

class _MockApi extends Mock implements TikTokAuthHostApi {}

void main() {
  late _MockApi api;
  late TikTokAuthIOS platform;

  setUpAll(() {
    registerFallbackValue(
      PlatformAuthRequest(
        clientKey: '',
        redirectUri: '',
        scopes: const [],
        state: '',
        preferWebAuth: false,
        disableAutoAuth: false,
      ),
    );
  });

  setUp(() {
    api = _MockApi();
    platform = TikTokAuthIOS(api: api);
  });

  test('registerWith sets the platform instance', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    TikTokAuthIOS.registerWith();
    expect(TikTokAuthPlatform.instance, isA<TikTokAuthIOS>());
  });

  test('validateConfiguration forwards to the host', () async {
    when(
      () => api.validateConfiguration('key', 'https://x.com/cb'),
    ).thenAnswer((_) async => ['problem']);
    expect(
      await platform.validateConfiguration(
        clientKey: 'key',
        redirectUri: 'https://x.com/cb',
      ),
      ['problem'],
    );
  });

  test('isTikTokInstalled forwards to the host', () async {
    when(() => api.isTikTokInstalled()).thenAnswer((_) async => false);
    expect(await platform.isTikTokInstalled(), isFalse);
  });

  test('authorize converts the request and the result', () async {
    when(() => api.authorize(any())).thenAnswer(
      (_) async => PlatformAuthResult(
        errorKind: PlatformErrorKind.success,
        usedWebAuth: false,
        grantedScopes: ['user.info.basic', 'video.list'],
        authCode: 'code',
        codeVerifier: 'verifier',
        state: 'state',
        redirectUri: 'https://x.com/cb',
      ),
    );

    final result = await platform.authorize(
      const AuthorizeRequest(
        clientKey: 'key',
        redirectUri: 'https://x.com/cb',
        scopes: ['user.info.basic', 'video.list'],
        state: 'state',
        language: 'fr',
      ),
    );

    final sent =
        verify(() => api.authorize(captureAny())).captured.single
            as PlatformAuthRequest;
    expect(sent.scopes, ['user.info.basic', 'video.list']);
    expect(sent.preferWebAuth, isFalse);
    expect(sent.disableAutoAuth, isFalse);
    expect(sent.language, 'fr');

    expect(result.isSuccess, isTrue);
    expect(result.authCode, 'code');
    expect(result.codeVerifier, 'verifier');
    expect(result.grantedScopes, ['user.info.basic', 'video.list']);
  });

  const kinds = {
    PlatformErrorKind.success: PlatformAuthErrorKind.none,
    PlatformErrorKind.cancelled: PlatformAuthErrorKind.cancelled,
    PlatformErrorKind.denied: PlatformAuthErrorKind.denied,
    PlatformErrorKind.misconfigured: PlatformAuthErrorKind.misconfigured,
    PlatformErrorKind.alreadyInProgress:
        PlatformAuthErrorKind.alreadyInProgress,
    PlatformErrorKind.network: PlatformAuthErrorKind.network,
    PlatformErrorKind.failed: PlatformAuthErrorKind.failed,
  };
  for (final MapEntry(key: native, value: dart) in kinds.entries) {
    test('maps ${native.name} to ${dart.name}', () async {
      when(() => api.authorize(any())).thenAnswer(
        (_) async => PlatformAuthResult(
          errorKind: native,
          usedWebAuth: true,
          grantedScopes: [],
          nativeCode: '-2',
        ),
      );
      final result = await platform.authorize(
        const AuthorizeRequest(
          clientKey: 'k',
          redirectUri: 'u',
          scopes: ['s'],
          state: 's',
        ),
      );
      expect(result.errorKind, dart);
      expect(result.nativeCode, '-2');
      expect(result.usedWebAuth, isTrue);
    });
  }

  test('takePendingResult returns null when nothing is pending', () async {
    when(() => api.takePendingResult()).thenAnswer((_) async => null);
    expect(await platform.takePendingResult(), isNull);
  });
}

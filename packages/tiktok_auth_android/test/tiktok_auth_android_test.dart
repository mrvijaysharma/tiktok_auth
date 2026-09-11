import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tiktok_auth_android/src/messages.g.dart';
import 'package:tiktok_auth_android/tiktok_auth_android.dart';
import 'package:tiktok_auth_platform_interface/tiktok_auth_platform_interface.dart';

class _MockApi extends Mock implements TikTokAuthHostApi {}

void main() {
  late _MockApi api;
  late TikTokAuthAndroid platform;

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
    platform = TikTokAuthAndroid(api: api);
  });

  test('registerWith sets the platform instance', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    TikTokAuthAndroid.registerWith();
    expect(TikTokAuthPlatform.instance, isA<TikTokAuthAndroid>());
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
    when(() => api.isTikTokInstalled()).thenAnswer((_) async => true);
    expect(await platform.isTikTokInstalled(), isTrue);
  });

  test('authorize converts the request and the result', () async {
    when(() => api.authorize(any())).thenAnswer(
      (_) async => PlatformAuthResult(
        errorKind: PlatformErrorKind.success,
        usedWebAuth: true,
        grantedScopes: ['user.info.basic'],
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
        scopes: ['user.info.basic'],
        state: 'state',
        preferWebAuth: true,
        disableAutoAuth: true,
        language: 'en',
      ),
    );

    final sent =
        verify(() => api.authorize(captureAny())).captured.single
            as PlatformAuthRequest;
    expect(sent.clientKey, 'key');
    expect(sent.redirectUri, 'https://x.com/cb');
    expect(sent.scopes, ['user.info.basic']);
    expect(sent.state, 'state');
    expect(sent.preferWebAuth, isTrue);
    expect(sent.disableAutoAuth, isTrue);
    expect(sent.language, 'en');

    expect(result.isSuccess, isTrue);
    expect(result.authCode, 'code');
    expect(result.codeVerifier, 'verifier');
    expect(result.state, 'state');
    expect(result.redirectUri, 'https://x.com/cb');
    expect(result.grantedScopes, ['user.info.basic']);
    expect(result.usedWebAuth, isTrue);
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
          usedWebAuth: false,
          grantedScopes: [],
          nativeCode: '-3',
          errorDescription: 'why',
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
      expect(result.nativeCode, '-3');
      expect(result.errorDescription, 'why');
    });
  }

  test('takePendingResult converts a pending result', () async {
    when(() => api.takePendingResult()).thenAnswer(
      (_) async => PlatformAuthResult(
        errorKind: PlatformErrorKind.success,
        usedWebAuth: false,
        grantedScopes: [],
        authCode: 'code',
        expectedState: 'expected',
      ),
    );
    final result = await platform.takePendingResult();
    expect(result?.authCode, 'code');
    expect(result?.expectedState, 'expected');
  });

  test('takePendingResult returns null when nothing is pending', () async {
    when(() => api.takePendingResult()).thenAnswer((_) async => null);
    expect(await platform.takePendingResult(), isNull);
  });
}

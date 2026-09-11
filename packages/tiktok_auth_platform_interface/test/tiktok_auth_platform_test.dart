import 'package:flutter_test/flutter_test.dart';
import 'package:tiktok_auth_platform_interface/tiktok_auth_platform_interface.dart';

class _ExtendingPlatform extends TikTokAuthPlatform {}

class _ImplementingPlatform implements TikTokAuthPlatform {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('TikTokAuthPlatform', () {
    test('default instance reports every method as unimplemented', () {
      final platform = TikTokAuthPlatform.instance;
      expect(
        () => platform.validateConfiguration(clientKey: 'k', redirectUri: 'u'),
        throwsUnimplementedError,
      );
      expect(platform.isTikTokInstalled, throwsUnimplementedError);
      expect(
        () => platform.authorize(
          const AuthorizeRequest(
            clientKey: 'k',
            redirectUri: 'u',
            scopes: ['user.info.basic'],
            state: 's',
          ),
        ),
        throwsUnimplementedError,
      );
      expect(platform.takePendingResult, throwsUnimplementedError);
    });

    test('accepts implementations that extend it', () {
      final platform = _ExtendingPlatform();
      TikTokAuthPlatform.instance = platform;
      expect(TikTokAuthPlatform.instance, same(platform));
    });

    test('rejects implementations that only implement it', () {
      expect(
        () => TikTokAuthPlatform.instance = _ImplementingPlatform(),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('AuthorizeResult', () {
    test('defaults to a success without data', () {
      const result = AuthorizeResult();
      expect(result.isSuccess, isTrue);
      expect(result.grantedScopes, isEmpty);
      expect(result.usedWebAuth, isFalse);
    });

    test('error constructor sets the error fields', () {
      const result = AuthorizeResult.error(
        PlatformAuthErrorKind.denied,
        nativeCode: '-2',
        errorDescription: 'access_denied',
        usedWebAuth: true,
      );
      expect(result.isSuccess, isFalse);
      expect(result.errorKind, PlatformAuthErrorKind.denied);
      expect(result.nativeCode, '-2');
      expect(result.errorDescription, 'access_denied');
      expect(result.usedWebAuth, isTrue);
      expect(result.authCode, isNull);
    });

    test('toString does not leak the auth code', () {
      const result = AuthorizeResult(authCode: 'secret-code');
      expect(result.toString(), isNot(contains('secret-code')));
      expect(result.toString(), contains('hasAuthCode: true'));
    });
  });

  test('AuthorizeRequest defaults', () {
    const request = AuthorizeRequest(
      clientKey: 'k',
      redirectUri: 'u',
      scopes: ['user.info.basic'],
      state: 's',
    );
    expect(request.preferWebAuth, isFalse);
    expect(request.disableAutoAuth, isFalse);
    expect(request.language, isNull);
  });
}

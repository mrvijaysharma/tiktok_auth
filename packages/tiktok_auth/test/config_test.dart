import 'package:flutter_test/flutter_test.dart';
import 'package:tiktok_auth/tiktok_auth.dart';

void main() {
  const validRedirect = 'https://example.com/tiktok/callback';

  group('TikTokAuthConfig.validate', () {
    test('accepts a valid configuration', () {
      const config = TikTokAuthConfig(
        clientKey: 'awabc123',
        redirectUri: validRedirect,
      );
      expect(config.validate(), isEmpty);
    });

    test('rejects an empty client key', () {
      const config = TikTokAuthConfig(
        clientKey: ' ',
        redirectUri: validRedirect,
      );
      expect(config.validate().single, contains('clientKey is empty'));
    });

    test('rejects a client key with surrounding whitespace', () {
      const config = TikTokAuthConfig(
        clientKey: 'awabc ',
        redirectUri: validRedirect,
      );
      expect(config.validate().single, contains('whitespace'));
    });

    test('rejects a relative redirect URI', () {
      const config = TikTokAuthConfig(
        clientKey: 'awabc',
        redirectUri: 'example.com/callback',
      );
      expect(config.validate().single, contains('not an absolute URL'));
    });

    test('rejects a non-https redirect URI', () {
      const config = TikTokAuthConfig(
        clientKey: 'awabc',
        redirectUri: 'http://example.com/callback',
      );
      expect(config.validate().single, contains('must use https'));
    });

    test('rejects a custom-scheme redirect URI', () {
      const config = TikTokAuthConfig(
        clientKey: 'awabc',
        redirectUri: 'myapp://callback',
      );
      expect(config.validate().single, contains('must use https'));
    });

    test('rejects fragments and query parameters', () {
      const config = TikTokAuthConfig(
        clientKey: 'awabc',
        redirectUri: 'https://example.com/callback?x=1#top',
      );
      final problems = config.validate();
      expect(problems, hasLength(2));
      expect(problems, contains(contains('fragment')));
      expect(problems, contains(contains('query parameters')));
    });

    test('rejects a redirect URI of 512 characters or more', () {
      final longPath = 'a' * 512;
      final config = TikTokAuthConfig(
        clientKey: 'awabc',
        redirectUri: 'https://example.com/$longPath',
      );
      expect(config.validate().single, contains('shorter than 512'));
    });
  });

  test('is a value object', () {
    const a = TikTokAuthConfig(clientKey: 'k', redirectUri: validRedirect);
    const b = TikTokAuthConfig(clientKey: 'k', redirectUri: validRedirect);
    expect(a, equals(b));
    expect(a.hashCode, b.hashCode);
    expect(a.toString(), contains(validRedirect));
  });
}

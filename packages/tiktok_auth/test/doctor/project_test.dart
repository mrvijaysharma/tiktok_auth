import 'package:flutter_test/flutter_test.dart';
import 'package:tiktok_auth/src/doctor/project.dart';

void main() {
  group('readPubspecConfig', () {
    test('reads the top-level tiktok_auth section', () {
      const pubspec = '''
name: my_app
dependencies:
  tiktok_auth: ^0.1.0

tiktok_auth:
  # From the TikTok developer portal.
  client_key: "awkey"   # not a secret
  redirect_uri: https://example.com/tiktok/callback

flutter:
  uses-material-design: true
''';
      expect(readPubspecConfig(pubspec), {
        'client_key': 'awkey',
        'redirect_uri': 'https://example.com/tiktok/callback',
      });
    });

    test('returns nothing without the section', () {
      expect(readPubspecConfig('name: my_app\n'), isEmpty);
    });
  });

  group('AndroidProject.parse', () {
    test('reads Kotlin DSL placeholders and ignores comments', () {
      const source = '''
android {
    defaultConfig {
        applicationId = "com.example.app"
        // manifestPlaceholders["tiktokRedirectHost"] = "old.example.com"
        manifestPlaceholders["tiktokRedirectHost"] = "example.com"
        manifestPlaceholders["tiktokRedirectPath"] = "tiktok/callback"
    }
}''';
      final project = AndroidProject.parse(
        source,
        buildFile: 'build.gradle.kts',
      );
      expect(project.applicationId, 'com.example.app');
      expect(project.redirectHost, 'example.com');
      expect(project.redirectPath, 'tiktok/callback');
    });

    test('reads Kotlin mapOf placeholders', () {
      const source = '''
applicationId = "com.example.app"
manifestPlaceholders += mapOf(
    "tiktokRedirectHost" to "example.com",
    "tiktokRedirectPath" to "tiktok/callback",
)''';
      final project = AndroidProject.parse(
        source,
        buildFile: 'build.gradle.kts',
      );
      expect(project.redirectHost, 'example.com');
      expect(project.redirectPath, 'tiktok/callback');
    });

    test('reads Groovy placeholders', () {
      const source = '''
defaultConfig {
    applicationId "com.example.app"
    manifestPlaceholders += [tiktokRedirectHost: 'example.com', tiktokRedirectPath: 'tiktok/callback']
}''';
      final project = AndroidProject.parse(source, buildFile: 'build.gradle');
      expect(project.applicationId, 'com.example.app');
      expect(project.redirectHost, 'example.com');
      expect(project.redirectPath, 'tiktok/callback');
    });

    test('reports missing values as null', () {
      final project = AndroidProject.parse('', buildFile: 'build.gradle.kts');
      expect(project.applicationId, isNull);
      expect(project.redirectHost, isNull);
      expect(project.redirectPath, isNull);
    });
  });
}

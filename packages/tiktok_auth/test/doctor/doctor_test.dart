import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiktok_auth/src/doctor/doctor.dart';
import 'package:tiktok_auth/src/doctor/domain.dart';
import 'package:tiktok_auth/src/doctor/signing.dart';

const _key = CertificateFingerprints(
  sha256: 'AA:BB:CC',
  md5: '0A:0B:0C',
);

const _pubspec = '''
name: my_app
tiktok_auth:
  client_key: awkey
  redirect_uri: https://example.com/tiktok/callback
''';

const _infoPlist = '''
<plist version="1.0"><dict>
<key>TikTokClientKey</key><string>awkey</string>
<key>LSApplicationQueriesSchemes</key>
<array><string>tiktokopensdk</string><string>snssdk1180</string><string>snssdk1233</string></array>
<key>CFBundleURLTypes</key>
<array><dict><key>CFBundleURLSchemes</key><array><string>awkey</string></array></dict></array>
</dict></plist>''';

const _pbxproj = '''
PRODUCT_BUNDLE_IDENTIFIER = com.example.app.RunnerTests;
PRODUCT_BUNDLE_IDENTIFIER = com.example.app;
DEVELOPMENT_TEAM = ABCDE12345;
CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;
''';

const _entitlements = '''
<plist version="1.0"><dict>
<key>com.apple.developer.associated-domains</key>
<array><string>applinks:example.com</string></array>
</dict></plist>''';

const _gradle = '''
android {
    defaultConfig {
        applicationId = "com.example.app"
        manifestPlaceholders["tiktokRedirectHost"] = "example.com"
        manifestPlaceholders["tiktokRedirectPath"] = "tiktok/callback"
    }
}''';

final String _aasa = jsonEncode({
  'applinks': {
    'details': [
      {
        'appIDs': ['ABCDE12345.com.example.app'],
        'components': [
          {'/': '/tiktok/callback*'},
        ],
      },
    ],
  },
});

final String _assetLinks = jsonEncode([
  {
    'relation': ['delegate_permission/common.handle_all_urls'],
    'target': {
      'namespace': 'android_app',
      'package_name': 'com.example.app',
      'sha256_cert_fingerprints': ['AA:BB:CC'],
    },
  },
]);

Future<HttpResult> _serve(Uri uri) async => switch (uri.path) {
  '/.well-known/apple-app-site-association' => HttpResult(
    200,
    _aasa,
    mimeType: 'application/json',
  ),
  '/.well-known/assetlinks.json' => HttpResult(
    200,
    _assetLinks,
    mimeType: 'application/json',
  ),
  _ => const HttpResult(404, ''),
};

void main() {
  late Directory project;
  late File keystore;

  void write(String path, String content) {
    File('${project.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
  }

  setUp(() {
    project = Directory.systemTemp.createTempSync('tiktok_auth_doctor_');
    write('pubspec.yaml', _pubspec);
    write('ios/Runner/Info.plist', _infoPlist);
    write('ios/Runner.xcodeproj/project.pbxproj', _pbxproj);
    write('ios/Runner/Runner.entitlements', _entitlements);
    write('android/app/build.gradle.kts', _gradle);
    keystore = File('${project.path}/debug.keystore')..writeAsStringSync('');
  });

  tearDown(() => project.deleteSync(recursive: true));

  Future<(int, String)> run(
    List<String> arguments, {
    HttpGet httpGet = _serve,
  }) async {
    final out = StringBuffer();
    final code = await runDoctor(
      ['--project', project.path, '--no-color', ...arguments],
      out: out,
      httpGet: httpGet,
      readCertificate: (_) async => _key,
      debugKeystore: KeystoreRef(
        label: 'Debug',
        path: keystore.path,
        alias: 'androiddebugkey',
        storePassword: 'android',
      ),
    );
    return (code, out.toString());
  }

  test('passes a correctly configured app', () async {
    final (code, output) = await run([]);
    expect(output, contains('No problems found.'));
    expect(output, contains('SHA-256: AA:BB:CC'));
    expect(output, contains('MD5:     0A:0B:0C (0a0b0c)'));
    expect(
      output,
      contains(
        'apple-app-site-association allows ABCDE12345.com.example.app',
      ),
    );
    expect(output, contains('assetlinks.json lists the Debug key.'));
    expect(code, 0);
  });

  test('reports every misconfiguration', () async {
    write('ios/Runner/Info.plist', '''
<plist version="1.0"><dict>
<key>TikTokClientKey</key><string>other</string>
</dict></plist>''');
    write(
      'android/app/build.gradle.kts',
      _gradle.replaceFirst('"tiktok/callback"', '"/tiktok/callback"'),
    );

    final (code, output) = await run([
      '--redirect-uri=https://example.com/tiktok/callback',
    ]);

    expect(code, 1);
    expect(output, contains('TikTokClientKey in Info.plist is other'));
    expect(output, contains('missing tiktokopensdk, snssdk1180, snssdk1233'));
    expect(output, contains('does not register the URL scheme awkey'));
    expect(output, contains('must not start with "/"'));
    expect(output, contains('manifestPlaceholders["tiktokRedirectPath"]'));
  });

  test('reports a missing Associated Domains entitlement', () async {
    write('ios/Runner.xcodeproj/project.pbxproj', '''
PRODUCT_BUNDLE_IDENTIFIER = com.example.app;
DEVELOPMENT_TEAM = ABCDE12345;
''');
    final (code, output) = await run(['--offline']);
    expect(code, 1);
    expect(output, contains('no entitlements, so Universal Links are off'));
    expect(output, contains('applinks:example.com'));
  });

  test('command-line values override pubspec.yaml', () async {
    final (code, output) = await run(['--client-key', 'other', '--offline']);
    expect(code, 1);
    expect(output, contains('Client key: other'));
  });

  test('reports a placeholder client key', () async {
    for (final key in [
      'YOUR_TIKTOK_CLIENT_KEY',
      'awxxxxxxxx',
      '<client-key>',
    ]) {
      final (code, output) = await run(['--client-key', key, '--offline']);
      expect(code, 1, reason: key);
      expect(output, contains('Client key "$key" is a placeholder.'));
      expect(output, isNot(contains('✓ Client key:')));
    }
  });

  test('skips network checks when offline', () async {
    final (code, output) = await run(
      ['--offline'],
      httpGet: (_) => fail('must not fetch'),
    );
    expect(code, 0);
    expect(output, contains('Skipped (--offline).'));
  });

  test('reports domain problems', () async {
    final (code, output) = await run(
      [],
      httpGet: (uri) async => const HttpResult(404, ''),
    );
    expect(code, 1);
    expect(output, contains('apple-app-site-association returned HTTP 404'));
    expect(output, contains('assetlinks.json returned HTTP 404'));
  });

  test('requires the client key and redirect URI', () async {
    write('pubspec.yaml', 'name: my_app\n');
    final (code, output) = await run([]);
    expect(code, 1);
    expect(output, contains('The client key and redirect URI are not set.'));
  });

  test('rejects invalid redirect URIs', () async {
    final (code, output) = await run([
      '--redirect-uri=http://example.com/callback',
    ]);
    expect(code, 1);
    expect(output, contains('must use https'));
  });

  test('requires a Flutter project', () async {
    File('${project.path}/pubspec.yaml').deleteSync();
    final (code, output) = await run([]);
    expect(code, 1);
    expect(output, contains('No pubspec.yaml'));
  });

  test('prints usage', () async {
    final out = StringBuffer();
    expect(await runDoctor(['--help'], out: out), 0);
    expect(out.toString(), contains('dart run tiktok_auth:doctor'));

    final invalid = StringBuffer();
    expect(await runDoctor(['--bogus'], out: invalid), 64);
    expect(invalid.toString(), contains('Unknown option --bogus.'));
  });
}

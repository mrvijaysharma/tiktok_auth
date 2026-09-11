import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiktok_auth/src/doctor/domain.dart';
import 'package:tiktok_auth/src/doctor/report.dart';
import 'package:tiktok_auth/src/doctor/signing.dart';

const _host = 'example.com';
const _path = '/tiktok/callback';
const _appId = 'ABCDE12345.com.example.app';
const _key = CertificateFingerprints(sha256: 'AA:BB', md5: '11:22');

HttpGet _serve(Map<String, HttpResult> responses) =>
    (uri) async => responses[uri.path] ?? const HttpResult(404, 'Not found');

HttpResult _json(Object value) =>
    HttpResult(200, jsonEncode(value), mimeType: 'application/json');

List<CheckStatus> _statuses(DoctorReport report) =>
    report.results.map((result) => result.status).toList();

void main() {
  group('matchesAasaPattern', () {
    test('supports * and ?', () {
      expect(matchesAasaPattern('/tiktok/callback*', _path), isTrue);
      expect(matchesAasaPattern('/tiktok/callback*', '$_path/x'), isTrue);
      expect(matchesAasaPattern('/tik?ok/*', '/tiktok/a'), isTrue);
      expect(matchesAasaPattern('*', _path), isTrue);
      expect(matchesAasaPattern('/other', _path), isFalse);
      expect(
        matchesAasaPattern('/tiktok.callback', '/tiktokXcallback'),
        isFalse,
      );
    });
  });

  group('checkAppleAppSiteAssociation', () {
    const aasaPath = '/.well-known/apple-app-site-association';

    Future<DoctorReport> check(
      HttpResult response, {
      String? appId = _appId,
      String? bundleId = 'com.example.app',
    }) async {
      final report = DoctorReport();
      await checkAppleAppSiteAssociation(
        report,
        _serve({aasaPath: response}),
        host: _host,
        path: _path,
        appId: appId,
        bundleId: bundleId,
      );
      return report;
    }

    test('passes for a matching components entry', () async {
      final report = await check(
        _json({
          'applinks': {
            'details': [
              {
                'appIDs': [_appId],
                'components': [
                  {'/': '/tiktok/callback*'},
                ],
              },
            ],
          },
        }),
      );
      expect(_statuses(report), [CheckStatus.pass]);
    });

    test('passes for the legacy paths format', () async {
      final report = await check(
        _json({
          'applinks': {
            'details': [
              {
                'appID': _appId,
                'paths': ['NOT /private/*', '/tiktok/*'],
              },
            ],
          },
        }),
      );
      expect(_statuses(report), [CheckStatus.pass]);
    });

    test('accepts any team when the team is unknown', () async {
      final report = await check(
        _json({
          'applinks': {
            'details': [
              {
                'appIDs': ['ZZZ.com.example.app'],
                'components': [
                  {'/': '*'},
                ],
              },
            ],
          },
        }),
        appId: null,
      );
      expect(_statuses(report), [CheckStatus.pass]);
    });

    test('fails when the path is excluded', () async {
      final report = await check(
        _json({
          'applinks': {
            'details': [
              {
                'appIDs': [_appId],
                'components': [
                  {'/': '/tiktok/*', 'exclude': true},
                  {'/': '*'},
                ],
              },
            ],
          },
        }),
      );
      expect(_statuses(report), [CheckStatus.error]);
      expect(report.results.single.message, contains('not the path'));
    });

    test('fails when the app is not listed', () async {
      final report = await check(
        _json({
          'applinks': {
            'details': [
              {
                'appIDs': ['OTHER.com.other.app'],
                'components': [
                  {'/': '*'},
                ],
              },
            ],
          },
        }),
      );
      expect(report.results.single.message, contains('does not list $_appId'));
      expect(report.results.single.fix, contains(_appId));
    });

    test('fails for redirects, HTTP errors and invalid JSON', () async {
      final redirected = await check(
        const HttpResult(301, '', location: 'https://www.example.com/'),
      );
      expect(redirected.results.single.message, contains('redirects'));

      final missing = await check(const HttpResult(404, 'Not found'));
      expect(missing.results.single.message, contains('HTTP 404'));

      final invalid = await check(const HttpResult(200, '<html>'));
      expect(invalid.results.single.message, contains('not valid JSON'));
    });

    test('reports network errors', () async {
      final report = DoctorReport();
      await checkAppleAppSiteAssociation(
        report,
        (uri) async => throw const SocketException('offline'),
        host: _host,
        path: _path,
        appId: _appId,
      );
      expect(report.results.single.message, contains('Could not fetch'));
    });
  });

  group('checkAssetLinks', () {
    const linksPath = '/.well-known/assetlinks.json';

    Map<String, Object> entry(List<String> fingerprints) => {
      'relation': ['delegate_permission/common.handle_all_urls'],
      'target': {
        'namespace': 'android_app',
        'package_name': 'com.example.app',
        'sha256_cert_fingerprints': fingerprints,
      },
    };

    Future<DoctorReport> check(HttpResult response) async {
      final report = DoctorReport();
      await checkAssetLinks(
        report,
        _serve({linksPath: response}),
        host: _host,
        packageName: 'com.example.app',
        localKeys: const [('Debug', _key)],
      );
      return report;
    }

    test('passes when the package and local key are listed', () async {
      final report = await check(
        _json([
          entry(['aa:bb']),
        ]),
      );
      expect(_statuses(report), [CheckStatus.pass, CheckStatus.pass]);
    });

    test('warns when a local key is missing', () async {
      final report = await check(
        _json([
          entry(['CC:DD']),
        ]),
      );
      expect(_statuses(report), [CheckStatus.pass, CheckStatus.warning]);
      expect(report.results.last.fix, contains('AA:BB'));
    });

    test('fails without an entry for the package', () async {
      final report = await check(_json(<Object>[]));
      expect(_statuses(report), [CheckStatus.error]);
      expect(report.results.single.fix, contains('"AA:BB"'));
    });
  });
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:tiktok_auth/src/doctor/report.dart';
import 'package:tiktok_auth/src/doctor/signing.dart';

/// The parts of an HTTP response the domain checks need.
class HttpResult {
  /// Creates a result.
  const HttpResult(this.statusCode, this.body, {this.location, this.mimeType});

  /// The HTTP status code.
  final int statusCode;

  /// The response body.
  final String body;

  /// The `Location` header of a redirect.
  final String? location;

  /// The MIME type of the `Content-Type` header.
  final String? mimeType;
}

/// Fetches [uri] without following redirects.
typedef HttpGet = Future<HttpResult> Function(Uri uri);

/// Fetches [uri] with `dart:io`, without following redirects: Apple and
/// Google both require the verification files to be served directly.
Future<HttpResult> ioHttpGet(Uri uri) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await client.getUrl(uri);
    request.followRedirects = false;
    final response = await request.close().timeout(
      const Duration(seconds: 15),
    );
    final body = await response.transform(utf8.decoder).join();
    return HttpResult(
      response.statusCode,
      body,
      location: response.headers.value(HttpHeaders.locationHeader),
      mimeType: response.headers.contentType?.mimeType,
    );
  } finally {
    client.close(force: true);
  }
}

/// Returns whether [path] matches an `apple-app-site-association` [pattern],
/// where `*` matches any characters and `?` matches one character.
bool matchesAasaPattern(String pattern, String path) {
  final regex = StringBuffer('^');
  for (final char in pattern.split('')) {
    regex.write(switch (char) {
      '*' => '.*',
      '?' => '.',
      _ => RegExp.escape(char),
    });
  }
  regex.write(r'$');
  return RegExp(regex.toString()).hasMatch(path);
}

/// Checks that `https://<host>/.well-known/apple-app-site-association`
/// lets [appId] (`TEAMID.bundle.id`) open [path].
///
/// If the team is unknown, pass [bundleId] instead of [appId] and any team is
/// accepted.
Future<void> checkAppleAppSiteAssociation(
  DoctorReport report,
  HttpGet get, {
  required String host,
  required String path,
  String? appId,
  String? bundleId,
}) async {
  final uri = Uri.https(host, '/.well-known/apple-app-site-association');
  final response = await _fetch(report, get, uri);
  if (response == null) return;

  final Object? json;
  try {
    json = jsonDecode(response.body);
  } on FormatException {
    report.error('$uri is not valid JSON.');
    return;
  }
  final details = switch (json) {
    {'applinks': {'details': final List<Object?> details}} => details,
    _ => const <Object?>[],
  };

  final wanted = appId ?? '<TEAMID>.$bundleId';
  var listed = false;
  var matched = false;
  for (final detail in details.whereType<Map<String, Object?>>()) {
    final ids = switch (detail) {
      {'appIDs': final List<Object?> ids} => ids.whereType<String>().toList(),
      {'appID': final String id} => [id],
      _ => const <String>[],
    };
    final forThisApp = appId != null
        ? ids.contains(appId)
        : ids.any((id) => bundleId != null && id.endsWith('.$bundleId'));
    if (!forThisApp) continue;
    listed = true;
    if (_detailMatches(detail, path)) matched = true;
  }

  final fixJson =
      '''
Serve this at $uri:
{"applinks": {"details": [{"appIDs": ["$wanted"],
  "components": [{"/": "$path*"}]}]}}''';
  if (!listed) {
    report.error(
      'apple-app-site-association does not list $wanted.',
      fix: fixJson,
    );
  } else if (!matched) {
    report.error(
      'apple-app-site-association lists $wanted but not the path $path.',
      fix: fixJson,
    );
  } else {
    report.pass('apple-app-site-association allows $wanted to open $path.');
  }
}

bool _detailMatches(Map<String, Object?> detail, String path) {
  if (detail case {'components': final List<Object?> components}) {
    for (final component in components.whereType<Map<String, Object?>>()) {
      final pattern = component['/'];
      if (matchesAasaPattern(pattern is String ? pattern : '*', path)) {
        return component['exclude'] != true;
      }
    }
    return false;
  }
  if (detail case {'paths': final List<Object?> paths}) {
    for (final entry in paths.whereType<String>()) {
      final exclude = entry.startsWith('NOT ');
      if (matchesAasaPattern(exclude ? entry.substring(4) : entry, path)) {
        return !exclude;
      }
    }
  }
  return false;
}

/// Checks that `https://<host>/.well-known/assetlinks.json` verifies
/// [packageName], and reports which of [localKeys] it lists.
Future<void> checkAssetLinks(
  DoctorReport report,
  HttpGet get, {
  required String host,
  required String packageName,
  required List<(String, CertificateFingerprints)> localKeys,
}) async {
  final uri = Uri.https(host, '/.well-known/assetlinks.json');
  final response = await _fetch(report, get, uri);
  if (response == null) return;

  final Object? json;
  try {
    json = jsonDecode(response.body);
  } on FormatException {
    report.error('$uri is not valid JSON.');
    return;
  }

  final fingerprints = <String>{};
  if (json is List<Object?>) {
    for (final entry in json) {
      if (entry
          case {
            'relation': final List<Object?> relation,
            'target': {
              'namespace': 'android_app',
              'package_name': final String package,
              'sha256_cert_fingerprints': final List<Object?> prints,
            },
          }
          when package == packageName &&
              relation.contains('delegate_permission/common.handle_all_urls')) {
        fingerprints.addAll(prints.whereType<String>().map(_normalize));
      }
    }
  }

  if (fingerprints.isEmpty) {
    final example = localKeys.isEmpty
        ? '"AB:CD:..."'
        : localKeys.map((key) => '"${key.$2.sha256}"').join(', ');
    report.error(
      'assetlinks.json has no handle_all_urls entry for $packageName.',
      fix:
          '''
Serve this at $uri:
[{"relation": ["delegate_permission/common.handle_all_urls"],
  "target": {"namespace": "android_app", "package_name": "$packageName",
    "sha256_cert_fingerprints": [$example]}}]''',
    );
    return;
  }

  report.pass(
    'assetlinks.json verifies $packageName '
    '(${fingerprints.length} fingerprint'
    '${fingerprints.length == 1 ? '' : 's'}).',
  );
  for (final (label, key) in localKeys) {
    if (fingerprints.contains(_normalize(key.sha256))) {
      report.pass('assetlinks.json lists the $label key.');
    } else {
      report.warning(
        'assetlinks.json does not list the $label key. Builds signed with it '
        'will not open the redirect URI.',
        fix: 'Add "${key.sha256}" to sha256_cert_fingerprints.',
      );
    }
  }
}

String _normalize(String fingerprint) => fingerprint.trim().toUpperCase();

Future<HttpResult?> _fetch(DoctorReport report, HttpGet get, Uri uri) async {
  final HttpResult response;
  try {
    response = await get(uri);
  } on Exception catch (error) {
    report.error('Could not fetch $uri: $error');
    return null;
  }
  if (response.statusCode >= 300 && response.statusCode < 400) {
    report.error(
      '$uri redirects to ${response.location ?? 'another URL'}.',
      fix: 'Serve the file directly with HTTP 200. Redirects are not followed.',
    );
    return null;
  }
  if (response.statusCode != 200) {
    report.error(
      '$uri returned HTTP ${response.statusCode}.',
      fix: 'Host the file at exactly this URL over https.',
    );
    return null;
  }
  final mimeType = response.mimeType;
  if (mimeType != null && mimeType != 'application/json') {
    report.warning('$uri is served as $mimeType; use application/json.');
  }
  return response;
}

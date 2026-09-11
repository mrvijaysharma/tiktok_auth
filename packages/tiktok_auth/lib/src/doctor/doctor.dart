import 'dart:io';

import 'package:tiktok_auth/src/doctor/domain.dart';
import 'package:tiktok_auth/src/doctor/project.dart';
import 'package:tiktok_auth/src/doctor/report.dart';
import 'package:tiktok_auth/src/doctor/signing.dart';
import 'package:tiktok_auth/src/validation.dart';

/// The usage text printed by `--help`.
const doctorUsage = '''
Checks the TikTok Login setup of a Flutter app.

Run it from the app's root directory:
  dart run tiktok_auth:doctor [options]

Options:
  --client-key=<key>     The TikTok client key.
  --redirect-uri=<uri>   The redirect URI registered with TikTok.
  --project=<dir>        The Flutter app directory (default: current).
  --offline              Skip fetching the .well-known files.
  --no-color             Print without colors.
  -h, --help             Show this help.

The client key and redirect URI can also be set in pubspec.yaml:
  tiktok_auth:
    client_key: awxxxxxxxx
    redirect_uri: https://example.com/tiktok/callback''';

/// Command-line options of the doctor.
class DoctorOptions {
  /// Creates options.
  const DoctorOptions({
    this.clientKey,
    this.redirectUri,
    this.projectPath,
    this.offline = false,
    this.color = true,
    this.help = false,
  });

  /// Parses [arguments]. Throws a [FormatException] for unknown options.
  factory DoctorOptions.parse(List<String> arguments) {
    String? clientKey;
    String? redirectUri;
    String? projectPath;
    var offline = false;
    var color = true;
    var help = false;

    for (var i = 0; i < arguments.length; i++) {
      final argument = arguments[i];
      final separator = argument.indexOf('=');
      final name = separator < 0 ? argument : argument.substring(0, separator);
      String value() {
        if (separator >= 0) return argument.substring(separator + 1);
        if (i + 1 >= arguments.length) {
          throw FormatException('Missing value for $name.');
        }
        return arguments[++i];
      }

      switch (name) {
        case '--client-key':
          clientKey = value();
        case '--redirect-uri':
          redirectUri = value();
        case '--project':
          projectPath = value();
        case '--offline':
          offline = true;
        case '--no-color':
          color = false;
        case '-h' || '--help':
          help = true;
        default:
          throw FormatException('Unknown option $argument.');
      }
    }
    return DoctorOptions(
      clientKey: clientKey,
      redirectUri: redirectUri,
      projectPath: projectPath,
      offline: offline,
      color: color,
      help: help,
    );
  }

  /// The client key from the command line.
  final String? clientKey;

  /// The redirect URI from the command line.
  final String? redirectUri;

  /// The app directory from the command line.
  final String? projectPath;

  /// Whether to skip network checks.
  final bool offline;

  /// Whether to use ANSI colors.
  final bool color;

  /// Whether to print the usage.
  final bool help;
}

/// Runs the doctor with [arguments], writes the report to [out], and
/// returns the process exit code: 0 without errors, 1 with errors, 64 for
/// invalid usage.
Future<int> runDoctor(
  List<String> arguments, {
  StringSink? out,
  HttpGet httpGet = ioHttpGet,
  CertificateReader readCertificate = readCertificateWithKeytool,
  KeystoreRef? debugKeystore,
}) async {
  final sink = out ?? stdout;
  final DoctorOptions options;
  try {
    options = DoctorOptions.parse(arguments);
  } on FormatException catch (error) {
    sink
      ..writeln(error.message)
      ..writeln()
      ..writeln(doctorUsage);
    return 64;
  }
  if (options.help) {
    sink.writeln(doctorUsage);
    return 0;
  }

  final root = Directory(options.projectPath ?? Directory.current.path);
  final report = DoctorReport();
  final pubspec = File('${root.path}/pubspec.yaml');

  report.section('Configuration');
  if (!pubspec.existsSync()) {
    report.error(
      'No pubspec.yaml in ${root.path}.',
      fix: 'Run the doctor from your Flutter app directory, or pass --project.',
    );
    sink.write(report.render(color: options.color));
    return 1;
  }
  final fromPubspec = readPubspecConfig(pubspec.readAsStringSync());
  final clientKey = options.clientKey ?? fromPubspec['client_key'];
  final redirectUri = options.redirectUri ?? fromPubspec['redirect_uri'];
  if (clientKey == null || redirectUri == null) {
    report.error(
      'The client key and redirect URI are not set.',
      fix:
          'Add to pubspec.yaml:\n'
          'tiktok_auth:\n'
          '  client_key: awxxxxxxxx\n'
          '  redirect_uri: https://example.com/tiktok/callback\n'
          'or pass --client-key and --redirect-uri.',
    );
    sink.write(report.render(color: options.color));
    return 1;
  }

  final problems = [
    ...clientKeyProblems(clientKey),
    ...redirectUriProblems(redirectUri),
  ];
  if (problems.isNotEmpty) {
    problems.forEach(report.error);
    sink.write(report.render(color: options.color));
    return 1;
  }
  final redirect = Uri.parse(redirectUri);
  report
    ..pass('Client key: $clientKey')
    ..pass('Redirect URI: $redirectUri');

  final ios = _checkIos(
    report,
    root,
    clientKey: clientKey,
    host: redirect.host,
  );
  final android = _checkAndroid(report, root, redirect: redirect);
  final localKeys = android == null
      ? const <(String, CertificateFingerprints)>[]
      : await _checkSigning(
          report,
          root,
          readCertificate,
          debugKeystore ?? KeystoreRef.debug(),
        );

  report.section('Domain verification (${redirect.host})');
  if (options.offline) {
    report.info('Skipped (--offline).');
  } else {
    if (ios != null && (ios.bundleId != null)) {
      final team = ios.teamId;
      await checkAppleAppSiteAssociation(
        report,
        httpGet,
        host: redirect.host,
        path: redirect.path,
        appId: team == null ? null : '$team.${ios.bundleId}',
        bundleId: ios.bundleId,
      );
    }
    final packageName = android?.applicationId;
    if (packageName != null) {
      await checkAssetLinks(
        report,
        httpGet,
        host: redirect.host,
        packageName: packageName,
        localKeys: localKeys,
      );
    }
  }

  sink.write(report.render(color: options.color));
  return report.errorCount == 0 ? 0 : 1;
}

IosProject? _checkIos(
  DoctorReport report,
  Directory root, {
  required String clientKey,
  required String host,
}) {
  report.section('iOS');
  final IosProject? ios;
  try {
    ios = IosProject.read(root);
  } on FormatException catch (error) {
    report.error('Could not parse the iOS project: ${error.message}');
    return null;
  }
  if (ios == null) {
    report.info('No iOS project found.');
    return null;
  }
  final info = ios.infoPlist;

  final plistKey = info['TikTokClientKey'];
  if (plistKey is! String || plistKey.isEmpty) {
    report.error(
      'Info.plist is missing TikTokClientKey.',
      fix: 'Add <key>TikTokClientKey</key><string>$clientKey</string>.',
    );
  } else if (plistKey.contains(r'$(')) {
    report.warning(
      'TikTokClientKey is set from a build setting ($plistKey). Make sure it '
      'resolves to $clientKey.',
    );
  } else if (plistKey != clientKey) {
    report.error(
      'TikTokClientKey in Info.plist is $plistKey, not $clientKey.',
    );
  } else {
    report.pass('Info.plist TikTokClientKey matches.');
  }

  const required = ['tiktokopensdk', 'snssdk1180', 'snssdk1233'];
  final querySchemes = switch (info['LSApplicationQueriesSchemes']) {
    final List<Object?> schemes => schemes.whereType<String>().toSet(),
    _ => const <String>{},
  };
  final missing = required.where((s) => !querySchemes.contains(s)).toList();
  if (missing.isEmpty) {
    report.pass('Info.plist LSApplicationQueriesSchemes are set.');
  } else {
    report.error(
      'Info.plist LSApplicationQueriesSchemes is missing '
      '${missing.join(', ')}.',
      fix: 'Without them the TikTok app is never detected.',
    );
  }

  final urlSchemes = <String>{
    if (info['CFBundleURLTypes'] case final List<Object?> types)
      for (final type in types)
        if (type case {'CFBundleURLSchemes': final List<Object?> schemes})
          ...schemes.whereType<String>(),
  };
  if (urlSchemes.contains(clientKey)) {
    report.pass('Info.plist registers the $clientKey URL scheme.');
  } else if (urlSchemes.any((scheme) => scheme.contains(r'$('))) {
    report.warning(
      'CFBundleURLSchemes uses a build setting. Make sure one of them '
      'resolves to $clientKey.',
    );
  } else {
    report.error(
      'Info.plist does not register the URL scheme $clientKey.',
      fix:
          'Add it to CFBundleURLTypes > CFBundleURLSchemes. The browser '
          'sign-in cannot return to the app without it.',
    );
  }

  final bundleId = ios.bundleId;
  if (bundleId == null) {
    report.warning('Could not find the Runner bundle ID in project.pbxproj.');
  } else {
    report.info(
      'Bundle ID: $bundleId\n'
      'Register it for iOS in the TikTok developer portal.',
    );
  }
  if (ios.teamId == null) {
    report.warning(
      'The Runner target has no DEVELOPMENT_TEAM. Universal Links require a '
      'paid Apple Developer team.',
    );
  }

  final domains = switch (ios.entitlements?[_associatedDomains]) {
    final List<Object?> list => list.whereType<String>().toList(),
    _ => const <String>[],
  };
  final hasDomain = domains.any(
    (domain) =>
        domain == 'applinks:$host' || domain.startsWith('applinks:$host?'),
  );
  if (hasDomain) {
    report.pass('Associated Domains include applinks:$host.');
  } else {
    report.error(
      ios.entitlementsPath == null
          ? 'The Runner target has no entitlements, so Universal Links are off.'
          : 'Associated Domains do not include applinks:$host.',
      fix:
          'In Xcode: Runner target > Signing & Capabilities > + Capability > '
          'Associated Domains, then add applinks:$host.',
    );
  }
  return ios;
}

const _associatedDomains = 'com.apple.developer.associated-domains';

AndroidProject? _checkAndroid(
  DoctorReport report,
  Directory root, {
  required Uri redirect,
}) {
  report.section('Android');
  final android = AndroidProject.read(root);
  if (android == null) {
    report.info('No Android project found.');
    return null;
  }

  final applicationId = android.applicationId;
  if (applicationId == null) {
    report.warning('Could not find applicationId in ${android.buildFile}.');
  } else {
    report.info(
      'Application ID: $applicationId\n'
      'Register it for Android in the TikTok developer portal.',
    );
  }

  final expectedPath = redirect.path.startsWith('/')
      ? redirect.path.substring(1)
      : redirect.path;
  final placeholderFix =
      'In ${android.buildFile}, inside defaultConfig:\n'
      'manifestPlaceholders["tiktokRedirectHost"] = "${redirect.host}"\n'
      'manifestPlaceholders["tiktokRedirectPath"] = "$expectedPath"';

  final host = android.redirectHost;
  if (host == null) {
    report.error(
      'The tiktokRedirectHost manifest placeholder is not set.',
      fix: placeholderFix,
    );
  } else if (host != redirect.host) {
    report.error(
      'tiktokRedirectHost is "$host", but the redirect URI host is '
      '"${redirect.host}".',
      fix: placeholderFix,
    );
  } else {
    report.pass('tiktokRedirectHost matches.');
  }

  final path = android.redirectPath;
  if (path == null) {
    report.error(
      'The tiktokRedirectPath manifest placeholder is not set.',
      fix: placeholderFix,
    );
  } else if (path.startsWith('/')) {
    report.error(
      'tiktokRedirectPath must not start with "/" (the plugin adds it).',
      fix: placeholderFix,
    );
  } else if (path != expectedPath) {
    report.error(
      'tiktokRedirectPath is "$path", but the redirect URI path is '
      '"/$expectedPath".',
      fix: placeholderFix,
    );
  } else {
    report.pass('tiktokRedirectPath matches.');
  }
  return android;
}

Future<List<(String, CertificateFingerprints)>> _checkSigning(
  DoctorReport report,
  Directory root,
  CertificateReader readCertificate,
  KeystoreRef? debugKeystore,
) async {
  report.section('Android signing certificates');
  final keys = <(String, CertificateFingerprints)>[];
  final keystores = [?debugKeystore, ?KeystoreRef.release(root)];
  for (final keystore in keystores) {
    if (!File(keystore.path).existsSync()) {
      report.info(
        keystore.label == 'Debug'
            ? 'No debug keystore yet; it is created by the first debug build.'
            : 'Release keystore ${keystore.path} not found.',
      );
      continue;
    }
    final fingerprints = await readCertificate(keystore);
    if (fingerprints == null) {
      report.warning(
        'Could not read the ${keystore.label} key. Is keytool installed '
        '(set JAVA_HOME)?',
      );
      continue;
    }
    keys.add((keystore.label, fingerprints));
    report.info(
      '${keystore.label} key\n'
      'SHA-256: ${fingerprints.sha256}\n'
      'MD5:     ${fingerprints.md5} (${fingerprints.md5Compact})',
    );
  }
  report.info(
    'Register every signing key in the TikTok developer portal, including '
    'the Google Play App Signing key (Play Console > Test and release > '
    'App integrity) if you publish on Google Play.',
  );
  return keys;
}

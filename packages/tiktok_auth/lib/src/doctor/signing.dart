import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;

/// Fingerprints of an Android signing certificate.
class CertificateFingerprints {
  /// Creates fingerprints from colon-separated upper-case hex strings.
  const CertificateFingerprints({required this.sha256, required this.md5});

  /// Computes the fingerprints of a DER-encoded certificate.
  factory CertificateFingerprints.fromDer(List<int> der) =>
      CertificateFingerprints(
        sha256: _hex(crypto.sha256.convert(der).bytes),
        md5: _hex(crypto.md5.convert(der).bytes),
      );

  /// SHA-256, as used in `assetlinks.json` (`AB:CD:...`).
  final String sha256;

  /// MD5 (`AB:CD:...`).
  final String md5;

  /// MD5 as 32 lower-case hex digits, the form some portals expect.
  String get md5Compact => md5.replaceAll(':', '').toLowerCase();

  static String _hex(List<int> bytes) => bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(':');
}

/// A keystore entry to read a certificate from.
class KeystoreRef {
  /// Creates a keystore reference.
  const KeystoreRef({
    required this.label,
    required this.path,
    required this.alias,
    required this.storePassword,
  });

  /// The default debug keystore created by the Android tools.
  static KeystoreRef? debug() {
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home == null) return null;
    return KeystoreRef(
      label: 'Debug',
      path: '$home/.android/debug.keystore',
      alias: 'androiddebugkey',
      storePassword: 'android',
    );
  }

  /// The release keystore described by `android/key.properties`, the
  /// convention used in the Flutter deployment guide.
  static KeystoreRef? release(Directory root) {
    final file = File('${root.path}/android/key.properties');
    if (!file.existsSync()) return null;
    final properties = <String, String>{};
    for (final line in file.readAsLinesSync()) {
      final separator = line.indexOf('=');
      if (separator <= 0 || line.trimLeft().startsWith('#')) continue;
      properties[line.substring(0, separator).trim()] = line
          .substring(separator + 1)
          .trim();
    }
    final storeFile = properties['storeFile'];
    final alias = properties['keyAlias'];
    final password = properties['storePassword'];
    if (storeFile == null || alias == null || password == null) return null;
    // Flutter's guide resolves storeFile relative to the app module.
    final path = File(storeFile).isAbsolute
        ? storeFile
        : '${root.path}/android/app/$storeFile';
    return KeystoreRef(
      label: 'Release',
      path: path,
      alias: alias,
      storePassword: password,
    );
  }

  /// A name for the report, such as `Debug`.
  final String label;

  /// The keystore file.
  final String path;

  /// The key alias.
  final String alias;

  /// The keystore password. Never printed.
  final String storePassword;
}

/// Reads the certificate of [keystore], or returns `null` if it cannot.
typedef CertificateReader =
    Future<CertificateFingerprints?> Function(KeystoreRef keystore);

/// Reads a certificate with the JDK `keytool`.
///
/// The password is passed through an environment variable so it does not
/// appear in the process list.
Future<CertificateFingerprints?> readCertificateWithKeytool(
  KeystoreRef keystore,
) async {
  const passwordVariable = 'TIKTOK_AUTH_DOCTOR_STOREPASS';
  for (final keytool in _keytoolCandidates()) {
    try {
      final result = await Process.run(
        keytool,
        [
          '-exportcert',
          '-alias',
          keystore.alias,
          '-keystore',
          keystore.path,
          '-storepass:env',
          passwordVariable,
        ],
        environment: {passwordVariable: keystore.storePassword},
        stdoutEncoding: null,
      );
      if (result.exitCode != 0) return null;
      return CertificateFingerprints.fromDer(result.stdout as List<int>);
    } on ProcessException {
      continue;
    }
  }
  return null;
}

Iterable<String> _keytoolCandidates() sync* {
  final executable = Platform.isWindows ? 'keytool.exe' : 'keytool';
  yield executable;
  final javaHome = Platform.environment['JAVA_HOME'];
  if (javaHome != null) yield '$javaHome/bin/$executable';
  if (Platform.isMacOS) {
    const jbr = '/Applications/Android Studio.app/Contents/jbr/Contents/Home';
    yield '$jbr/bin/keytool';
  } else if (Platform.isWindows) {
    yield r'C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe';
  } else {
    final home = Platform.environment['HOME'];
    if (home != null) yield '$home/android-studio/jbr/bin/keytool';
    yield '/opt/android-studio/jbr/bin/keytool';
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:tiktok_auth/src/doctor/plist.dart';

/// Reads the `tiktok_auth:` section of a pubspec:
///
/// ```yaml
/// tiktok_auth:
///   client_key: awxxxxxxxx
///   redirect_uri: https://example.com/tiktok/callback
/// ```
Map<String, String> readPubspecConfig(String pubspec) {
  final lines = const LineSplitter().convert(pubspec);
  final start = lines.indexWhere(
    (line) => RegExp(r'^tiktok_auth:\s*(#.*)?$').hasMatch(line),
  );
  if (start < 0) return {};

  final values = <String, String>{};
  for (final line in lines.skip(start + 1)) {
    if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
    if (!line.startsWith(' ') && !line.startsWith('\t')) break;
    final match = RegExp(
      r'^\s+([A-Za-z_]+):\s*(.*?)\s*(\s#.*)?$',
    ).firstMatch(line);
    if (match != null) values[match[1]!] = _unquote(match[2]!);
  }
  return values;
}

String _unquote(String value) {
  if (value.length >= 2 &&
      (value.startsWith('"') && value.endsWith('"') ||
          value.startsWith("'") && value.endsWith("'"))) {
    return value.substring(1, value.length - 1);
  }
  return value;
}

/// What the doctor knows about the app's iOS project.
class IosProject {
  /// Creates a description of an iOS project.
  const IosProject({
    required this.infoPlist,
    this.bundleId,
    this.teamId,
    this.entitlementsPath,
    this.entitlements,
  });

  /// The parsed `ios/Runner/Info.plist`.
  final Map<String, Object?> infoPlist;

  /// The Runner target's `PRODUCT_BUNDLE_IDENTIFIER`.
  final String? bundleId;

  /// The Runner target's `DEVELOPMENT_TEAM`.
  final String? teamId;

  /// The Runner target's `CODE_SIGN_ENTITLEMENTS`, relative to `ios/`.
  final String? entitlementsPath;

  /// The parsed entitlements file, if there is one.
  final Map<String, Object?>? entitlements;

  /// Reads the iOS project in [root], or returns `null` if there is none.
  ///
  /// Throws a [FormatException] if a property list cannot be parsed.
  static IosProject? read(Directory root) {
    final infoFile = File('${root.path}/ios/Runner/Info.plist');
    if (!infoFile.existsSync()) return null;
    final info = parsePlist(infoFile.readAsStringSync());
    if (info is! Map<String, Object?>) {
      throw const FormatException('Info.plist is not a dictionary');
    }

    final pbxproj = File('${root.path}/ios/Runner.xcodeproj/project.pbxproj');
    final project = pbxproj.existsSync() ? pbxproj.readAsStringSync() : '';
    final bundleIds = _settings(
      project,
      'PRODUCT_BUNDLE_IDENTIFIER',
    ).where((id) => !id.endsWith('RunnerTests')).toList();
    final entitlementsPath = _settings(
      project,
      'CODE_SIGN_ENTITLEMENTS',
    ).firstOrNull;

    Map<String, Object?>? entitlements;
    if (entitlementsPath != null) {
      final file = File('${root.path}/ios/$entitlementsPath');
      if (file.existsSync()) {
        final parsed = parsePlist(file.readAsStringSync());
        if (parsed is Map<String, Object?>) entitlements = parsed;
      }
    }

    return IosProject(
      infoPlist: info,
      bundleId: bundleIds.firstOrNull,
      teamId: _settings(project, 'DEVELOPMENT_TEAM').firstOrNull,
      entitlementsPath: entitlementsPath,
      entitlements: entitlements,
    );
  }

  static Iterable<String> _settings(String pbxproj, String name) =>
      RegExp('$name = ([^;]+);')
          .allMatches(pbxproj)
          .map((match) => _unquote(match[1]!.trim()))
          .where((value) => value.isNotEmpty);
}

/// What the doctor knows about the app's Android project.
class AndroidProject {
  /// Creates a description of an Android project.
  const AndroidProject({
    required this.buildFile,
    this.applicationId,
    this.redirectHost,
    this.redirectPath,
  });

  /// Extracts the values the doctor needs from the Gradle build file
  /// [source], found at [buildFile].
  factory AndroidProject.parse(String source, {required String buildFile}) {
    final code = source.replaceAll(RegExp(r'^\s*//.*$', multiLine: true), '');
    return AndroidProject(
      buildFile: buildFile,
      applicationId: RegExp(
        r'''applicationId\s*=?\s*["']([^"']+)["']''',
      ).firstMatch(code)?[1],
      redirectHost: _placeholder(code, 'tiktokRedirectHost'),
      redirectPath: _placeholder(code, 'tiktokRedirectPath'),
    );
  }

  /// The app module's build file, relative to the project root.
  final String buildFile;

  /// The app's `applicationId`.
  final String? applicationId;

  /// The `tiktokRedirectHost` manifest placeholder.
  final String? redirectHost;

  /// The `tiktokRedirectPath` manifest placeholder.
  final String? redirectPath;

  /// Reads the Android project in [root], or returns `null` if there is none.
  static AndroidProject? read(Directory root) {
    for (final name in ['build.gradle.kts', 'build.gradle']) {
      final file = File('${root.path}/android/app/$name');
      if (file.existsSync()) {
        return AndroidProject.parse(
          file.readAsStringSync(),
          buildFile: 'android/app/$name',
        );
      }
    }
    return null;
  }

  /// Matches Kotlin (`["name"] = "v"`, `"name" to "v"`) and Groovy
  /// (`name: 'v'`, `name = 'v'`) placeholder syntax.
  static String? _placeholder(String code, String name) => RegExp(
    '["\']?$name["\']?\\s*(?:\\]\\s*=|:|\\bto\\b|=)\\s*["\']([^"\']*)["\']',
  ).firstMatch(code)?[1];
}

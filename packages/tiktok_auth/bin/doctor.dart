import 'dart:io';

import 'package:tiktok_auth/src/doctor/doctor.dart';

/// Checks the TikTok Login setup of the Flutter app in the current directory.
///
/// ```bash
/// dart run tiktok_auth:doctor
/// ```
Future<void> main(List<String> arguments) async {
  exitCode = await runDoctor(arguments);
}

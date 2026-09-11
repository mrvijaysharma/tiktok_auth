import 'dart:convert';
import 'dart:math';

/// Generates an unguessable OAuth `state` value: 256 random bits, encoded as
/// unpadded base64url.
String generateState({Random? random}) {
  final rng = random ?? Random.secure();
  final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}

/// Compares [actual] with [expected] in time that does not depend on where
/// the strings first differ. A `null` [actual] never matches.
bool constantTimeEquals(String? actual, String expected) {
  if (actual == null || actual.length != expected.length) return false;
  var difference = 0;
  for (var i = 0; i < expected.length; i++) {
    difference |= actual.codeUnitAt(i) ^ expected.codeUnitAt(i);
  }
  return difference == 0;
}

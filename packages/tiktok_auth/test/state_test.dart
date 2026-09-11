import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiktok_auth/src/state.dart';

void main() {
  group('generateState', () {
    test('returns 43 url-safe characters (256 bits)', () {
      final state = generateState();
      expect(state, hasLength(43));
      expect(state, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
    });

    test('returns a different value each time', () {
      final values = {for (var i = 0; i < 100; i++) generateState()};
      expect(values, hasLength(100));
    });

    test('uses the given random source', () {
      expect(
        generateState(random: Random(1)),
        generateState(random: Random(1)),
      );
    });
  });

  group('constantTimeEquals', () {
    test('matches equal strings', () {
      expect(constantTimeEquals('abc', 'abc'), isTrue);
    });

    test('rejects different strings of the same length', () {
      expect(constantTimeEquals('abd', 'abc'), isFalse);
    });

    test('rejects different lengths and null', () {
      expect(constantTimeEquals('ab', 'abc'), isFalse);
      expect(constantTimeEquals(null, 'abc'), isFalse);
    });
  });
}

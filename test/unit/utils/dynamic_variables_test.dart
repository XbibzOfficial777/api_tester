import 'package:test/test.dart';
import 'package:api_tester/core/utils/dynamic_variables.dart';

void main() {
  group('generateTimestamp', () {
    test('returns a positive integer', () {
      final ts = generateTimestamp();
      expect(ts, isA<int>());
      expect(ts, isPositive);
    });

    test('returns seconds since epoch (not milliseconds)', () {
      final ts = generateTimestamp();
      final msTs = DateTime.now().millisecondsSinceEpoch;
      // Should be within a few seconds of the current time in seconds.
      final expectedSeconds = msTs ~/ 1000;
      expect(ts, closeTo(expectedSeconds, 2));
    });
  });

  group('generateRandomString', () {
    test('returns empty string for length 0', () {
      final result = generateRandomString(0);
      expect(result, equals(''));
    });

    test('returns empty string for negative length', () {
      final result = generateRandomString(-5);
      expect(result, equals(''));
    });

    test('returns string of exact specified length', () {
      for (final length in [1, 5, 10, 16, 32, 100]) {
        final result = generateRandomString(length);
        expect(result.length, equals(length),
            reason: 'Expected length $length');
      }
    });

    test('only contains alphanumeric characters from the expected set', () {
      final result = generateRandomString(1000);
      final validChars = RegExp(r'^[a-zA-Z23456789]+$');
      expect(validChars.hasMatch(result), isTrue);
    });

    test('excludes ambiguous characters (0, O, 1, l, I)', () {
      final result = generateRandomString(5000);
      expect(result, isNot(contains('0')));
      expect(result, isNot(contains('O')));
      expect(result, isNot(contains('1')));
      expect(result, isNot(contains('l')));
      expect(result, isNot(contains('I')));
    });

    test('generates different strings on successive calls', () {
      final a = generateRandomString(16);
      final b = generateRandomString(16);
      // With 16 chars from a 61-char alphabet, the probability of collision
      // is astronomically low.
      expect(a, isNot(equals(b)));
    });
  });

  group('generateUUID', () {
    test('returns a string in UUID v4 format (8-4-4-4-12)', () {
      final uuid = generateUUID();
      final pattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      );
      expect(pattern.hasMatch(uuid), isTrue,
          reason: 'UUID "$uuid" does not match expected format');
    });

    test('has version nibble set to 4', () {
      final uuid = generateUUID();
      // Position 14 (after removing hyphens: index 12 in the hex array).
      expect(uuid[14], equals('4'));
    });

    test('has variant nibble in {8, 9, a, b}', () {
      final uuid = generateUUID();
      final variantChar = uuid[19];
      expect(['8', '9', 'a', 'b'], contains(variantChar));
    });

    test('is exactly 36 characters long (32 hex + 4 hyphens)', () {
      final uuid = generateUUID();
      expect(uuid.length, equals(36));
    });

    test('generates different UUIDs on successive calls', () {
      final a = generateUUID();
      final b = generateUUID();
      expect(a, isNot(equals(b)));
    });
  });

  group('generateRandomInt', () {
    test('returns value within the specified range [min, max]', () {
      for (var i = 0; i < 50; i++) {
        final result = generateRandomInt(1, 10);
        expect(result, greaterThanOrEqualTo(1));
        expect(result, lessThanOrEqualTo(10));
      }
    });

    test('returns min when min equals max', () {
      final result = generateRandomInt(42, 42);
      expect(result, equals(42));
    });

    test('handles swapped min/max by swapping them internally', () {
      // When min > max, the implementation swaps them.
      for (var i = 0; i < 20; i++) {
        final result = generateRandomInt(100, 1);
        expect(result, greaterThanOrEqualTo(1));
        expect(result, lessThanOrEqualTo(100));
      }
    });

    test('returns only positive integers for the default range', () {
      final result = resolveDynamicVariable('randomInt');
      expect(result, isNotNull);
      final parsed = int.tryParse(result!);
      expect(parsed, isNotNull);
      expect(parsed!, greaterThanOrEqualTo(1));
      expect(parsed, lessThanOrEqualTo(9999));
    });
  });

  group('resolveDynamicVariable', () {
    test('returns integer string for \$timestamp', () {
      final result = resolveDynamicVariable('timestamp');
      expect(result, isNotNull);
      expect(int.tryParse(result!), isNotNull);
    });

    test('returns integer string for \$timestampMs', () {
      final result = resolveDynamicVariable('timestampMs');
      expect(result, isNotNull);
      final parsed = int.tryParse(result!);
      expect(parsed, isNotNull);
      expect(parsed!, greaterThan(1000000000000)); // Milliseconds since epoch.
    });

    test('returns a string for \$randomString', () {
      final result = resolveDynamicVariable('randomString');
      expect(result, isNotNull);
      expect(result!.length, equals(16));
    });

    test('returns UUID format for \$uuid', () {
      final result = resolveDynamicVariable('uuid');
      expect(result, isNotNull);
      final pattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      expect(pattern.hasMatch(result!), isTrue);
    });

    test('returns integer string for \$randomInt', () {
      final result = resolveDynamicVariable('randomInt');
      expect(result, isNotNull);
      expect(int.tryParse(result!), isNotNull);
    });

    test('returns email-like string for \$randomEmail', () {
      final result = resolveDynamicVariable('randomEmail');
      expect(result, isNotNull);
      expect(result!.endsWith('@example.com'), isTrue);
      expect(result, contains('@'));
      // The local part should be 8 characters (from generateRandomString(8)).
      final localPart = result.split('@').first;
      expect(localPart.length, equals(8));
    });

    test('returns "true" or "false" for \$randomBool', () {
      final result = resolveDynamicVariable('randomBool');
      expect(result, isNotNull);
      expect(['true', 'false'], contains(result));
    });

    test('returns null for unknown variable name', () {
      final result = resolveDynamicVariable('unknownVariable');
      expect(result, isNull);
    });

    test('returns null for empty string', () {
      final result = resolveDynamicVariable('');
      expect(result, isNull);
    });
  });

  group('resolveAllDynamicVariables', () {
    test('replaces \$timestamp with a numeric value', () {
      final result = resolveAllDynamicVariables('time=\$timestamp');
      expect(result, startsWith('time='));
      final value = result.substring(5);
      expect(int.tryParse(value), isNotNull);
    });

    test('replaces multiple dynamic variables in one string', () {
      final result = resolveAllDynamicVariables(
        '{"id": "\$uuid", "ts": \$timestamp, "email": "\$randomEmail"}',
      );
      // Should not contain the raw variable references anymore.
      expect(result, isNot(contains('\$uuid')));
      expect(result, isNot(contains('\$timestamp')));
      expect(result, isNot(contains('\$randomEmail')));
      // Should contain @example.com from the email.
      expect(result, contains('@example.com'));
    });

    test('leaves unknown \$variables as-is', () {
      const input = 'price=\$50.00';
      final result = resolveAllDynamicVariables(input);
      // \$50 doesn't start with a letter, so it should be left as-is.
      expect(result, equals(input));
    });

    test('returns empty string for empty input', () {
      final result = resolveAllDynamicVariables('');
      expect(result, equals(''));
    });

    test('replaces \$randomBool with true or false', () {
      final result = resolveAllDynamicVariables('flag=\$randomBool');
      expect(
        result,
        anyOf(equals('flag=true'), equals('flag=false')),
      );
    });
  });
}
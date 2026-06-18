/// @file dynamic_variables.dart
/// @brief Dynamic variable generators for API testing workflows.
///
/// Provides functions that generate timestamp, random strings, UUIDs, and
/// random integers on-the-fly. These are useful in request bodies and URLs
/// where unique or time-based values are needed (e.g. signup flows,
/// idempotency keys, load testing).
///
/// Dynamic variables are referenced using the `$variableName` syntax and
/// resolved at request-sending time via [resolveDynamicVariable].

import 'dart:math';

/// Cryptographically-secure random number generator.
final _random = Random.secure();

/// Characters used by [generateRandomString].
///
/// Excludes visually ambiguous characters (0/O, 1/l/I) for clarity.
const String _alnumChars =
    'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ23456789';

/// Generates a Unix timestamp representing the current moment in seconds
/// since the Unix epoch (January 1, 1970, UTC).
///
/// ```dart
/// final ts = generateTimestamp(); // e.g. 1719000000
/// ```
int generateTimestamp() {
  return DateTime.now().millisecondsSinceEpoch ~/ 1000;
}

/// Generates a millisecond-precision Unix timestamp.
///
/// Useful for high-resolution timing requirements or unique identifiers.
int generateTimestampMs() {
  return DateTime.now().millisecondsSinceEpoch;
}

/// Generates a random alphanumeric string of exactly [length] characters.
///
/// Characters are drawn from [a-zA-Z2-3-9] (visually unambiguous).
/// The generator is cryptographically seeded for uniqueness.
///
/// ```dart
/// final s = generateRandomString(12); // e.g. 'kX7bNpQ2mRvT'
/// ```
String generateRandomString(int length) {
  if (length <= 0) return '';
  return List.generate(
    length,
    (_) => _alnumChars[_random.nextInt(_alnumChars.length)],
  ).join();
}

/// Generates a random UUID v4 string.
///
/// Follows the RFC 4122 §4.4 format: `xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx`
/// where `y` is one of `8`, `9`, `a`, or `b`.
///
/// ```dart
/// final id = generateUUID(); // e.g. '3e9f1a2c-7b4d-4e5f-8a6b-9c0d1e2f3a4b'
/// ```
String generateUUID() {
  // 32 hex characters
  final hex = List.generate(32, (_) => _random.nextInt(16).toRadixString(16));

  // Version nibble (4 at position 12)
  hex[12] = '4';

  // Variant nibble (8/9/a/b at position 16)
  final variantBits = _random.nextInt(4); // 0-3
  hex[16] = ['8', '9', 'a', 'b'][variantBits];

  // Insert hyphens: 8-4-4-4-12
  final buffer = StringBuffer();
  for (var i = 0; i < 36; i++) {
    if (i == 8 || i == 13 || i == 18 || i == 23) {
      buffer.write('-');
    } else {
      buffer.write(hex[i]);
    }
  }
  return buffer.toString();
}

/// Generates a random integer in the inclusive range [`min`, `max`].
///
/// ```dart
/// final dice = generateRandomInt(1, 6); // e.g. 4
/// ```
int generateRandomInt(int min, int max) {
  if (min > max) {
    // Swap so the range is always valid.
    final temp = min;
    min = max;
    max = temp;
  }
  return min + _random.nextInt(max - min + 1);
}

/// Resolves a named dynamic variable to its generated value.
///
/// Supported variable names:
///
/// | Name            | Example Output               |
/// |-----------------|------------------------------|
/// | `$timestamp`    | `1719000000`                 |
/// | `$timestampMs`  | `1719000000123`              |
/// | `$randomString` | `kX7bNpQ2mRvT`              |
/// | `$uuid`         | `3e9f1a2c-…`                 |
/// | `$randomInt`    | `42` (range 1–9999)          |
/// | `$randomEmail`  | `user@example.com`           |
/// | `$randomBool`   | `true` or `false`            |
///
/// Returns `null` if the variable name is not recognised.
///
/// ```dart
/// final ts = resolveDynamicVariable('\$timestamp'); // 1719000000
/// final unknown = resolveDynamicVariable('\$foo'); // null
/// ```
String? resolveDynamicVariable(String name) {
  switch (name) {
    case 'timestamp':
      return generateTimestamp().toString();
    case 'timestampMs':
      return generateTimestampMs().toString();
    case 'randomString':
      return generateRandomString(16);
    case 'uuid':
      return generateUUID();
    case 'randomInt':
      return generateRandomInt(1, 9999).toString();
    case 'randomEmail':
      return '${generateRandomString(8).toLowerCase()}@example.com';
    case 'randomBool':
      return _random.nextBool().toString();
    default:
      return null;
  }
}

/// Scans [input] for `$variableName` patterns and replaces them with
/// dynamically generated values.
///
/// Uses a regex that matches `$` followed by word characters. To avoid
/// replacing accidental `$` signs in currency values, the pattern requires
/// the variable name to start with a letter.
///
/// ```dart
/// final body = resolveAllDynamicVariables(
///   '{"ts": "$timestamp", "id": "$uuid"}',
/// );
/// ```
String resolveAllDynamicVariables(String input) {
  if (input.isEmpty) return input;

  // Match $ followed by a letter then more word characters.
  final regex = RegExp(r'\$([a-zA-Z]\w*)');

  return input.replaceAllMapped(regex, (match) {
    final varName = match.group(1)!;
    final value = resolveDynamicVariable(varName);
    return value ?? match.input.substring(match.start, match.end);
  });
}

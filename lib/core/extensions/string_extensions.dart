/// @file string_extensions.dart
/// @brief Extension methods on [String] for common formatting and validation.
///
/// Provides case-conversion helpers (snake, camel, kebab, title), content
/// validators (JSON, XML), and a truncation utility. All methods are
/// implemented as extensions on [String] for a fluent, discoverable API:
///
/// ```dart
/// 'hello world'.toTitleCase();  // 'Hello World'
/// '{"key": 1}'.isJson;          // true
/// ```

import 'dart:convert';

/// Extension that adds formatting, case-conversion, and validation methods
/// to [String].
extension StringExtensions on String {
  // ---------------------------------------------------------------------------
  // Case Conversion
  // ---------------------------------------------------------------------------

  /// Converts the string to `snake_case`.
  ///
  /// Handles `camelCase`, `PascalCase`, `kebab-case`, `Title Case`, and
  /// strings with existing separators. Multiple consecutive spaces or
  /// separators are collapsed to a single underscore.
  ///
  /// ```dart
  /// 'helloWorld'.toSnakeCase();     // 'hello_world'
  /// 'HelloWorld'.toSnakeCase();     // 'hello_world'
  /// 'hello-world'.toSnakeCase();    // 'hello_world'
  /// 'Hello World'.toSnakeCase();    // 'hello_world'
  /// '  hello   world  '.toSnakeCase(); // 'hello_world'
  /// ```
  String toSnakeCase() {
    // 1. Split on camelCase boundaries.
    final words = _splitIntoWords();
    return words.map((w) => w.toLowerCase()).join('_');
  }

  /// Converts the string to `camelCase`.
  ///
  /// The first word is lowercased; subsequent words are capitalised and
  /// concatenated without separators.
  ///
  /// ```dart
  /// 'hello_world'.toCamelCase();     // 'helloWorld'
  /// 'hello-world'.toCamelCase();     // 'helloWorld'
  /// 'Hello World'.toCamelCase();     // 'helloWorld'
  /// 'hello_world'.toCamelCase();     // 'helloWorld'
  /// ```
  String toCamelCase() {
    final words = _splitIntoWords().map((w) => w.toLowerCase()).toList();
    if (words.isEmpty) return '';
    final first = words.first;
    final rest = words.skip(1).map(_capitalize).join();
    return '$first$rest';
  }

  /// Converts the string to `kebab-case`.
  ///
  /// ```dart
  /// 'helloWorld'.toKebabCase();     // 'hello-world'
  /// 'Hello World'.toKebabCase();    // 'hello-world'
  /// 'hello_world'.toKebabCase();    // 'hello-world'
  /// ```
  String toKebabCase() {
    final words = _splitIntoWords();
    return words.map((w) => w.toLowerCase()).join('-');
  }

  /// Converts the string to `Title Case` (first letter of each word
  /// capitalised, rest lowercased).
  ///
  /// ```dart
  /// 'hello world'.toTitleCase();    // 'Hello World'
  /// 'hELLO wORLD'.toTitleCase();    // 'Hello World'
  /// 'hello-world'.toTitleCase();    // 'Hello World'
  /// ```
  String toTitleCase() {
    final words = _splitIntoWords();
    return words.map(_capitalize).join(' ');
  }

  // ---------------------------------------------------------------------------
  // Content Validation
  // ---------------------------------------------------------------------------

  /// Returns `true` if the string appears to contain valid JSON.
  ///
  /// Performs a trial JSON decode; returns `false` for any [FormatException].
  /// Note: empty strings and whitespace-only strings return `false`.
  ///
  /// ```dart
  /// '{"key": "value"}'.isJson;   // true
  /// '[1, 2, 3]'.isJson;          // true
  /// 'not json'.isJson;           // false
  /// ''.isJson;                    // false
  /// ```
  bool get isJson {
    final trimmed = trim();
    if (trimmed.isEmpty) return false;
    try {
      jsonDecode(trimmed);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Returns `true` if the string appears to contain valid XML.
  ///
  /// A lightweight heuristic: the string must be non-empty and contain at
  /// least one opening XML tag (`<name`). This does **not** perform a full
  /// DTD or schema validation.
  ///
  /// ```dart
  /// '<root><item/></root>'.isXml;   // true
  /// '<?xml version="1.0"?>'.isXml;  // true
  /// 'not xml'.isXml;                // false
  /// ```
  bool get isXml {
    final trimmed = trim();
    if (trimmed.isEmpty) return false;
    // Check for XML declaration or at least one opening tag.
    return trimmed.contains('<?xml') || RegExp(r'<\w+[^>]*>').hasMatch(trimmed);
  }

  // ---------------------------------------------------------------------------
  // Truncation
  // ---------------------------------------------------------------------------

  /// Returns a truncated copy of the string limited to [maxLength] characters.
  ///
  /// If the original string is shorter than or equal to [maxLength] it is
  /// returned unchanged. Otherwise, the result is the first [maxLength]
  /// characters followed by the [suffix] (default `"…"`).
  ///
  /// ```dart
  /// 'Hello, World!'.truncate(5);            // 'Hello…'
  /// 'Hi'.truncate(10);                       // 'Hi'
  /// 'Hello'.truncate(3, suffix: '...');      // 'Hel...'
  /// ```
  String truncate(int maxLength, {String suffix = '…'}) {
    if (length <= maxLength) return this;
    if (maxLength <= 0) return '';
    return '${substring(0, maxLength)}$suffix';
  }

  // ---------------------------------------------------------------------------
  // Internal Helpers
  // ---------------------------------------------------------------------------

  /// Splits an arbitrary string into lowercase word tokens.
  ///
  /// Handles camelCase boundaries, PascalCase, snake_case, kebab-case,
  /// spaces, and mixed separators. Empty tokens are discarded.
  List<String> _splitIntoWords() {
    // Insert spaces before uppercase letters (camelCase → camel Case).
    final spaced = replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (Match m) => '${m.group(1)} ${m.group(2)}',
    );

    // Replace all common separators with spaces.
    final normalised = spaced
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll('.', ' ');

    // Collapse multiple spaces and trim.
    return normalised
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
  }

  /// Capitalises the first character of [word] and lowercases the rest.
  String _capitalize(String word) {
    if (word.isEmpty) return '';
    return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
  }
}

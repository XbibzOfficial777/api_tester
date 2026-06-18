/// @file environment_variable_parser.dart
/// @brief Template variable substitution engine.
///
/// Scans a string for `{{variableName}}` patterns and replaces each
/// occurrence with the corresponding value from the supplied [variables]
/// map. If a variable name has no matching entry the placeholder is left
/// unchanged, which makes debugging easier than silently swallowing it.
///
/// Works for URLs, headers, body text, query parameters, and any other
/// string that supports template substitution.
///
/// ## Usage
/// ```dart
/// final variables = {'baseUrl': 'https://api.example.com', 'userId': '42'};
/// final url = parseVariables('{{baseUrl}}/users/{{userId}}', variables);
/// // Result: 'https://api.example.com/users/42'
/// ```

/// Regular expression that matches `{{variableName}}` patterns.
///
/// - Captures the variable name between double curly braces.
/// - Handles variable names containing letters, digits, underscores,
///   hyphens, and dots (for nested references like `auth.token`).
final _variableRegex = RegExp(r'\{\{([\w\-.]+)\}\}');

/// Replaces all `{{variable}}` placeholders in [input] with values from
/// the [variables] map.
///
/// **Matching rules:**
/// - The pattern `{{key}}` is replaced by `variables[key]` if it exists.
/// - The pattern `{{key}}` is **preserved as-is** if `key` is missing from
///   the map, which aids debugging by keeping the unresolved placeholder
///   visible in the UI.
/// - Both `toString()` and special types are supported — values are
///   converted to strings via `.toString()`.
///
/// **Parameters:**
/// - [input] — The template string containing `{{…}}` placeholders.
/// - [variables] — A flat map of variable names to replacement values.
///
/// **Returns:**
/// A new string with all matched placeholders resolved.
///
/// ```dart
/// final result = parseVariables(
///   'Hello {{name}}, your order {{orderId}} is ready.',
///   {'name': 'Alice', 'orderId': '12345'},
/// );
/// // 'Hello Alice, your order 12345 is ready.'
/// ```
String parseVariables(String input, Map<String, dynamic> variables) {
  if (input.isEmpty || variables.isEmpty) return input;

  return input.replaceAllMapped(_variableRegex, (match) {
    final variableName = match.group(1)!;
    final value = variables[variableName];
    if (value == null) {
      // Keep the placeholder so the user can see which variable is missing.
      return match.input.substring(match.start, match.end);
    }
    return value.toString();
  });
}

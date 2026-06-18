/// @file environment_variable.dart
/// @brief Domain entity for an environment variable.
///
/// Environment variables allow users to define reusable values (such as
/// base URLs, API keys, and tokens) that can be referenced in requests
/// using the {{variableName}} syntax.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'environment_variable.freezed.dart';
part 'environment_variable.g.dart';

/// The data type of an environment variable.
enum VariableType {
  /// A plain text string value.
  @JsonValue('string')
  string,

  /// A numeric value (integer or floating point).
  @JsonValue('number')
  number,

  /// A boolean value (true/false).
  @JsonValue('boolean')
  boolean,
}

/// A single variable within an environment.
///
/// Variables are referenced in request URLs, headers, bodies, etc.
/// using the double-curly-brace syntax: `{{variableName}}`.
@freezed
class EnvironmentVariable with _$EnvironmentVariable {
  /// Creates a new [EnvironmentVariable] instance.
  ///
  /// [key] - The variable name used for referencing (e.g., "base_url").
  /// [value] - The actual value to substitute.
  /// [type] - The data type of the variable. Defaults to [VariableType.string].
  /// [description] - Human-readable description of what this variable represents.
  /// [isEnabled] - Whether this variable is currently active for substitution.
  const factory EnvironmentVariable({
    required String key,
    required String value,
    @Default(VariableType.string) VariableType type,
    @Default('') String description,
    @Default(true) bool isEnabled,
  }) = _EnvironmentVariable;

  /// Deserializes an [EnvironmentVariable] from a JSON map.
  factory EnvironmentVariable.fromJson(Map<String, dynamic> json) =>
      _$EnvironmentVariableFromJson(json);
}
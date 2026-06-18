/// @file assertion.dart
/// @brief Domain entity for a test assertion on an API response.
///
/// Assertions define expected conditions that an API response must satisfy.
/// They are evaluated after a request is sent and their results determine
/// whether the request is considered to have passed or failed in
/// collection runs and automated testing scenarios.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'assertion.freezed.dart';
part 'assertion.g.dart';

/// The property of the response to assert against.
enum AssertionType {
  /// Assert on the HTTP status code.
  @JsonValue('statusCode')
  statusCode,

  /// Assert that the response body contains a specific string.
  @JsonValue('bodyContains')
  bodyContains,

  /// Assert that a specific response header exists (and optionally has a value).
  @JsonValue('headerExists')
  headerExists,

  /// Assert on the response time in milliseconds.
  @JsonValue('responseTime')
  responseTime,
}

/// The comparison operator to use for the assertion.
enum AssertionOperator {
  /// The actual value must exactly equal the expected value.
  @JsonValue('equals')
  equals,

  /// The actual value must not equal the expected value.
  @JsonValue('notEquals')
  notEquals,

  /// The actual value must contain the expected value as a substring.
  @JsonValue('contains')
  contains,

  /// The actual numeric value must be less than the expected value.
  @JsonValue('lessThan')
  lessThan,

  /// The actual numeric value must be greater than the expected value.
  @JsonValue('greaterThan')
  greaterThan,

  /// The actual value must match the expected value as a regular expression.
  @JsonValue('matches')
  matches,
}

/// A test assertion attached to a specific request.
///
/// Each assertion defines a property to check, an expected value,
/// and a comparison operator. After execution, the actual value,
/// pass/fail status, and optional error message are populated.
@freezed
class Assertion with _$Assertion {
  /// Creates a new [Assertion] instance.
  ///
  /// [id] - Unique identifier for this assertion.
  /// [requestId] - The request this assertion is attached to.
  /// [type] - Which response property to evaluate.
  /// [expectedValue] - The value to compare against.
  /// [operator] - The comparison operator to apply.
  /// [actualValue] - The actual value observed after evaluation (populated at runtime).
  /// [passed] - Whether the assertion passed (populated at runtime).
  /// [errorMessage] - Human-readable error message if the assertion failed.
  const factory Assertion({
    required String id,
    required String requestId,
    required AssertionType type,
    required String expectedValue,
    @Default(AssertionOperator.equals) AssertionOperator operator,
    String? actualValue,
    bool? passed,
    String? errorMessage,
  }) = _Assertion;

  /// Deserializes an [Assertion] from a JSON map.
  factory Assertion.fromJson(Map<String, dynamic> json) =>
      _$AssertionFromJson(json);
}
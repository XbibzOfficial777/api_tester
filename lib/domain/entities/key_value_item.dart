/// @file key_value_item.dart
/// @brief Domain entity for a generic key-value pair with enable toggle.
///
/// Used for headers, query parameters, and other simple key-value
/// collections throughout the application. Each item has an [isEnabled]
/// flag to allow users to temporarily disable specific entries without
/// deleting them.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'key_value_item.freezed.dart';
part 'key_value_item.g.dart';

/// A generic key-value pair with an enable/disable toggle.
///
/// Commonly used for HTTP headers, query parameters, and form fields
/// where individual items may need to be toggled on or off.
@freezed
class KeyValueItem with _$KeyValueItem {
  /// Creates a new [KeyValueItem] instance.
  ///
  /// [key] - The parameter name or header key.
  /// [value] - The parameter value or header value.
  /// [isEnabled] - Whether this item is currently active. Defaults to true.
  /// [id] - Unique identifier for this item.
  const factory KeyValueItem({
    required String key,
    required String value,
    @Default(true) bool isEnabled,
    required String id,
  }) = _KeyValueItem;

  /// Deserializes a [KeyValueItem] from a JSON map.
  factory KeyValueItem.fromJson(Map<String, dynamic> json) =>
      _$KeyValueItemFromJson(json);
}
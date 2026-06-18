/// Represents a simple key-value pair used for headers, query parameters,
/// form data, and environment variables throughout the application.
class KeyValue {
  /// The key of this key-value pair (e.g., header name, variable name).
  final String key;

  /// The value associated with [key].
  final String value;

  /// Whether this entry is currently enabled / active.
  /// Disabled entries are ignored during request execution.
  final bool enabled;

  const KeyValue({
    required this.key,
    required this.value,
    this.enabled = true,
  });

  /// Creates a copy of this [KeyValue] with optional field overrides.
  KeyValue copyWith({
    String? key,
    String? value,
    bool? enabled,
  }) {
    return KeyValue(
      key: key ?? this.key,
      value: value ?? this.value,
      enabled: enabled ?? this.enabled,
    );
  }

  /// Serialises this pair to a JSON-encodable map.
  Map<String, dynamic> toJson() => {
        'key': key,
        'value': value,
        'enabled': enabled,
      };

  /// Deserialises a [KeyValue] from a JSON map.
  factory KeyValue.fromJson(Map<String, dynamic> json) {
    return KeyValue(
      key: json['key'] as String? ?? '',
      value: json['value'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeyValue &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          value == other.value &&
          enabled == other.enabled;

  @override
  int get hashCode => Object.hash(key, value, enabled);

  @override
  String toString() => 'KeyValue(key: $key, value: $value, enabled: $enabled)';
}
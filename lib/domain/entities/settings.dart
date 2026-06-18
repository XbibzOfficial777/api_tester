/// Domain entity representing a single application-wide setting stored as a
/// key-value pair.
class Setting {
  /// Unique setting key (e.g. "theme", "default_timeout").
  final String key;

  /// The setting value as a plain string.
  final String value;

  const Setting({
    required this.key,
    required this.value,
  });

  /// Creates a mutable copy with optional field overrides.
  Setting copyWith({
    String? key,
    String? value,
  }) {
    return Setting(
      key: key ?? this.key,
      value: value ?? this.value,
    );
  }
}
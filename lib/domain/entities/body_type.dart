/// Enumerates the supported HTTP body types for API requests.
///
/// Each variant maps to a specific content type and serialisation strategy
/// used when sending the request via [Dio].
enum BodyType {
  /// No request body is sent.
  none,

  /// `multipart/form-data` – file uploads and keyed form fields.
  formData,

  /// `application/x-www-form-urlencoded` – URL-encoded key-value body.
  urlEncoded,

  /// Raw text body (JSON, XML, plain text, etc.).
  raw,

  /// Binary file body sent as-is.
  binary,
}

/// Extension that provides a human-readable display name for each [BodyType].
extension BodyTypeX on BodyType {
  /// A short user-facing label.
  String get label => switch (this) {
        BodyType.none       => 'None',
        BodyType.formData   => 'Form Data',
        BodyType.urlEncoded => 'URL Encoded',
        BodyType.raw        => 'Raw',
        BodyType.binary     => 'Binary',
      };

  /// Serialises the enum to the string value stored in the database.
  String toDbString() => name;

  /// Deserialises a database string back to a [BodyType].
  /// Falls back to [BodyType.none] when the string is unrecognised.
  static BodyType fromDbString(String value) {
    return BodyType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => BodyType.none,
    );
  }
}
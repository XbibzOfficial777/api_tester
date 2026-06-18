/// @file form_data_item.dart
/// @brief Domain entity for multipart form data items.
///
/// Represents a single entry in a multipart/form-data request body.
/// Each item can be either a text field or a file upload, determined
/// by the [isFile] flag.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'form_data_item.freezed.dart';
part 'form_data_item.g.dart';

/// A single item in a multipart/form-data request.
///
/// Supports both text fields and file uploads. When [isFile] is true,
/// [filePath] and [fileName] are used to locate and identify the file
/// to upload. The [contentType] field allows specifying the MIME type.
@freezed
class FormDataItem with _$FormDataItem {
  /// Creates a new [FormDataItem] instance.
  ///
  /// [key] - The form field name.
  /// [value] - The text value (ignored when [isFile] is true).
  /// [isFile] - Whether this item represents a file upload.
  /// [filePath] - Absolute path to the file on disk (when [isFile] is true).
  /// [fileName] - Original filename to send with the upload.
  /// [contentType] - MIME type (e.g., "image/png", "application/json").
  /// [id] - Unique identifier for this item.
  const factory FormDataItem({
    required String key,
    required String value,
    @Default(false) bool isFile,
    @Default('') String filePath,
    @Default('') String fileName,
    @Default('') String contentType,
    required String id,
  }) = _FormDataItem;

  /// Deserializes a [FormDataItem] from a JSON map.
  factory FormDataItem.fromJson(Map<String, dynamic> json) =>
      _$FormDataItemFromJson(json);
}
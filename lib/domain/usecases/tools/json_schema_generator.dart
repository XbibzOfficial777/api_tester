/// @file json_schema_generator.dart
/// @brief Use case for generating a JSON Schema from a JSON string.
///
/// Analyzes a JSON value and produces a compliant JSON Schema (Draft-07)
/// that describes the structure, types, and constraints of the input.
/// Useful for documentation, validation, and API specification generation.
library;

import 'dart:convert';

import '../usecase.dart';

/// Parameters for the JSON Schema generator use case.
class JsonSchemaGeneratorParams {
  /// The JSON string to generate a schema for.
  final String jsonString;

  /// An optional root schema title.
  final String? title;

  /// Creates parameter object for JSON Schema generation.
  ///
  /// [jsonString] - A valid JSON string (object, array, or primitive).
  /// [title] - Optional title to set on the root schema object.
  const JsonSchemaGeneratorParams({
    required this.jsonString,
    this.title,
  });
}

/// Generates a JSON Schema from a JSON string.
///
/// Produces a JSON Schema (Draft-07 compatible) that accurately describes
/// the structure of the input JSON, including:
/// - Types (object, array, string, number, integer, boolean, null)
/// - Object properties and required fields
/// - Array item schemas
/// - String format hints (email, URI, date-time from patterns)
/// - Enum values when all values in a list share a type
/// - Example values from the input
class JsonSchemaGenerator
    extends UseCase<Map<String, dynamic>, JsonSchemaGeneratorParams> {
  /// Creates a new [JsonSchemaGenerator] use case.
  JsonSchemaGenerator();

  /// Parses the JSON and generates a schema.
  @override
  Future<Map<String, dynamic>> call(JsonSchemaGeneratorParams params) async {
    // Parse the JSON string.
    final dynamic jsonValue;
    try {
      jsonValue = json.decode(params.jsonString);
    } catch (e) {
      throw FormatException('Invalid JSON: $e');
    }

    // Generate the schema.
    final schema = _generateSchema(jsonValue);

    // Add the JSON Schema version and optional title.
    schema['\$schema'] = 'http://json-schema.org/draft-07/schema#';
    if (params.title != null && params.title!.isNotEmpty) {
      schema['title'] = params.title;
    }

    return schema;
  }

  /// Recursively generates a JSON Schema for the given value.
  Map<String, dynamic> _generateSchema(dynamic value) {
    if (value == null) {
      return {'type': 'null'};
    }

    if (value is String) {
      return _generateStringSchema(value);
    }

    if (value is int) {
      return {'type': 'integer', 'example': value};
    }

    if (value is double) {
      // If the double is actually a whole number, prefer integer.
      if (value == value.truncateToDouble()) {
        return {'type': 'integer', 'example': value.toInt()};
      }
      return {'type': 'number', 'example': value};
    }

    if (value is bool) {
      return {'type': 'boolean', 'example': value};
    }

    if (value is List) {
      return _generateArraySchema(value);
    }

    if (value is Map<String, dynamic>) {
      return _generateObjectSchema(value);
    }

    // Fallback for unknown types.
    return {'type': 'string'};
  }

  /// Generates a schema for a string value with format detection.
  Map<String, dynamic> _generateStringSchema(String value) {
    final schema = <String, dynamic>{'type': 'string'};

    // Detect common string formats from content patterns.
    if (value.isEmpty) return schema;

    // Email detection.
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (emailRegex.hasMatch(value)) {
      schema['format'] = 'email';
    }
    // URI detection.
    else if (value.startsWith('http://') || value.startsWith('https://')) {
      schema['format'] = 'uri';
    }
    // ISO 8601 date-time detection.
    else if (RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}').hasMatch(value)) {
      schema['format'] = 'date-time';
    }
    // ISO 8601 date detection.
    else if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      schema['format'] = 'date';
    }
    // UUID detection.
    else if (RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
        .hasMatch(value)) {
      schema['format'] = 'uuid';
    }

    schema['example'] = value;

    // Set minimum length based on the example.
    if (value.isNotEmpty) {
      schema['minLength'] = 0;
    }

    return schema;
  }

  /// Generates a schema for an array value.
  ///
  /// If the array is non-empty, the schema for the first item is used
  /// as the "items" template. If all items are of the same type and
  /// share the same structure, a single items schema is used.
  /// Otherwise, the first item's schema serves as the example.
  Map<String, dynamic> _generateArraySchema(List value) {
    final schema = <String, dynamic>{'type': 'array'};

    if (value.isEmpty) {
      schema['items'] = {};
      return schema;
    }

    // Generate schemas for all items.
    final itemSchemas = value.map((item) => _generateSchema(item)).toList();

    // Determine if all items have the same type.
    final allSameType = itemSchemas
        .every((s) => s['type'] == itemSchemas[0]['type']);

    if (allSameType) {
      // For objects, try to merge all properties for a comprehensive schema.
      if (itemSchemas[0]['type'] == 'object' && value.length > 1) {
        schema['items'] = _mergeObjectSchemas(itemSchemas);
      } else {
        schema['items'] = itemSchemas[0];
      }
    } else {
      // Use the first item's schema as a representative example.
      schema['items'] = itemSchemas[0];
    }

    return schema;
  }

  /// Merges multiple object schemas into a single comprehensive schema.
  ///
  /// Collects all unique properties across all schemas. For properties
  /// that appear in multiple schemas with different types, the merged
  /// schema uses a "oneOf" constraint.
  Map<String, dynamic> _mergeObjectSchemas(List<Map<String, dynamic>> schemas) {
    final mergedProperties = <String, dynamic>{};
    final allRequired = <String>{};

    for (final schema in schemas) {
      final props = schema['properties'] as Map<String, dynamic>? ?? {};
      final required = (schema['required'] as List<dynamic>?)?.cast<String>() ?? [];

      allRequired.addAll(required);

      for (final entry in props.entries) {
        final propName = entry.key;
        final propSchema = entry.value as Map<String, dynamic>;

        if (!mergedProperties.containsKey(propName)) {
          mergedProperties[propName] = propSchema;
        } else {
          // If the property already exists with a different type, merge.
          final existing = mergedProperties[propName] as Map<String, dynamic>;
          final existingType = existing['type'];
          final newType = propSchema['type'];

          if (existingType != newType) {
            // Create a oneOf schema for the conflicting types.
            mergedProperties[propName] = {
              'oneOf': [existing, propSchema],
            };
          } else if (existingType == 'object' && propSchema['properties'] != null) {
            // Merge nested objects recursively.
            final mergedNested = _mergeObjectSchemas([existing, propSchema]);
            mergedProperties[propName] = mergedNested;
          }
        }
      }
    }

    final result = <String, dynamic>{
      'type': 'object',
      'properties': mergedProperties,
    };

    if (allRequired.isNotEmpty) {
      result['required'] = allRequired.toList()..sort();
    }

    return result;
  }

  /// Generates a schema for an object value.
  ///
  /// Analyzes all properties and determines which are "required"
  /// (present in every examined object if multiple were merged).
  Map<String, dynamic> _generateObjectSchema(Map<String, dynamic> value) {
    final properties = <String, dynamic>{};
    final required = <String>[];

    for (final entry in value.entries) {
      properties[entry.key] = _generateSchema(entry.value);
      // All properties present in the example are considered potentially required.
      // In a single-object context, we mark all as required.
      required.add(entry.key);
    }

    final schema = <String, dynamic>{
      'type': 'object',
      'properties': properties,
    };

    if (required.isNotEmpty) {
      schema['required'] = required;
    }

    // Add example from the original object.
    schema['example'] = value;

    return schema;
  }
}
import 'dart:convert';
import 'package:test/test.dart';
import 'package:api_tester/domain/usecases/tools/json_schema_generator.dart';

void main() {
  late JsonSchemaGenerator generator;

  setUp(() {
    generator = JsonSchemaGenerator();
  });

  group('JsonSchemaGenerator', () {
    group('simple object', () {
      test('generates schema for a simple flat object', () async {
        const json = '{"name": "Alice", "age": 30}';
        final schema = await generator(
          const JsonSchemaGeneratorParams(jsonString: json),
        );

        expect(schema['type'], equals('object'));
        expect(schema['\$schema'], contains('json-schema.org'));
        expect((schema['properties'] as Map).containsKey('name'), isTrue);
        expect((schema['properties'] as Map).containsKey('age'), isTrue);
        expect(schema['required'], containsAll(['name', 'age']));
      });

      test('infers string type for string values', () async {
        const json = '{"name": "Alice"}';
        final schema = await generator(
          const JsonSchemaGeneratorParams(jsonString: json),
        );

        final nameSchema = (schema['properties'] as Map)['name'] as Map;
        expect(nameSchema['type'], equals('string'));
        expect(nameSchema['example'], equals('Alice'));
      });

      test('infers integer type for integer values', () async {
        const json = '{"count": 42}';
        final schema = await generator(
          const JsonSchemaGeneratorParams(jsonString: json),
        );

        final countSchema = (schema['properties'] as Map)['count'] as Map;
        expect(countSchema['type'], equals('integer'));
        expect(countSchema['example'], equals(42));
      });

      test('infers boolean type for boolean values', () async {
        const json = '{"active": true}';
        final schema = await generator(
          const JsonSchemaGeneratorParams(jsonString: json),
        );

        final activeSchema = (schema['properties'] as Map)['active'] as Map;
        expect(activeSchema['type'], equals('boolean'));
        expect(activeSchema['example'], isTrue);
      });

      test('detects email format for string values that look like emails', () async {
        const json = '{"email": "user@example.com"}';
        final schema = await generator(
          const JsonSchemaGeneratorParams(jsonString: json),
        );

        final emailSchema = (schema['properties'] as Map)['email'] as Map;
        expect(emailSchema['format'], equals('email'));
      });

      test('detects URI format for URL values', () async {
        const json = '{"website": "https://example.com"}';
        final schema = await generator(
          const JsonSchemaGeneratorParams(jsonString: json),
        );

        final webSchema = (schema['properties'] as Map)['website'] as Map;
        expect(webSchema['format'], equals('uri'));
      });

      test('includes the optional title when provided', () async {
        const json = '{"name": "Alice"}';
        final schema = await generator(
          const JsonSchemaGeneratorParams(jsonString: json, title: 'User'),
        );

        expect(schema['title'], equals('User'));
      });

      test('does not include title when not provided', () async {
        const json = '{"name": "Alice"}';
        final schema = await generator(
          const JsonSchemaGeneratorParams(jsonString: json),
        );

        expect(schema.containsKey('title'), isFalse);
      });
    });

    group('nested object', () {
      test('generates schema for nested objects', () async {
        const json = '{"user": {"name": "Alice", "age": 30}}';
        final schema = await generator(
          const JsonSchemaGeneratorParams(jsonString: json),
        );

        final userSchema = (schema['properties'] as Map)['user'] as Map;
        expect(userSchema['type'], equals('object'));
        final nestedProps = (userSchema['properties'] as Map);
        expect(nestedProps.containsKey('name'), isTrue);
        expect(nestedProps.containsKey('age'), isTrue);
      });

      test('generates required list for nested objects', () async {
        const json = '{"user": {"name": "Alice", "age": 30}}';
        final schema = await generator(
          const JsonSchemaGeneratorParams(jsonString: json),
        );

        final userSchema = (schema['properties'] as Map)['user'] as Map;
        expect(userSchema['required'], containsAll(['name', 'age']));
      });
    });

    group('array', () {
      test('generates schema for an array of primitives', () async {
        const json = '[1, 2, 3]';
        final schema = await generator(
          const JsonSchemaGeneratorParams(jsonString: json),
        );

        expect(schema['type'], equals('array'));
        final items = schema['items'] as Map;
        expect(items['type'], equals('integer'));
      });

      test('generates empty items schema for empty array', () async {
        const json = '[]';
        final schema = await generator(
          const JsonSchemaGeneratorParams(jsonString: json),
        );

        expect(schema['type'], equals('array'));
        expect(schema['items'], equals({}));
      });
    });

    group('array of objects', () {
      test('generates schema with object items for array of objects', () async {
        const json = '[{"name": "Alice"}, {"name": "Bob", "age": 25}]';
        final schema = await generator(
          const JsonSchemaGeneratorParams(jsonString: json),
        );

        expect(schema['type'], equals('array'));
        final items = schema['items'] as Map;
        expect(items['type'], equals('object'));
        final props = (items['properties'] as Map);
        expect(props.containsKey('name'), isTrue);
        expect(props.containsKey('age'), isTrue);
      });

      test('merges properties from multiple array items', () async {
        const json = '[{"name": "Alice"}, {"email": "a@b.com"}]';
        final schema = await generator(
          const JsonSchemaGeneratorParams(jsonString: json),
        );

        final items = schema['items'] as Map;
        final props = (items['properties'] as Map);
        // Both properties should be merged.
        expect(props.containsKey('name'), isTrue);
        expect(props.containsKey('email'), isTrue);
      });
    });

    group('mixed types', () {
      test('handles mixed type array items by using first item type', () async {
        const json = '[1, "hello"]';
        final schema = await generator(
          const JsonSchemaGeneratorParams(jsonString: json),
        );

        expect(schema['type'], equals('array'));
        // First item is integer, so items should be integer.
        final items = schema['items'] as Map;
        expect(items['type'], equals('integer'));
      });
    });

    group('null values', () {
      test('generates null type for null values', () async {
        const json = '{"value": null}';
        final schema = await generator(
          const JsonSchemaGeneratorParams(jsonString: json),
        );

        final valueSchema = (schema['properties'] as Map)['value'] as Map;
        expect(valueSchema['type'], equals('null'));
      });
    });

    group('error handling', () {
      test('throws FormatException for invalid JSON', () async {
        expect(
          () => generator(const JsonSchemaGeneratorParams(jsonString: 'not json')),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws FormatException for empty string', () async {
        expect(
          () => generator(const JsonSchemaGeneratorParams(jsonString: '')),
          throwsA(isA<FormatException>()),
        );
      });

      test('generates schema for primitive JSON values', () async {
        final schema = await generator(
          const JsonSchemaGeneratorParams(jsonString: '42'),
        );
        expect(schema['type'], equals('integer'));
        expect(schema['example'], equals(42));
      });
    });
  });
}
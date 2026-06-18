import 'package:test/test.dart';
import 'package:api_tester/core/extensions/string_extensions.dart';

void main() {
  group('toSnakeCase', () {
    test('converts camelCase to snake_case', () {
      expect('helloWorld'.toSnakeCase(), equals('hello_world'));
    });

    test('converts PascalCase to snake_case', () {
      expect('HelloWorld'.toSnakeCase(), equals('hello_world'));
    });

    test('converts kebab-case to snake_case', () {
      expect('hello-world'.toSnakeCase(), equals('hello_world'));
    });

    test('converts Title Case to snake_case', () {
      expect('Hello World'.toSnakeCase(), equals('hello_world'));
    });

    test('handles already snake_case input', () {
      expect('hello_world'.toSnakeCase(), equals('hello_world'));
    });

    test('handles single word', () {
      expect('hello'.toSnakeCase(), equals('hello'));
    });

    test('handles empty string', () {
      expect(''.toSnakeCase(), equals(''));
    });

    test('collapses multiple spaces', () {
      expect('  hello   world  '.toSnakeCase(), equals('hello_world'));
    });

    test('handles mixed separators', () {
      expect('hello-world_test.foo'.toSnakeCase(), equals('hello_world_test_foo'));
    });

    test('handles consecutive uppercase letters (acronyms)', () {
      expect('parseXMLFile'.toSnakeCase(), equals('parse_x_m_l_file'));
    });
  });

  group('toCamelCase', () {
    test('converts snake_case to camelCase', () {
      expect('hello_world'.toCamelCase(), equals('helloWorld'));
    });

    test('converts kebab-case to camelCase', () {
      expect('hello-world'.toCamelCase(), equals('helloWorld'));
    });

    test('converts Title Case to camelCase', () {
      expect('Hello World'.toCamelCase(), equals('helloWorld'));
    });

    test('handles already camelCase input', () {
      expect('helloWorld'.toCamelCase(), equals('hello_world'.toCamelCase()));
    });

    test('handles single word', () {
      expect('hello'.toCamelCase(), equals('hello'));
    });

    test('handles empty string', () {
      expect(''.toCamelCase(), equals(''));
    });

    test('capitalizes subsequent words', () {
      expect('my_variable_name'.toCamelCase(), equals('myVariableName'));
    });
  });

  group('toKebabCase', () {
    test('converts camelCase to kebab-case', () {
      expect('helloWorld'.toKebabCase(), equals('hello-world'));
    });

    test('converts PascalCase to kebab-case', () {
      expect('HelloWorld'.toKebabCase(), equals('hello-world'));
    });

    test('converts snake_case to kebab-case', () {
      expect('hello_world'.toKebabCase(), equals('hello-world'));
    });

    test('converts Title Case to kebab-case', () {
      expect('Hello World'.toKebabCase(), equals('hello-world'));
    });

    test('handles single word', () {
      expect('hello'.toKebabCase(), equals('hello'));
    });

    test('handles empty string', () {
      expect(''.toKebabCase(), equals(''));
    });
  });

  group('toTitleCase', () {
    test('converts lowercase to Title Case', () {
      expect('hello world'.toTitleCase(), equals('Hello World'));
    });

    test('handles ALL CAPS input', () {
      expect('HELLO WORLD'.toTitleCase(), equals('Hello World'));
    });

    test('handles mixed case input', () {
      expect('hELLO wORLD'.toTitleCase(), equals('Hello World'));
    });

    test('handles single word', () {
      expect('hello'.toTitleCase(), equals('Hello'));
    });

    test('handles empty string', () {
      expect(''.toTitleCase(), equals(''));
    });

    test('converts kebab-case to Title Case (space separated)', () {
      expect('hello-world'.toTitleCase(), equals('Hello World'));
    });

    test('converts snake_case to Title Case', () {
      expect('hello_world'.toTitleCase(), equals('Hello World'));
    });
  });

  group('isJson', () {
    test('returns true for valid JSON object', () {
      expect('{"key": "value"}'.isJson, isTrue);
    });

    test('returns true for valid JSON array', () {
      expect('[1, 2, 3]'.isJson, isTrue);
    });

    test('returns true for valid JSON string literal', () {
      expect('"hello"'.isJson, isTrue);
    });

    test('returns true for valid JSON number', () {
      expect('42'.isJson, isTrue);
    });

    test('returns true for valid JSON boolean', () {
      expect('true'.isJson, isTrue);
    });

    test('returns true for valid JSON null', () {
      expect('null'.isJson, isTrue);
    });

    test('returns false for invalid JSON', () {
      expect('not json'.isJson, isFalse);
    });

    test('returns false for empty string', () {
      expect(''.isJson, isFalse);
    });

    test('returns false for whitespace-only string', () {
      expect('   '.isJson, isFalse);
    });

    test('returns false for truncated JSON', () {
      expect('{"key": "value"'.isJson, isFalse);
    });

    test('returns true for JSON with whitespace', () {
      expect('  { "key" : "value" }  '.isJson, isTrue);
    });

    test('returns true for nested JSON', () {
      expect('{"outer": {"inner": [1, 2, 3]}}'.isJson, isTrue);
    });
  });

  group('isXml', () {
    test('returns true for valid XML with root element', () {
      expect('<root><item/></root>'.isXml, isTrue);
    });

    test('returns true for XML declaration', () {
      expect('<?xml version="1.0"?><root/>'.isXml, isTrue);
    });

    test('returns true for XML with attributes', () {
      expect('<root attr="value">text</root>'.isXml, isTrue);
    });

    test('returns false for plain text', () {
      expect('not xml'.isXml, isFalse);
    });

    test('returns false for empty string', () {
      expect(''.isXml, isFalse);
    });

    test('returns false for whitespace-only string', () {
      expect('   '.isXml, isFalse);
    });

    test('returns true for self-closing tag', () {
      expect('<br/>'.isXml, isTrue);
    });

    test('returns true for tag with content', () {
      expect('<p>Hello</p>'.isXml, isTrue);
    });
  });

  group('truncate', () {
    test('returns original string if shorter than maxLength', () {
      expect('Hi'.truncate(10), equals('Hi'));
    });

    test('returns original string if equal to maxLength', () {
      expect('Hello'.truncate(5), equals('Hello'));
    });

    test('truncates and adds default suffix when longer', () {
      expect('Hello, World!'.truncate(5), equals('Hello\u2026'));
    });

    test('uses custom suffix when provided', () {
      expect('Hello'.truncate(3, suffix: '...'), equals('Hel...'));
    });

    test('returns empty string for maxLength <= 0', () {
      expect('Hello'.truncate(0), equals(''));
      expect('Hello'.truncate(-1), equals(''));
    });

    test('handles empty input string', () {
      expect(''.truncate(5), equals(''));
    });
  });
}
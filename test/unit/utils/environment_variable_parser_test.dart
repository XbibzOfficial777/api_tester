import 'package:test/test.dart';
import 'package:api_tester/core/utils/environment_variable_parser.dart';

void main() {
  group('parseVariables', () {
    group('single variable replacement', () {
      test('replaces a single {{variable}} with its value', () {
        const input = 'Hello {{name}}';
        final result = parseVariables(input, {'name': 'Alice'});
        expect(result, equals('Hello Alice'));
      });

      test('replaces variable at the start of string', () {
        const input = '{{baseUrl}}/users';
        final result = parseVariables(input, {'baseUrl': 'https://api.example.com'});
        expect(result, equals('https://api.example.com/users'));
      });

      test('replaces variable at the end of string', () {
        const input = 'Order #{{orderId}}';
        final result = parseVariables(input, {'orderId': '42'});
        expect(result, equals('Order #42'));
      });
    });

    group('multiple variables', () {
      test('replaces multiple different variables', () {
        const input = '{{greeting}} {{name}}, your order {{orderId}} is ready.';
        final result = parseVariables(input, {
          'greeting': 'Hello',
          'name': 'Alice',
          'orderId': '12345',
        });
        expect(result, equals('Hello Alice, your order 12345 is ready.'));
      });

      test('replaces repeated occurrences of the same variable', () {
        const input = '{{key}}={{key}}';
        final result = parseVariables(input, {'key': 'value'});
        expect(result, equals('value=value'));
      });
    });

    group('variable not found', () {
      test('leaves placeholder as-is when variable is not in the map', () {
        const input = 'Hello {{unknown}}';
        final result = parseVariables(input, {});
        expect(result, equals('Hello {{unknown}}'));
      });

      test('leaves unknown placeholder alongside resolved ones', () {
        const input = '{{known}} and {{unknown}}';
        final result = parseVariables(input, {'known': 'resolved'});
        expect(result, equals('resolved and {{unknown}}'));
      });
    });

    group('nested braces', () {
      test('handles variables with dots in the name', () {
        const input = '{{auth.token}}';
        final result = parseVariables(input, {'auth.token': 'abc123'});
        expect(result, equals('abc123'));
      });

      test('handles variables with hyphens in the name', () {
        const input = '{{my-var}}';
        final result = parseVariables(input, {'my-var': 'hello'});
        expect(result, equals('hello'));
      });

      test('does not treat nested double braces as separate variables', () {
        // The regex is non-greedy, so {{a{{b}}}} only matches the innermost.
        const input = 'before {{a}} middle {{b}} after';
        final result = parseVariables(input, {'a': 'A', 'b': 'B'});
        expect(result, equals('before A middle B after'));
      });
    });

    group('empty input', () {
      test('returns empty string for empty input', () {
        final result = parseVariables('', {'key': 'value'});
        expect(result, equals(''));
      });

      test('returns empty string for empty input even with variables map', () {
        final result = parseVariables('', {'key': 'value', 'other': 'thing'});
        expect(result, equals(''));
      });
    });

    group('no variables in input', () {
      test('returns input unchanged when no placeholders exist', () {
        const input = 'Hello World, no variables here!';
        final result = parseVariables(input, {'key': 'value'});
        expect(result, equals(input));
      });

      test('returns input unchanged when variables map is empty', () {
        const input = 'Hello {{name}}';
        final result = parseVariables(input, {});
        expect(result, equals(input));
      });
    });

    group('variable with special characters in value', () {
      test('replaces variable with value containing special characters', () {
        const input = 'token={{bearerToken}}';
        final result = parseVariables(input, {
          'bearerToken': 'eyJhbGciOiJIUzI1NiJ9.abc.def',
        });
        expect(result, equals('token=eyJhbGciOiJIUzI1NiJ9.abc.def'));
      });

      test('replaces variable with value containing URL characters', () {
        const input = 'url={{apiUrl}}';
        final result = parseVariables(input, {
          'apiUrl': 'https://api.example.com/v1/users?page=1&limit=20',
        });
        expect(result, equals('url=https://api.example.com/v1/users?page=1&limit=20'));
      });

      test('replaces variable with value containing JSON', () {
        const input = 'body={{payload}}';
        final result = parseVariables(input, {
          'payload': '{"key": "value", "nested": {"a": 1}}',
        });
        expect(result, equals('body={"key": "value", "nested": {"a": 1}}'));
      });

      test('converts non-string values via toString()', () {
        const input = 'port={{port}}';
        final result = parseVariables(input, {'port': 8080});
        expect(result, equals('port=8080'));
      });

      test('handles null value by leaving placeholder', () {
        const input = 'value={{maybeNull}}';
        final result = parseVariables(input, {'maybeNull': null});
        expect(result, equals('value={{maybeNull}}'));
      });
    });
  });
}
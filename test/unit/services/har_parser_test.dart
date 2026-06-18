import 'dart:convert';
import 'package:test/test.dart';
import 'package:api_tester/core/services/har_parser.dart';

void main() {
  /// Creates a minimal valid HAR JSON string.
  String _makeHarJson(List<Map<String, dynamic>> entries) {
    return jsonEncode({
      'log': {
        'version': '1.2',
        'creator': {'name': 'Test', 'version': '1.0'},
        'entries': entries,
      }
    });
  }

  group('HarParser', () {
    group('valid HAR with multiple entries', () {
      test('parses multiple entries from a valid HAR file', () {
        final harJson = _makeHarJson([
          {
            'request': {
              'method': 'GET',
              'url': 'https://api.example.com/users',
              'httpVersion': 'HTTP/1.1',
            },
            'response': {
              'status': 200,
              'statusText': 'OK',
              'headers': [
                {'name': 'Content-Type', 'value': 'application/json'},
              ],
              'content': {'text': '[{"id":1}]'},
            }
          },
          {
            'request': {
              'method': 'POST',
              'url': 'https://api.example.com/users',
              'httpVersion': 'HTTP/2',
            },
            'response': {
              'status': 201,
              'statusText': 'Created',
            }
          },
        ]);

        final results = HarParser.parse(harJson);
        expect(results, hasLength(2));

        // First entry.
        expect(results[0]['method'], equals('GET'));
        expect(results[0]['url'], equals('https://api.example.com/users'));
        expect(results[0]['httpVersion'], equals('HTTP/1.1'));

        // Second entry.
        expect(results[1]['method'], equals('POST'));
        expect(results[1]['url'], equals('https://api.example.com/users'));
        expect(results[1]['httpVersion'], equals('HTTP/2'));
      });
    });

    group('request headers', () {
      test('parses request headers from HAR entry', () {
        final harJson = _makeHarJson([
          {
            'request': {
              'method': 'GET',
              'url': 'https://api.example.com/data',
              'headers': [
                {'name': 'Accept', 'value': 'application/json'},
                {'name': 'Authorization', 'value': 'Bearer token'},
              ],
            },
          }
        ]);

        final results = HarParser.parse(harJson);
        expect(results, hasLength(1));

        final headers = results[0]['headers'] as List;
        expect(headers, hasLength(2));

        final headerNames =
            headers.cast<Map<String, String>>().map((h) => h['name']).toSet();
        expect(headerNames, containsAll(['Accept', 'Authorization']));
      });

      test('handles missing headers gracefully', () {
        final harJson = _makeHarJson([
          {
            'request': {
              'method': 'GET',
              'url': 'https://api.example.com/data',
            },
          }
        ]);

        final results = HarParser.parse(harJson);
        final headers = results[0]['headers'] as List;
        expect(headers, isEmpty);
      });
    });

    group('POST data', () {
      test('parses POST data with text and mimeType', () {
        final harJson = _makeHarJson([
          {
            'request': {
              'method': 'POST',
              'url': 'https://api.example.com/users',
              'postData': {
                'mimeType': 'application/json',
                'text': '{"name": "John"}',
                'params': [
                  {'name': 'name', 'value': 'John'},
                ],
              },
            },
          }
        ]);

        final results = HarParser.parse(harJson);
        expect(results, hasLength(1));

        final postData = results[0]['postData'] as Map;
        expect(postData['mimeType'], equals('application/json'));
        expect(postData['text'], equals('{"name": "John"}'));
        expect((postData['params'] as List), hasLength(1));
      });

      test('postData is null when no post data exists', () {
        final harJson = _makeHarJson([
          {
            'request': {
              'method': 'GET',
              'url': 'https://api.example.com/data',
            },
          }
        ]);

        final results = HarParser.parse(harJson);
        expect(results[0]['postData'], isNull);
      });
    });

    group('query string', () {
      test('parses query string parameters', () {
        final harJson = _makeHarJson([
          {
            'request': {
              'method': 'GET',
              'url': 'https://api.example.com/search',
              'queryString': [
                {'name': 'q', 'value': 'flutter'},
                {'name': 'page', 'value': '2'},
              ],
            },
          }
        ]);

        final results = HarParser.parse(harJson);
        final queryString = results[0]['queryString'] as List;
        expect(queryString, hasLength(2));

        final names = queryString
            .cast<Map<String, String>>()
            .map((q) => q['name'])
            .toSet();
        expect(names, containsAll(['q', 'page']));
      });
    });

    group('error handling', () {
      test('throws FormatException for invalid JSON', () {
        expect(
          () => HarParser.parse('not json at all'),
          throwsA(isA<FormatException>()),
        );
      });

      test('returns empty list when log key is missing', () {
        final harJson = jsonEncode({'not_log': {}});
        final results = HarParser.parse(harJson);
        expect(results, isEmpty);
      });
    });

    group('empty entries array', () {
      test('returns empty list for empty entries', () {
        final harJson = _makeHarJson([]);
        final results = HarParser.parse(harJson);
        expect(results, isEmpty);
      });
    });

    group('response parsing', () {
      test('parses response status, headers, and body', () {
        final harJson = _makeHarJson([
          {
            'request': {
              'method': 'GET',
              'url': 'https://api.example.com/data',
            },
            'response': {
              'status': 200,
              'statusText': 'OK',
              'headers': [
                {'name': 'Content-Type', 'value': 'application/json'},
              ],
              'content': {
                'text': '{"result": "success"}',
              },
            }
          }
        ]);

        final results = HarParser.parse(harJson);
        expect(results[0]['responseStatus'], equals(200));
        expect(results[0]['responseStatusText'], equals('OK'));
        expect(results[0]['responseBody'], equals('{"result": "success"}'));

        final respHeaders = results[0]['responseHeaders'] as List;
        expect(respHeaders, hasLength(1));
      });
    });

    group('filtering invalid entries', () {
      test('skips entries without a request object', () {
        final harJson = _makeHarJson([
          {'notRequest': {}},
          {
            'request': {
              'method': 'GET',
              'url': 'https://api.example.com/valid',
            },
          }
        ]);

        final results = HarParser.parse(harJson);
        expect(results, hasLength(1));
        expect(results.first['url'], equals('https://api.example.com/valid'));
      });

      test('skips entries with empty method', () {
        final harJson = _makeHarJson([
          {
            'request': {
              'method': '',
              'url': 'https://api.example.com/data',
            },
          }
        ]);

        final results = HarParser.parse(harJson);
        expect(results, isEmpty);
      });

      test('defaults httpVersion to HTTP/1.1 when missing', () {
        final harJson = _makeHarJson([
          {
            'request': {
              'method': 'GET',
              'url': 'https://api.example.com/',
            },
          }
        ]);

        final results = HarParser.parse(harJson);
        expect(results[0]['httpVersion'], equals('HTTP/1.1'));
      });
    });
  });
}
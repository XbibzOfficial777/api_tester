import 'dart:convert';
import 'package:test/test.dart';
import 'package:api_tester/domain/usecases/import/postman_import.dart';
import 'package:api_tester/domain/entities/api_request.dart';

void main() {
  late PostmanImport postmanImport;

  setUp(() {
    postmanImport = PostmanImport();
  });

  /// Creates a minimal valid Postman Collection v2.1 JSON string.
  String _makeCollection(List<Map<String, dynamic>> items) {
    return jsonEncode({
      'info': {
        'name': 'Test Collection',
        'schema': 'https://schema.getpostman.com/json/collection/v2.1.0/collection.json',
      },
      'item': items,
    });
  }

  group('PostmanImport', () {
    group('GET request', () {
      test('parses a Postman Collection with a simple GET request', () async {
        final json = _makeCollection([
          {
            'name': 'Get Users',
            'request': {
              'method': 'GET',
              'url': 'https://api.example.com/users',
            }
          }
        ]);

        final requests = await postmanImport(PostmanImportParams(
          content: json,
          workspaceId: 'ws-1',
        ));

        expect(requests, hasLength(1));
        expect(requests.first.method, equals(HttpMethod.get));
        expect(requests.first.url, equals('https://api.example.com/users'));
        expect(requests.first.name, equals('Get Users'));
      });
    });

    group('POST with body', () {
      test('parses POST request with raw JSON body', () async {
        final json = _makeCollection([
          {
            'name': 'Create User',
            'request': {
              'method': 'POST',
              'url': {
                'raw': 'https://api.example.com/users',
                'protocol': 'https',
                'host': ['api', 'example', 'com'],
                'path': ['users'],
              },
              'body': {
                'mode': 'raw',
                'raw': '{"name": "John", "email": "john@example.com"}',
              },
            }
          }
        ]);

        final requests = await postmanImport(PostmanImportParams(
          content: json,
          workspaceId: 'ws-1',
        ));

        expect(requests, hasLength(1));
        expect(requests.first.method, equals(HttpMethod.post));
        expect(requests.first.bodyType, equals(BodyType.raw));
        expect(requests.first.bodyContent,
            contains('"name": "John"'));
      });
    });

    group('headers', () {
      test('parses request with headers', () async {
        final json = _makeCollection([
          {
            'name': 'Auth Request',
            'request': {
              'method': 'GET',
              'url': 'https://api.example.com/me',
              'header': [
                {'key': 'Authorization', 'value': 'Bearer token123'},
                {'key': 'Accept', 'value': 'application/json'},
                {'key': 'X-Disabled', 'value': 'skip', 'disabled': true},
              ],
            }
          }
        ]);

        final requests = await postmanImport(PostmanImportParams(
          content: json,
          workspaceId: 'ws-1',
        ));

        expect(requests, hasLength(1));
        // Should have 2 enabled headers (disabled one is still parsed but disabled).
        final enabledHeaders = requests.first.headers.where((h) => h.isEnabled);
        final disabledHeaders =
            requests.first.headers.where((h) => !h.isEnabled);

        expect(enabledHeaders.length, equals(2));
        expect(disabledHeaders.length, equals(1));
      });
    });

    group('query params', () {
      test('parses query params from URL object', () async {
        final json = _makeCollection([
          {
            'name': 'Search',
            'request': {
              'method': 'GET',
              'url': {
                'raw': 'https://api.example.com/search?q=flutter&page=1',
                'protocol': 'https',
                'host': ['api', 'example', 'com'],
                'path': ['search'],
                'query': [
                  {'key': 'q', 'value': 'flutter'},
                  {'key': 'page', 'value': '1'},
                ],
              },
            }
          }
        ]);

        final requests = await postmanImport(PostmanImportParams(
          content: json,
          workspaceId: 'ws-1',
        ));

        expect(requests, hasLength(1));
        expect(requests.first.queryParams, isNotEmpty);
        final keys = requests.first.queryParams.map((q) => q.key).toSet();
        expect(keys, containsAll(['q', 'page']));
      });

      test('parses query params from simple URL string', () async {
        final json = _makeCollection([
          {
            'name': 'Search',
            'request': {
              'method': 'GET',
              'url': 'https://api.example.com/search?q=test&limit=10',
            }
          }
        ]);

        final requests = await postmanImport(PostmanImportParams(
          content: json,
          workspaceId: 'ws-1',
        ));

        expect(requests, hasLength(1));
        expect(requests.first.queryParams, isNotEmpty);
      });
    });

    group('nested folder structure', () {
      test('recursively extracts requests from nested folders', () async {
        final json = _makeCollection([
          {
            'name': 'Users',
            'item': [
              {
                'name': 'List Users',
                'request': {
                  'method': 'GET',
                  'url': 'https://api.example.com/users',
                }
              },
              {
                'name': 'Auth',
                'item': [
                  {
                    'name': 'Login',
                    'request': {
                      'method': 'POST',
                      'url': 'https://api.example.com/login',
                      'body': {
                        'mode': 'raw',
                        'raw': '{"user": "admin"}',
                      },
                    }
                  }
                ]
              }
            ]
          }
        ]);

        final requests = await postmanImport(PostmanImportParams(
          content: json,
          workspaceId: 'ws-1',
        ));

        // Should find 2 requests from nested folders.
        expect(requests, hasLength(2));

        // Names should include folder path.
        final names = requests.map((r) => r.name).toList();
        expect(names.any((n) => n.contains('List Users')), isTrue);
        expect(names.any((n) => n.contains('Login')), isTrue);
      });
    });

    group('error handling', () {
      test('throws FormatException for invalid JSON', () async {
        expect(
          () => postmanImport(PostmanImportParams(
            content: 'not json',
            workspaceId: 'ws-1',
          )),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws FormatException for missing info field', () async {
        final json = jsonEncode({'item': []});
        expect(
          () => postmanImport(PostmanImportParams(
            content: json,
            workspaceId: 'ws-1',
          )),
          throwsA(isA<FormatException>()),
        );
      });

      test('returns empty list for collection with no items', () async {
        final json = _makeCollection([]);
        final requests = await postmanImport(PostmanImportParams(
          content: json,
          workspaceId: 'ws-1',
        ));
        expect(requests, isEmpty);
      });
    });

    group('workspace and collection IDs', () {
      test('assigns the provided workspace ID', () async {
        final json = _makeCollection([
          {
            'name': 'Test',
            'request': {'method': 'GET', 'url': 'https://example.com/'}
          }
        ]);

        final requests = await postmanImport(PostmanImportParams(
          content: json,
          workspaceId: 'my-ws-id',
        ));

        expect(requests.every((r) => r.workspaceId == 'my-ws-id'), isTrue);
      });

      test('assigns the optional collection ID', () async {
        final json = _makeCollection([
          {
            'name': 'Test',
            'request': {'method': 'GET', 'url': 'https://example.com/'}
          }
        ]);

        final requests = await postmanImport(PostmanImportParams(
          content: json,
          workspaceId: 'ws-1',
          collectionId: 'col-1',
        ));

        expect(requests.every((r) => r.collectionId == 'col-1'), isTrue);
      });
    });
  });
}
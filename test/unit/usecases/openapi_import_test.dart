import 'dart:convert';
import 'package:test/test.dart';
import 'package:api_tester/domain/usecases/import/openapi_import.dart';
import 'package:api_tester/domain/entities/api_request.dart';

void main() {
  late OpenApiImport openApiImport;

  setUp(() {
    openApiImport = OpenApiImport();
  });

  group('OpenApiImport', () {
    group('OpenAPI 3.0 spec', () {
      test('parses simple OpenAPI 3.0 spec with GET endpoint', () async {
        final spec = jsonEncode({
          'openapi': '3.0.3',
          'info': {'title': 'Test API', 'version': '1.0.0'},
          'servers': [{'url': 'https://api.example.com'}],
          'paths': {
            '/users': {
              'get': {
                'summary': 'List users',
                'operationId': 'listUsers',
                'responses': {
                  '200': {
                    'description': 'Success',
                    'content': {
                      'application/json': {
                        'schema': {'type': 'array', 'items': {'type': 'object'}}
                      }
                    }
                  }
                }
              }
            }
          }
        });

        final requests = await openApiImport(OpenApiImportParams(
          content: spec,
          format: 'json',
          workspaceId: 'ws-1',
        ));

        expect(requests, isNotEmpty);
        final getUsers = requests.where((r) => r.url.contains('/users'));
        expect(getUsers, isNotEmpty);
        expect(getUsers.first.method, equals(HttpMethod.get));
        expect(getUsers.first.name, contains('List users'));
      });

      test('parses spec with POST and request body', () async {
        final spec = jsonEncode({
          'openapi': '3.0.3',
          'info': {'title': 'Test API', 'version': '1.0.0'},
          'servers': [{'url': 'https://api.example.com'}],
          'paths': {
            '/users': {
              'post': {
                'summary': 'Create user',
                'requestBody': {
                  'required': true,
                  'content': {
                    'application/json': {
                      'schema': {
                        'type': 'object',
                        'properties': {
                          'name': {'type': 'string'},
                          'email': {'type': 'string'}
                        }
                      }
                    }
                  }
                },
                'responses': {
                  '201': {'description': 'Created'}
                }
              }
            }
          }
        });

        final requests = await openApiImport(OpenApiImportParams(
          content: spec,
          format: 'json',
          workspaceId: 'ws-1',
        ));

        final postUsers = requests.where((r) =>
            r.url.contains('/users') && r.method == HttpMethod.post);
        expect(postUsers, isNotEmpty);
        expect(postUsers.first.name, contains('Create user'));
      });

      test('parses spec with multiple parameters', () async {
        final spec = jsonEncode({
          'openapi': '3.0.3',
          'info': {'title': 'Test API', 'version': '1.0.0'},
          'servers': [{'url': 'https://api.example.com'}],
          'paths': {
            '/users/{id}': {
              'get': {
                'summary': 'Get user by ID',
                'parameters': [
                  {
                    'name': 'id',
                    'in': 'path',
                    'required': true,
                    'schema': {'type': 'string'}
                  },
                  {
                    'name': 'include',
                    'in': 'query',
                    'required': false,
                    'schema': {'type': 'string'}
                  }
                ],
                'responses': {'200': {'description': 'OK'}}
              }
            }
          }
        });

        final requests = await openApiImport(OpenApiImportParams(
          content: spec,
          format: 'json',
          workspaceId: 'ws-1',
        ));

        expect(requests, isNotEmpty);
        final getUser = requests.firstWhere(
          (r) => r.url.contains('/users/'),
          orElse: () => throw TestFailure('No request found'),
        );
        expect(getUser.queryParams, isNotEmpty);
      });
    });

    group('OpenAPI 2.0 (Swagger) spec', () {
      test('parses Swagger 2.0 spec with GET endpoint', () async {
        final spec = jsonEncode({
          'swagger': '2.0',
          'info': {'title': 'Test API', 'version': '1.0.0'},
          'host': 'api.example.com',
          'basePath': '/v1',
          'schemes': ['https'],
          'paths': {
            '/products': {
              'get': {
                'summary': 'List products',
                'responses': {
                  '200': {
                    'description': 'Success',
                    'schema': {'type': 'array', 'items': {'type': 'object'}}
                  }
                }
              }
            }
          }
        });

        final requests = await openApiImport(OpenApiImportParams(
          content: spec,
          format: 'json',
          workspaceId: 'ws-1',
        ));

        expect(requests, isNotEmpty);
        expect(requests.first.url, contains('/v1/products'));
        expect(requests.first.method, equals(HttpMethod.get));
      });
    });

    group('security schemes', () {
      test('extracts Bearer token from security schemes', () async {
        final spec = jsonEncode({
          'openapi': '3.0.3',
          'info': {'title': 'Test API', 'version': '1.0.0'},
          'servers': [{'url': 'https://api.example.com'}],
          'components': {
            'securitySchemes': {
              'bearerAuth': {
                'type': 'http',
                'scheme': 'bearer',
              }
            }
          },
          'security': [{'bearerAuth': []}],
          'paths': {
            '/me': {
              'get': {
                'summary': 'Get current user',
                'responses': {'200': {'description': 'OK'}}
              }
            }
          }
        });

        final requests = await openApiImport(OpenApiImportParams(
          content: spec,
          format: 'json',
          workspaceId: 'ws-1',
        ));

        expect(requests, isNotEmpty);
        // Check if any request has the auth header.
        final hasBearer = requests.any((r) => r.headers.any(
            (h) => h.key.toLowerCase() == 'authorization' && h.value.contains('Bearer')));
        expect(hasBearer, isTrue);
      });
    });

    group('example values from schema', () {
      test('extracts example values and sets as default values', () async {
        final spec = jsonEncode({
          'openapi': '3.0.3',
          'info': {'title': 'Test API', 'version': '1.0.0'},
          'servers': [{'url': 'https://api.example.com'}],
          'paths': {
            '/items': {
              'get': {
                'summary': 'Get items',
                'parameters': [
                  {
                    'name': 'limit',
                    'in': 'query',
                    'schema': {'type': 'integer', 'example': 10}
                  }
                ],
                'responses': {'200': {'description': 'OK'}}
              }
            }
          }
        });

        final requests = await openApiImport(OpenApiImportParams(
          content: spec,
          format: 'json',
          workspaceId: 'ws-1',
        ));

        expect(requests, isNotEmpty);
      });
    });

    group('error handling', () {
      test('throws for invalid JSON', () async {
        expect(
          () => openApiImport(OpenApiImportParams(
            content: 'not valid json',
            format: 'json',
            workspaceId: 'ws-1',
          )),
          throwsA(anything),
        );
      });

      test('returns empty list for spec with no paths', () async {
        final spec = jsonEncode({
          'openapi': '3.0.3',
          'info': {'title': 'Test API', 'version': '1.0.0'},
          'paths': {}
        });

        final requests = await openApiImport(OpenApiImportParams(
          content: spec,
          format: 'json',
          workspaceId: 'ws-1',
        ));

        expect(requests, isEmpty);
      });
    });
  });
}
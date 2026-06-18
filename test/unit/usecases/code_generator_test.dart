import 'package:test/test.dart';
import 'package:api_tester/domain/usecases/tools/code_generator.dart';
import 'package:api_tester/domain/entities/api_request.dart';
import 'package:api_tester/domain/entities/key_value_item.dart';
import 'package:api_tester/domain/entities/form_data_item.dart';

void main() {
  late CodeGenerator generator;

  final now = DateTime.now();

  /// Creates a basic GET request.
  ApiRequest get _getRequest => ApiRequest(
        id: 'req-1',
        workspaceId: 'ws-1',
        name: 'Get Users',
        method: HttpMethod.get,
        url: 'https://api.example.com/users',
        createdAt: now,
        updatedAt: now,
      );

  /// Creates a POST request with JSON body and headers.
  ApiRequest get _postRequest => ApiRequest(
        id: 'req-2',
        workspaceId: 'ws-1',
        name: 'Create User',
        method: HttpMethod.post,
        url: 'https://api.example.com/users',
        headers: [
          KeyValueItem(
            key: 'Content-Type',
            value: 'application/json',
            isEnabled: true,
            id: 'h-1',
          ),
          KeyValueItem(
            key: 'Authorization',
            value: 'Bearer token123',
            isEnabled: true,
            id: 'h-2',
          ),
        ],
        bodyType: BodyType.raw,
        bodyContent: '{"name":"John","email":"john@example.com"}',
        createdAt: now,
        updatedAt: now,
      );

  setUp(() {
    generator = CodeGenerator();
  });

  group('CodeGenerator - Dart', () {
    test('generates Dart code with import and GET method', () async {
      final code = await generator(CodeGeneratorParams(
        request: _getRequest,
        language: CodeLanguage.dart,
      ));

      expect(code, contains("import 'package:http/http.dart'"));
      expect(code, contains('http.get'));
      expect(code, contains('https://api.example.com/users'));
      expect(code, contains('Status:'));
      expect(code, contains('Body:'));
    });

    test('generates Dart code for POST with body and headers', () async {
      final code = await generator(CodeGeneratorParams(
        request: _postRequest,
        language: CodeLanguage.dart,
      ));

      expect(code, contains('http.post'));
      expect(code, contains('Content-Type'));
      expect(code, contains('Authorization'));
      expect(code, contains('body:'));
    });
  });

  group('CodeGenerator - Python', () {
    test('generates Python code with import and GET method', () async {
      final code = await generator(CodeGeneratorParams(
        request: _getRequest,
        language: CodeLanguage.python,
      ));

      expect(code, contains('import requests'));
      expect(code, contains('requests.get'));
      expect(code, contains('https://api.example.com/users'));
    });

    test('generates Python code for POST with JSON body', () async {
      final code = await generator(CodeGeneratorParams(
        request: _postRequest,
        language: CodeLanguage.python,
      ));

      expect(code, contains('requests.post'));
      expect(code, contains('json_data'));
      expect(code, contains('headers'));
    });
  });

  group('CodeGenerator - JavaScript', () {
    test('generates JavaScript fetch code for GET', () async {
      final code = await generator(CodeGeneratorParams(
        request: _getRequest,
        language: CodeLanguage.javascript,
      ));

      expect(code, contains('fetch('));
      expect(code, contains("method: 'GET'"));
      expect(code, contains('https://api.example.com/users'));
      expect(code, contains('console.log'));
    });

    test('generates JavaScript fetch code for POST with body', () async {
      final code = await generator(CodeGeneratorParams(
        request: _postRequest,
        language: CodeLanguage.javascript,
      ));

      expect(code, contains("method: 'POST'"));
      expect(code, contains('JSON.stringify'));
      expect(code, contains('body:'));
    });
  });

  group('CodeGenerator - cURL', () {
    test('generates cURL command for GET (no -X GET)', () async {
      final code = await generator(CodeGeneratorParams(
        request: _getRequest,
        language: CodeLanguage.curl,
      ));

      expect(code, contains('curl'));
      expect(code, contains('https://api.example.com/users'));
      // GET should not have -X GET.
      expect(code, isNot(contains('-X GET')));
    });

    test('generates cURL command for POST with -X POST', () async {
      final code = await generator(CodeGeneratorParams(
        request: _postRequest,
        language: CodeLanguage.curl,
      ));

      expect(code, contains('-X POST'));
      expect(code, contains('-H'));
      expect(code, contains('-d'));
      expect(code, contains('Content-Type'));
    });

    test('generates cURL with headers', () async {
      final code = await generator(CodeGeneratorParams(
        request: _postRequest,
        language: CodeLanguage.curl,
      ));

      expect(code, contains("Authorization: Bearer token123"));
      expect(code, contains("Content-Type: application/json"));
    });
  });

  group('CodeGenerator - different body types', () {
    test('handles request with no body', () async {
      final code = await generator(CodeGeneratorParams(
        request: _getRequest,
        language: CodeLanguage.curl,
      ));

      expect(code, isNot(contains('-d')));
    });

    test('handles form data body type', () async {
      final request = ApiRequest(
        id: 'req-3',
        workspaceId: 'ws-1',
        name: 'Upload',
        method: HttpMethod.post,
        url: 'https://api.example.com/upload',
        bodyType: BodyType.formData,
        formDataItems: [
          FormDataItem(
            key: 'file',
            value: '',
            isFile: true,
            filePath: '/path/to/file.txt',
            fileName: 'file.txt',
            contentType: 'text/plain',
            id: 'f-1',
          ),
          FormDataItem(
            key: 'description',
            value: 'A test file',
            isFile: false,
            id: 'f-2',
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      final code = await generator(CodeGeneratorParams(
        request: request,
        language: CodeLanguage.curl,
      ));

      expect(code, contains('-F'));
      expect(code, contains('description='));
    });
  });

  group('CodeGenerator - with headers', () {
    test('includes enabled headers in generated code', () async {
      final code = await generator(CodeGeneratorParams(
        request: _postRequest,
        language: CodeLanguage.python,
      ));

      expect(code, contains('Content-Type'));
      expect(code, contains('Authorization'));
    });

    test('excludes disabled headers from generated code', () async {
      final request = ApiRequest(
        id: 'req-4',
        workspaceId: 'ws-1',
        name: 'Test',
        method: HttpMethod.get,
        url: 'https://api.example.com/',
        headers: [
          KeyValueItem(
            key: 'X-Enabled',
            value: 'yes',
            isEnabled: true,
            id: 'h-1',
          ),
          KeyValueItem(
            key: 'X-Disabled',
            value: 'no',
            isEnabled: false,
            id: 'h-2',
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      final code = await generator(CodeGeneratorParams(
        request: request,
        language: CodeLanguage.curl,
      ));

      expect(code, contains('X-Enabled'));
      expect(code, isNot(contains('X-Disabled')));
    });

    test('generates code with query parameters in URL', () async {
      final request = ApiRequest(
        id: 'req-5',
        workspaceId: 'ws-1',
        name: 'Search',
        method: HttpMethod.get,
        url: 'https://api.example.com/search',
        queryParams: [
          KeyValueItem(
            key: 'q',
            value: 'flutter',
            isEnabled: true,
            id: 'q-1',
          ),
          KeyValueItem(
            key: 'page',
            value: '1',
            isEnabled: true,
            id: 'q-2',
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      final code = await generator(CodeGeneratorParams(
        request: request,
        language: CodeLanguage.curl,
      ));

      expect(code, contains('q=flutter'));
      expect(code, contains('page=1'));
    });
  });
}
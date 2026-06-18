import 'dart:convert';
import 'package:test/test.dart';
import 'package:api_tester/domain/usecases/import/curl_import.dart';
import 'package:api_tester/domain/entities/api_request.dart';

void main() {
  late CurlImport curlImport;

  setUp(() {
    curlImport = CurlImport();
  });

  group('CurlImport', () {
    group('parsing GET requests', () {
      test('parses a simple GET request with just a URL', () async {
        const command = 'curl https://api.example.com/users';
        final request = await curlImport(CurlImportParams(
          curlCommand: command,
          workspaceId: 'ws-1',
        ));

        expect(request.method, equals(HttpMethod.get));
        expect(request.url, equals('https://api.example.com/users'));
        expect(request.headers, isEmpty);
        expect(request.bodyType, equals(BodyType.none));
      });

      test('parses GET with silent flag', () async {
        const command = 'curl -s https://api.example.com/users';
        final request = await curlImport(CurlImportParams(
          curlCommand: command,
          workspaceId: 'ws-1',
        ));

        expect(request.method, equals(HttpMethod.get));
        expect(request.url, equals('https://api.example.com/users'));
      });
    });

    group('parsing POST with -d flag', () {
      test('parses POST with JSON body via -d', () async {
        const command = "curl -X POST https://api.example.com/users -d '{\"name\":\"John\"}'";
        final request = await curlImport(CurlImportParams(
          curlCommand: command,
          workspaceId: 'ws-1',
        ));

        expect(request.method, equals(HttpMethod.post));
        expect(request.url, equals('https://api.example.com/users'));
        expect(request.bodyType, equals(BodyType.raw));
        expect(request.bodyContent, equals('{"name":"John"}'));
      });

      test('auto-adds Content-Type: application/json for JSON body', () async {
        const command = "curl -X POST https://api.example.com/users -d '{\"name\":\"John\"}'";
        final request = await curlImport(CurlImportParams(
          curlCommand: command,
          workspaceId: 'ws-1',
        ));

        final contentTypeHeaders = request.headers
            .where((h) => h.key.toLowerCase() == 'content-type');
        expect(contentTypeHeaders, isNotEmpty);
        expect(contentTypeHeaders.first.value,
            equals('application/json'));
      });
    });

    group('parsing headers with -H flag', () {
      test('parses a single header', () async {
        const command =
            "curl -H 'Authorization: Bearer token123' https://api.example.com/data";
        final request = await curlImport(CurlImportParams(
          curlCommand: command,
          workspaceId: 'ws-1',
        ));

        final authHeaders = request.headers
            .where((h) => h.key.toLowerCase() == 'authorization');
        expect(authHeaders, isNotEmpty);
        expect(authHeaders.first.value, equals('Bearer token123'));
      });

      test('parses multiple headers', () async {
        const command =
            "curl -H 'Content-Type: application/json' -H 'Accept: application/json' https://api.example.com/data";
        final request = await curlImport(CurlImportParams(
          curlCommand: command,
          workspaceId: 'ws-1',
        ));

        expect(request.headers.length, greaterThanOrEqualTo(2));

        final ct = request.headers
            .where((h) => h.key.toLowerCase() == 'content-type');
        expect(ct, isNotEmpty);

        final accept = request.headers
            .where((h) => h.key.toLowerCase() == 'accept');
        expect(accept, isNotEmpty);
      });

      test('all parsed headers are enabled', () async {
        const command =
            "curl -H 'X-Custom: value' https://api.example.com/";
        final request = await curlImport(CurlImportParams(
          curlCommand: command,
          workspaceId: 'ws-1',
        ));

        for (final h in request.headers) {
          expect(h.isEnabled, isTrue);
        }
      });
    });

    group('parsing method override with -X flag', () {
      test('parses -X PUT', () async {
        const command =
            "curl -X PUT https://api.example.com/users/1 -d '{\"name\":\"Jane\"}'";
        final request = await curlImport(CurlImportParams(
          curlCommand: command,
          workspaceId: 'ws-1',
        ));
        expect(request.method, equals(HttpMethod.put));
      });

      test('parses -X DELETE', () async {
        const command = 'curl -X DELETE https://api.example.com/users/1';
        final request = await curlImport(CurlImportParams(
          curlCommand: command,
          workspaceId: 'ws-1',
        ));
        expect(request.method, equals(HttpMethod.delete));
      });

      test('parses -X PATCH', () async {
        const command =
            "curl -X PATCH https://api.example.com/users/1 -d '{\"email\":\"new@test.com\"}'";
        final request = await curlImport(CurlImportParams(
          curlCommand: command,
          workspaceId: 'ws-1',
        ));
        expect(request.method, equals(HttpMethod.patch));
      });

      test('parses --request METHOD', () async {
        const command =
            'curl --request POST https://api.example.com/data';
        final request = await curlImport(CurlImportParams(
          curlCommand: command,
          workspaceId: 'ws-1',
        ));
        expect(request.method, equals(HttpMethod.post));
      });
    });

    group('parsing basic auth with -u flag', () {
      test('parses -u user:pass and adds Basic auth header', () async {
        const command =
            'curl -u admin:secret https://api.example.com/admin';
        final request = await curlImport(CurlImportParams(
          curlCommand: command,
          workspaceId: 'ws-1',
        ));

        final authHeaders = request.headers
            .where((h) => h.key.toLowerCase() == 'authorization');
        expect(authHeaders, isNotEmpty);

        final value = authHeaders.first.value;
        expect(value, startsWith('Basic '));

        // Decode and verify.
        final encoded = value.substring(6);
        final decoded = utf8.decode(base64Decode(encoded));
        expect(decoded, equals('admin:secret'));
      });
    });

    group('parsing --data-binary', () {
      test('parses --data-binary as raw body', () async {
        const command =
            "curl --data-binary '@file.bin' https://api.example.com/upload";
        final request = await curlImport(CurlImportParams(
          curlCommand: command,
          workspaceId: 'ws-1',
        ));

        expect(request.bodyType, equals(BodyType.raw));
        expect(request.bodyContent, equals('@file.bin'));
      });
    });

    group('parsing -k (insecure) flag', () {
      test('sets verifySsl to false when -k is present', () async {
        const command = 'curl -k https://self-signed.example.com/data';
        final request = await curlImport(CurlImportParams(
          curlCommand: command,
          workspaceId: 'ws-1',
        ));
        expect(request.verifySsl, isFalse);
      });

      test('sets verifySsl to false when --insecure is present', () async {
        const command = 'curl --insecure https://self-signed.example.com/data';
        final request = await curlImport(CurlImportParams(
          curlCommand: command,
          workspaceId: 'ws-1',
        ));
        expect(request.verifySsl, isFalse);
      });

      test('verifySsl defaults to true when -k is absent', () async {
        const command = 'curl https://api.example.com/data';
        final request = await curlImport(CurlImportParams(
          curlCommand: command,
          workspaceId: 'ws-1',
        ));
        expect(request.verifySsl, isTrue);
      });
    });

    group('parsing complex curl with all flags', () {
      test('parses a realistic curl command with multiple flags', () async {
        const command =
            "curl -s -k -X POST 'https://api.example.com/v1/users' -H 'Content-Type: application/json' -H 'Authorization: Bearer abc123' -d '{\"name\":\"Test\",\"email\":\"test@example.com\"}'";
        final request = await curlImport(CurlImportParams(
          curlCommand: command,
          workspaceId: 'ws-1',
        ));

        expect(request.method, equals(HttpMethod.post));
        expect(request.url, equals('https://api.example.com/v1/users'));
        expect(request.verifySsl, isFalse);
        expect(request.bodyType, equals(BodyType.raw));
        expect(request.bodyContent,
            contains('"name":"Test"'));
        expect(request.bodyContent,
            contains('"email":"test@example.com"'));

        // Verify headers.
        final authHeaders = request.headers
            .where((h) => h.key.toLowerCase() == 'authorization');
        expect(authHeaders, isNotEmpty);
        expect(authHeaders.first.value, equals('Bearer abc123'));
      });
    });

    group('error handling for malformed curl', () {
      test('defaults URL to example.com when no URL is found', () async {
        const command = 'curl -X POST';
        final request = await curlImport(CurlImportParams(
          curlCommand: command,
          workspaceId: 'ws-1',
        ));
        expect(request.url, equals('https://example.com'));
      });

      test('handles empty string gracefully', () async {
        const command = '';
        final request = await curlImport(CurlImportParams(
          curlCommand: command,
          workspaceId: 'ws-1',
        ));
        // Should not throw; defaults to example.com.
        expect(request.url, equals('https://example.com'));
      });

      test('handles curl with only flags (no URL) gracefully', () async {
        const command = 'curl -s -k -H "X-Test: value"';
        final request = await curlImport(CurlImportParams(
          curlCommand: command,
          workspaceId: 'ws-1',
        ));
        expect(request.url, equals('https://example.com'));
      });
    });

    group('parsing form data with -F flag', () {
      test('parses --data-urlencode', () async {
        const command =
            "curl -X POST 'https://api.example.com/login' --data-urlencode 'username=admin' --data-urlencode 'password=secret'";
        final request = await curlImport(CurlImportParams(
          curlCommand: command,
          workspaceId: 'ws-1',
        ));

        expect(request.method, equals(HttpMethod.post));
        expect(request.bodyType, equals(BodyType.raw));
        expect(request.bodyContent, contains('username=admin'));
      });
    });

    group('generated request metadata', () {
      test('assigns the provided workspace ID', () async {
        const command = 'curl https://api.example.com/test';
        final request = await curlImport(CurlImportParams(
          curlCommand: command,
          workspaceId: 'my-workspace-id',
        ));
        expect(request.workspaceId, equals('my-workspace-id'));
      });

      test('assigns optional collection ID when provided', () async {
        const command = 'curl https://api.example.com/test';
        final request = await curlImport(CurlImportParams(
          curlCommand: command,
          workspaceId: 'ws-1',
          collectionId: 'col-1',
        ));
        expect(request.collectionId, equals('col-1'));
      });

      test('generates a non-empty UUID for the request ID', () async {
        const command = 'curl https://api.example.com/test';
        final request = await curlImport(CurlImportParams(
          curlCommand: command,
          workspaceId: 'ws-1',
        ));
        expect(request.id, isNotEmpty);
      });

      test('generates a name from the URL path', () async {
        const command = 'curl https://api.example.com/v1/users';
        final request = await curlImport(CurlImportParams(
          curlCommand: command,
          workspaceId: 'ws-1',
        ));
        expect(request.name, contains('GET'));
        expect(request.name, contains('/v1/users'));
      });
    });
  });
}
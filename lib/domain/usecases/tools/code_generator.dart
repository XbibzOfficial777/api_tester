/// @file code_generator.dart
/// @brief Use case for generating code snippets from an API request.
///
/// Takes a configured [ApiRequest] and a target programming language,
/// then produces a ready-to-use code snippet that reproduces the same
/// HTTP request. Supports 7 programming languages/frameworks.
library;

import '../../entities/api_request.dart';
import '../../entities/form_data_item.dart';
import '../usecase.dart';

/// Supported target languages for code generation.
enum CodeLanguage {
  /// Dart (using the http or dio package).
  @JsonValue('dart')
  dart,

  /// Python (using the requests library).
  @JsonValue('python')
  python,

  /// JavaScript (using the fetch API).
  @JsonValue('javascript')
  javascript,

  /// Java (using java.net.HttpURLConnection).
  @JsonValue('java')
  java,

  /// cURL command line.
  @JsonValue('curl')
  curl,

  /// C# (using HttpClient).
  @JsonValue('csharp')
  csharp,

  /// Go (using net/http).
  @JsonValue('go')
  go,
}

/// Parameters for the code generation use case.
class CodeGeneratorParams {
  /// The API request to generate code for.
  final ApiRequest request;

  /// The target programming language for the generated code.
  final CodeLanguage language;

  /// Creates parameter object for code generation.
  ///
  /// [request] - The fully configured API request.
  /// [language] - The target language to generate code for.
  const CodeGeneratorParams({
    required this.request,
    required this.language,
  });
}

/// Generates a code snippet that reproduces the given API request.
///
/// Supports seven target languages with idiomatic code that handles
/// all body types, headers, query parameters, and authentication.
class CodeGenerator extends UseCase<String, CodeGeneratorParams> {
  /// Creates a new [CodeGenerator] use case.
  CodeGenerator();

  /// Generates a code snippet in the specified language.
  @override
  Future<String> call(CodeGeneratorParams params) async {
    final request = params.request;

    switch (params.language) {
      case CodeLanguage.dart:
        return _generateDart(request);
      case CodeLanguage.python:
        return _generatePython(request);
      case CodeLanguage.javascript:
        return _generateJavaScript(request);
      case CodeLanguage.java:
        return _generateJava(request);
      case CodeLanguage.curl:
        return _generateCurl(request);
      case CodeLanguage.csharp:
        return _generateCSharp(request);
      case CodeLanguage.go:
        return _generateGo(request);
    }
  }

  /// Builds the full URL with query parameters appended.
  String _buildUrlWithQuery(ApiRequest request) {
    final enabledParams = request.queryParams.where((q) => q.isEnabled);
    if (enabledParams.isEmpty) return request.url;

    final uri = Uri.parse(request.url);
    final queryParams = Map<String, String>.from(uri.queryParameters);
    for (final p in enabledParams) {
      if (p.key.isNotEmpty) queryParams[p.key] = p.value;
    }

    final newUri = uri.replace(queryParameters: queryParams);
    return newUri.toString();
  }

  /// Builds a headers map string representation from enabled headers.
  Map<String, String> _enabledHeaders(ApiRequest request) {
    return {
      for (final h in request.headers.where((h) => h.isEnabled))
        if (h.key.isNotEmpty) h.key: h.value
    };
  }

  // ---------------------------------------------------------------------------
  // Dart code generation
  // ---------------------------------------------------------------------------

  /// Generates a Dart code snippet using the `http` package.
  String _generateDart(ApiRequest request) {
    final headers = _enabledHeaders(request);
    final url = _buildUrlWithQuery(request);
    final method = request.method.name.toUpperCase();

    final buffer = StringBuffer();
    buffer.writeln("import 'package:http/http.dart' as http;");
    buffer.writeln();

    buffer.writeln('Future<void> sendRequest() async {');
    buffer.writeln("  final url = Uri.parse('$url');");
    buffer.writeln('  final response = await http.');

    if (method == 'GET') {
      buffer.write('get');
    } else if (method == 'POST') {
      buffer.write('post');
    } else if (method == 'PUT') {
      buffer.write('put');
    } else if (method == 'PATCH') {
      buffer.write('patch');
    } else if (method == 'DELETE') {
      buffer.write('delete');
    } else if (method == 'HEAD') {
      buffer.write('head');
    } else {
      buffer.write('get');
    }
    buffer.writeln('(url, headers: {');

    for (var i = 0; i < headers.entries.length; i++) {
      final entry = headers.entries.elementAt(i);
      final comma = i < headers.entries.length - 1 ? ',' : '';
      buffer.writeln(
          "    '${_escapeDart(entry.key)}': '${_escapeDart(entry.value)}'$comma");
    }
    buffer.writeln('  }');

    // Add body if applicable.
    if (_hasBody(request)) {
      buffer.writeln(", body: '${_escapeDart(request.bodyContent)}'");
    }

    buffer.writeln('  });');
    buffer.writeln();
    buffer.writeln('  print(\'Status: \${response.statusCode}\');');
    buffer.writeln('  print(\'Body: \${response.body}\');');
    buffer.writeln('}');

    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // Python code generation
  // ---------------------------------------------------------------------------

  /// Generates a Python code snippet using the `requests` library.
  String _generatePython(ApiRequest request) {
    final headers = _enabledHeaders(request);
    final url = _buildUrlWithQuery(request);
    final method = request.method.name.toLowerCase();

    final buffer = StringBuffer();
    buffer.writeln('import requests');
    buffer.writeln();

    buffer.writeln('url = "$url"');

    // Headers.
    if (headers.isNotEmpty) {
      buffer.writeln('headers = {');
      final entries = headers.entries.toList();
      for (var i = 0; i < entries.length; i++) {
        final comma = i < entries.length - 1 ? ',' : '';
        buffer.writeln(
            '    "${_escapePython(entries[i].key)}": "${_escapePython(entries[i].value)}"$comma');
      }
      buffer.writeln('}');
    }

    // Body.
    if (_hasBody(request)) {
      if (request.bodyType == BodyType.raw &&
          request.bodyContent.trim().startsWith('{')) {
        // Pretty-print JSON body.
        buffer.writeln('json_data = ${request.bodyContent}');
      } else {
        buffer.writeln('data = "${_escapePython(request.bodyContent)}"');
      }
    }

    buffer.writeln();
    buffer.write('response = requests.$method(url');

    if (headers.isNotEmpty) {
      buffer.write(', headers=headers');
    }

    if (_hasBody(request)) {
      if (request.bodyType == BodyType.raw &&
          request.bodyContent.trim().startsWith('{')) {
        buffer.write(', json=json_data');
      } else {
        buffer.write(', data=data');
      }
    }

    buffer.writeln(')');
    buffer.writeln('print(f"Status: {response.status_code}")');
    buffer.writeln('print(f"Body: {response.text}")');

    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // JavaScript code generation
  // ---------------------------------------------------------------------------

  /// Generates a JavaScript code snippet using the Fetch API.
  String _generateJavaScript(ApiRequest request) {
    final headers = _enabledHeaders(request);
    final url = _buildUrlWithQuery(request);
    final method = request.method.name.toUpperCase();

    final buffer = StringBuffer();

    buffer.writeln('const url = "$url";');
    buffer.writeln();

    buffer.writeln('const options = {');
    buffer.writeln('  method: "$method",');

    // Headers.
    if (headers.isNotEmpty) {
      buffer.writeln('  headers: {');
      final entries = headers.entries.toList();
      for (var i = 0; i < entries.length; i++) {
        final comma = i < entries.length - 1 ? ',' : '';
        buffer.writeln(
            '    "${_escapeJs(entries[i].key)}": "${_escapeJs(entries[i].value)}"$comma');
      }
      buffer.writeln('  },');
    }

    // Body.
    if (_hasBody(request) && method != 'GET' && method != 'HEAD') {
      buffer.writeln('  body: JSON.stringify(${request.bodyContent}),');
    }

    buffer.writeln('};');
    buffer.writeln();
    buffer.writeln('fetch(url, options)');
    buffer.writeln('  .then(response => {');
    buffer.writeln('    console.log("Status:", response.status);');
    buffer.writeln('    return response.text();');
    buffer.writeln('  })');
    buffer.writeln('  .then(body => console.log("Body:", body))');
    buffer.writeln('  .catch(error => console.error("Error:", error));');

    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // Java code generation
  // ---------------------------------------------------------------------------

  /// Generates a Java code snippet using HttpURLConnection.
  String _generateJava(ApiRequest request) {
    final headers = _enabledHeaders(request);
    final url = _buildUrlWithQuery(request);
    final method = request.method.name.toUpperCase();

    final buffer = StringBuffer();
    buffer.writeln('import java.net.HttpURLConnection;');
    buffer.writeln('import java.net.URL;');
    buffer.writeln('import java.io.BufferedReader;');
    buffer.writeln('import java.io.InputStreamReader;');
    buffer.writeln('import java.io.OutputStream;');
    buffer.writeln();

    buffer.writeln('public class ApiRequest {');
    buffer.writeln('  public static void main(String[] args) throws Exception {');
    buffer.writeln('    URL url = new URL("$url");');
    buffer.writeln('    HttpURLConnection conn = (HttpURLConnection) url.openConnection();');
    buffer.writeln('    conn.setRequestMethod("$method");');

    // Headers.
    for (final entry in headers.entries) {
      buffer.writeln(
          '    conn.setRequestProperty("${_escapeJava(entry.key)}", "${_escapeJava(entry.value)}");');
    }

    // Body for POST/PUT/PATCH.
    if (_hasBody(request) &&
        method != 'GET' &&
        method != 'HEAD' &&
        method != 'DELETE') {
      buffer.writeln('    conn.setDoOutput(true);');
      buffer.writeln('    String requestBody = "${_escapeJava(request.bodyContent)}";');
      buffer.writeln('    try (OutputStream os = conn.getOutputStream()) {');
      buffer.writeln('      byte[] input = requestBody.getBytes("utf-8");');
      buffer.writeln('      os.write(input, 0, input.length);');
      buffer.writeln('    }');
    }

    buffer.writeln();
    buffer.writeln('    int status = conn.getResponseCode();');
    buffer.writeln('    System.out.println("Status: " + status);');
    buffer.writeln();
    buffer.writeln('    BufferedReader br = new BufferedReader(');
    buffer.writeln('      new InputStreamReader(');
    buffer.writeln('        status < 400 ? conn.getInputStream() : conn.getErrorStream()');
    buffer.writeln('      )');
    buffer.writeln('    );');
    buffer.writeln('    StringBuilder response = new StringBuilder();');
    buffer.writeln('    String line;');
    buffer.writeln('    while ((line = br.readLine()) != null) {');
    buffer.writeln('      response.append(line);');
    buffer.writeln('    }');
    buffer.writeln('    br.close();');
    buffer.writeln('    System.out.println("Body: " + response.toString());');
    buffer.writeln('  }');
    buffer.writeln('}');

    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // cURL code generation
  // ---------------------------------------------------------------------------

  /// Generates a cURL command that reproduces the request.
  String _generateCurl(ApiRequest request) {
    final headers = _enabledHeaders(request);
    final url = _buildUrlWithQuery(request);
    final method = request.method.name.toUpperCase();

    final parts = <String>['curl'];

    // Method (only if not GET).
    if (method != 'GET') {
      parts.add('-X $method');
    }

    // Headers.
    for (final entry in headers.entries) {
      parts.add("-H '${entry.key}: ${entry.value}'");
    }

    // Body.
    if (_hasBody(request)) {
      if (request.bodyType == BodyType.formData) {
        for (final item in request.formDataItems.where((f) => f.key.isNotEmpty)) {
          if (item.isFile) {
            parts.add('-F "${item.key}=@${item.filePath}"');
          } else {
            parts.add('-F "${item.key}=${item.value}"');
          }
        }
      } else {
        // Escape single quotes in the body.
        final escapedBody = request.bodyContent.replaceAll("'", "'\\''");
        parts.add("-d '$escapedBody'");
      }
    }

    // URL (always last).
    parts.add("'$url'");

    return parts.join(' \\\n  ');
  }

  // ---------------------------------------------------------------------------
  // C# code generation
  // ---------------------------------------------------------------------------

  /// Generates a C# code snippet using HttpClient.
  String _generateCSharp(ApiRequest request) {
    final headers = _enabledHeaders(request);
    final url = _buildUrlWithQuery(request);
    final method = request.method.name.ToUpperFirst();

    final buffer = StringBuffer();
    buffer.writeln('using System;');
    buffer.writeln('using System.Net.Http;');
    buffer.writeln('using System.Text;');
    buffer.writeln('using System.Threading.Tasks;');
    buffer.writeln();

    buffer.writeln('class Program {');
    buffer.writeln('  static async Task Main() {');
    buffer.writeln('    using var client = new HttpClient();');

    // Headers.
    for (final entry in headers.entries) {
      buffer.writeln(
          '    client.DefaultRequestHeaders.TryAddWithoutValidation("${_escapeCSharp(entry.key)}", "${_escapeCSharp(entry.value)}");');
    }

    buffer.writeln();
    buffer.writeln('    var content = new StringContent(');
    buffer.writeln('      "${_escapeCSharp(request.bodyContent)}",');
    buffer.writeln('      Encoding.UTF8,');
    buffer.writeln('      "${_getContentType(headers)}"');
    buffer.writeln('    );');
    buffer.writeln();
    buffer.writeln('    var response = await client.$methodAsync("$url", content);');
    buffer.writeln('    Console.WriteLine($"Status: {(int)response.StatusCode}");');
    buffer.writeln('    var body = await response.Content.ReadAsStringAsync();');
    buffer.writeln('    Console.WriteLine($"Body: {body}");');
    buffer.writeln('  }');
    buffer.writeln('}');

    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // Go code generation
  // ---------------------------------------------------------------------------

  /// Generates a Go code snippet using net/http.
  String _generateGo(ApiRequest request) {
    final headers = _enabledHeaders(request);
    final url = _buildUrlWithQuery(request);
    final method = request.method.name.toUpperCase();

    final buffer = StringBuffer();
    buffer.writeln('package main');
    buffer.writeln();
    buffer.writeln('import (');
    buffer.writeln('    "bytes"');
    buffer.writeln('    "fmt"');
    buffer.writeln('    "io"');
    buffer.writeln('    "net/http"');
    buffer.writeln(')');
    buffer.writeln();
    buffer.writeln('func main() {');

    // Body.
    if (_hasBody(request) && method != 'GET' && method != 'HEAD') {
      buffer
          .writeln('    body := []byte(`' + request.bodyContent + '`)');
    }

    // Request creation.
    if (_hasBody(request) && method != 'GET' && method != 'HEAD') {
      buffer.writeln('  req, err := http.NewRequest("$method", "$url", bytes.NewBuffer(body))');
    } else {
      buffer.writeln(
          '     req, err := http.NewRequest("$method", "$url", nil)');
    }
    buffer.writeln('    if err != nil {');
    buffer.writeln('            panic(err)');
    buffer.writeln('    }');
    buffer.writeln();

    // Headers.
    for (final entry in headers.entries) {
      buffer.writeln(
          '     req.Header.Set("${_escapeGo(entry.key)}", "${_escapeGo(entry.value)}")');
    }

    buffer.writeln();
    buffer.writeln('    client := &http.Client{}');
    buffer.writeln('    resp, err := client.Do(req)');
    buffer.writeln('    if err != nil {');
    buffer.writeln('            panic(err)');
    buffer.writeln('    }');
    buffer.writeln('    defer resp.Body.Close()');
    buffer.writeln();
    buffer.writeln('    fmt.Printf("Status: %d\\n", resp.StatusCode)');
    buffer.writeln('    body, _ := io.ReadAll(resp.Body)');
    buffer.writeln('    fmt.Printf("Body: %s\\n", body)');
    buffer.writeln('}');

    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // Helper methods
  // ---------------------------------------------------------------------------

  /// Returns true if the request has a body to send.
  bool _hasBody(ApiRequest request) {
    return request.bodyType != BodyType.none &&
        (request.bodyContent.isNotEmpty ||
            request.formDataItems.isNotEmpty);
  }

  /// Extracts the Content-Type from the headers map, defaulting to
  /// application/json.
  String _getContentType(Map<String, String> headers) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == 'content-type') {
        return entry.value;
      }
    }
    return 'application/json';
  }

  // Language-specific string escaping utilities.

  /// Escapes special characters for Dart string literals.
  String _escapeDart(String input) {
    return input
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
  }

  /// Escapes special characters for Python string literals.
  String _escapePython(String input) {
    return input
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
  }

  /// Escapes special characters for JavaScript string literals.
  String _escapeJs(String input) {
    return input
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
  }

  /// Escapes special characters for Java string literals.
  String _escapeJava(String input) {
    return input
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
  }

  /// Escapes special characters for C# string literals.
  String _escapeCSharp(String input) {
    return input
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
  }

  /// Escapes special characters for Go string literals.
  String _escapeGo(String input) {
    return input
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
  }
}

/// Extension to capitalize the first letter of a string (used for C# method names).
extension _StringExtension on String {
  String ToUpperFirst() {
    if (isEmpty) return this;
    return '${substring(0, 1).toUpperCase()}${substring(1).toLowerCase()}';
  }
}
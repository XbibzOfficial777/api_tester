/// @file har_parser.dart
/// @brief Parser for HAR (HTTP Archive) files.
///
/// Accepts a HAR JSON string conforming to the [HAR 1.2 spec](http://www.softwareishard.com/blog/har-12-spec/)
/// and extracts HTTP request/response entries into a list of simple maps.
///
/// Each entry map mirrors the structure of an [ApiRequest]-like object
/// with fields such as `method`, `url`, `headers`, `queryString`, `postData`,
/// and `response` (status, headers, body).
///
/// **Features:**
/// - Extracts all entries from `log.entries`.
/// - Handles `request.method`, `request.url`, `request.httpVersion`.
/// - Extracts `request.headers` as a `List<Map<String, String>>`.
/// - Extracts `request.queryString` and appends to URL or stores separately.
/// - Handles `request.postData` including `text`, `mimeType`, and `params`.
/// - Extracts `response.status`, `response.statusText`, `response.headers`,
///   and `response.content.text`.
/// - Filters out non-HTTP entries (missing method or URL).
/// - Gracefully handles missing or malformed fields with sensible defaults.
///
/// Example:
/// ```dart
/// final harJson = File('recording.har').readAsStringSync();
/// final entries = HarParser.parse(harJson);
/// for (final entry in entries) {
///   print('${entry['method']} ${entry['url']}');
/// }
/// ```

library;

import 'dart:convert';

/// Parses HAR (HTTP Archive) JSON data into a list of request-like maps.
///
/// The parser is designed to be forgiving: missing fields default to
/// sensible values rather than causing exceptions. Only entries that have
/// both a valid HTTP method and a non-empty URL are included in the result.
class HarParser {
  HarParser._();

  /// Parses a HAR JSON string and returns a list of request entry maps.
  ///
  /// [harJson] — The raw JSON string of the HAR file.
  ///
  /// Returns a list of maps, each containing:
  /// - `'method'` (String) — HTTP method, e.g. `"GET"`.
  /// - `'url'` (String) — The full request URL.
  /// - `'httpVersion'` (String) — HTTP version, defaults to `"HTTP/1.1"`.
  /// - `'headers'` (List<Map<String, String>>) — Request headers.
  /// - `'queryString'` (List<Map<String, String>>) — Query parameters.
  /// - `'postData'` (Map<String, dynamic>?) — Request body info.
  /// - `'responseStatus'` (int?) — Response status code.
  /// - `'responseStatusText'` (String?) — Response status phrase.
  /// - `'responseHeaders'` (List<Map<String, String>>) — Response headers.
  /// - `'responseBody'` (String?) — Decoded response body text.
  ///
  /// Throws [FormatException] if [harJson] is not valid JSON.
  static List<Map<String, dynamic>> parse(String harJson) {
    final Map<String, dynamic> har;
    try {
      har = jsonDecode(harJson) as Map<String, dynamic>;
    } on FormatException catch (e) {
      throw FormatException('Invalid HAR JSON: ${e.message}');
    }

    // Navigate to log.entries
    final log = har['log'] as Map<String, dynamic>?;
    if (log == null) {
      // Malformed HAR — no "log" key.
      return [];
    }

    final entries = log['entries'] as List<dynamic>?;
    if (entries == null) {
      return [];
    }

    final results = <Map<String, dynamic>>[];

    for (final entry in entries) {
      final parsed = _parseEntry(entry as Map<String, dynamic>?);
      if (parsed != null) {
        results.add(parsed);
      }
    }

    return results;
  }

  /// Parses a single HAR entry into a request-like map.
  ///
  /// Returns `null` if the entry lacks a valid method or URL (i.e. it is
  /// not a real HTTP request).
  static Map<String, dynamic>? _parseEntry(
    Map<String, dynamic>? entry,
  ) {
    if (entry == null) return null;

    final request = entry['request'] as Map<String, dynamic>?;
    if (request == null) return null;

    // Extract method — must be a non-empty string.
    final method = _stringOrNull(request['method'])?.toUpperCase().trim();
    if (method == null || method.isEmpty) return null;

    // Extract URL — must be a non-empty string.
    final url = _stringOrNull(request['url'])?.trim();
    if (url == null || url.isEmpty) return null;

    // Parse response (optional, may be missing).
    final response = entry['response'] as Map<String, dynamic>?;

    return {
      'method': method,
      'url': url,
      'httpVersion':
          _stringOrNull(request['httpVersion']) ?? 'HTTP/1.1',
      'headers': _parseHeaders(request['headers']),
      'queryString': _parseQueryString(request['queryString']),
      'postData': _parsePostData(request['postData']),
      'responseStatus': _intOrNull(response?['status']),
      'responseStatusText': _stringOrNull(response?['statusText']),
      'responseHeaders': _parseHeaders(response?['headers']),
      'responseBody': _parseResponseBody(response?['content']),
    };
  }

  /// Parses a headers array into a list of `{name, value}` maps.
  ///
  /// HAR headers are formatted as:
  /// ```json
  /// [{"name": "Content-Type", "value": "application/json"}]
  /// ```
  ///
  /// Returns an empty list if the input is null or not a list.
  static List<Map<String, String>> _parseHeaders(dynamic headers) {
    if (headers is! List) return [];

    return headers
        .whereType<Map<String, dynamic>>()
        .map((h) {
          final name = _stringOrNull(h['name']);
          final value = _stringOrNull(h['value']);
          if (name == null) return null;
          return <String, String>{'name': name, 'value': value ?? ''};
        })
        .whereType<Map<String, String>>()
        .toList();
  }

  /// Parses a queryString array into a list of `{name, value}` maps.
  ///
  /// HAR query strings use the same format as headers:
  /// ```json
  /// [{"name": "page", "value": "1"}]
  /// ```
  static List<Map<String, String>> _parseQueryString(dynamic queryString) {
    if (queryString is! List) return [];

    return queryString
        .whereType<Map<String, dynamic>>()
        .map((q) {
          final name = _stringOrNull(q['name']);
          final value = _stringOrNull(q['value']);
          if (name == null) return null;
          return <String, String>{'name': name, 'value': value ?? ''};
        })
        .whereType<Map<String, String>>()
        .toList();
  }

  /// Parses the `postData` object from a HAR request.
  ///
  /// Returns a map with:
  /// - `'mimeType'` — The MIME type of the posted data.
  /// - `'text'` — The raw text body (if available).
  /// - `'params'` — Parsed parameters (if available).
  ///
  /// Returns `null` if there is no post data.
  static Map<String, dynamic>? _parsePostData(dynamic postData) {
    if (postData is! Map<String, dynamic>) return null;

    // Extract params array if present.
    final params = <Map<String, String>>[];
    final rawParams = postData['params'] as List<dynamic>?;
    if (rawParams != null) {
      for (final p in rawParams) {
        if (p is Map<String, dynamic>) {
          final name = _stringOrNull(p['name']);
          final value = _stringOrNull(p['value']);
          if (name != null) {
            params.add({'name': name, 'value': value ?? ''});
          }
        }
      }
    }

    return {
      'mimeType': _stringOrNull(postData['mimeType']) ?? '',
      'text': _stringOrNull(postData['text']) ?? '',
      'params': params,
    };
  }

  /// Extracts the response body text from the `content` object.
  ///
  /// The content object in HAR has a `text` field with the decoded body.
  /// Some HAR exporters may omit it (e.g. for binary responses).
  static String? _parseResponseBody(dynamic content) {
    if (content is! Map<String, dynamic>) return null;
    return _stringOrNull(content['text']);
  }

  /// Safely extracts a String from a dynamic value.
  ///
  /// Returns `null` if [value] is not a [String].
  static String? _stringOrNull(dynamic value) {
    if (value is String) return value;
    return null;
  }

  /// Safely extracts an int from a dynamic value.
  ///
  /// Returns `null` if [value] is not an [int].
  static int? _intOrNull(dynamic value) {
    if (value is int) return value;
    return null;
  }
}
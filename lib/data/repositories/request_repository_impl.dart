/// Implementation of [RequestRepository] backed by the Drift local database
/// for persistence and [Dio] for actual HTTP execution.
///
/// This is the most complex repository in the application because it must:
/// 1. Persist / retrieve request definitions.
/// 2. Resolve `{{variable}}` placeholders from the active environment.
/// 3. Build a Dio instance that respects proxy, timeout, and SSL settings.
/// 4. Handle every [BodyType] variant (none, formData, urlEncoded, raw, binary).
/// 5. Record response timing and return a domain [ApiResponse].
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../../../domain/entities/api_request.dart';
import '../../../domain/entities/api_response.dart';
import '../../../domain/entities/key_value.dart';
import '../../../domain/entities/key_value_item.dart';
import '../../../domain/repositories/request_repository.dart';
import '../datasources/local/database/app_database.dart';
import '../datasources/remote/api_service.dart';
import '../mappers/request_mapper.dart';

/// Concrete [RequestRepository] that persists requests to SQLite via Drift
/// and executes them over the network via [Dio].
class RequestRepositoryImpl implements RequestRepository {
  /// The Drift database instance for local persistence.
  final AppDatabase _db;

  /// Creates a [RequestRepositoryImpl].
  ///
  /// [db] is the local database; the [ApiService] is instantiated
  /// internally per-request so that per-request proxy / timeout settings
  /// are always honoured.
  RequestRepositoryImpl(this._db);

  // ---------------------------------------------------------------------------
  // RequestRepository – Persistence
  // ---------------------------------------------------------------------------

  @override
  Future<List<ApiRequest>> getRequestsByWorkspace(String workspaceId) async {
    try {
      final rows = await _db.requestDao.getRequestsByWorkspace(workspaceId);
      return RequestMapper.toEntityList(rows);
    } catch (e) {
      throw Exception(
          'Failed to fetch requests for workspace "$workspaceId": $e');
    }
  }

  @override
  Future<ApiRequest> getRequest(String id) async {
    try {
      final row = await _db.requestDao.getRequestById(id);
      if (row == null) {
        throw Exception('Request with id "$id" not found.');
      }
      return RequestMapper.toEntity(row);
    } catch (e) {
      throw Exception('Failed to fetch request with id "$id": $e');
    }
  }

  Future<ApiRequest?> getRequestById(String id) async {
    try {
      final row = await _db.requestDao.getRequestById(id);
      return row != null ? RequestMapper.toEntity(row) : null;
    } catch (e) {
      throw Exception('Failed to fetch request with id "$id": $e');
    }
  }

  @override
  Future<List<ApiRequest>> getRequestsByCollection(String collectionId) async {
    try {
      final rows = await _db.requestDao.getRequestsByCollection(collectionId);
      return RequestMapper.toEntityList(rows);
    } catch (e) {
      throw Exception(
          'Failed to fetch requests for collection "$collectionId": $e');
    }
  }

  @override
  Future<ApiRequest> createRequest(ApiRequest request) async {
    try {
      final companion = RequestMapper.fromEntity(request);
      await _db.requestDao.insertRequest(companion);
      return request;
    } catch (e) {
      throw Exception('Failed to create request "${request.name}": $e');
    }
  }

  @override
  Future<ApiRequest> updateRequest(ApiRequest request) async {
    try {
      final companion = RequestMapper.fromEntity(request);
      final updated = await _db.requestDao.updateRequest(companion);
      if (!updated) {
        throw Exception('Request with id "${request.id}" not found.');
      }
      return request;
    } catch (e) {
      throw Exception('Failed to update request "${request.name}": $e');
    }
  }

  Future<ApiRequest> duplicateRequest(String requestId) async {
    try {
      final row = await _db.requestDao.getRequestById(requestId);
      if (row == null) {
        throw Exception('Request with id "$requestId" not found for duplication.');
      }

      // Convert to entity, create a new copy with a fresh ID.
      final original = RequestMapper.toEntity(row);
      final now = DateTime.now();
      final duplicate = original.copyWith(
        id: _generateUuid(),
        name: '${original.name} (Copy)',
        createdAt: now,
        updatedAt: now,
      );

      final companion = RequestMapper.fromEntity(duplicate);
      await _db.requestDao.insertRequest(companion);
      return duplicate;
    } catch (e) {
      throw Exception('Failed to duplicate request "$requestId": $e');
    }
  }

  @override
  Future<void> deleteRequest(String id) async {
    try {
      await _db.requestDao.deleteRequest(id);
    } catch (e) {
      throw Exception('Failed to delete request with id "$id": $e');
    }
  }

  Future<void> deleteRequestsByWorkspace(String workspaceId) async {
    try {
      await _db.requestDao.deleteRequestsByWorkspace(workspaceId);
    } catch (e) {
      throw Exception(
          'Failed to delete requests for workspace "$workspaceId": $e');
    }
  }

  Stream<List<ApiRequest>> watchRequestsByWorkspace(String workspaceId) {
    try {
      return _db.requestDao
          .watchRequestsByWorkspace(workspaceId)
          .map(RequestMapper.toEntityList);
    } catch (e) {
      throw Exception(
          'Failed to watch requests for workspace "$workspaceId": $e');
    }
  }

  @override
  Future<List<String>> getRecentEndpoints() async {
    try {
      final results = await _db.customSelect(
        'SELECT DISTINCT url FROM request_history ORDER BY timestamp DESC LIMIT 20',
      ).get();
      return results
          .map((row) => row.read<String>('url'))
          .where((url) => url.isNotEmpty)
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch recent endpoints: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // RequestRepository – HTTP Execution
  // ---------------------------------------------------------------------------

  @override
  Future<ApiResponse> sendRequest(ApiRequest request) async {
    // 1. Resolve environment variables in URL, headers, and body.
    final variables = await _resolveVariables(request.workspaceId);
    final resolvedUrl = _substituteVariables(request.url, variables);
    final resolvedHeaders = _resolveHeaders(request.headers, variables);
    final resolvedBody =
        request.bodyType == BodyType.raw ? _substituteVariables(request.bodyContent ?? '', variables) : request.bodyContent;

    // 2. Build query-parameters map from the enabled entries only.
    final queryParams = <String, dynamic>{};
    for (final kv in request.queryParams) {
      if (kv.isEnabled && kv.key.isNotEmpty) {
        queryParams[_substituteVariables(kv.key, variables)] =
            _substituteVariables(kv.value, variables);
      }
    }

    // 3. Build the Dio instance with request-specific configuration.
    final dio = _buildDio(request, variables);

    // 4. Build the request body based on body type.
    final dynamic body = _buildRequestBody(request, variables);

    // 5. Determine the content-type header based on body type.
    final contentType = _resolveContentType(request, body);

    // 6. Merge resolved headers with the content-type.
    final finalHeaders = <String, dynamic>{
      ...resolvedHeaders,
      if (contentType != null) 'Content-Type': contentType,
    };

    // 7. Execute the request and measure response time.
    final apiService = ApiService(dio);
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _executeMethod(
        apiService,
        request.method,
        resolvedUrl,
        queryParameters: queryParams,
        headers: finalHeaders,
        body: body,
      );
      stopwatch.stop();

      // Extract response headers as a flat map.
      final responseHeaders = <String, String>{};
      response.headers.forEach((name, values) {
        responseHeaders[name] = values.join(', ');
      });

      return ApiResponse(
        statusCode: response.statusCode,
        statusMessage: response.statusMessage,
        headers: responseHeaders,
        body: response.data is String
            ? response.data as String
            : json.encode(response.data),
        responseTimeMs: stopwatch.elapsedMilliseconds,
        contentLength: response.data is String
            ? (response.data as String).length
            : int.tryParse(response.headers.value('content-length') ?? ''),
      );
    } on Exception catch (e) {
      stopwatch.stop();

      // If the error is a DioException with a partial response, still
      // return useful metadata.
      if (e is DioException && e.response != null) {
        final partial = e.response!;
        final responseHeaders = <String, String>{};
        partial.headers.forEach((name, values) {
          responseHeaders[name] = values.join(', ');
        });

        return ApiResponse(
          statusCode: partial.statusCode,
          statusMessage: partial.statusMessage,
          headers: responseHeaders,
          body: partial.data is String
              ? partial.data as String
              : json.encode(partial.data),
          responseTimeMs: stopwatch.elapsedMilliseconds,
          error: e.message,
        );
      }

      // Network-level failure (no response at all).
      return ApiResponse(
        responseTimeMs: stopwatch.elapsedMilliseconds,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers – Variable resolution
  // ---------------------------------------------------------------------------

  /// Loads variables from the active environment and the global environment
  /// of [workspaceId], returning a flat map.
  ///
  /// Active-environment variables take precedence over global variables.
  Future<Map<String, String>> _resolveVariables(String workspaceId) async {
    final variables = <String, String>{};

    // Load global environment variables first (lower priority).
    final global =
        await _db.environmentDao.getGlobalEnvironment(workspaceId);
    if (global != null) {
      for (final kv in _parseVariables(global.variables)) {
        if (kv.enabled && kv.key.isNotEmpty) {
          variables[kv.key] = kv.value;
        }
      }
    }

    // Load active environment variables (higher priority – overwrites
    // global duplicates).
    final active =
        await _db.environmentDao.getActiveEnvironment(workspaceId);
    if (active != null) {
      for (final kv in _parseVariables(active.variables)) {
        if (kv.enabled && kv.key.isNotEmpty) {
          variables[kv.key] = kv.value;
        }
      }
    }

    return variables;
  }

  /// Parses the JSON variable list from the database into [KeyValue] objects.
  List<KeyValue> _parseVariables(String jsonString) {
    if (jsonString.isEmpty) return [];
    try {
      final decoded = json.decode(jsonString) as List<dynamic>;
      return decoded.map((item) {
        final map = item as Map<String, dynamic>;
        return KeyValue(
          key: map['key'] as String? ?? '',
          value: map['value'] as String? ?? '',
          enabled: map['enabled'] as bool? ?? true,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Replaces all `{{variable_name}}` occurrences in [input] with values
  /// from [variables]. Unmatched placeholders are left as-is.
  static String _substituteVariables(
      String input, Map<String, String> variables) {
    if (variables.isEmpty) return input;

    String result = input;
    for (final entry in variables.entries) {
      result = result.replaceAll('{{${entry.key}}}', entry.value);
    }
    return result;
  }

  /// Resolves headers by substituting variables and filtering out
  /// disabled / empty-key entries.
  static Map<String, dynamic> _resolveHeaders(
      List<KeyValueItem> headers, Map<String, String> variables) {
    final result = <String, dynamic>{};
    for (final kv in headers) {
      if (kv.isEnabled && kv.key.isNotEmpty) {
        final resolvedKey = _substituteVariables(kv.key, variables);
        final resolvedValue = _substituteVariables(kv.value, variables);
        result[resolvedKey] = resolvedValue;
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Private helpers – Dio construction
  // ---------------------------------------------------------------------------

  /// Builds a Dio instance configured with the proxy, timeout, and SSL
  /// settings from the given [request].
  Dio _buildDio(ApiRequest request, Map<String, String> variables) {
    final dio = Dio();

    // -- Timeout --------------------------------------------------------------
    final timeoutMs =
        (request.timeoutSeconds ?? 30) * 1000; // default 30 seconds
    dio.options.connectTimeout = Duration(milliseconds: timeoutMs);
    dio.options.receiveTimeout = Duration(milliseconds: timeoutMs);
    dio.options.sendTimeout = Duration(milliseconds: timeoutMs);

    // -- Follow redirects ------------------------------------------------------
    dio.options.followRedirects = request.followRedirects;
    dio.options.maxRedirects = 5;

    // -- SSL verification ------------------------------------------------------
    // When SSL verification is disabled we use a custom HTTPS client that
    // accepts any certificate.
    if (!request.verifySsl) {
      final badCertClient = HttpClient()
        ..badCertificateCallback = (_, __, ___) => true;

      // Apply proxy to the bad-cert client if configured.
      if (request.useProxy &&
          request.proxyHost != null &&
          request.proxyHost!.isNotEmpty) {
        final proxyPort = request.proxyPort ?? 8080;
        final proxyType = request.proxyType?.name ?? 'http';
        badCertClient.findProxy = (uri) =>
            'PROXY ${request.proxyHost}:$proxyPort';
      }

      dio.httpClientAdapter = IOHttpClientAdapter(createHttpClient: () {
        return badCertClient;
      });
    }

    // -- Proxy (only when SSL verification IS enabled) -------------------------
    if (request.verifySsl &&
        request.useProxy &&
        request.proxyHost != null &&
        request.proxyHost!.isNotEmpty) {
      final proxyPort = request.proxyPort ?? 8080;
      final proxyType = request.proxyType?.name ?? 'http';
      final proxyUrl = '$proxyType://${request.proxyHost}:$proxyPort';
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.findProxy = (uri) => 'PROXY ${request.proxyHost}:$proxyPort';
          return client;
        },
      );
    }

    // -- Validate status codes (allow all, the caller decides) -----------------
    dio.options.validateStatus = (_) => true;

    // -- Response type – always receive as a string for consistent handling ----
    dio.options.responseType = ResponseType.plain;

    return dio;
  }

  // ---------------------------------------------------------------------------
  // Private helpers – Body construction
  // ---------------------------------------------------------------------------

  /// Builds the request body based on the [BodyType] of the [request].
  ///
  /// Returns `null` for [BodyType.none], a [FormData] for
  /// [BodyType.formData], a [String] or [Map] for [BodyType.raw], etc.
  dynamic _buildRequestBody(ApiRequest request, Map<String, String> variables) {
    switch (request.bodyType) {
      case BodyType.none:
        return null;

      case BodyType.formData:
        // Build multipart/form-data from the enabled key-value entries.
        final formData = FormData();
        for (final kv in request.formDataItems) {
          if (kv.key.isEmpty) continue;

          final resolvedKey = _substituteVariables(kv.key, variables);
          final resolvedValue = _substituteVariables(kv.value, variables);

          // Heuristic: if the value looks like a file path, try to attach
          // it as a file. Otherwise send as a text field.
          if (_looksLikeFilePath(resolvedValue) &&
              File(resolvedValue).existsSync()) {
            formData.files.add(
              MapEntry(
                resolvedKey,
                MultipartFile.fromFileSync(resolvedValue),
              ),
            );
          } else {
            formData.fields.add(MapEntry(resolvedKey, resolvedValue));
          }
        }
        return formData;

      case BodyType.urlEncoded:
        // Build a simple key-value map for URL-encoded body.
        final map = <String, dynamic>{};
        for (final kv in request.formDataItems) {
          if (kv.key.isEmpty) continue;
          map[_substituteVariables(kv.key, variables)] =
              _substituteVariables(kv.value, variables);
        }
        return map;

      case BodyType.raw:
        // Raw text body (JSON, XML, plain text, etc.).
        // Variables have already been substituted in the calling method.
        final raw = request.bodyContent ?? '';
        if (raw.isEmpty) return null;

        // Try to parse as JSON and send as a map/list, falling back to
        // the raw string if parsing fails.
        try {
          final decoded = json.decode(raw);
          return decoded;
        } catch (_) {
          return raw;
        }

      case BodyType.binary:
        // Read the binary file and send it as a MultipartFile.
        final path = request.binaryFilePath;
        if (path == null || path.isEmpty || !File(path).existsSync()) {
          return null;
        }
        final file = File(path);
        final fileName = path.split(Platform.pathSeparator).last;
        return MultipartFile.fromFileSync(
          path,
          filename: fileName,
        );
    }
  }

  /// Determines the appropriate Content-Type header value based on the
  /// body type and whether the caller has already set one.
  ///
  /// Returns `null` when the body type is [BodyType.none] or
  /// [BodyType.formData] (Dio sets it automatically for multipart).
  String? _resolveContentType(ApiRequest request, dynamic body) {
    // Don't override if the user already set a Content-Type header.
    final hasExplicitContentType = request.headers.any(
      (kv) => kv.isEnabled && kv.key.toLowerCase() == 'content-type',
    );

    if (hasExplicitContentType) {
      return null; // let the user's header through.
    }

    switch (request.bodyType) {
      case BodyType.none:
        return null;
      case BodyType.formData:
        // Dio sets the multipart boundary automatically.
        return null;
      case BodyType.urlEncoded:
        return 'application/x-www-form-urlencoded';
      case BodyType.raw:
        // Try to detect JSON; default to text/plain.
        final raw = request.bodyContent ?? '';
        if (raw.trimLeft().startsWith('{') ||
            raw.trimLeft().startsWith('[')) {
          return 'application/json';
        }
        if (raw.trimLeft().startsWith('<')) {
          return 'application/xml';
        }
        return 'text/plain';
      case BodyType.binary:
        // Dio will set the content-type based on the MultipartFile.
        return null;
    }
  }

  /// Dispatches the call to the correct [ApiService] method based on the
  /// HTTP method enum.
  Future<Response> _executeMethod(
    ApiService apiService,
    HttpMethod method,
    String url, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    dynamic body,
  }) {
    switch (method) {
      case HttpMethod.get:
        return apiService.get(url,
            queryParameters: queryParameters, headers: headers);
      case HttpMethod.post:
        return apiService.post(url,
            body: body,
            queryParameters: queryParameters,
            headers: headers);
      case HttpMethod.put:
        return apiService.put(url,
            body: body,
            queryParameters: queryParameters,
            headers: headers);
      case HttpMethod.patch:
        return apiService.patch(url,
            body: body,
            queryParameters: queryParameters,
            headers: headers);
      case HttpMethod.delete:
        return apiService.delete(url,
            body: body,
            queryParameters: queryParameters,
            headers: headers);
      case HttpMethod.head:
        return apiService.head(url,
            queryParameters: queryParameters, headers: headers);
      case HttpMethod.options:
        return apiService.options(url,
            body: body,
            queryParameters: queryParameters,
            headers: headers);
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers – Utilities
  // ---------------------------------------------------------------------------

  /// Simple heuristic to determine if a string value looks like a file
  /// path (starts with `/`, `./`, `../`, or a drive letter on Windows).
  static bool _looksLikeFilePath(String value) {
    if (value.isEmpty) return false;
    return value.startsWith('/') ||
        value.startsWith('./') ||
        value.startsWith('../') ||
        (value.length >= 2 && value[1] == ':'); // Windows drive letter
  }

  /// Generates a UUID v4 string.
  ///
  /// This avoids pulling in an external UUID package just for IDs.
  static String _generateUuid() {
    // Note: In production you may want to use `package:uuid` for
    // proper RFC 4122 compliance. This implementation is sufficient
    // for local-only IDs where cryptographic uniqueness is not required.
    final now = DateTime.now().microsecondsSinceEpoch;
    final random =
        (now ^ (now << 12)).toRadixString(16).padLeft(8, '0');
    return '${random.substring(0, 8)}-${random.substring(2, 6)}-4${random.substring(4, 7)}-${random.substring(0, 4)}-${random.substring(4, 16)}'.substring(0, 36);
  }
}
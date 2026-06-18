/// @file api_request.dart
/// @brief Domain entity representing a configurable HTTP request.
///
/// This is the core entity of the API Tester application. It encapsulates
/// all configurable aspects of an HTTP request including method, URL,
/// headers, query parameters, body, proxy settings, and more.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

import 'form_data_item.dart';
import 'key_value_item.dart';
import 'proxy_settings.dart';

part 'api_request.freezed.dart';
part 'api_request.g.dart';

/// The HTTP method for a request.
enum HttpMethod {
  /// HTTP GET method - retrieve a resource.
  @JsonValue('GET')
  get,

  /// HTTP POST method - create a resource or submit data.
  @JsonValue('POST')
  post,

  /// HTTP PUT method - replace a resource entirely.
  @JsonValue('PUT')
  put,

  /// HTTP PATCH method - partially update a resource.
  @JsonValue('PATCH')
  patch,

  /// HTTP DELETE method - remove a resource.
  @JsonValue('DELETE')
  delete,

  /// HTTP HEAD method - retrieve only response headers.
  @JsonValue('HEAD')
  head,

  /// HTTP OPTIONS method - retrieve allowed methods (CORS preflight).
  @JsonValue('OPTIONS')
  options,
}

/// The type of request body to send.
enum BodyType {
  /// No request body.
  @JsonValue('none')
  none,

  /// Multipart/form-data with text and file fields.
  @JsonValue('formData')
  formData,

  /// application/x-www-form-urlencoded encoded body.
  @JsonValue('urlEncoded')
  urlEncoded,

  /// Raw body (JSON, XML, text, etc.).
  @JsonValue('raw')
  raw,

  /// Binary file upload.
  @JsonValue('binary')
  binary,
}

/// The proxy protocol type for per-request proxy configuration.
enum RequestProxyType {
  /// Standard HTTP/HTTPS proxy.
  @JsonValue('http')
  http,

  /// SOCKS5 proxy protocol.
  @JsonValue('socks5')
  socks5,
}

/// A fully configurable HTTP request entity.
///
/// Contains every aspect needed to execute an HTTP request, from the
/// basic URL and method to advanced features like proxy configuration,
/// pre-request scripts, and SSL verification settings.
@freezed
class ApiRequest with _$ApiRequest {
  /// Creates a new [ApiRequest] instance with all configuration.
  ///
  /// [id] - Unique identifier (UUID format).
  /// [workspaceId] - The workspace this request belongs to.
  /// [collectionId] - Optional collection this request is part of.
  /// [name] - Human-readable name for the request.
  /// [description] - Optional description of what the request does.
  /// [method] - The HTTP method to use. Defaults to GET.
  /// [url] - The full request URL (may contain environment variables).
  /// [headers] - List of HTTP headers to send with the request.
  /// [queryParams] - List of query parameters to append to the URL.
  /// [bodyType] - The type of body to include in the request.
  /// [bodyContent] - Raw body content string.
  /// [formDataItems] - Multipart form data items (when bodyType is formData).
  /// [binaryFilePath] - Path to a binary file (when bodyType is binary).
  /// [preRequestScript] - Optional script to execute before sending.
  /// [useProxy] - Whether to route this request through a proxy.
  /// [proxyHost] - Proxy server hostname or IP address.
  /// [proxyPort] - Proxy server port number.
  /// [proxyType] - The proxy protocol to use.
  /// [timeoutSeconds] - Request timeout in seconds. Defaults to 30.
  /// [followRedirects] - Whether to follow HTTP redirects. Defaults to true.
  /// [verifySsl] - Whether to verify SSL certificates. Defaults to true.
  /// [createdAt] - Timestamp when this request was first created.
  /// [updatedAt] - Timestamp when this request was last modified.
  const factory ApiRequest({
    required String id,
    required String workspaceId,
    String? collectionId,
    required String name,
    @Default('') String description,
    @Default(HttpMethod.get) HttpMethod method,
    required String url,
    @Default([]) List<KeyValueItem> headers,
    @Default([]) List<KeyValueItem> queryParams,
    @Default(BodyType.none) BodyType bodyType,
    @Default('') String bodyContent,
    @Default([]) List<FormDataItem> formDataItems,
    String? binaryFilePath,
    String? preRequestScript,
    @Default(false) bool useProxy,
    @Default('') String proxyHost,
    @Default(8080) int proxyPort,
    @Default(RequestProxyType.http) RequestProxyType proxyType,
    @Default(30) int timeoutSeconds,
    @Default(true) bool followRedirects,
    @Default(true) bool verifySsl,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _ApiRequest;

  /// Deserializes an [ApiRequest] from a JSON map.
  factory ApiRequest.fromJson(Map<String, dynamic> json) =>
      _$ApiRequestFromJson(json);
}

/// Extension that provides a human-readable display name for each [BodyType].
extension BodyTypeX on BodyType {
  /// A short user-facing label.
  String get label => switch (this) {
        BodyType.none       => 'None',
        BodyType.formData   => 'Form Data',
        BodyType.urlEncoded => 'URL Encoded',
        BodyType.raw        => 'Raw',
        BodyType.binary     => 'Binary',
      };

  /// Serialises the enum to the string value stored in the database.
  String toDbString() => name;

  /// Deserialises a database string back to a [BodyType].
  static BodyType fromDbString(String value) {
    return BodyType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => BodyType.none,
    );
  }
}
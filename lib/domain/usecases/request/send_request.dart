/// @file send_request.dart
/// @brief Use case for sending an HTTP request with environment variable resolution.
///
/// Orchestrates the full request execution pipeline:
/// 1. Resolves environment variables in URL, headers, and body.
/// 2. Merges global proxy settings if the request doesn't have its own proxy.
/// 3. Delegates actual HTTP execution to the repository.
/// 4. Returns the complete [ApiResponse].
library;

import '../../entities/api_request.dart';
import '../../entities/api_response.dart';
import '../../entities/app_settings.dart';
import '../../entities/proxy_settings.dart';
import '../../repositories/environment_repository.dart';
import '../../repositories/request_repository.dart';
import '../../repositories/settings_repository.dart';
import '../usecase.dart';

/// Parameters required to send a request.
class SendRequestParams {
  /// The fully configured request to send.
  /// Environment variables do not need to be pre-resolved;
  /// this use case handles resolution automatically.
  final ApiRequest request;

  /// Creates parameter object for sending a request.
  ///
  /// [request] - The API request entity to execute.
  const SendRequestParams({required this.request});
}

/// Sends an HTTP request after resolving environment variables and applying proxy settings.
///
/// This is the primary use case for executing a single request. It integrates
/// with the environment repository for variable substitution and the settings
/// repository for global proxy configuration.
class SendRequest extends UseCase<ApiResponse, SendRequestParams> {
  /// Repository for executing HTTP requests.
  final RequestRepository _requestRepository;

  /// Repository for resolving environment variables.
  final EnvironmentRepository _environmentRepository;

  /// Repository for reading global app settings (e.g., proxy).
  final SettingsRepository _settingsRepository;

  /// Creates a new [SendRequest] use case.
  SendRequest(
    this._requestRepository,
    this._environmentRepository,
    this._settingsRepository,
  );

  /// Resolves variables, applies proxy settings, and sends the request.
  ///
  /// [params] - Contains the request to execute.
  ///
  /// Returns the [ApiResponse] from the server.
  @override
  Future<ApiResponse> call(SendRequestParams params) async {
    final request = params.request;

    // Step 1: Resolve environment variables in all text fields.
    final resolvedUrl = await _environmentRepository.resolveVariables(
      request.workspaceId,
      request.url,
    );

    // Resolve variables in each enabled header.
    final resolvedHeaders = await Future.wait(
      request.headers.where((h) => h.isEnabled).map((h) async {
        final resolvedKey = await _environmentRepository.resolveVariables(
          request.workspaceId,
          h.key,
        );
        final resolvedValue = await _environmentRepository.resolveVariables(
          request.workspaceId,
          h.value,
        );
        return h.copyWith(key: resolvedKey, value: resolvedValue);
      }),
    );

    // Resolve variables in query parameters.
    final resolvedQueryParams = await Future.wait(
      request.queryParams.where((q) => q.isEnabled).map((q) async {
        final resolvedKey = await _environmentRepository.resolveVariables(
          request.workspaceId,
          q.key,
        );
        final resolvedValue = await _environmentRepository.resolveVariables(
          request.workspaceId,
          q.value,
        );
        return q.copyWith(key: resolvedKey, value: resolvedValue);
      }),
    );

    // Resolve variables in the raw body content.
    String resolvedBody = request.bodyContent;
    if (request.bodyType == BodyType.raw) {
      resolvedBody = await _environmentRepository.resolveVariables(
        request.workspaceId,
        request.bodyContent,
      );
    }

    // Step 2: Build the updated request with resolved values.
    var resolvedRequest = request.copyWith(
      url: resolvedUrl,
      headers: resolvedHeaders,
      queryParams: resolvedQueryParams,
      bodyContent: resolvedBody,
    );

    // Step 3: If request doesn't use its own proxy, apply global proxy from settings.
    if (!request.useProxy) {
      final settings = await _settingsRepository.getAppSettings();
      if (settings.globalProxy != null && settings.globalProxy!.enabled) {
        final proxy = settings.globalProxy!;
        resolvedRequest = resolvedRequest.copyWith(
          useProxy: true,
          proxyHost: proxy.host,
          proxyPort: proxy.port,
          proxyType: proxy.type == ProxyType.http
              ? RequestProxyType.http
              : RequestProxyType.socks5,
        );
      }
    }

    // Step 4: Execute the request via the repository.
    return _requestRepository.sendRequest(resolvedRequest);
  }
}
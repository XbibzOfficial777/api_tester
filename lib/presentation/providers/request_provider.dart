/// @file request_provider.dart
/// @brief Riverpod providers for building, editing, and sending API requests.
///
/// Splits the request UI state into two concerns:
///   1. **Request list** – loaded from the repository, filtered by the
///      currently selected workspace.
///   2. **Current request form** – a mutable [RequestFormState] that the
///      request-builder UI mutates in real-time.
///
/// Additionally manages:
///   - The latest [ApiResponse] (for the response panel).
///   - A loading flag (for the send-button spinner).
///   - A send callback that wires up the [SendRequest] use case.
///   - Recent endpoint URLs for autocomplete.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:api_tester/core/di/injection.dart';
import 'package:api_tester/domain/entities/api_request.dart';
import 'package:api_tester/domain/entities/api_response.dart';
import 'package:api_tester/domain/entities/form_data_item.dart';
import 'package:api_tester/domain/entities/key_value_item.dart';
import 'package:api_tester/domain/entities/proxy_settings.dart' as proxy_entity;
import 'package:api_tester/domain/repositories/environment_repository.dart';
import 'package:api_tester/domain/repositories/request_repository.dart';
import 'package:api_tester/domain/repositories/settings_repository.dart';
import 'package:api_tester/domain/usecases/request/send_request.dart';
import 'package:api_tester/presentation/providers/workspace_provider.dart';

// ---------------------------------------------------------------------------
// Request Form State
// ---------------------------------------------------------------------------

/// Immutable state object that represents every field of the request form.
///
/// The UI mutates this through the [RequestFormNotifier] methods. Each
/// mutation produces a new state instance, keeping the change history
/// visible to Riverpod's rebuild system.
class RequestFormState {
  /// HTTP method (GET, POST, etc.).
  final HttpMethod method;

  /// The request URL – may contain {{variable}} placeholders.
  final String url;

  /// Ordered list of HTTP headers.
  final List<KeyValueItem> headers;

  /// Ordered list of query parameters.
  final List<KeyValueItem> queryParams;

  /// The body type (none, raw, form-data, url-encoded, binary).
  final BodyType bodyType;

  /// Raw body content (used when bodyType is [BodyType.raw] or [BodyType.urlEncoded]).
  final String bodyContent;

  /// Multipart form-data items (used when bodyType is [BodyType.formData]).
  final List<FormDataItem> formDataItems;

  /// Whether per-request proxy is enabled.
  final bool useProxy;

  /// Proxy host (only meaningful when [useProxy] is true).
  final String proxyHost;

  /// Proxy port.
  final int proxyPort;

  /// Proxy protocol type.
  final RequestProxyType proxyType;

  /// Request timeout in seconds.
  final int timeoutSeconds;

  /// Whether to follow HTTP 3xx redirects.
  final bool followRedirects;

  /// Whether to verify SSL certificates.
  final bool verifySsl;

  const RequestFormState({
    this.method = HttpMethod.get,
    this.url = '',
    this.headers = const [],
    this.queryParams = const [],
    this.bodyType = BodyType.none,
    this.bodyContent = '',
    this.formDataItems = const [],
    this.useProxy = false,
    this.proxyHost = '',
    this.proxyPort = 8080,
    this.proxyType = RequestProxyType.http,
    this.timeoutSeconds = 30,
    this.followRedirects = true,
    this.verifySsl = true,
  });

  /// Creates a copy with optional field overrides.
  RequestFormState copyWith({
    HttpMethod? method,
    String? url,
    List<KeyValueItem>? headers,
    List<KeyValueItem>? queryParams,
    BodyType? bodyType,
    String? bodyContent,
    List<FormDataItem>? formDataItems,
    bool? useProxy,
    String? proxyHost,
    int? proxyPort,
    RequestProxyType? proxyType,
    int? timeoutSeconds,
    bool? followRedirects,
    bool? verifySsl,
  }) {
    return RequestFormState(
      method: method ?? this.method,
      url: url ?? this.url,
      headers: headers ?? this.headers,
      queryParams: queryParams ?? this.queryParams,
      bodyType: bodyType ?? this.bodyType,
      bodyContent: bodyContent ?? this.bodyContent,
      formDataItems: formDataItems ?? this.formDataItems,
      useProxy: useProxy ?? this.useProxy,
      proxyHost: proxyHost ?? this.proxyHost,
      proxyPort: proxyPort ?? this.proxyPort,
      proxyType: proxyType ?? this.proxyType,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      followRedirects: followRedirects ?? this.followRedirects,
      verifySsl: verifySsl ?? this.verifySsl,
    );
  }
}

// ---------------------------------------------------------------------------
// Request Form Notifier
// ---------------------------------------------------------------------------

/// Manages the mutable request form state.
///
/// All methods synchronously update the state so the UI rebuilds
/// immediately. When the user taps "Send", the [sendRequestProvider]
/// reads the current form state and executes the request.
class RequestFormNotifier extends StateNotifier<RequestFormState> {
  RequestFormNotifier() : super(const RequestFormState());

  /// Generates a unique ID for new key-value items.
  static const _uuid = Uuid();

  // -- Method ---------------------------------------------------------------

  /// Sets the HTTP [method] for the current request.
  void setMethod(HttpMethod method) {
    state = state.copyWith(method: method);
  }

  // -- URL ------------------------------------------------------------------

  /// Sets the request [url].
  void setUrl(String url) {
    state = state.copyWith(url: url);
  }

  // -- Headers --------------------------------------------------------------

  /// Appends a new header row and returns its generated ID.
  ///
  /// [key] and [value] default to empty strings so the user can fill them in.
  String addHeader({String key = '', String value = ''}) {
    final id = _uuid.v4();
    final item = KeyValueItem(key: key, value: value, isEnabled: true, id: id);
    state = state.copyWith(headers: [...state.headers, item]);
    return id;
  }

  /// Removes the header at [index].
  void removeHeader(int index) {
    final updated = List<KeyValueItem>.from(state.headers)..removeAt(index);
    state = state.copyWith(headers: updated);
  }

  /// Updates the header at [index] with the given [key] and [value].
  void updateHeader(int index, {required String key, required String value}) {
    final updated = List<KeyValueItem>.from(state.headers);
    updated[index] = updated[index].copyWith(key: key, value: value);
    state = state.copyWith(headers: updated);
  }

  /// Toggles the enabled state of the header at [index].
  void toggleHeaderEnabled(int index) {
    final updated = List<KeyValueItem>.from(state.headers);
    updated[index] = updated[index].copyWith(
      isEnabled: !updated[index].isEnabled,
    );
    state = state.copyWith(headers: updated);
  }

  // -- Query Parameters -----------------------------------------------------

  /// Appends a new query parameter row.
  String addParam({String key = '', String value = ''}) {
    final id = _uuid.v4();
    final item = KeyValueItem(key: key, value: value, isEnabled: true, id: id);
    state = state.copyWith(queryParams: [...state.queryParams, item]);
    return id;
  }

  /// Removes the query parameter at [index].
  void removeParam(int index) {
    final updated = List<KeyValueItem>.from(state.queryParams)..removeAt(index);
    state = state.copyWith(queryParams: updated);
  }

  /// Updates the query parameter at [index].
  void updateParam(int index, {required String key, required String value}) {
    final updated = List<KeyValueItem>.from(state.queryParams);
    updated[index] = updated[index].copyWith(key: key, value: value);
    state = state.copyWith(queryParams: updated);
  }

  /// Toggles the enabled state of the query parameter at [index].
  void toggleParamEnabled(int index) {
    final updated = List<KeyValueItem>.from(state.queryParams);
    updated[index] = updated[index].copyWith(
      isEnabled: !updated[index].isEnabled,
    );
    state = state.copyWith(queryParams: updated);
  }

  // -- Body -----------------------------------------------------------------

  /// Sets the [BodyType] for the request.
  void setBodyType(BodyType bodyType) {
    state = state.copyWith(bodyType: bodyType);
  }

  /// Sets the raw body [content].
  void setBodyContent(String content) {
    state = state.copyWith(bodyContent: content);
  }

  // -- Form Data ------------------------------------------------------------

  /// Appends a new form-data item (text field or file upload).
  String addFormDataItem({
    String key = '',
    String value = '',
    bool isFile = false,
  }) {
    final id = _uuid.v4();
    final item = FormDataItem(
      key: key,
      value: value,
      isFile: isFile,
      id: id,
    );
    state = state.copyWith(formDataItems: [...state.formDataItems, item]);
    return id;
  }

  /// Removes the form-data item at [index].
  void removeFormDataItem(int index) {
    final updated = List<FormDataItem>.from(state.formDataItems)
      ..removeAt(index);
    state = state.copyWith(formDataItems: updated);
  }

  /// Updates the form-data item at [index].
  void updateFormDataItem(
    int index, {
    String? key,
    String? value,
    String? filePath,
    String? fileName,
    String? contentType,
  }) {
    final updated = List<FormDataItem>.from(state.formDataItems);
    final old = updated[index];
    updated[index] = FormDataItem(
      key: key ?? old.key,
      value: value ?? old.value,
      isFile: old.isFile,
      filePath: filePath ?? old.filePath,
      fileName: fileName ?? old.fileName,
      contentType: contentType ?? old.contentType,
      id: old.id,
    );
    state = state.copyWith(formDataItems: updated);
  }

  // -- Proxy ----------------------------------------------------------------

  /// Applies proxy settings from the global [proxy_entity.ProxySettings] entity.
  void setProxySettings(proxy_entity.ProxySettings? proxy) {
    if (proxy == null || !proxy.enabled) {
      state = state.copyWith(useProxy: false);
      return;
    }
    state = state.copyWith(
      useProxy: true,
      proxyHost: proxy.host,
      proxyPort: proxy.port,
      proxyType: proxy.type == proxy_entity.ProxyType.http
          ? RequestProxyType.http
          : RequestProxyType.socks5,
    );
  }

  // -- Timeout / Misc -------------------------------------------------------

  /// Sets the request timeout in seconds.
  void setTimeout(int seconds) {
    state = state.copyWith(timeoutSeconds: seconds);
  }

  /// Sets whether to follow HTTP redirects.
  void setFollowRedirects(bool follow) {
    state = state.copyWith(followRedirects: follow);
  }

  /// Sets whether to verify SSL certificates.
  void setVerifySsl(bool verify) {
    state = state.copyWith(verifySsl: verify);
  }

  // -- Load from existing request -------------------------------------------

  /// Populates the form state from a persisted [ApiRequest].
  void loadFromRequest(ApiRequest request) {
    state = RequestFormState(
      method: request.method,
      url: request.url,
      headers: request.headers,
      queryParams: request.queryParams,
      bodyType: request.bodyType,
      bodyContent: request.bodyContent,
      formDataItems: request.formDataItems,
      useProxy: request.useProxy,
      proxyHost: request.proxyHost,
      proxyPort: request.proxyPort,
      proxyType: request.proxyType,
      timeoutSeconds: request.timeoutSeconds,
      followRedirects: request.followRedirects,
      verifySsl: request.verifySsl,
    );
  }

  // -- Reset ----------------------------------------------------------------

  /// Clears the form back to default values.
  ///
  /// Optionally accepts [timeout], [followRedirects], and [verifySsl] from
  /// app settings so the defaults match the user's preferences.
  void reset({int? timeout, bool? followRedirects, bool? verifySsl}) {
    state = RequestFormState(
      timeoutSeconds: timeout ?? 30,
      followRedirects: followRedirects ?? true,
      verifySsl: verifySsl ?? true,
    );
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Manages the mutable request form state (method, URL, headers, etc.).
///
/// The request-builder UI watches this provider and sends a request via
/// [sendRequestProvider] when the user taps the send button.
final currentRequestProvider =
    StateNotifierProvider<RequestFormNotifier, RequestFormState>(
  (ref) => RequestFormNotifier(),
);

/// Holds the latest [ApiResponse] after sending a request.
///
/// `null` when no request has been sent yet or after a reset.
final responseProvider = StateProvider<ApiResponse?>((ref) => null);

/// Indicates whether a request is currently in-flight.
///
/// The send button should show a spinner when this is `true` and be
/// disabled to prevent double-submissions.
final isLoadingProvider = StateProvider<bool>((ref) => false);

/// Lists all requests belonging to the currently selected workspace.
///
/// Automatically reloads when the workspace changes. Returns an empty list
/// when no workspace is selected.
final requestListProvider =
    FutureProvider.autoDispose<List<ApiRequest>>((ref) async {
  final workspace = ref.watch(currentWorkspaceProvider);
  if (workspace == null) return [];

  final repo = getIt<RequestRepository>();
  return repo.getRequestsByWorkspace(workspace.id);
});

/// Sends the current request form and stores the response.
///
/// This is a **callback-style** provider that the UI invokes via
/// `ref.read(sendRequestProvider.notifier)`. It:
///   1. Guards against double-submission.
///   2. Sets [isLoadingProvider] to `true`.
///   3. Builds an [ApiRequest] from the current form state.
///   4. Delegates to the [SendRequest] use case (which resolves env vars
///      and applies global proxy).
///   5. Stores the [ApiResponse] in [responseProvider].
///   6. Sets [isLoadingProvider] to `false`.
///   7. Re-throws so the caller can show error messages.
final sendRequestProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    // Guard against double-submission.
    if (ref.read(isLoadingProvider)) return;

    ref.read(isLoadingProvider.notifier).state = true;

    try {
      final form = ref.read(currentRequestProvider);
      final workspace = ref.read(currentWorkspaceProvider);

      if (workspace == null) {
        throw StateError(
          'No workspace selected. Please select or create a workspace first.',
        );
      }

      if (form.url.trim().isEmpty) {
        throw ArgumentError('URL cannot be empty');
      }

      // Build the ApiRequest entity from the form state.
      final now = DateTime.now();
      final request = ApiRequest(
        id: '', // Empty ID – not yet persisted.
        workspaceId: workspace.id,
        name: '', // Name is assigned on save.
        method: form.method,
        url: form.url.trim(),
        headers: form.headers,
        queryParams: form.queryParams,
        bodyType: form.bodyType,
        bodyContent: form.bodyContent,
        formDataItems: form.formDataItems,
        useProxy: form.useProxy,
        proxyHost: form.proxyHost,
        proxyPort: form.proxyPort,
        proxyType: form.proxyType,
        timeoutSeconds: form.timeoutSeconds,
        followRedirects: form.followRedirects,
        verifySsl: form.verifySsl,
        createdAt: now,
        updatedAt: now,
      );

      // Execute the request through the use case, which resolves
      // environment variables and applies global proxy settings.
      final requestRepo = getIt<RequestRepository>();
      final envRepo = getIt<EnvironmentRepository>();
      final settingsRepo = getIt<SettingsRepository>();

      final useCase = SendRequest(requestRepo, envRepo, settingsRepo);
      final response = await useCase(SendRequestParams(request: request));

      // Store the response for the response panel.
      ref.read(responseProvider.notifier).state = response;
    } finally {
      ref.read(isLoadingProvider.notifier).state = false;
    }
  };
});

/// Provides a list of recently used endpoint URLs for autocomplete.
///
/// Reloads every time the provider is re-created (auto-dispose).
final recentEndpointsProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  final repo = getIt<RequestRepository>();
  return repo.getRecentEndpoints();
});
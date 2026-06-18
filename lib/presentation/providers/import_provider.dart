/// @file import_provider.dart
/// @brief Riverpod providers for importing API requests.
///
/// Supports three import sources:
///   - **OpenAPI / Swagger** (JSON or YAML)
///   - **Postman Collection** (v2.1 JSON)
///   - **cURL** command string
///
/// The [ImportState] tracks the import lifecycle (idle → importing →
/// complete / error) and holds the resulting list of [ApiRequest]s.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:api_tester/core/di/injection.dart';
import 'package:api_tester/domain/entities/api_request.dart';
import 'package:api_tester/domain/usecases/import/curl_import.dart';
import 'package:api_tester/domain/usecases/import/openapi_import.dart';
import 'package:api_tester/domain/usecases/import/postman_import.dart';

// ---------------------------------------------------------------------------
// Import Type
// ---------------------------------------------------------------------------

/// Supported import source formats.
enum ImportType {
  /// OpenAPI 3.x or Swagger 2.0 specification.
  openapi,

  /// Postman Collection v2.1 JSON export.
  postman,

  /// A single cURL command string.
  curl,
}

// ---------------------------------------------------------------------------
// Import State
// ---------------------------------------------------------------------------

/// Immutable snapshot of the import workflow state.
class ImportState {
  /// Whether an import operation is currently in progress.
  final bool isImporting;

  /// The source format being imported.
  final ImportType? importType;

  /// Requests successfully parsed from the import source.
  /// Populated only after a successful import.
  final List<ApiRequest> importedRequests;

  /// User-friendly error message if the import failed.
  /// `null` when there is no error.
  final String? error;

  const ImportState({
    this.isImporting = false,
    this.importType,
    this.importedRequests = const [],
    this.error,
  });

  /// Convenience getter – `true` when the import produced results.
  bool get hasResults => importedRequests.isNotEmpty;

  ImportState copyWith({
    bool? isImporting,
    ImportType? importType,
    List<ApiRequest>? importedRequests,
    String? error,
  }) {
    return ImportState(
      isImporting: isImporting ?? this.isImporting,
      importType: importType ?? this.importType,
      importedRequests: importedRequests ?? this.importedRequests,
      error: error,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// Manages the import workflow state.
///
/// Call [importOpenApi], [importPostman], or [importCurl] to start an
/// import. The notifier handles loading, error, and success states.
class ImportNotifier extends StateNotifier<ImportState> {
  ImportNotifier() : super(const ImportState());

  /// Imports requests from an OpenAPI / Swagger specification.
  ///
  /// [content] – The raw JSON or YAML string.
  /// [format] – Either `'json'` or `'yaml'`.
  /// [workspaceId] – Target workspace for imported requests.
  /// [collectionId] – Optional collection to assign requests to.
  Future<void> importOpenApi({
    required String content,
    required String format,
    required String workspaceId,
    String? collectionId,
    String? baseUrlOverride,
  }) async {
    state = state.copyWith(
      isImporting: true,
      importType: ImportType.openapi,
      error: null,
      importedRequests: [],
    );

    try {
      final useCase = OpenApiImport();
      final requests = await useCase(OpenApiImportParams(
        content: content,
        format: format,
        workspaceId: workspaceId,
        collectionId: collectionId,
        baseUrlOverride: baseUrlOverride,
      ));

      state = state.copyWith(
        isImporting: false,
        importedRequests: requests,
      );
    } catch (e) {
      state = state.copyWith(
        isImporting: false,
        error: _friendlyError(e, 'OpenAPI'),
      );
    }
  }

  /// Imports requests from a Postman Collection v2.1 JSON export.
  ///
  /// [content] – The raw JSON string of the Postman Collection.
  /// [workspaceId] – Target workspace for imported requests.
  /// [collectionId] – Optional collection to assign requests to.
  Future<void> importPostman({
    required String content,
    required String workspaceId,
    String? collectionId,
  }) async {
    state = state.copyWith(
      isImporting: true,
      importType: ImportType.postman,
      error: null,
      importedRequests: [],
    );

    try {
      final useCase = PostmanImport();
      final requests = await useCase(PostmanImportParams(
        content: content,
        workspaceId: workspaceId,
        collectionId: collectionId,
      ));

      state = state.copyWith(
        isImporting: false,
        importedRequests: requests,
      );
    } catch (e) {
      state = state.copyWith(
        isImporting: false,
        error: _friendlyError(e, 'Postman'),
      );
    }
  }

  /// Imports a single request from a cURL command string.
  ///
  /// [curlCommand] – The complete curl command as pasted by the user.
  /// [workspaceId] – Target workspace for the imported request.
  /// [collectionId] – Optional collection to assign the request to.
  Future<void> importCurl({
    required String curlCommand,
    required String workspaceId,
    String? collectionId,
  }) async {
    state = state.copyWith(
      isImporting: true,
      importType: ImportType.curl,
      error: null,
      importedRequests: [],
    );

    try {
      final useCase = CurlImport();
      final request = await useCase(CurlImportParams(
        curlCommand: curlCommand,
        workspaceId: workspaceId,
        collectionId: collectionId,
      ));

      state = state.copyWith(
        isImporting: false,
        importedRequests: [request],
      );
    } catch (e) {
      state = state.copyWith(
        isImporting: false,
        error: _friendlyError(e, 'cURL'),
      );
    }
  }

  /// Resets the import state back to idle.
  ///
  /// Should be called after the user has reviewed or dismissed the import
  /// results, or to clear an error.
  void reset() {
    state = const ImportState();
  }

  /// Converts a raw error into a user-friendly message.
  String _friendlyError(Object error, String source) {
    if (error is FormatException) {
      return 'Invalid $source format: ${error.message}';
    }
    return 'Failed to import from $source: $error';
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Provides the import workflow state.
///
/// Watch this to show import progress, results, or errors in the UI.
final importStateProvider =
    StateNotifierProvider<ImportNotifier, ImportState>(
  (ref) => ImportNotifier(),
);
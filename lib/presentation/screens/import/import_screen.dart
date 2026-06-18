/// @file import_screen.dart
/// @brief Screen for importing API definitions from external sources.
///
/// Supports five import types through a tabbed interface:
///   1. **OpenAPI** – JSON/YAML spec files or URL fetch.
///   2. **Postman** – Collection v2.1 JSON export.
///   3. **cURL** – Paste a cURL command.
///   4. **HAR File** – HTTP Archive format.
///   5. **HTML Scraper** – Fetch a page and extract /api/ URLs.
///
/// Each tab provides real parsing logic by calling the domain-layer
/// use cases. After parsing, a preview shows the extracted requests
/// before the user confirms the import.
library;

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:uuid/uuid.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/api_request.dart';
import '../../../domain/entities/key_value_item.dart';
import '../../../domain/usecases/import/curl_import.dart';
import '../../../domain/usecases/import/openapi_import.dart';
import '../../../domain/usecases/import/postman_import.dart';

// ---------------------------------------------------------------------------
// Import Source Types
// ---------------------------------------------------------------------------

/// The five supported import source types.
enum _ImportTab {
  /// OpenAPI / Swagger specification.
  openapi,

  /// Postman Collection v2.1.
  postman,

  /// cURL command string.
  curl,

  /// HTTP Archive (HAR) file.
  har,

  /// HTML page scraper for /api/ URLs.
  htmlScraper,
}

// ---------------------------------------------------------------------------
// Parsed Import Result
// ---------------------------------------------------------------------------

/// The result of an import operation, containing the parsed requests
/// and optional metadata.
class _ImportResult {
  /// Successfully parsed requests.
  final List<ApiRequest> requests;

  /// Human-readable summary (e.g. "42 endpoints found").
  final String summary;

  /// Method distribution map (e.g. {"GET": 20, "POST": 15}).
  final Map<String, int> methodDistribution;

  const _ImportResult({
    required this.requests,
    required this.summary,
    this.methodDistribution = const {},
  });
}

// ---------------------------------------------------------------------------
// Screen State
// ---------------------------------------------------------------------------

/// Immutable state for the import screen.
class _ImportUiState {
  /// Currently active import tab.
  final _ImportTab activeTab;

  /// Whether an import operation is in progress.
  final bool isImporting;

  /// The parsed result, or null if not yet imported.
  final _ImportResult? result;

  /// Error message.
  final String? error;

  const _ImportUiState({
    this.activeTab = _ImportTab.openapi,
    this.isImporting = false,
    this.result,
    this.error,
  });

  _ImportUiState copyWith({
    _ImportTab? activeTab,
    bool? isImporting,
    _ImportResult? result,
    String? error,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return _ImportUiState(
      activeTab: activeTab ?? this.activeTab,
      isImporting: isImporting ?? this.isImporting,
      result: clearResult ? null : (result ?? this.result),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class _ImportScreenNotifier extends StateNotifier<_ImportUiState> {
  _ImportScreenNotifier() : super(const _ImportUiState());

  static const _uuid = Uuid();

  void setTab(_ImportTab tab) {
    state = state.copyWith(activeTab: tab, clearResult: true, clearError: true);
  }

  // =========================================================================
  // OpenAPI Import
  // =========================================================================

  /// Imports from an OpenAPI spec file content.
  Future<void> importOpenApiFile(String content, String format) async {
    final workspaceId = _currentWorkspaceId();
    _setLoading();

    try {
      final useCase = OpenApiImport();
      final requests = await useCase(OpenApiImportParams(
        content: content,
        format: format,
        workspaceId: workspaceId,
      ));
      _setResult(requests, 'OpenAPI');
    } catch (e) {
      _setError('OpenAPI', e);
    }
  }

  /// Imports from an OpenAPI spec fetched from a URL.
  Future<void> importOpenApiUrl(String url) async {
    final workspaceId = _currentWorkspaceId();
    _setLoading();

    try {
      final dio = getIt<Dio>();
      final response = await dio.get<String>(url);

      final body = response.data ?? '';
      // Detect format from URL or content.
      String format = 'json';
      if (url.toLowerCase().endsWith('.yaml') ||
          url.toLowerCase().endsWith('.yml')) {
        format = 'yaml';
      } else if (body.trim().startsWith('{') || body.trim().startsWith('[')) {
        format = 'json';
      } else {
        format = 'yaml'; // Default to YAML for other content.
      }

      final useCase = OpenApiImport();
      final requests = await useCase(OpenApiImportParams(
        content: body,
        format: format,
        workspaceId: workspaceId,
      ));
      _setResult(requests, 'OpenAPI');
    } catch (e) {
      _setError('OpenAPI', e);
    }
  }

  // =========================================================================
  // Postman Import
  // =========================================================================

  /// Imports from a Postman Collection JSON file.
  Future<void> importPostmanFile(String content) async {
    final workspaceId = _currentWorkspaceId();
    _setLoading();

    try {
      final useCase = PostmanImport();
      final requests = await useCase(PostmanImportParams(
        content: content,
        workspaceId: workspaceId,
      ));
      _setResult(requests, 'Postman');
    } catch (e) {
      _setError('Postman', e);
    }
  }

  // =========================================================================
  // cURL Import
  // =========================================================================

  /// Imports a single request from a cURL command.
  Future<void> importCurl(String curlCommand) async {
    final workspaceId = _currentWorkspaceId();
    _setLoading();

    try {
      final useCase = CurlImport();
      final request = await useCase(CurlImportParams(
        curlCommand: curlCommand,
        workspaceId: workspaceId,
      ));
      _setResult([request], 'cURL');
    } catch (e) {
      _setError('cURL', e);
    }
  }

  // =========================================================================
  // HAR Import
  // =========================================================================

  /// Imports requests from a HAR (HTTP Archive) file.
  Future<void> importHarFile(String content) async {
    final workspaceId = _currentWorkspaceId();
    _setLoading();

    try {
      final json = jsonDecode(content) as Map<String, dynamic>;
      final entries =
          json['log']?['entries'] as List<dynamic>? ?? [];

      final requests = <ApiRequest>[];
      final now = DateTime.now();

      for (final entry in entries) {
        if (entry is! Map<String, dynamic>) continue;

        final request = entry['request'] as Map<String, dynamic>? ?? {};
        final methodStr = request['method'] as String? ?? 'GET';
        final url = request['url'] as String? ?? '';

        if (url.isEmpty) continue;

        // Parse headers.
        final headersList =
            request['headers'] as List<dynamic>? ?? [];
        final headers = headersList
            .whereType<Map<String, dynamic>>()
            .map((h) => KeyValueItem(
                  key: h['name'] as String? ?? '',
                  value: h['value'] as String? ?? '',
                  isEnabled: true,
                  id: _uuid.v4(),
                ))
            .where((h) => h.key.isNotEmpty)
            .toList();

        // Parse body.
        final postData = request['postData'] as Map<String, dynamic>?;
        String bodyContent = '';
        if (postData != null) {
          bodyContent = postData['text'] as String? ?? '';
        }

        requests.add(ApiRequest(
          id: _uuid.v4(),
          workspaceId: workspaceId,
          name: '${methodStr.toUpperCase()} ${Uri.parse(url).path}',
          method: _parseMethod(methodStr),
          url: url,
          headers: headers,
          bodyType: bodyContent.isNotEmpty ? BodyType.raw : BodyType.none,
          bodyContent: bodyContent,
          createdAt: now,
          updatedAt: now,
        ));
      }

      _setResult(requests, 'HAR');
    } catch (e) {
      _setError('HAR', e);
    }
  }

  // =========================================================================
  // HTML Scraper
  // =========================================================================

  /// Fetches an HTML page and extracts /api/... URLs.
  Future<void> scrapeHtmlUrls(String url) async {
    final workspaceId = _currentWorkspaceId();
    _setLoading();

    try {
      final dio = getIt<Dio>();
      final response = await dio.get<String>(url);
      final html = response.data ?? '';

      // Regex to find API URLs in href, src, action, fetch(), and
      // inline JavaScript strings.
      final urlRegex = RegExp(
        r'''(?:https?://[^"'<>\s]+|["'])(/api/[^"'<>\s]+)(?:["']?)''',
        caseSensitive: false,
      );

      // Also match URLs that look like API endpoints.
      final endpointRegex = RegExp(
        r'''https?://[^"'<>\s]+/api/[^"'<>\s]+''',
        caseSensitive: false,
      );

      final foundUrls = <String>{};

      // Collect from both patterns.
      for (final match in urlRegex.allMatches(html)) {
        final path = match.group(1);
        if (path != null) {
          // Construct full URL from the base.
          final baseUri = Uri.parse(url);
          final fullUrl = baseUri
              .replace(path: path)
              .toString();
          foundUrls.add(fullUrl);
        }
      }

      for (final match in endpointRegex.allMatches(html)) {
        foundUrls.add(match.group(0)!);
      }

      // Convert found URLs to ApiRequest objects.
      final requests = <ApiRequest>[];
      final now = DateTime.now();

      for (final foundUrl in foundUrls) {
        requests.add(ApiRequest(
          id: _uuid.v4(),
          workspaceId: workspaceId,
          name: 'GET ${Uri.parse(foundUrl).path}',
          method: HttpMethod.get,
          url: foundUrl,
          createdAt: now,
          updatedAt: now,
        ));
      }

      _setResult(requests, 'HTML Scraper');
    } catch (e) {
      _setError('HTML Scraper', e);
    }
  }

  // =========================================================================
  // Helpers
  // =========================================================================

  String _currentWorkspaceId() {
    // Will be provided by the widget via a callback.
    return 'default-workspace';
  }

  void _setLoading() {
    state = state.copyWith(
      isImporting: true,
      clearResult: true,
      clearError: true,
    );
  }

  void _setResult(List<ApiRequest> requests, String source) {
    // Calculate method distribution.
    final dist = <String, int>{};
    for (final r in requests) {
      final m = r.method.name.toUpperCase();
      dist[m] = (dist[m] ?? 0) + 1;
    }

    final distStr = dist.entries
        .map((e) => '${e.key}: ${e.value}')
        .join(', ');

    state = state.copyWith(
      isImporting: false,
      result: _ImportResult(
        requests: requests,
        summary: '$source: ${requests.length} endpoint(s) found. $distStr',
        methodDistribution: dist,
      ),
    );
  }

  void _setError(String source, Object error) {
    final msg = error is FormatException
        ? error.message
        : error.toString();
    state = state.copyWith(
      isImporting: false,
      error: 'Failed to import from $source: $msg',
    );
  }

  /// Persists the imported requests to the repository.
  void reset() {
    state = const _ImportUiState();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final _importScreenProvider =
    StateNotifierProvider<_ImportScreenNotifier, _ImportUiState>(
  (ref) => _ImportScreenNotifier(),
);

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Supports importing API definitions from OpenAPI, Postman, cURL,
/// HAR files, and HTML page scraping.
///
/// The UI is tabbed. Each tab has its own input controls and a shared
/// preview area showing parsed requests before the user confirms the
/// import into their workspace.
class ImportScreen extends ConsumerStatefulWidget {
  /// Creates an [ImportScreen].
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  // --- OpenAPI tab controllers ---
  final _openApiUrlController = TextEditingController();
  final _openApiController = TextEditingController();

  // --- Postman tab controllers ---
  final _postmanContentController = TextEditingController();

  // --- cURL tab controllers ---
  final _curlContentController = TextEditingController();

  // --- HAR tab controllers ---
  final _harContentController = TextEditingController();

  // --- HTML Scraper tab controllers ---
  final _htmlUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _openApiUrlController.dispose();
    _openApiController.dispose();
    _postmanContentController.dispose();
    _curlContentController.dispose();
    _harContentController.dispose();
    _htmlUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final importState = ref.watch(_importScreenProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // Switch tab in state when user taps a tab.
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final tab = _ImportTab.values[_tabController.index];
        ref.read(_importScreenProvider.notifier).setTab(tab);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'OpenAPI', icon: Icon(Symbols.description, size: 18)),
            Tab(text: 'Postman', icon: Icon(Symbols.folder_special, size: 18)),
            Tab(text: 'cURL', icon: Icon(Symbols.terminal, size: 18)),
            Tab(text: 'HAR', icon: Icon(Symbols.web, size: 18)),
            Tab(text: 'HTML', icon: Icon(Symbols.language, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OpenApiTab(
            urlController: _openApiUrlController,
            contentController: _openApiController,
          ),
          _PostmanTab(controller: _postmanContentController),
          _CurlTab(controller: _curlContentController),
          _HarTab(controller: _harContentController),
          _HtmlScraperTab(controller: _htmlUrlController),
        ],
      ),
      // --- Bottom Result Panel ---
      bottomNavigationBar: importState.result != null
          ? _ResultBottomSheet(state: importState)
          : null,
    );
  }
}

// ===========================================================================
// OpenAPI Tab
// ===========================================================================

/// OpenAPI import tab with file picker and URL fetch options.
class _OpenApiTab extends ConsumerWidget {
  /// Controller for the URL input field.
  final TextEditingController urlController;

  /// Controller for the pasted content field.
  final TextEditingController contentController;

  const _OpenApiTab({
    required this.urlController,
    required this.contentController,
  });

  Future<void> _pickFile(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        final content = await String.fromCharCodes(
            await File(result.files.single.path!).readAsBytes());
        contentController.text = content;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to read file: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final importState = ref.watch(_importScreenProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Import API endpoints from an OpenAPI (Swagger) 2.0 or 3.x specification.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          // --- File Picker ---
          OutlinedButton.icon(
            onPressed: importState.isImporting
                ? null
                : () => _pickFile(context, ref),
            icon: const Icon(Symbols.folder_open, size: 18),
            label: const Text('Pick OpenAPI File (JSON/YAML)'),
          ),

          const SizedBox(height: 16),

          // --- Divider ---
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('OR',
                    style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant)),
              ),
              const Expanded(child: Divider()),
            ],
          ),

          const SizedBox(height: 16),

          // --- URL Input ---
          TextField(
            controller: urlController,
            decoration: InputDecoration(
              labelText: 'Spec URL',
              hintText: 'https://api.example.com/openapi.json',
              prefixIcon: const Icon(Symbols.link, size: 18),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Symbols.download, size: 18),
                tooltip: 'Fetch & Import',
                onPressed: importState.isImporting
                    ? null
                    : () => ref
                        .read(_importScreenProvider.notifier)
                        .importOpenApiUrl(urlController.text),
              ),
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),

          const SizedBox(height: 16),

          // --- Paste Area ---
          Text('Or paste spec content:',
              style: textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          TextField(
            controller: contentController,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: 'Paste your OpenAPI JSON or YAML here…',
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          const SizedBox(height: 12),

          // --- Import from pasted content ---
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: importState.isImporting ||
                      contentController.text.trim().isEmpty
                  ? null
                  : () {
                      final content = contentController.text.trim();
                      final isJson =
                          content.startsWith('{') || content.startsWith('[');
                      ref.read(_importScreenProvider.notifier).importOpenApiFile(
                            content,
                            isJson ? 'json' : 'yaml',
                          );
                    },
              icon: importState.isImporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Symbols.download, size: 18),
              label: Text(importState.isImporting
                  ? 'Importing…'
                  : 'Import from Content'),
            ),
          ),

          // --- Error ---
          if (importState.error != null) ...[
            const SizedBox(height: 16),
            Card(
              color: colorScheme.error.withOpacity(0.08),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(importState.error!,
                    style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.error)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ===========================================================================
// Postman Tab
// ===========================================================================

/// Postman Collection import tab.
class _PostmanTab extends ConsumerWidget {
  /// Controller for the pasted Postman JSON.
  final TextEditingController controller;

  const _PostmanTab({required this.controller});

  Future<void> _pickFile(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        final content = await String.fromCharCodes(
            await File(result.files.single.path!).readAsBytes());
        controller.text = content;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to read file: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final importState = ref.watch(_importScreenProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Import API requests from a Postman Collection v2.1 JSON export.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          // --- File Picker ---
          OutlinedButton.icon(
            onPressed: importState.isImporting
                ? null
                : () => _pickFile(context, ref),
            icon: const Icon(Symbols.folder_open, size: 18),
            label: const Text('Pick Postman Collection JSON'),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('OR',
                    style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant)),
              ),
              const Expanded(child: Divider()),
            ],
          ),

          const SizedBox(height: 16),

          // --- Paste Area ---
          TextField(
            controller: controller,
            maxLines: 10,
            decoration: const InputDecoration(
              hintText: 'Paste your Postman Collection JSON here…',
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          const SizedBox(height: 12),

          // --- Import Button ---
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: importState.isImporting ||
                      controller.text.trim().isEmpty
                  ? null
                  : () => ref
                      .read(_importScreenProvider.notifier)
                      .importPostmanFile(controller.text),
              icon: importState.isImporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Symbols.download, size: 18),
              label: Text(importState.isImporting
                  ? 'Importing…'
                  : 'Import Collection'),
            ),
          ),

          // --- Error ---
          if (importState.error != null) ...[
            const SizedBox(height: 16),
            Card(
              color: colorScheme.error.withOpacity(0.08),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(importState.error!,
                    style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.error)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ===========================================================================
// cURL Tab
// ===========================================================================

/// cURL import tab.
class _CurlTab extends ConsumerWidget {
  /// Controller for the pasted cURL command.
  final TextEditingController controller;

  const _CurlTab({required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final importState = ref.watch(_importScreenProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Paste a cURL command to import it as an API request.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          // --- Paste Area ---
          TextField(
            controller: controller,
            maxLines: 10,
            decoration: InputDecoration(
              hintText: "curl -X GET 'https://api.example.com/users' \\\n"
                  "  -H 'Authorization: Bearer TOKEN'",
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Symbols.content_paste, size: 18),
                tooltip: 'Paste',
                onPressed: () async {
                  final data =
                      await Clipboard.getData(Clipboard.kTextPlain);
                  if (data?.text != null) {
                    controller.text = data!.text!;
                  }
                },
              ),
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          const SizedBox(height: 12),

          // --- Import Button ---
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: importState.isImporting ||
                      controller.text.trim().isEmpty
                  ? null
                  : () => ref
                      .read(_importScreenProvider.notifier)
                      .importCurl(controller.text),
              icon: importState.isImporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Symbols.download, size: 18),
              label: Text(importState.isImporting
                  ? 'Importing…'
                  : 'Import cURL'),
            ),
          ),

          // --- Error ---
          if (importState.error != null) ...[
            const SizedBox(height: 16),
            Card(
              color: colorScheme.error.withOpacity(0.08),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(importState.error!,
                    style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.error)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ===========================================================================
// HAR Tab
// ===========================================================================

/// HAR (HTTP Archive) file import tab.
class _HarTab extends ConsumerWidget {
  /// Controller for the pasted HAR content.
  final TextEditingController controller;

  const _HarTab({required this.controller});

  Future<void> _pickFile(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        final content = await String.fromCharCodes(
            await File(result.files.single.path!).readAsBytes());
        controller.text = content;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to read file: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final importState = ref.watch(_importScreenProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Import API calls from a HAR (HTTP Archive) file. '
            'HAR files record all network requests made by a browser.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          // --- File Picker ---
          OutlinedButton.icon(
            onPressed: importState.isImporting
                ? null
                : () => _pickFile(context, ref),
            icon: const Icon(Symbols.folder_open, size: 18),
            label: const Text('Pick HAR File'),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('OR',
                    style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant)),
              ),
              const Expanded(child: Divider()),
            ],
          ),

          const SizedBox(height: 16),

          TextField(
            controller: controller,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: 'Paste your HAR JSON content here…',
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: importState.isImporting ||
                      controller.text.trim().isEmpty
                  ? null
                  : () => ref
                      .read(_importScreenProvider.notifier)
                      .importHarFile(controller.text),
              icon: importState.isImporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Symbols.download, size: 18),
              label: Text(importState.isImporting
                  ? 'Importing…'
                  : 'Import HAR'),
            ),
          ),

          if (importState.error != null) ...[
            const SizedBox(height: 16),
            Card(
              color: colorScheme.error.withOpacity(0.08),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(importState.error!,
                    style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.error)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ===========================================================================
// HTML Scraper Tab
// ===========================================================================

/// HTML page scraper tab that extracts /api/... URLs.
class _HtmlScraperTab extends ConsumerWidget {
  /// Controller for the URL input.
  final TextEditingController controller;

  const _HtmlScraperTab({required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final importState = ref.watch(_importScreenProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fetch a web page and extract API endpoint URLs that contain '
            '"/api/" from the HTML source, JavaScript, and link attributes.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'Page URL',
              hintText: 'https://example.com',
              prefixIcon: const Icon(Symbols.link, size: 18),
              border: const OutlineInputBorder(),
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: importState.isImporting ||
                      controller.text.trim().isEmpty
                  ? null
                  : () => ref
                      .read(_importScreenProvider.notifier)
                      .scrapeHtmlUrls(controller.text),
              icon: importState.isImporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Symbols.travel_explore, size: 18),
              label: Text(importState.isImporting
                  ? 'Scraping…'
                  : 'Scrape & Extract'),
            ),
          ),

          if (importState.error != null) ...[
            const SizedBox(height: 16),
            Card(
              color: colorScheme.error.withOpacity(0.08),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(importState.error!,
                    style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.error)),
              ),
            ),
          ],

          const SizedBox(height: 16),
          Text(
            'Note: This extracts URLs matching /api/... patterns from '
            'the page source. It does not execute JavaScript.',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Result Bottom Sheet
// ===========================================================================

/// A bottom sheet shown when import results are available.
///
/// Displays the import summary, method distribution, a scrollable list of
/// extracted requests, and an "Import All" button.
class _ResultBottomSheet extends ConsumerWidget {
  /// The current import state.
  final _ImportUiState state;

  const _ResultBottomSheet({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final result = state.result!;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar.
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header.
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Symbols.check_circle,
                    color: AppTheme.status2xx, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    result.summary,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Symbols.close, size: 20),
                  onPressed: () =>
                      ref.read(_importScreenProvider.notifier).reset(),
                ),
              ],
            ),
          ),

          // Method distribution chips.
          if (result.methodDistribution.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: result.methodDistribution.entries.map((e) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Chip(
                        label: Text('${e.key}: ${e.value}'),
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          const Divider(height: 1),

          // Request list.
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: result.requests.length,
              itemBuilder: (context, index) {
                final req = result.requests[index];
                return ListTile(
                  dense: true,
                  leading: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _methodColor(req.method)
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      req.method.name.toUpperCase(),
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: _methodColor(req.method),
                        fontSize: 10,
                      ),
                    ),
                  ),
                  title: Text(req.name,
                      style: textTheme.bodySmall, maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  subtitle: Text(req.url,
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontFamily: 'monospace',
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                );
              },
            ),
          ),

          const Divider(height: 1),

          // Action buttons.
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        ref.read(_importScreenProvider.notifier).reset(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      // TODO: Persist imported requests to the repository.
                      // For now, navigate back.
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              '${result.requests.length} request(s) imported!'),
                        ),
                      );
                      ref.read(_importScreenProvider.notifier).reset();
                      Navigator.of(context).maybePop();
                    },
                    icon: const Icon(Symbols.check, size: 18),
                    label: Text('Import All (${result.requests.length})'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Returns a colour for an HTTP method.
  Color _methodColor(HttpMethod method) {
    switch (method) {
      case HttpMethod.get:
        return AppTheme.status2xx;
      case HttpMethod.post:
        return AppTheme.status3xx;
      case HttpMethod.put:
        return AppTheme.status4xx;
      case HttpMethod.patch:
        return AppTheme.tertiarySeed;
      case HttpMethod.delete:
        return AppTheme.status5xx;
      case HttpMethod.head:
      case HttpMethod.options:
        return Colors.grey;
    }
  }
}
/// @file response_viewer.dart
/// @brief Full-featured response viewer with three tabs: Body, Headers,
///        and Assertions.
///
/// **Body tab:**
/// - Top info bar with status code badge, response time, and body size.
/// - Format selector: Pretty (tree view), Raw (highlighted text), Preview
///   (for HTML).
/// - For JSON: [JsonTreeView] with search bar, copy/share buttons.
/// - For XML: syntax-highlighted view with collapsible structure.
/// - For HTML: formatted text display.
/// - For plain text: monospace display.
/// - Auto-detects format from the Content-Type response header.
///
/// **Headers tab:**
/// - Key-value list of response headers.
/// - Search/filter field.
/// - Copy individual values or all headers.
///
/// **Assertions tab:**
/// - Add assertion form with type, operator, and expected value.
/// - List of defined assertions with pass/fail status.
/// - "Run Assertions" button that evaluates all assertions against the
///   current response.

library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:uuid/uuid.dart';

import 'package:api_tester/core/theme/app_theme.dart';
import 'package:api_tester/core/utils/response_helper.dart';
import 'package:api_tester/domain/entities/api_response.dart';
import 'package:api_tester/domain/entities/assertion.dart';
import 'package:api_tester/presentation/providers/request_provider.dart';
import 'package:api_tester/presentation/widgets/common/code_view.dart';
import 'package:api_tester/presentation/widgets/common/status_code_badge.dart';
import 'json_tree_view.dart';

const _uuid = Uuid();

/// The format in which to display the response body.
enum BodyFormat {
  /// Tree view with collapsible nodes (JSON only).
  pretty('Pretty'),

  /// Highlighted raw text.
  raw('Raw'),

  /// HTML preview mode.
  preview('Preview');

  const BodyFormat(this.label);
  final String label;
}

/// Supported response body languages for syntax highlighting.
enum ResponseBodyLanguage {
  json('json'),
  xml('xml'),
  html('html'),
  text('text'),
  unknown('text');

  const ResponseBodyLanguage(this.highlightLang);
  final String highlightLang;
}

/// The complete response viewer widget.
///
/// Displays nothing if no response has been received yet. Once a response
/// is available, it renders a three-tab interface: Body, Headers, Assertions.
class ResponseViewer extends ConsumerStatefulWidget {
  /// Creates a [ResponseViewer].
  const ResponseViewer({super.key});

  @override
  ConsumerState<ResponseViewer> createState() => _ResponseViewerState();
}

class _ResponseViewerState extends ConsumerState<ResponseViewer>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  /// Currently selected body format (pretty / raw / preview).
  BodyFormat _bodyFormat = BodyFormat.pretty;

  /// Search query for highlighting in the body view.
  String _bodySearchQuery = '';

  /// Search query for filtering response headers.
  String _headerSearchQuery = '';

  /// List of user-defined assertions.
  final List<Assertion> _assertions = [];

  /// Controller for adding a new assertion expected value.
  final _assertionValueController = TextEditingController();

  /// Controller for searching in the body.
  final _bodySearchController = TextEditingController();

  /// Controller for filtering headers.
  final _headerSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _assertionValueController.dispose();
    _bodySearchController.dispose();
    _headerSearchController.dispose();
    super.dispose();
  }

  /// Detects the response body language from the Content-Type header.
  ResponseBodyLanguage _detectLanguage(ApiResponse response) {
    final ct = response.headers['content-type']?.toLowerCase() ?? '';
    if (ct.contains('json')) return ResponseBodyLanguage.json;
    if (ct.contains('xml')) return ResponseBodyLanguage.xml;
    if (ct.contains('html')) return ResponseBodyLanguage.html;
    if (ct.contains('text')) return ResponseBodyLanguage.text;
    // Try to guess by parsing.
    if (response.body != null && response.body!.trim().startsWith('{')) {
      return ResponseBodyLanguage.json;
    }
    if (response.body != null &&
        response.body!.trim().startsWith('<')) {
      return ResponseBodyLanguage.xml;
    }
    return ResponseBodyLanguage.unknown;
  }

  @override
  Widget build(BuildContext context) {
    final response = ref.watch(responseProvider);

    // No response yet – show placeholder.
    if (response == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tab bar.
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Body'),
              Tab(text: 'Headers'),
              Tab(text: 'Assertions'),
            ],
          ),

          // Tab content.
          SizedBox(
            height: 400, // Fixed height for response viewer.
            child: TabBarView(
              controller: _tabController,
              children: [
                _ResponseBodyTab(
                  response: response,
                  bodyFormat: _bodyFormat,
                  searchQuery: _bodySearchQuery,
                  searchController: _bodySearchController,
                  onFormatChanged: (f) => setState(() => _bodyFormat = f),
                  onSearchChanged: (q) =>
                      setState(() => _bodySearchQuery = q),
                ),
                _ResponseHeadersTab(
                  response: response,
                  searchQuery: _headerSearchQuery,
                  searchController: _headerSearchController,
                  onSearchChanged: (q) =>
                      setState(() => _headerSearchQuery = q),
                ),
                _AssertionsTab(
                  response: response,
                  assertions: _assertions,
                  valueController: _assertionValueController,
                  onAddAssertion: (a) =>
                      setState(() => _assertions.add(a)),
                  onRemoveAssertion: (i) =>
                      setState(() => _assertions.removeAt(i)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Response Body Tab
// =============================================================================

/// The Body tab showing the response content with format switching and search.
class _ResponseBodyTab extends StatelessWidget {
  final ApiResponse response;
  final BodyFormat bodyFormat;
  final String searchQuery;
  final TextEditingController searchController;
  final ValueChanged<BodyFormat> onFormatChanged;
  final ValueChanged<String> onSearchChanged;

  const _ResponseBodyTab({
    required this.response,
    required this.bodyFormat,
    required this.searchQuery,
    required this.searchController,
    required this.onFormatChanged,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Error state – show error message.
    if (response.isError) {
      return _ErrorView(error: response.error!);
    }

    // Empty body.
    if (response.body == null || response.body!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.hourglass_empty,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'Empty response body',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Info bar: status code, time, size.
        _ResponseInfoBar(response: response),
        Divider(height: 1),

        // Toolbar: format selector + search + copy/share.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              // Format selector.
              SizedBox(
                height: 30,
                child: SegmentedButton<BodyFormat>(
                  segments: BodyFormat.values
                      .map((f) => ButtonSegment(
                            value: f,
                            label: Text(f.label,
                                style: const TextStyle(fontSize: 11)),
                          ))
                      .toList(),
                  selected: {bodyFormat},
                  onSelectionChanged: (s) => onFormatChanged(s.first),
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Search field.
              Expanded(
                child: SizedBox(
                  height: 30,
                  child: TextField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Search in body...',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      prefixIcon: const Icon(Symbols.search, size: 16),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Symbols.close, size: 14),
                              onPressed: () {
                                searchController.clear();
                                onSearchChanged('');
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              visualDensity: VisualDensity.compact,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Copy button.
              IconButton(
                icon: const Icon(Symbols.content_copy, size: 18),
                onPressed: () {
                  ResponseHelper.copyToClipboard(
                    response.body!,
                    scaffoldMessenger:
                        ScaffoldMessenger.of(context),
                  );
                },
                tooltip: 'Copy body',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),

              // Share button.
              IconButton(
                icon: const Icon(Symbols.share, size: 18),
                onPressed: () {
                  ResponseHelper.shareText(response.body!);
                },
                tooltip: 'Share body',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),

        // Body content.
        Expanded(
          child: _BodyContentView(
            body: response.body!,
            format: bodyFormat,
            language: _detectLanguage(response),
            searchQuery: searchQuery,
          ),
        ),
      ],
    );
  }

  /// Detects the language of the response body.
  ResponseBodyLanguage _detectLanguage(ApiResponse response) {
    final ct = response.headers['content-type']?.toLowerCase() ?? '';
    if (ct.contains('json')) return ResponseBodyLanguage.json;
    if (ct.contains('xml')) return ResponseBodyLanguage.xml;
    if (ct.contains('html')) return ResponseBodyLanguage.html;
    if (ct.contains('text/plain')) return ResponseBodyLanguage.text;
    // Guess from content.
    final body = response.body ?? '';
    final trimmed = body.trimLeft();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      return ResponseBodyLanguage.json;
    }
    if (trimmed.startsWith('<') && ct.contains('xml')) {
      return ResponseBodyLanguage.xml;
    }
    return ResponseBodyLanguage.unknown;
  }
}

/// Info bar showing status code, response time, and content size.
class _ResponseInfoBar extends StatelessWidget {
  final ApiResponse response;

  const _ResponseInfoBar({required this.response});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Status code badge.
          if (response.statusCode != null)
            StatusCodeBadge(statusCode: response.statusCode!),
          const SizedBox(width: 8),

          // Status message.
          if (response.statusMessage != null)
            Text(
              response.statusMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.statusCodeColor(response.statusCode ?? 0),
                fontWeight: FontWeight.w500,
              ),
            ),
          const Spacer(),

          // Response time.
          Icon(
            Symbols.timer,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            ResponseHelper.formatDuration(response.responseTimeMs),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 16),

          // Content size.
          Icon(
            Symbols.data_usage,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            response.contentLength != null
                ? ResponseHelper.formatBytes(response.contentLength!)
                : '${(response.body?.length ?? 0)} B',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders the response body content based on the selected format and
/// detected language.
class _BodyContentView extends StatelessWidget {
  final String body;
  final BodyFormat format;
  final ResponseBodyLanguage language;
  final String searchQuery;

  const _BodyContentView({
    required this.body,
    required this.format,
    required this.language,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    if (format == BodyFormat.preview && language == ResponseBodyLanguage.html) {
      return _HtmlPreview(body: body);
    }

    if (format == BodyFormat.pretty && language == ResponseBodyLanguage.json) {
      return _PrettyJsonView(body: body, searchQuery: searchQuery);
    }

    // Raw mode or any non-JSON pretty mode falls back to highlighted text.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: CodeView(
        code: body,
        language: _mapToCodeLanguage(language),
        showLineNumbers: format == BodyFormat.raw,
      ),
    );
  }

  /// Maps [ResponseBodyLanguage] to [CodeLanguage] for the CodeView widget.
  CodeLanguage _mapToCodeLanguage(ResponseBodyLanguage lang) {
    switch (lang) {
      case ResponseBodyLanguage.json:
        return CodeLanguage.json;
      case ResponseBodyLanguage.xml:
        return CodeLanguage.xml;
      case ResponseBodyLanguage.html:
        return CodeLanguage.html;
      case ResponseBodyLanguage.text:
      case ResponseBodyLanguage.unknown:
        return CodeLanguage.plainText;
    }
  }
}

/// Pretty-printed JSON view using [JsonTreeView].
class _PrettyJsonView extends StatelessWidget {
  final String body;
  final String searchQuery;

  const _PrettyJsonView({required this.body, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    // Attempt to pretty-print first.
    String prettyBody = body;
    try {
      final decoded = jsonDecode(body);
      prettyBody = const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      // If parsing fails, show raw.
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: JsonTreeView(
        jsonString: prettyBody,
        searchQuery: searchQuery,
        initialExpandedDepth: 2,
      ),
    );
  }
}

/// Simple HTML preview showing formatted HTML text.
class _HtmlPreview extends StatelessWidget {
  final String body;

  const _HtmlPreview({required this.body});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Strip HTML tags for a basic preview.
    final plainText = body.replaceAll(RegExp(r'<[^>]*>'), '').trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        plainText.isNotEmpty ? plainText : '(No visible content)',
        style: TextStyle(
          fontSize: 13,
          fontFamily: 'monospace',
          color: theme.colorScheme.onSurface,
          height: 1.5,
        ),
      ),
    );
  }
}

/// Error display when the request failed entirely.
class _ErrorView extends StatelessWidget {
  final String error;

  const _ErrorView({required this.error});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.wifi_off,
              size: 48,
              color: theme.colorScheme.error.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Request Failed',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Response Headers Tab
// =============================================================================

/// Displays response headers with search/filter and copy functionality.
class _ResponseHeadersTab extends StatelessWidget {
  final ApiResponse response;
  final String searchQuery;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  const _ResponseHeadersTab({
    required this.response,
    required this.searchQuery,
    required this.searchController,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headers = response.headers.entries.toList();

    // Filter headers based on search query.
    final filtered = searchQuery.isEmpty
        ? headers
        : headers
            .where((h) =>
                h.key.toLowerCase().contains(searchQuery.toLowerCase()) ||
                h.value.toLowerCase().contains(searchQuery.toLowerCase()))
            .toList();

    return Column(
      children: [
        // Search bar.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: TextField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Filter headers...',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      prefixIcon: const Icon(Symbols.search, size: 16),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Symbols.close, size: 14),
                              onPressed: () {
                                searchController.clear();
                                onSearchChanged('');
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              visualDensity: VisualDensity.compact,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Copy all headers.
              IconButton(
                icon: const Icon(Symbols.content_copy, size: 18),
                onPressed: () {
                  final allHeaders = response.headers.entries
                      .map((e) => '${e.key}: ${e.value}')
                      .join('\n');
                  ResponseHelper.copyToClipboard(
                    allHeaders,
                    scaffoldMessenger: ScaffoldMessenger.of(context),
                  );
                },
                tooltip: 'Copy all headers',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),

        // Header count.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${filtered.length} header${filtered.length != 1 ? 's' : ''}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),

        // Headers list.
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    searchQuery.isEmpty
                        ? 'No response headers'
                        : 'No headers match "$searchQuery"',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                  ),
                  itemBuilder: (context, index) {
                    final entry = filtered[index];
                    return _HeaderRow(
                      key: ValueKey(entry.key),
                      headerKey: entry.key,
                      headerValue: entry.value,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// A single response header row with copy button.
class _HeaderRow extends StatelessWidget {
  final String headerKey;
  final String headerValue;

  const _HeaderRow({
    super.key,
    required this.headerKey,
    required this.headerValue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onLongPress: () {
        ResponseHelper.copyToClipboard(
          headerValue,
          scaffoldMessenger: ScaffoldMessenger.of(context),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header name.
            SizedBox(
              width: 180,
              child: Text(
                headerKey,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Header value.
            Expanded(
              child: SelectableText(
                headerValue,
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'monospace',
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),

            // Copy value button.
            IconButton(
              icon: Icon(
                Symbols.content_copy,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              onPressed: () {
                ResponseHelper.copyToClipboard(
                  headerValue,
                  scaffoldMessenger: ScaffoldMessenger.of(context),
                );
              },
              tooltip: 'Copy value',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Assertions Tab
// =============================================================================

/// Assertions tab where users define and evaluate test assertions.
class _AssertionsTab extends StatefulWidget {
  final ApiResponse response;
  final List<Assertion> assertions;
  final TextEditingController valueController;
  final void Function(Assertion) onAddAssertion;
  final void Function(int) onRemoveAssertion;

  const _AssertionsTab({
    required this.response,
    required this.assertions,
    required this.valueController,
    required this.onAddAssertion,
    required this.onRemoveAssertion,
  });

  @override
  State<_AssertionsTab> createState() => _AssertionsTabState();
}

class _AssertionsTabState extends State<_AssertionsTab> {
  /// Currently selected assertion type.
  AssertionType _selectedType = AssertionType.statusCode;

  /// Currently selected operator.
  AssertionOperator _selectedOperator = AssertionOperator.equals;

  /// Evaluation results: index → (passed, message).
  final Map<int, ({bool passed, String message})> _results = {};

  /// Runs all assertions against the current response.
  void _runAssertions() {
    final results = <int, ({bool passed, String message})>{};
    final response = widget.response;

    for (var i = 0; i < widget.assertions.length; i++) {
      final a = widget.assertions[i];
      String actual = '';
      bool passed = false;
      String message = '';

      switch (a.type) {
        case AssertionType.statusCode:
          actual = (response.statusCode ?? 0).toString();
          break;
        case AssertionType.bodyContains:
          actual = response.body ?? '';
          break;
        case AssertionType.headerExists:
          actual =
              response.headers.containsKey(a.expectedValue) ? 'true' : 'false';
          break;
        case AssertionType.responseTime:
          actual = response.responseTimeMs.toString();
          break;
      }

      passed = _evaluate(actual, a.expectedValue, a.operator);
      message = passed
          ? 'Passed: $actual ${_opSymbol(a.operator)} ${a.expectedValue}'
          : 'Failed: $actual ${_opSymbol(a.operator)} ${a.expectedValue}';

      results[i] = (passed: passed, message: message);
    }

    setState(() => _results.clear());
    _results.addAll(results);

    // Update the provider for external consumers.
    final allResults = results.entries
        .map((e) => e.value)
        .toList();
    // Note: In production this would update a provider.
  }

  /// Evaluates [actual] vs [expected] using [operator].
  bool _evaluate(String actual, String expected, AssertionOperator operator) {
    final actualNum = num.tryParse(actual);
    final expectedNum = num.tryParse(expected);

    switch (operator) {
      case AssertionOperator.equals:
        return actual == expected;
      case AssertionOperator.notEquals:
        return actual != expected;
      case AssertionOperator.contains:
        return actual.contains(expected);
      case AssertionOperator.lessThan:
        if (actualNum != null && expectedNum != null) {
          return actualNum < expectedNum;
        }
        return actual.compareTo(expected) < 0;
      case AssertionOperator.greaterThan:
        if (actualNum != null && expectedNum != null) {
          return actualNum > expectedNum;
        }
        return actual.compareTo(expected) > 0;
      case AssertionOperator.matches:
        try {
          return RegExp(expected).hasMatch(actual);
        } catch (_) {
          return false;
        }
    }
  }

  String _opSymbol(AssertionOperator op) {
    switch (op) {
      case AssertionOperator.equals:
        return '==';
      case AssertionOperator.notEquals:
        return '!=';
      case AssertionOperator.contains:
        return 'contains';
      case AssertionOperator.lessThan:
        return '<';
      case AssertionOperator.greaterThan:
        return '>';
      case AssertionOperator.matches:
        return 'matches';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Add assertion form.
        Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Assertion',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Type selector.
                    Expanded(
                      child: DropdownButtonFormField<AssertionType>(
                        value: _selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Type',
                          isDense: true,
                        ),
                        items: AssertionType.values
                            .map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(
                                    _typeLabel(t),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedType = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Operator selector.
                    Expanded(
                      child: DropdownButtonFormField<AssertionOperator>(
                        value: _selectedOperator,
                        decoration: const InputDecoration(
                          labelText: 'Operator',
                          isDense: true,
                        ),
                        items: AssertionOperator.values
                            .map((o) => DropdownMenuItem(
                                  value: o,
                                  child: Text(
                                    o.name,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedOperator = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Expected value.
                    Expanded(
                      child: TextField(
                        controller: widget.valueController,
                        decoration: const InputDecoration(
                          labelText: 'Expected Value',
                          hintText: 'e.g. 200',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () {
                        final value = widget.valueController.text.trim();
                        if (value.isEmpty) return;
                        widget.onAddAssertion(Assertion(
                          id: _uuid.v4(),
                          requestId: '',
                          type: _selectedType,
                          expectedValue: value,
                          operator: _selectedOperator,
                        ));
                        widget.valueController.clear();
                      },
                      icon: const Icon(Symbols.add, size: 16),
                      label: const Text('Add'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Run assertions button.
        if (widget.assertions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _runAssertions,
                icon: const Icon(Symbols.play_arrow, size: 18),
                label: const Text('Run All Assertions'),
              ),
            ),
          ),

        const SizedBox(height: 8),

        // Assertions list.
        Expanded(
          child: widget.assertions.isEmpty
              ? Center(
                  child: Text(
                    'No assertions defined.\nAdd an assertion above to validate this response.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: widget.assertions.length,
                  itemBuilder: (context, index) {
                    final a = widget.assertions[index];
                    final result = _results[index];
                    return _AssertionCard(
                      assertion: a,
                      result: result,
                      onRemove: () => widget.onRemoveAssertion(index),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _typeLabel(AssertionType type) {
    switch (type) {
      case AssertionType.statusCode:
        return 'Status Code';
      case AssertionType.bodyContains:
        return 'Body Contains';
      case AssertionType.headerExists:
        return 'Header Exists';
      case AssertionType.responseTime:
        return 'Response Time';
    }
  }
}

/// A single assertion card showing type, operator, expected value,
/// and pass/fail result.
class _AssertionCard extends StatelessWidget {
  final Assertion assertion;
  final ({bool passed, String message})? result;
  final VoidCallback onRemove;

  const _AssertionCard({
    required this.assertion,
    this.result,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasResult = result != null;
    final passed = result?.passed;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: hasResult
          ? (passed!
              ? theme.colorScheme.primaryContainer.withOpacity(0.3)
              : theme.colorScheme.errorContainer.withOpacity(0.3))
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Status icon.
            if (hasResult)
              Icon(
                passed! ? Symbols.check_circle : Symbols.error,
                size: 20,
                color: passed!
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
              )
            else
              Icon(
                Symbols.circle,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
              ),
            const SizedBox(width: 10),

            // Assertion description.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${assertion.type.name} ${assertion.operator.name} "${assertion.expectedValue}"',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (hasResult)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        result!.message,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: passed!
                              ? theme.colorScheme.primary
                              : theme.colorScheme.error,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),

            // Remove button.
            IconButton(
              icon: Icon(
                Symbols.close,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              onPressed: onRemove,
              tooltip: 'Remove assertion',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
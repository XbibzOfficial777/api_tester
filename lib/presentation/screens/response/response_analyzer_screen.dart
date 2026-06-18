/// @file response_analyzer_screen.dart
/// @brief Deep response analyzer with five analysis tabs.
///
/// Provides comprehensive analysis of an API response including structure
/// validation, JSON Path / XPath evaluation, text diffing, JSON Schema
/// generation, and JWT decoding. Each tab is self-contained and operates
/// on the current response body and headers.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/api_response.dart';
import '../../../domain/usecases/tools/diff_tool.dart';
import '../../../domain/usecases/tools/jwt_decoder.dart';
import '../../../domain/usecases/tools/json_schema_generator.dart';
import '../../providers/request_provider.dart';
import '../../widgets/common/code_view.dart';
import '../../widgets/common/empty_state_widget.dart';

// ---------------------------------------------------------------------------
// Response Type Detection
// ---------------------------------------------------------------------------

/// The detected content type of a response body.
enum ResponseContentType {
  /// Well-formed JSON.
  json,

  /// Well-formed XML.
  xml,

  /// Well-formed HTML.
  html,

  /// Plain text or unrecognised format.
  plainText,
}

/// Result of validating a response body's structure.
class StructureValidationResult {
  /// The detected content type.
  final ResponseContentType type;

  /// Whether the content was valid for its detected type.
  final bool isValid;

  /// For JSON: the parsed value (object, array, or primitive).
  final dynamic parsedValue;

  /// The count of top-level keys (for objects/arrays).
  final int keyCount;

  /// The maximum nesting depth of the structure.
  final int nestingDepth;

  /// If invalid, the error message with position info.
  final String? errorMessage;

  /// Creates a [StructureValidationResult].
  const StructureValidationResult({
    required this.type,
    required this.isValid,
    this.parsedValue,
    this.keyCount = 0,
    this.nestingDepth = 0,
    this.errorMessage,
  });
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Provides the structure validation result for the current response body.
final structureValidationProvider = Provider<StructureValidationResult>((ref) {
  final response = ref.watch(responseAnalyzerResponseProvider);
  if (response?.body == null || response!.body!.isEmpty) {
    return const StructureValidationResult(
      type: ResponseContentType.plainText,
      isValid: true,
    );
  }
  return _validateStructure(response.body!);
});

/// Provides the generated JSON Schema for the current response body.
final jsonSchemaProvider =
    FutureProvider.family<String, String>((ref, body) async {
  if (body.isEmpty) return '';
  final generator = JsonSchemaGenerator();
  final schema = await generator(JsonSchemaGeneratorParams(jsonString: body));
  return const JsonEncoder.withIndent('  ').convert(schema);
});

/// Holds the response to analyze. Can be set from outside or defaults to
/// the global [responseProvider].
final responseAnalyzerResponseProvider =
    StateProvider<ApiResponse?>((ref) => null);

// ---------------------------------------------------------------------------
// Structure Validation Helpers
// ---------------------------------------------------------------------------

/// Detects content type and validates the response body.
StructureValidationResult _validateStructure(String body) {
  final trimmed = body.trim();

  // Try JSON first.
  if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
      (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
    try {
      final parsed = json.decode(trimmed);
      final depth = _calculateDepth(parsed);
      int keys = 0;
      if (parsed is Map) {
        keys = parsed.length;
      } else if (parsed is List) {
        keys = parsed.length;
      }
      return StructureValidationResult(
        type: ResponseContentType.json,
        isValid: true,
        parsedValue: parsed,
        keyCount: keys,
        nestingDepth: depth,
      );
    } catch (e) {
      // Extract error position from the exception message.
      final errorMsg = e.toString();
      int? errorPos;
      final posMatch = RegExp(r'at line (\d+), column (\d+)').firstMatch(errorMsg);
      if (posMatch != null) {
        errorPos = int.tryParse(posMatch.group(1) ?? '');
      }
      return StructureValidationResult(
        type: ResponseContentType.json,
        isValid: false,
        errorMessage: errorPos != null
            ? 'Invalid JSON at line $errorPos:\n$errorMsg'
            : 'Invalid JSON: $errorMsg',
      );
    }
  }

  // Try XML.
  if (trimmed.startsWith('<')) {
    if (_looksLikeHtml(trimmed)) {
      return StructureValidationResult(
        type: ResponseContentType.html,
        isValid: true,
      );
    }
    // Basic XML validation – check for matching root tags.
    final tagMatch = RegExp(r'^<(\w+)').firstMatch(trimmed);
    final closeTagMatch = RegExp(r'</(\w+)\s*>$').firstMatch(trimmed);
    if (tagMatch != null &&
        closeTagMatch != null &&
        tagMatch.group(1) == closeTagMatch.group(1)) {
      return StructureValidationResult(
        type: ResponseContentType.xml,
        isValid: true,
      );
    }
    return StructureValidationResult(
      type: ResponseContentType.xml,
      isValid: false,
      errorMessage: 'XML validation failed: root tags do not match.',
    );
  }

  return StructureValidationResult(
    type: ResponseContentType.plainText,
    isValid: true,
  );
}

/// Recursively calculates the maximum nesting depth of a JSON value.
int _calculateDepth(dynamic value) {
  if (value is Map) {
    if (value.isEmpty) return 1;
    return 1 + value.values
        .map(_calculateDepth)
        .reduce((a, b) => a > b ? a : b);
  }
  if (value is List) {
    if (value.isEmpty) return 1;
    return 1 + value.map(_calculateDepth).reduce((a, b) => a > b ? a : b);
  }
  return 0;
}

/// Simple heuristic: if the body contains common HTML tags, classify as HTML.
bool _looksLikeHtml(String body) {
  const htmlTags = ['<html', '<!doctype', '<head', '<body', '<div', '<span'];
  final lower = body.toLowerCase();
  return htmlTags.any((tag) => lower.contains(tag));
}

// ---------------------------------------------------------------------------
// Main Screen
// ---------------------------------------------------------------------------

/// Deep response analyzer with five analysis tabs.
///
/// Accepts an optional [ApiResponse] via constructor or falls back to the
/// global [responseProvider]. The five tabs are:
/// 1. Structure Validation
/// 2. JSON Path / XPath Evaluator
/// 3. Diff Tool
/// 4. JSON Schema Generator
/// 5. JWT Decoder
class ResponseAnalyzerScreen extends ConsumerStatefulWidget {
  /// Optional response to analyze. If null, reads from [responseProvider].
  final ApiResponse? response;

  /// Creates a [ResponseAnalyzerScreen].
  const ResponseAnalyzerScreen({super.key, this.response});

  @override
  ConsumerState<ResponseAnalyzerScreen> createState() =>
      _ResponseAnalyzerScreenState();
}

class _ResponseAnalyzerScreenState
    extends ConsumerState<ResponseAnalyzerScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    // Seed the provider with the constructor-provided response.
    if (widget.response != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(responseAnalyzerResponseProvider.notifier).state =
            widget.response;
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(responseAnalyzerResponseProvider.notifier).state =
            ref.read(responseProvider);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Response Analyzer'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Structure', icon: Icon(Symbols.account_tree, size: 18)),
            Tab(text: 'Path Eval', icon: Icon(Symbols.route, size: 18)),
            Tab(text: 'Diff', icon: Icon(Symbols.compare, size: 18)),
            Tab(
                text: 'Schema',
                icon: Icon(Symbols.schema, size: 18)),
            Tab(text: 'JWT', icon: Icon(Symbols.key, size: 18)),
          ],
        ),
      ),
      body: ref.watch(responseAnalyzerResponseProvider) == null
          ? EmptyStateWidget(
              icon: Symbols.analytics,
              title: 'No Response to Analyze',
              subtitle: 'Send a request first, then open the response analyzer.',
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _StructureValidationTab(),
                _PathEvaluatorTab(),
                _DiffToolTab(),
                _SchemaGeneratorTab(),
                _JwtDecoderTab(),
              ],
            ),
    );
  }
}

// ===========================================================================
// Tab 1: Structure Validation
// ===========================================================================

/// Tab that shows whether the response is valid JSON, XML, HTML, or plain
/// text, along with structural metadata (key count, nesting depth).
class _StructureValidationTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final validation = ref.watch(structureValidationProvider);
    final response = ref.watch(responseAnalyzerResponseProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Content Type Badge ---
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    _typeIcon(validation.type),
                    size: 32,
                    color: validation.isValid
                        ? AppTheme.status2xx
                        : AppTheme.status5xx,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _typeLabel(validation.type),
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          validation.isValid ? 'Valid structure' : 'Invalid structure',
                          style: textTheme.bodySmall?.copyWith(
                            color: validation.isValid
                                ? AppTheme.status2xx
                                : AppTheme.status5xx,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: validation.isValid
                          ? AppTheme.status2xx.withOpacity(0.15)
                          : AppTheme.status5xx.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      validation.isValid ? 'VALID' : 'INVALID',
                      style: textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: validation.isValid
                            ? AppTheme.status2xx
                            : AppTheme.status5xx,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // --- Error Display ---
          if (!validation.isValid && validation.errorMessage != null)
            Card(
              color: AppTheme.status5xx.withOpacity(0.08),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Symbols.error,
                            color: AppTheme.status5xx, size: 20),
                        const SizedBox(width: 8),
                        Text('Validation Error',
                            style: textTheme.titleSmall?.copyWith(
                                color: AppTheme.status5xx,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      validation.errorMessage!,
                      style: textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // --- Structure Summary ---
          if (validation.isValid &&
              validation.type == ResponseContentType.json) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Structure Summary',
                        style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    _InfoRow(
                        icon: Symbols.data_object,
                        label: 'Type',
                        value: _jsonTypeLabel(validation.parsedValue)),
                    _InfoRow(
                        icon: Symbols.tag,
                        label: 'Top-Level Keys / Items',
                        value: '${validation.keyCount}'),
                    _InfoRow(
                        icon: Symbols.layers,
                        label: 'Nesting Depth',
                        value: '${validation.nestingDepth}'),
                    _InfoRow(
                        icon: Symbols.data_usage,
                        label: 'Body Size',
                        value:
                            '${response?.body?.length ?? 0} characters'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // --- Parsed JSON Preview ---
            if (validation.parsedValue != null)
              CodeView(
                code: const JsonEncoder.withIndent('  ')
                    .convert(validation.parsedValue),
                language: CodeLanguage.json,
                title: 'Formatted JSON',
                maxHeight: 300,
              ),
          ],

          // --- Plain Text Info ---
          if (validation.isValid &&
              validation.type == ResponseContentType.plainText) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Text Info',
                        style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    _InfoRow(
                        icon: Symbols.data_usage,
                        label: 'Length',
                        value:
                            '${response?.body?.length ?? 0} characters'),
                    _InfoRow(
                        icon: Symbols.text_fields,
                        label: 'Lines',
                        value:
                            '${response?.body?.split('\n').length ?? 0}'),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Returns an icon for the detected content type.
  IconData _typeIcon(ResponseContentType type) {
    switch (type) {
      case ResponseContentType.json:
        return Symbols.data_object;
      case ResponseContentType.xml:
        return Symbols.code;
      case ResponseContentType.html:
        return Symbols.language;
      case ResponseContentType.plainText:
        return Symbols.article;
    }
  }

  /// Returns a human-readable label for the content type.
  String _typeLabel(ResponseContentType type) {
    switch (type) {
      case ResponseContentType.json:
        return 'JSON';
      case ResponseContentType.xml:
        return 'XML';
      case ResponseContentType.html:
        return 'HTML';
      case ResponseContentType.plainText:
        return 'Plain Text';
    }
  }

  /// Returns a type label for a parsed JSON value.
  String _jsonTypeLabel(dynamic value) {
    if (value == null) return 'Null';
    if (value is Map) return 'Object';
    if (value is List) return 'Array';
    if (value is String) return 'String';
    if (value is int) return 'Integer';
    if (value is double) return 'Number';
    if (value is bool) return 'Boolean';
    return 'Unknown';
  }
}

/// A single label-value information row used in cards.
class _InfoRow extends StatelessWidget {
  /// Material Symbols icon.
  final IconData icon;

  /// The label text (e.g. "Type").
  final String label;

  /// The value text (e.g. "Object").
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 12),
          Text(label,
              style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant)),
          const Spacer(),
          Text(value,
              style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ===========================================================================
// Tab 2: JSON Path / XPath Evaluator
// ===========================================================================

/// State for the path evaluator tab.
class _PathEvalState {
  /// The current query expression.
  final String query;

  /// The evaluated result string (or null if not yet evaluated).
  final String? result;

  /// Whether an evaluation is in progress.
  final bool isEvaluating;

  /// Error message if evaluation failed.
  final String? error;

  const _PathEvalState({
    this.query = '',
    this.result,
    this.isEvaluating = false,
    this.error,
  });

  _PathEvalState copyWith({
    String? query,
    String? result,
    bool? isEvaluating,
    String? error,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return _PathEvalState(
      query: query ?? this.query,
      result: clearResult ? null : (result ?? this.result),
      isEvaluating: isEvaluating ?? this.isEvaluating,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Tab for evaluating JSON Path or XPath expressions against the response.
class _PathEvaluatorTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_PathEvaluatorTab> createState() => _PathEvaluatorTabState();
}

class _PathEvaluatorTabState extends ConsumerState<_PathEvaluatorTab> {
  _PathEvalState _state = const _PathEvalState();
  final _queryController = TextEditingController();

  /// Common JSON Path examples for quick-insert.
  static const _jsonPathExamples = [
    ('\$', 'Root object'),
    ('\$.store', 'Store object'),
    ('\$.store.book', 'All books array'),
    ('\$.store.book[0]', 'First book'),
    ('\$.store.book[0].title', 'First book title'),
    ('\$.store.book[*].author', 'All authors'),
    ('\$.store.book[?(@.price < 10)]', 'Books under \$10'),
  ];

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  /// Evaluates a JSON Path expression against the parsed response body.
  void _evaluateJsonPath(String body) {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    setState(() => _state = _state.copyWith(
          isEvaluating: true,
          clearResult: true,
          clearError: true,
        ));

    try {
      final parsed = json.decode(body) as dynamic;
      final result = _evaluateJsonPathQuery(parsed, query);
      final formatted =
          const JsonEncoder.withIndent('  ').convert(result);

      setState(() => _state = _state.copyWith(
            isEvaluating: false,
            result: formatted,
          ));
    } catch (e) {
      setState(() => _state = _state.copyWith(
            isEvaluating: false,
            error: 'Evaluation error: $e',
          ));
    }
  }

  /// Simple JSON Path evaluator supporting dot notation and array indexing.
  dynamic _evaluateJsonPathQuery(dynamic data, String path) {
    // Strip leading '$.
    String remaining = path;
    if (remaining.startsWith('\$')) {
      remaining = remaining.substring(1);
      if (remaining.startsWith('.')) remaining = remaining.substring(1);
    }

    dynamic current = data;
    final parts = <String>[];
    final buffer = StringBuffer();

    // Tokenise the path into parts, handling brackets and dots.
    for (var i = 0; i < remaining.length; i++) {
      final ch = remaining[i];
      if (ch == '.') {
        if (buffer.isNotEmpty) {
          parts.add(buffer.toString());
          buffer.clear();
        }
      } else if (ch == '[') {
        if (buffer.isNotEmpty) {
          parts.add(buffer.toString());
          buffer.clear();
        }
        // Read until closing bracket.
        final closeIdx = remaining.indexOf(']', i);
        if (closeIdx == -1) throw FormatException('Unclosed bracket at $i');
        parts.add(remaining.substring(i, closeIdx + 1));
        i = closeIdx;
      } else {
        buffer.write(ch);
      }
    }
    if (buffer.isNotEmpty) parts.add(buffer.toString());

    // Walk each part.
    for (final part in parts) {
      if (current == null) return null;

      if (part.startsWith('[') && part.endsWith(']')) {
        final inner = part.substring(1, part.length - 1);
        if (inner == '*') {
          // Wildcard – return all elements as a list.
          if (current is List) {
            // Continue with next parts on each element.
            continue;
          }
          if (current is Map) {
            current = current.values.toList();
            continue;
          }
          throw FormatException('Cannot apply [*] to ${current.runtimeType}');
        }
        final index = int.tryParse(inner);
        if (index == null) {
          throw FormatException('Invalid array index: $inner');
        }
        if (current is! List) {
          throw FormatException('Cannot index ${current.runtimeType} with [$index]');
        }
        if (index < 0 || index >= current.length) {
          throw FormatException('Index $index out of range (length ${current.length})');
        }
        current = current[index];
      } else if (part == '*') {
        if (current is Map) {
          current = current.values.toList();
        } else if (current is List) {
          // Flatten
        }
      } else {
        if (current is! Map) {
          throw FormatException('Cannot access property "$part" on ${current.runtimeType}');
        }
        current = current[part];
      }
    }

    return current;
  }

  @override
  Widget build(BuildContext context) {
    final response = ref.watch(responseAnalyzerResponseProvider);
    final body = response?.body ?? '';
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isJson = body.trim().startsWith('{') || body.trim().startsWith('[');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Auto-detection info ---
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    isJson ? Symbols.data_object : Symbols.code,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Detected format: ${isJson ? 'JSON' : 'XML/Text'}',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // --- Query Input ---
          if (isJson) ...[
            TextField(
              controller: _queryController,
              decoration: InputDecoration(
                labelText: 'JSON Path Query',
                hintText: '\$.store.book[0].title',
                prefixIcon:
                    const Icon(Symbols.route, size: 20),
                suffixIcon: IconButton(
                  icon: const Icon(Symbols.play_arrow, size: 20),
                  tooltip: 'Execute',
                  onPressed: body.isNotEmpty
                      ? () => _evaluateJsonPath(body)
                      : null,
                ),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) =>
                  body.isNotEmpty ? _evaluateJsonPath(body) : null,
            ),

            const SizedBox(height: 8),

            // --- Quick-insert buttons ---
            Text('Quick Examples',
                style: textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _jsonPathExamples.map((example) {
                return ActionChip(
                  label: Text(example.$2,
                      style: const TextStyle(fontSize: 11)),
                  onPressed: () {
                    _queryController.text = example.$1;
                  },
                );
              }).toList(),
            ),
          ] else
            TextField(
              controller: _queryController,
              decoration: const InputDecoration(
                labelText: 'XPath Query',
                hintText: '/root/element/@attr',
                prefixIcon: Icon(Symbols.route, size: 20),
                border: OutlineInputBorder(),
              ),
            ),

          const SizedBox(height: 16),

          // --- Execute Button ---
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _state.isEvaluating
                  ? null
                  : () => _evaluateJsonPath(body),
              icon: _state.isEvaluating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Symbols.play_arrow, size: 18),
              label: Text(_state.isEvaluating ? 'Evaluating…' : 'Execute Query'),
            ),
          ),

          const SizedBox(height: 16),

          // --- Result ---
          if (_state.error != null)
            Card(
              color: AppTheme.status5xx.withOpacity(0.08),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_state.error!,
                    style: textTheme.bodySmall?.copyWith(
                        color: AppTheme.status5xx)),
              ),
            ),

          if (_state.result != null)
            CodeView(
              code: _state.result!,
              language: CodeLanguage.json,
              title: 'Query Result',
              maxHeight: 300,
            ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Tab 3: Diff Tool
// ===========================================================================

/// State for the diff tool tab within the response analyzer.
class _DiffState {
  /// Left-side text (original).
  final String leftText;

  /// Right-side text (modified).
  final String rightText;

  /// Whether a diff operation is in progress.
  final bool isComparing;

  /// The diff results, or null if not yet compared.
  final DiffToolResult? diffResult;

  /// Error message.
  final String? error;

  const _DiffState({
    this.leftText = '',
    this.rightText = '',
    this.isComparing = false,
    this.diffResult,
    this.error,
  });

  _DiffState copyWith({
    String? leftText,
    String? rightText,
    bool? isComparing,
    DiffToolResult? diffResult,
    String? error,
    bool clearDiff = false,
    bool clearError = false,
  }) {
    return _DiffState(
      leftText: leftText ?? this.leftText,
      rightText: rightText ?? this.rightText,
      isComparing: isComparing ?? this.isComparing,
      diffResult: clearDiff ? null : (diffResult ?? this.diffResult),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Tab for diffing two text inputs (e.g. two response bodies).
class _DiffToolTab extends StatefulWidget {
  @override
  State<_DiffToolTab> createState() => _DiffToolTabState();
}

class _DiffToolTabState extends State<_DiffToolTab> {
  _DiffState _state = const _DiffState();
  final _leftController = TextEditingController();
  final _rightController = TextEditingController();

  @override
  void dispose() {
    _leftController.dispose();
    _rightController.dispose();
    super.dispose();
  }

  /// Runs the diff comparison.
  Future<void> _compare() async {
    final left = _leftController.text;
    final right = _rightController.text;

    if (left.isEmpty && right.isEmpty) {
      setState(() => _state = _state.copyWith(
            error: 'Both inputs are empty.',
          ));
      return;
    }

    setState(() => _state = _state.copyWith(
          isComparing: true,
          clearDiff: true,
          clearError: true,
        ));

    try {
      final tool = DiffTool();
      final result = await tool(DiffToolParams(
        original: left,
        modified: right,
      ));
      setState(() => _state = _state.copyWith(
            isComparing: false,
            diffResult: result,
          ));
    } catch (e) {
      setState(() => _state = _state.copyWith(
            isComparing: false,
            error: 'Diff failed: $e',
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isWide = MediaQuery.of(context).size.width > 700;

    return Column(
      children: [
        // --- Text Inputs ---
        Expanded(
          flex: _state.diffResult != null ? 1 : 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildTextArea(
                          controller: _leftController,
                          label: 'Original (Left)',
                          icon: Symbols.format_align_left,
                          hint: 'Paste the original text here…',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextArea(
                          controller: _rightController,
                          label: 'Modified (Right)',
                          icon: Symbols.format_align_right,
                          hint: 'Paste the modified text here…',
                        ),
                      ),
                    ],
                  )
                else ...[
                  _buildTextArea(
                    controller: _leftController,
                    label: 'Original (Left)',
                    icon: Symbols.format_align_left,
                    hint: 'Paste the original text here…',
                  ),
                  const SizedBox(height: 12),
                  _buildTextArea(
                    controller: _rightController,
                    label: 'Modified (Right)',
                    icon: Symbols.format_align_right,
                    hint: 'Paste the modified text here…',
                  ),
                ],

                const SizedBox(height: 12),

                // --- Compare Button ---
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _state.isComparing ? null : _compare,
                    icon: _state.isComparing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Symbols.compare_arrows, size: 18),
                    label: Text(
                        _state.isComparing ? 'Comparing…' : 'Compare'),
                  ),
                ),
              ],
            ),
          ),
        ),

        // --- Error ---
        if (_state.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              color: AppTheme.status5xx.withOpacity(0.08),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_state.error!,
                    style: textTheme.bodySmall?.copyWith(
                        color: AppTheme.status5xx)),
              ),
            ),
          ),

        // --- Diff Results ---
        if (_state.diffResult != null) ...[
          // --- Statistics Bar ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatChip(
                    label: 'Added',
                    count: _state.diffResult!.statistics.addedCount,
                    color: AppTheme.status2xx),
                _StatChip(
                    label: 'Removed',
                    count: _state.diffResult!.statistics.removedCount,
                    color: AppTheme.status5xx),
                _StatChip(
                    label: 'Unchanged',
                    count: _state.diffResult!.statistics.unchangedCount,
                    color: colorScheme.outline),
              ],
            ),
          ),

          // --- Diff Content ---
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _state.diffResult!.results.length,
              itemBuilder: (context, index) {
                final segment = _state.diffResult!.results[index];
                return _buildDiffSegment(segment, colorScheme);
              },
            ),
          ),
        ],
      ],
    );
  }

  /// Builds a single text area with label.
  Widget _buildTextArea({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Text(label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          maxLines: 6,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  /// Renders a single diff segment with colour coding.
  Widget _buildDiffSegment(DiffResult segment, ColorScheme colorScheme) {
    Color? bgColor;
    if (segment.type == DiffType.added) {
      bgColor = AppTheme.status2xx.withOpacity(0.15);
    } else if (segment.type == DiffType.removed) {
      bgColor = AppTheme.status5xx.withOpacity(0.15);
    }

    // Split multi-line text into individual lines.
    final lines = segment.text.split('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          color: bgColor,
          child: Text(
            line,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.5,
              color: segment.type == DiffType.unchanged
                  ? colorScheme.onSurface
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// A compact chip showing a diff statistic.
class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text('$label: ',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Text('$count',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

// ===========================================================================
// Tab 4: JSON Schema Generator
// ===========================================================================

/// Tab that generates a JSON Schema from the response body.
class _SchemaGeneratorTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SchemaGeneratorTab> createState() =>
      _SchemaGeneratorTabState();
}

class _SchemaGeneratorTabState extends ConsumerState<_SchemaGeneratorTab> {
  bool _generating = false;
  String? _schema;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final response = ref.watch(responseAnalyzerResponseProvider);
    final body = response?.body ?? '';
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Generate a JSON Schema (Draft-07) from the current response body.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),

          const SizedBox(height: 16),

          // --- Generate Button ---
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _generating || body.isEmpty
                  ? null
                  : () => _generate(body),
              icon: _generating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Symbols.auto_awesome, size: 18),
              label: Text(
                  _generating ? 'Generating…' : 'Generate Schema'),
            ),
          ),

          if (body.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: EmptyStateWidget(
                icon: Symbols.schema,
                title: 'No Response Body',
                subtitle: 'Send a request that returns JSON to generate a schema.',
              ),
            ),

          const SizedBox(height: 16),

          // --- Error ---
          if (_error != null)
            Card(
              color: AppTheme.status5xx.withOpacity(0.08),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.status5xx)),
              ),
            ),

          // --- Generated Schema ---
          if (_schema != null)
            CodeView(
              code: _schema!,
              language: CodeLanguage.json,
              title: 'Generated JSON Schema',
              maxHeight: 500,
            ),
        ],
      ),
    );
  }

  /// Generates the JSON Schema from the given body.
  Future<void> _generate(String body) async {
    setState(() {
      _generating = true;
      _schema = null;
      _error = null;
    });

    try {
      final generator = JsonSchemaGenerator();
      final schema =
          await generator(JsonSchemaGeneratorParams(jsonString: body));
      final formatted =
          const JsonEncoder.withIndent('  ').convert(schema);
      if (mounted) setState(() {
        _schema = formatted;
        _generating = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = 'Failed to generate schema: $e';
        _generating = false;
      });
    }
  }
}

// ===========================================================================
// Tab 5: JWT Decoder
// ===========================================================================

/// Tab that auto-detects and decodes JWT tokens from response headers.
class _JwtDecoderTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_JwtDecoderTab> createState() => _JwtDecoderTabState();
}

class _JwtDecoderTabState extends ConsumerState<_JwtDecoderTab> {
  final _tokenController = TextEditingController();
  JwtDecodeResult? _decoded;
  bool _isDecoding = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Auto-detect JWT from response headers on first build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoDetectJwt();
    });
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  /// Attempts to extract a JWT from the Authorization header.
  void _autoDetectJwt() {
    final response = ref.read(responseAnalyzerResponseProvider);
    if (response == null) return;

    final authHeader = response.headers['authorization'] ??
        response.headers['Authorization'];

    if (authHeader != null && authHeader.startsWith('Bearer ')) {
      final token = authHeader.substring(7).trim();
      if (token.split('.').length == 3) {
        _tokenController.text = token;
        _decode(token);
      }
    }
  }

  /// Decodes the given JWT token.
  Future<void> _decode(String token) async {
    if (token.trim().isEmpty) return;

    setState(() {
      _isDecoding = true;
      _decoded = null;
      _error = null;
    });

    try {
      final decoder = JwtDecoder();
      final result =
          await decoder(JwtDecoderParams(token: token.trim()));
      if (mounted) setState(() {
        _decoded = result;
        _isDecoding = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = 'Failed to decode JWT: $e';
        _isDecoding = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- JWT Input ---
          TextField(
            controller: _tokenController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'JWT Token',
              hintText: 'Paste or auto-detected from Authorization header',
              prefixIcon:
                  const Icon(Symbols.key, size: 20),
              suffixIcon: IconButton(
                icon: const Icon(Symbols.play_arrow, size: 20),
                tooltip: 'Decode',
                onPressed: () => _decode(_tokenController.text),
              ),
              border: const OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 8),

          // --- Decode Button ---
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isDecoding
                  ? null
                  : () => _decode(_tokenController.text),
              icon: _isDecoding
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Symbols.lock_open, size: 18),
              label:
                  Text(_isDecoding ? 'Decoding…' : 'Decode Token'),
            ),
          ),

          const SizedBox(height: 16),

          // --- Error ---
          if (_error != null)
            Card(
              color: AppTheme.status5xx.withOpacity(0.08),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!,
                    style: textTheme.bodySmall?.copyWith(
                        color: AppTheme.status5xx)),
              ),
            ),

          // --- Decoded Result ---
          if (_decoded != null) ...[
            // --- Expiration Status ---
            Card(
              color: _decoded!.isExpired
                  ? AppTheme.status5xx.withOpacity(0.08)
                  : AppTheme.status2xx.withOpacity(0.08),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      _decoded!.isExpired
                          ? Symbols.warning
                          : Symbols.check_circle,
                      color: _decoded!.isExpired
                          ? AppTheme.status5xx
                          : AppTheme.status2xx,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _decoded!.expirationStatus,
                        style: textTheme.bodySmall?.copyWith(
                          color: _decoded!.isExpired
                              ? AppTheme.status5xx
                              : AppTheme.status2xx,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // --- Header ---
            _buildSectionCard(
              context,
              title: 'Header',
              icon: Symbols.settings,
              content: const JsonEncoder.withIndent('  ')
                  .convert(_decoded!.header),
            ),

            const SizedBox(height: 8),

            // --- Payload ---
            _buildSectionCard(
              context,
              title: 'Payload',
              icon: Symbols.description,
              content: const JsonEncoder.withIndent('  ')
                  .convert(_decoded!.payload),
            ),

            const SizedBox(height: 8),

            // --- Signature ---
            _buildSectionCard(
              context,
              title: 'Signature (Base64)',
              icon: Symbols.fingerprint,
              content: _decoded!.signature,
            ),

            const SizedBox(height: 8),

            // --- Key Claims ---
            _buildClaimsSummary(context, _decoded!.payload),
          ],
        ],
      ),
    );
  }

  /// Builds a section card with copy functionality.
  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String content,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
            child: Row(
              children: [
                Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(title,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Symbols.copy_all, size: 16),
                  tooltip: 'Copy',
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: content)),
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              content,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Shows a summary of common JWT claims (iat, exp, sub, iss).
  Widget _buildClaimsSummary(
      BuildContext context, Map<String, dynamic> payload) {
    final claims = <String, String>{};

    if (payload.containsKey('sub')) {
      claims['Subject'] = payload['sub'].toString();
    }
    if (payload.containsKey('iss')) {
      claims['Issuer'] = payload['iss'].toString();
    }
    if (payload.containsKey('aud')) {
      claims['Audience'] = payload['aud'].toString();
    }
    if (payload.containsKey('iat')) {
      final iat = payload['iat'];
      final dt = iat is int
          ? DateTime.fromMillisecondsSinceEpoch(iat * 1000).toUtc()
          : null;
      claims['Issued At'] = dt?.toIso8601String() ?? iat.toString();
    }
    if (payload.containsKey('exp')) {
      final exp = payload['exp'];
      final dt = exp is int
          ? DateTime.fromMillisecondsSinceEpoch(exp * 1000).toUtc()
          : null;
      claims['Expires At'] = dt?.toIso8601String() ?? exp.toString();
    }

    if (claims.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Key Claims',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...claims.entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text('${e.key}: ',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                      Expanded(
                        child: SelectableText(e.value,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontFamily: 'monospace')),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
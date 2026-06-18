/// @file graphql_screen.dart
/// @brief Tool screen for sending GraphQL queries and mutations.
///
/// Provides a query editor with syntax highlighting hints, a variables
/// editor (JSON), a headers editor, operation name input, response viewer,
/// introspection query support, query history, and save-to-workspace.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/common/code_view.dart';
import '../../widgets/common/key_value_editor.dart';

// ---------------------------------------------------------------------------
// GraphQL History Entry
// ---------------------------------------------------------------------------

/// A single saved GraphQL query in the history list.
class _GraphQlHistoryEntry {
  /// The GraphQL query/mutation string.
  final String query;

  /// The variables JSON string.
  final String variables;

  /// The operation name.
  final String operationName;

  /// The server URL.
  final String url;

  /// Timestamp when this query was executed.
  final DateTime timestamp;

  const _GraphQlHistoryEntry({
    required this.query,
    this.variables = '',
    this.operationName = '',
    required this.url,
    required this.timestamp,
  });
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Immutable state for the GraphQL screen.
class _GraphQlState {
  /// Whether a request is in-flight.
  final bool isLoading;

  /// The latest response body string.
  final String? responseBody;

  /// The latest response status code.
  final int? statusCode;

  /// Error message if the request failed.
  final String? error;

  /// History of executed queries.
  final List<_GraphQlHistoryEntry> history;

  const _GraphQlState({
    this.isLoading = false,
    this.responseBody,
    this.statusCode,
    this.error,
    this.history = const [],
  });

  _GraphQlState copyWith({
    bool? isLoading,
    String? responseBody,
    int? statusCode,
    String? error,
    List<_GraphQlHistoryEntry>? history,
  }) {
    return _GraphQlState(
      isLoading: isLoading ?? this.isLoading,
      responseBody: responseBody,
      statusCode: statusCode,
      error: error,
      history: history ?? this.history,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class _GraphQlNotifier extends StateNotifier<_GraphQlState> {
  _GraphQlNotifier() : super(const _GraphQlState());

  /// Sends a GraphQL query to the given URL.
  Future<void> executeQuery({
    required String url,
    required String query,
    String variables = '',
    String operationName = '',
    List<KeyValueEntry>? headers,
  }) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      responseBody: null,
      statusCode: null,
    );

    try {
      final dio = getIt<Dio>();

      final bodyMap = <String, dynamic>{
        'query': query,
      };
      if (variables.trim().isNotEmpty) {
        bodyMap['variables'] = json.decode(variables.trim());
      }
      if (operationName.trim().isNotEmpty) {
        bodyMap['operationName'] = operationName.trim();
      }

      final headerMap = <String, String>{
        'Content-Type': 'application/json',
      };
      if (headers != null) {
        for (final h in headers.where((h) => h.isEnabled && h.key.isNotEmpty)) {
          headerMap[h.key] = h.value;
        }
      }

      final response = await dio.post<dynamic>(
        url,
        data: bodyMap,
        options: Options(
          headers: headerMap,
          responseType: ResponseType.plain,
        ),
      );

      final bodyStr = response.data?.toString() ?? '';

      state = state.copyWith(
        isLoading: false,
        responseBody: bodyStr,
        statusCode: response.statusCode,
        history: [
          _GraphQlHistoryEntry(
            query: query,
            variables: variables,
            operationName: operationName,
            url: url,
            timestamp: DateTime.now(),
          ),
          ...state.history,
        ].take(50).toList(), // Keep last 50 entries.
      );
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'GraphQL Error: ${e.message}',
        statusCode: e.response?.statusCode,
        responseBody: e.response?.data?.toString(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error: $e',
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final _graphQlProvider =
    StateNotifierProvider<_GraphQlNotifier, _GraphQlState>(
  (ref) => _GraphQlNotifier(),
);

// ---------------------------------------------------------------------------
// Common GraphQL Endpoints for Autocomplete
// ---------------------------------------------------------------------------

/// Common public GraphQL endpoints used for autocomplete suggestions.
const _kGraphQlEndpoints = [
  'https://graphql.org/swapi-graphql',
  'https://api.spacex.land/graphql',
  'https://countries.trevorblades.com/graphql',
  'https://rickandmortyapi.com/graphql',
  'https://api.github.com/graphql',
];

/// The standard GraphQL introspection query.
const _kIntrospectionQuery = r'''
query IntrospectionQuery {
  __schema {
    queryType { name }
    mutationType { name }
    subscriptionType { name }
    types {
      ...FullType
    }
    directives {
      name
      description
      locations
      args {
        ...InputValue
      }
    }
  }
}

fragment FullType on __Type {
  kind
  name
  description
  fields(includeDeprecated: true) {
    name
    description
    args {
      ...InputValue
    }
    type {
      ...TypeRef
    }
    isDeprecated
    deprecationReason
  }
  inputFields {
    ...InputValue
  }
  interfaces {
    ...TypeRef
  }
  enumValues(includeDeprecated: true) {
    name
    description
    isDeprecated
    deprecationReason
  }
  possibleTypes {
    ...TypeRef
  }
}

fragment InputValue on __InputValue {
  name
  description
  type {
    ...TypeRef
  }
  defaultValue
}

fragment TypeRef on __Type {
  kind
  name
  ofType {
    kind
    name
    ofType {
      kind
      name
      ofType {
        kind
        name
      }
    }
  }
}
''';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Provides a query editor with variables panel for GraphQL endpoints.
///
/// Features:
/// - Server URL input with endpoint autocomplete.
/// - Multi-line query editor with tab support.
/// - "Introspection Query" button.
/// - Variables editor (JSON with validation).
/// - Headers editor (reuses [KeyValueEditor]).
/// - Operation name input.
/// - Response viewer (reuses [CodeView]).
/// - Query history.
/// - Save query button.
class GraphQLScreen extends ConsumerStatefulWidget {
  /// Creates a [GraphQLScreen].
  const GraphQLScreen({super.key});

  @override
  ConsumerState<GraphQLScreen> createState() => _GraphQLScreenState();
}

class _GraphQLScreenState extends ConsumerState<GraphQLScreen> {
  final _urlController = TextEditingController();
  final _queryController = TextEditingController();
  final _variablesController = TextEditingController();
  final _operationNameController = TextEditingController();
  final _urlFocusNode = FocusNode();
  List<KeyValueEntry> _headers = [];

  /// A default sample query.
  static const _defaultQuery = r'''query {
  __typename
}''';

  @override
  void initState() {
    super.initState();
    _queryController.text = _defaultQuery;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _queryController.dispose();
    _variablesController.dispose();
    _operationNameController.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  /// Executes the current GraphQL query.
  Future<void> _execute() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a GraphQL endpoint URL')),
      );
      return;
    }

    // Validate variables JSON if provided.
    final vars = _variablesController.text.trim();
    if (vars.isNotEmpty) {
      try {
        json.decode(vars);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid variables JSON: $e')),
        );
        return;
      }
    }

    await ref.read(_graphQlProvider.notifier).executeQuery(
          url: url,
          query: _queryController.text,
          variables: vars,
          operationName: _operationNameController.text,
          headers: _headers,
        );
  }

  /// Loads the introspection query into the editor.
  void _loadIntrospection() {
    setState(() {
      _queryController.text = _kIntrospectionQuery.trim();
    });
  }

  /// Loads a history entry into the editors.
  void _loadHistoryEntry(_GraphQlHistoryEntry entry) {
    setState(() {
      _urlController.text = entry.url;
      _queryController.text = entry.query;
      _variablesController.text = entry.variables;
      _operationNameController.text = entry.operationName;
    });
  }

  /// Saves the current query (copies to clipboard as a simple save).
  Future<void> _saveQuery() async {
    final data = json.encode({
      'url': _urlController.text,
      'query': _queryController.text,
      'variables': _variablesController.text,
      'operationName': _operationNameController.text,
    });
    await Clipboard.setData(ClipboardData(text: data));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Query saved to clipboard as JSON'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gqlState = ref.watch(_graphQlProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text('GraphQL'),
        actions: [
          // Save query.
          IconButton(
            icon: const Icon(Symbols.save, size: 20),
            tooltip: 'Save Query',
            onPressed: _saveQuery,
          ),
          // History.
          PopupMenuButton<int>(
            icon: const Icon(Symbols.history, size: 20),
            tooltip: 'Query History',
            itemBuilder: (context) {
              if (gqlState.history.isEmpty) {
                return [
                  const PopupMenuItem<int>(
                    value: -1,
                    enabled: false,
                    child: Text('No history yet'),
                  ),
                ];
              }
              return gqlState.history.asMap().entries.map((entry) {
                final idx = entry.key;
                final h = entry.value;
                final preview =
                    h.query.replaceAll('\n', ' ').substring(0, 40);
                return PopupMenuItem<int>(
                  value: idx,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(preview,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12)),
                      Text(h.url,
                          style: TextStyle(
                              fontSize: 10,
                              color: colorScheme.onSurfaceVariant)),
                    ],
                  ),
                );
              }).toList();
            },
            onSelected: (idx) {
              if (idx >= 0 && idx < gqlState.history.length) {
                _loadHistoryEntry(gqlState.history[idx]);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // --- URL Input ---
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Autocomplete<String>(
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                // Sync with our controller.
                if (_urlController.text != controller.text) {
                  _urlController.text = controller.text;
                }
                return TextField(
                  controller: _urlController,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: 'https://api.example.com/graphql',
                    labelText: 'GraphQL Endpoint',
                    isDense: true,
                    prefixIcon:
                        const Icon(Symbols.link, size: 18),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Symbols.send, size: 18),
                      tooltip: 'Send',
                      onPressed: gqlState.isLoading ? null : _execute,
                    ),
                  ),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  onSubmitted: (_) => _execute(),
                  onChanged: (v) => controller.text = v,
                );
              },
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return _kGraphQlEndpoints;
                }
                return _kGraphQlEndpoints
                    .where((url) => url
                        .toLowerCase()
                        .contains(textEditingValue.text.toLowerCase()));
              },
              onSelected: (url) {
                _urlController.text = url;
              },
            ),
          ),

          // --- Operation Name ---
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _operationNameController,
                    decoration: InputDecoration(
                      hintText: 'MyQuery',
                      labelText: 'Operation Name',
                      isDense: true,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Introspection button.
                OutlinedButton.icon(
                  onPressed: _loadIntrospection,
                  icon: const Icon(Symbols.device_hub, size: 16),
                  label: const Text('Introspection'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // --- Main Content (Query/Variables/Response) ---
          Expanded(
            child: isWide
                ? _buildWideLayout(gqlState, colorScheme, textTheme)
                : _buildNarrowLayout(gqlState, colorScheme, textTheme),
          ),
        ],
      ),
    );
  }

  /// Builds the layout for wide screens (side-by-side editors).
  Widget _buildWideLayout(
      _GraphQlState gqlState, ColorScheme colorScheme, TextTheme textTheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: Query + Variables + Headers.
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Query editor.
                _buildQueryEditor(colorScheme, textTheme),
                const SizedBox(height: 12),
                // Variables editor.
                _buildVariablesEditor(colorScheme, textTheme),
                const SizedBox(height: 12),
                // Headers editor.
                KeyValueEditor(
                  entries: _headers,
                  onChanged: (v) => setState(() => _headers = v),
                  keyHint: 'Header',
                  valueHint: 'Value',
                  title: 'Headers',
                ),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        // Right: Response.
        Expanded(
          flex: 2,
          child: _buildResponsePanel(gqlState, colorScheme, textTheme),
        ),
      ],
    );
  }

  /// Builds the layout for narrow screens (stacked tabs).
  Widget _buildNarrowLayout(
      _GraphQlState gqlState, ColorScheme colorScheme, TextTheme textTheme) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Query'),
              Tab(text: 'Variables'),
              Tab(text: 'Response'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Query tab.
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildQueryEditor(colorScheme, textTheme),
                      const SizedBox(height: 12),
                      KeyValueEditor(
                        entries: _headers,
                        onChanged: (v) =>
                            setState(() => _headers = v),
                        keyHint: 'Header',
                        valueHint: 'Value',
                        title: 'Headers',
                      ),
                    ],
                  ),
                ),
                // Variables tab.
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildVariablesEditor(colorScheme, textTheme),
                ),
                // Response tab.
                _buildResponsePanel(gqlState, colorScheme, textTheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the query editor with tab support.
  Widget _buildQueryEditor(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Query',
            style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        KeyboardListener(
          focusNode: FocusNode(),
          onKeyEvent: (event) {
            // Handle Tab key for indentation.
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.tab) {
              final controller = _queryController;
              final selection = controller.selection;
              final text = controller.text;

              // Replace selection or insert spaces at cursor.
              controller.text = text.replaceRange(
                selection.start,
                selection.end,
                '  ',
              );
              // Move cursor after inserted spaces.
              controller.selection = TextSelection.collapsed(
                offset: selection.start + 2,
              );
            }
          },
          child: TextField(
            controller: _queryController,
            maxLines: 14,
            decoration: InputDecoration(
              hintText: '{\n  query {\n    ...\n  }\n}',
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
        ),
      ],
    );
  }

  /// Builds the variables JSON editor with validation.
  Widget _buildVariablesEditor(
      ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Variables (JSON)',
            style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextField(
          controller: _variablesController,
          maxLines: 6,
          decoration: InputDecoration(
            hintText: '{\n  "id": 1\n}',
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        ),
        // Validate and show status.
        Builder(builder: (context) {
          final vars = _variablesController.text.trim();
          if (vars.isEmpty) return const SizedBox.shrink();
          try {
            json.decode(vars);
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(Symbols.check_circle,
                      size: 14, color: AppTheme.status2xx),
                  const SizedBox(width: 4),
                  Text('Valid JSON',
                      style: textTheme.labelSmall?.copyWith(
                          color: AppTheme.status2xx)),
                ],
              ),
            );
          } catch (e) {
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(Symbols.error,
                      size: 14, color: AppTheme.status5xx),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('Invalid JSON: $e',
                        style: textTheme.labelSmall?.copyWith(
                            color: AppTheme.status5xx),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            );
          }
        }),
      ],
    );
  }

  /// Builds the response panel with loading/error/response display.
  Widget _buildResponsePanel(
      _GraphQlState gqlState, ColorScheme colorScheme, TextTheme textTheme) {
    if (gqlState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (gqlState.error != null && gqlState.responseBody == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Symbols.error, size: 48, color: colorScheme.error),
              const SizedBox(height: 12),
              Text('Request Failed',
                  style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.error)),
              const SizedBox(height: 8),
              Text(gqlState.error!,
                  style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _execute,
                icon: const Icon(Symbols.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (gqlState.responseBody == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.data_object,
                size: 48, color: colorScheme.outline),
            const SizedBox(height: 12),
            Text('No Response Yet',
                style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text('Enter a query and press Send.',
                style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.outline)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status bar.
        if (gqlState.statusCode != null)
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
            child: Text(
              'Status: ${gqlState.statusCode}',
              style: textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600),
            ),
          ),

        // Error banner.
        if (gqlState.error != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: AppTheme.status4xx.withOpacity(0.08),
            child: Row(
              children: [
                Icon(Symbols.warning,
                    size: 16, color: AppTheme.status4xx),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(gqlState.error!,
                      style: textTheme.bodySmall?.copyWith(
                          color: AppTheme.status4xx)),
                ),
              ],
            ),
          ),

        // Response body.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: CodeView(
              code: gqlState.responseBody!,
              language: CodeLanguage.json,
              maxHeight: double.infinity,
            ),
          ),
        ),
      ],
    );
  }
}
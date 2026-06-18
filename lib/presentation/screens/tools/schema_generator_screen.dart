/// @file schema_generator_screen.dart
/// @brief Standalone tool screen for generating JSON Schema from JSON.
///
/// Provides a text area for pasting or typing JSON, a "Generate" button
/// that uses the [JsonSchemaGenerator] use case, and the output in a
/// [CodeView] with syntax highlighting and a copy button.
library;

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/usecases/tools/json_schema_generator.dart';
import '../../widgets/common/code_view.dart';
import '../../widgets/common/empty_state_widget.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Immutable state for the schema generator screen.
class _SchemaState {
  /// Whether generation is in progress.
  final bool isGenerating;

  /// The generated JSON Schema string, or null.
  final String? schema;

  /// Error message.
  final String? error;

  const _SchemaState({
    this.isGenerating = false,
    this.schema,
    this.error,
  });

  _SchemaState copyWith({
    bool? isGenerating,
    String? schema,
    String? error,
    bool clearSchema = false,
    bool clearError = false,
  }) {
    return _SchemaState(
      isGenerating: isGenerating ?? this.isGenerating,
      schema: clearSchema ? null : (schema ?? this.schema),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class _SchemaNotifier extends StateNotifier<_SchemaState> {
  _SchemaNotifier() : super(const _SchemaState());

  /// Generates a JSON Schema from the given JSON string.
  Future<void> generate(String jsonString, {String? title}) async {
    final trimmed = jsonString.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(error: 'Input is empty.');
      return;
    }

    state = state.copyWith(
      isGenerating: true,
      clearSchema: true,
      clearError: true,
    );

    try {
      final generator = JsonSchemaGenerator();
      final schema = await generator(
        JsonSchemaGeneratorParams(
          jsonString: trimmed,
          title: title,
        ),
      );
      final formatted =
          const JsonEncoder.withIndent('  ').convert(schema);
      state = state.copyWith(isGenerating: false, schema: formatted);
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        error: 'Failed to generate schema: $e',
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final _schemaProvider =
    StateNotifierProvider<_SchemaNotifier, _SchemaState>(
  (ref) => _SchemaNotifier(),
);

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Generates a JSON Schema (Draft-07) from a pasted JSON sample.
///
/// Features:
/// - Large text area for JSON input.
/// - Load from file button.
/// - "Generate" button.
/// - Output displayed in [CodeView] with syntax highlighting.
/// - Copy button.
class SchemaGeneratorScreen extends ConsumerStatefulWidget {
  /// Creates a [SchemaGeneratorScreen].
  const SchemaGeneratorScreen({super.key});

  @override
  ConsumerState<SchemaGeneratorScreen> createState() =>
      _SchemaGeneratorScreenState();
}

class _SchemaGeneratorScreenState extends ConsumerState<SchemaGeneratorScreen> {
  final _jsonController = TextEditingController();
  final _titleController = TextEditingController();

  @override
  void dispose() {
    _jsonController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  /// Loads a JSON file into the input area.
  Future<void> _loadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        final content = await String.fromCharCodes(
            await result.files.single.readAsBytes());
        setState(() {
          _jsonController.text = content;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to read file: $e')),
        );
      }
    }
  }

  /// Generates the schema.
  void _generate() {
    ref.read(_schemaProvider.notifier).generate(
          _jsonController.text,
          title: _titleController.text.trim().isNotEmpty
              ? _titleController.text.trim()
              : null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final schemaState = ref.watch(_schemaProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schema Generator'),
        actions: [
          if (schemaState.schema != null)
            IconButton(
              icon: const Icon(Symbols.copy_all, size: 20),
              tooltip: 'Copy Schema',
              onPressed: () {
                Clipboard.setData(
                    ClipboardData(text: schemaState.schema!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Schema copied to clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // --- Input Area ---
          Expanded(
            flex: schemaState.schema != null ? 1 : 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title input.
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Schema Title (optional)',
                      hintText: 'MyApiSchema',
                      isDense: true,
                      prefixIcon:
                          const Icon(Symbols.title, size: 18),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // JSON input header.
                  Row(
                    children: [
                      Icon(Symbols.data_object,
                          size: 16, color: colorScheme.primary),
                      const SizedBox(width: 6),
                      Text('JSON Input',
                          style: textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600)),
                      const Spacer(),
                      // Load from file.
                      OutlinedButton.icon(
                        onPressed: _loadFile,
                        icon: const Icon(Symbols.folder_open, size: 16),
                        label: const Text('Load File'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // JSON input text area.
                  TextField(
                    controller: _jsonController,
                    maxLines: 12,
                    decoration: InputDecoration(
                      hintText: '{\n  "name": "example",\n  "age": 30\n}',
                      '\n\nOr paste a JSON response here…',
                      border: const OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 13),
                  ),

                  // Validate input.
                  Builder(builder: (context) {
                    final input = _jsonController.text.trim();
                    if (input.isEmpty) return const SizedBox.shrink();
                    try {
                      json.decode(input);
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

                  const SizedBox(height: 12),

                  // --- Generate Button ---
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: schemaState.isGenerating
                          ? null
                          : _generate,
                      icon: schemaState.isGenerating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(
                              Symbols.auto_awesome, size: 18),
                      label: Text(schemaState.isGenerating
                          ? 'Generating…'
                          : 'Generate Schema'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- Error ---
          if (schemaState.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: colorScheme.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Symbols.error, color: colorScheme.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(schemaState.error!,
                        style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.error)),
                  ),
                ],
              ),
            ),

          // --- Generated Schema ---
          if (schemaState.schema != null)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: CodeView(
                  code: schemaState.schema!,
                  language: CodeLanguage.json,
                  title: 'Generated JSON Schema (Draft-07)',
                  maxHeight: double.infinity,
                ),
              ),
            ),

          // --- Empty state when nothing generated ---
          if (schemaState.schema == null &&
              schemaState.error == null &&
              !schemaState.isGenerating)
            Expanded(
              child: EmptyStateWidget(
                icon: Symbols.schema,
                title: 'No Schema Generated',
                subtitle:
                    'Enter a JSON sample above and tap "Generate Schema".',
              ),
            ),
        ],
      ),
    );
  }
}
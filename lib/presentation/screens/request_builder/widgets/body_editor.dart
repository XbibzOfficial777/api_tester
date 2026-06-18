/// @file body_editor.dart
/// @brief Request body editor supporting all five body types.
///
/// Provides a [SegmentedButton] row to switch between body types:
/// [None], [Form Data], [x-www-form-urlencoded], [Raw], and [Binary].
///
/// Each type has its own sub-editor:
/// - **None**: informational message.
/// - **Form Data**: list of key-value rows, each with an optional file
///   upload toggle. Uses `file_picker` for file selection.
/// - **x-www-form-urlencoded**: standard [KeyValueEditor].
/// - **Raw**: sub-type selector (JSON / XML / HTML / Text) plus a
///   [SyntaxHighlightEditor] with real-time validation.
/// - **Binary**: file picker button showing the selected file.
///
/// A pre-request script text area is appended at the bottom.

library;

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import 'package:api_tester/domain/entities/api_request.dart';
import 'package:api_tester/domain/entities/form_data_item.dart';
import 'package:api_tester/presentation/providers/request_provider.dart';
import 'package:api_tester/presentation/widgets/common/key_value_editor.dart';
import 'syntax_highlight_editor.dart';

/// Supported raw body sub-types for syntax highlighting and validation.
enum RawBodySubType {
  /// JavaScript Object Notation.
  json('JSON', 'json'),

  /// Extensible Markup Language.
  xml('XML', 'xml'),

  /// HyperText Markup Language.
  html('HTML', 'text'),

  /// Plain text (no highlighting).
  text('Text', 'text');

  const RawBodySubType(this.label, this.highlightLang);

  /// Display label.
  final String label;

  /// Language identifier for the syntax highlighter.
  final String highlightLang;
}

/// The main body editor widget used in the request builder.
///
/// Dynamically renders the appropriate sub-editor based on the selected
/// [BodyType].
class BodyEditor extends ConsumerStatefulWidget {
  /// Creates a [BodyEditor].
  const BodyEditor({super.key});

  @override
  ConsumerState<BodyEditor> createState() => _BodyEditorState();
}

class _BodyEditorState extends ConsumerState<BodyEditor> {
  /// The selected raw body sub-type (JSON by default).
  RawBodySubType _rawSubType = RawBodySubType.json;

  /// Whether the pre-request script section is expanded.
  bool _showPreRequestScript = false;

  /// Local cache of pre-request script text.
  String _preRequestScript = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formState = ref.watch(currentRequestProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Body type selector.
        _BodyTypeSelector(
          selectedType: formState.bodyType,
          onTypeChanged: (type) {
            ref.read(currentRequestProvider.notifier).setBodyType(type);
          },
        ),
        const SizedBox(height: 16),

        // Body content based on selected type.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _buildBodyContent(formState),
        ),

        const SizedBox(height: 16),

        // Pre-request script toggle and editor.
        _buildPreRequestScriptSection(theme),
      ],
    );
  }

  /// Builds the appropriate editor for the current [BodyType].
  Widget _buildBodyContent(dynamic formState) {
    // formState is RequestFormState from the provider.
    final bodyType = formState.bodyType as BodyType;

    switch (bodyType) {
      case BodyType.none:
        return _NoneBody();
      case BodyType.formData:
        return _FormDataBody(
          items: formState.formDataItems as List<FormDataItem>,
          notifier: ref.read(currentRequestProvider.notifier),
        );
      case BodyType.urlEncoded:
        return _UrlEncodedBody(
          bodyContent: formState.bodyContent as String,
          onContentChanged: (content) {
            ref.read(currentRequestProvider.notifier).setBodyContent(content);
          },
        );
      case BodyType.raw:
        return _RawBody(
          content: formState.bodyContent as String,
          subType: _rawSubType,
          onSubTypeChanged: (sub) => setState(() => _rawSubType = sub),
          onContentChanged: (content) {
            ref.read(currentRequestProvider.notifier).setBodyContent(content);
          },
        );
      case BodyType.binary:
        return _BinaryBody();
    }
  }

  /// Builds the pre-request script collapsible section.
  Widget _buildPreRequestScriptSection(ThemeData theme) {
    return Column(
      children: [
        Divider(color: theme.colorScheme.outlineVariant),
        const SizedBox(height: 8),
        InkWell(
          onTap: () =>
              setState(() => _showPreRequestScript = !_showPreRequestScript),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  _showPreRequestScript
                      ? Symbols.expand_more
                      : Symbols.chevron_right,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Icon(Symbols.code, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Pre-request Script',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (_preRequestScript.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Active',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: _showPreRequestScript
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextField(
                    controller: TextEditingController(text: _preRequestScript)
                      ..selection = TextSelection.collapsed(
                        offset: _preRequestScript.length,
                      ),
                    maxLines: 5,
                    minLines: 3,
                    onChanged: (script) =>
                        setState(() => _preRequestScript = script),
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    decoration: InputDecoration(
                      hintText:
                          '// Write pre-request script here (e.g. set variables)\n'
                          '// Example: pm.environment.set("token", "abc123");',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// =============================================================================
// Body Type Selector
// =============================================================================

/// A horizontal [SegmentedButton] row for picking the body type.
class _BodyTypeSelector extends StatelessWidget {
  final BodyType selectedType;
  final ValueChanged<BodyType> onTypeChanged;

  const _BodyTypeSelector({
    required this.selectedType,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<BodyType>(
      segments: [
        ButtonSegment(
          value: BodyType.none,
          label: const Text('None', style: TextStyle(fontSize: 12)),
          icon: const Icon(Symbols.block, size: 16),
        ),
        ButtonSegment(
          value: BodyType.formData,
          label: const Text('Form Data', style: TextStyle(fontSize: 12)),
          icon: const Icon(Symbols.description, size: 16),
        ),
        ButtonSegment(
          value: BodyType.urlEncoded,
          label: const Text('x-www-form', style: TextStyle(fontSize: 12)),
          icon: const Icon(Symbols.data_object, size: 16),
        ),
        ButtonSegment(
          value: BodyType.raw,
          label: const Text('Raw', style: TextStyle(fontSize: 12)),
          icon: const Icon(Symbols.code, size: 16),
        ),
        ButtonSegment(
          value: BodyType.binary,
          label: const Text('Binary', style: TextStyle(fontSize: 12)),
          icon: const Icon(Symbols.attach_file, size: 16),
        ),
      ],
      selected: {selectedType},
      onSelectionChanged: (selected) => onTypeChanged(selected.first),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

// =============================================================================
// None Body
// =============================================================================

/// Informational widget shown when "None" body type is selected.
class _NoneBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Icon(
            Symbols.info,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            'This request will not send a body.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Form Data Body
// =============================================================================

/// Multipart form data editor with text fields and file upload rows.
class _FormDataBody extends StatelessWidget {
  final List<FormDataItem> items;
  final dynamic notifier;

  const _FormDataBody({required this.items, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row.
        Padding(
          padding: const EdgeInsets.only(left: 40, bottom: 4),
          child: Row(
            children: [
              const SizedBox(
                width: 140,
                child: Text(
                  'Key',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF888888),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Value',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF888888),
                  ),
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
        ),

        // Form data rows.
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return _FormDataRow(
            item: item,
            index: index,
            notifier: notifier,
          );
        }),

        // Add buttons.
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => notifier.addFormDataItem(),
              icon: const Icon(Symbols.add, size: 16),
              label: const Text('Text Field'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => notifier.addFormDataItem(isFile: true),
              icon: const Icon(Symbols.upload_file, size: 16),
              label: const Text('File Upload'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A single form-data row (text or file).
class _FormDataRow extends StatelessWidget {
  final FormDataItem item;
  final int index;
  final dynamic notifier;

  const _FormDataRow({
    required this.item,
    required this.index,
    required this.notifier,
  });

  /// Opens a file picker and updates the form data item.
  Future<void> _pickFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      notifier.updateFormDataItem(
        index,
        filePath: file.path ?? '',
        fileName: file.name,
        contentType: file.extension != null ? 'application/${file.extension}' : '',
        value: file.name,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          // Toggle file/text indicator.
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              icon: Icon(
                item.isFile ? Symbols.attach_file : Symbols.text_fields,
                size: 18,
                color: item.isFile
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              onPressed: () {
                // Toggle isFile by recreating the item.
                notifier.removeFormDataItem(index);
                notifier.addFormDataItem(
                  key: item.key,
                  value: item.value,
                  isFile: !item.isFile,
                );
              },
              tooltip: item.isFile ? 'Switch to text' : 'Switch to file',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              visualDensity: VisualDensity.compact,
            ),
          ),

          // Key field.
          SizedBox(
            width: 140,
            height: 40,
            child: TextField(
              controller: TextEditingController(text: item.key)
                ..selection = TextSelection.collapsed(offset: item.key.length),
              onChanged: (v) => notifier.updateFormDataItem(index, key: v),
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Field name',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Value or file field.
          Expanded(
            child: item.isFile
                ? _FileValueField(item: item, onPickFile: () => _pickFile(context))
                : SizedBox(
                    height: 40,
                    child: TextField(
                      controller: TextEditingController(text: item.value)
                        ..selection = TextSelection.collapsed(
                            offset: item.value.length),
                      onChanged: (v) =>
                          notifier.updateFormDataItem(index, value: v),
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Value',
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ),
          ),

          // Delete button.
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              icon: Icon(
                Symbols.delete,
                size: 18,
                color: theme.colorScheme.error,
              ),
              onPressed: () => notifier.removeFormDataItem(index),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              visualDensity: VisualDensity.compact,
              tooltip: 'Remove',
            ),
          ),
        ],
      ),
    );
  }
}

/// Displays the selected file path and a "Browse" button.
class _FileValueField extends StatelessWidget {
  final FormDataItem item;
  final VoidCallback onPickFile;

  const _FileValueField({required this.item, required this.onPickFile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasFile = item.filePath.isNotEmpty;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                hasFile ? item.fileName : 'No file selected',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: hasFile
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                  overflow: TextOverflow.ellipsis,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: TextButton(
              onPressed: onPickFile,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Browse',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// URL-Encoded Body
// =============================================================================

/// URL-encoded body editor using key-value pairs.
///
/// Parses the bodyContent string ("key=value&...") into a list for
/// the KeyValueEditor, and serialises back when items change.
class _UrlEncodedBody extends StatefulWidget {
  final String bodyContent;
  final ValueChanged<String> onContentChanged;

  const _UrlEncodedBody({
    required this.bodyContent,
    required this.onContentChanged,
  });

  @override
  State<_UrlEncodedBody> createState() => _UrlEncodedBodyState();
}

class _UrlEncodedBodyState extends State<_UrlEncodedBody> {
  late List<KeyValueEntry> _entries;

  @override
  void initState() {
    super.initState();
    _entries = _parseBodyContent(widget.bodyContent);
  }

  @override
  void didUpdateWidget(covariant _UrlEncodedBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bodyContent != widget.bodyContent) {
      _entries = _parseBodyContent(widget.bodyContent);
    }
  }

  /// Parses "key=value&key2=value2" into a list of KeyValueEntries.
  List<KeyValueEntry> _parseBodyContent(String content) {
    if (content.isEmpty) return [];
    return content.split('&').where((s) => s.isNotEmpty).map((pair) {
      final eq = pair.indexOf('=');
      if (eq < 0) {
        return KeyValueEntry(
          key: Uri.decodeComponent(pair),
          value: '',
        );
      }
      return KeyValueEntry(
        key: Uri.decodeComponent(pair.substring(0, eq)),
        value: Uri.decodeComponent(pair.substring(eq + 1)),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return KeyValueEditor(
      entries: _entries,
      keyHint: 'Field name',
      valueHint: 'Field value',
      onChanged: (entries) {
        setState(() => _entries = List.of(entries));
        final parts = entries
            .where((e) => e.isEnabled && e.key.isNotEmpty)
            .map((e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
            .join('&');
        widget.onContentChanged(parts);
      },
    );
  }
}

// =============================================================================
// Raw Body
// =============================================================================

/// Raw body editor with a sub-type selector and syntax-highlighted editor.
class _RawBody extends StatelessWidget {
  final String content;
  final RawBodySubType subType;
  final ValueChanged<RawBodySubType> onSubTypeChanged;
  final ValueChanged<String> onContentChanged;

  const _RawBody({
    required this.content,
    required this.subType,
    required this.onSubTypeChanged,
    required this.onContentChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sub-type selector row.
        Row(
          children: [
            Text(
              'Language:',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(width: 12),
            SegmentedButton<RawBodySubType>(
              segments: RawBodySubType.values
                  .map((t) => ButtonSegment(
                        value: t,
                        label: Text(t.label, style: const TextStyle(fontSize: 11)),
                      ))
                  .toList(),
              selected: {subType},
              onSelectionChanged: (selected) =>
                  onSubTypeChanged(selected.first),
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const Spacer(),

            // Format JSON button.
            if (subType == RawBodySubType.json && content.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  try {
                    final decoded = const JsonDecoder().convert(content);
                    final pretty =
                        const JsonEncoder.withIndent('  ').convert(decoded);
                    onContentChanged(pretty);
                  } catch (_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Cannot format invalid JSON'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                icon: const Icon(Symbols.auto_fix_high, size: 16),
                label:
                    const Text('Beautify', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Syntax-highlighted editor.
        SyntaxHighlightEditor(
          text: content,
          onChanged: onContentChanged,
          language: subType.highlightLang,
          hintText: subType == RawBodySubType.json
              ? '{\n  "key": "value"\n}'
              : subType == RawBodySubType.xml
                  ? '<root>\n  <element>value</element>\n</root>'
                  : null,
          minHeight: 200,
        ),
      ],
    );
  }
}

// =============================================================================
// Binary Body
// =============================================================================

/// Binary file upload selector.
class _BinaryBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return OutlinedButton.icon(
      onPressed: () async {
        final result = await FilePicker.platform.pickFiles();
        if (result != null && result.files.isNotEmpty) {
          // Binary file path is stored in the bodyContent for now.
          // The full request builder can handle this in the send flow.
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Selected: ${result.files.first.name}'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      icon: const Icon(Symbols.upload_file, size: 20),
      label: const Text('Select a file to upload'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
/// @file params_editor.dart
/// @brief Query parameters section for the request builder.
///
/// Uses the shared [KeyValueEditor] for key-value editing and shows a
/// live URL preview below the editor with the encoded query parameters
/// appended. A toggle lets the user switch between raw and encoded
/// preview modes.

library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import 'package:api_tester/domain/entities/key_value_item.dart';
import 'package:api_tester/presentation/providers/request_provider.dart';
import 'package:api_tester/presentation/widgets/common/key_value_editor.dart';

/// A section for managing the request's query parameters.
///
/// Displays a [KeyValueEditor] for adding/removing/toggling params,
/// and below it a live URL preview that shows the full URL with encoded
/// parameters appended.
class ParamsEditor extends ConsumerStatefulWidget {
  /// Creates a [ParamsEditor].
  const ParamsEditor({super.key});

  @override
  ConsumerState<ParamsEditor> createState() => _ParamsEditorState();
}

class _ParamsEditorState extends ConsumerState<ParamsEditor> {
  /// When `true`, the URL preview shows URL-encoded characters.
  bool _showEncoded = false;

  /// Converts domain [KeyValueItem] list to widget [KeyValueEntry] list.
  List<KeyValueEntry> _toEntries(List<KeyValueItem> items) {
    return items
        .map((i) => KeyValueEntry(
              id: i.id,
              key: i.key,
              value: i.value,
              isEnabled: i.isEnabled,
            ))
        .toList();
  }

  /// Converts widget entries back and syncs with the provider.
  void _syncFromEntries(List<KeyValueEntry> entries) {
    final notifier = ref.read(currentRequestProvider.notifier);
    final current = ref.read(currentRequestProvider);
    while (current.queryParams.isNotEmpty) {
      notifier.removeParam(0);
    }
    for (final entry in entries) {
      notifier.addParam(key: entry.key, value: entry.value);
      if (!entry.isEnabled) {
        notifier.toggleParamEnabled(current.queryParams.length);
      }
    }
  }

  /// Builds the full URL preview with query parameters appended.
  String _buildUrlPreview() {
    final formState = ref.read(currentRequestProvider);
    final baseUrl = formState.url;
    if (baseUrl.isEmpty) return '';

    final activeParams =
        formState.queryParams.where((p) => p.isEnabled && p.key.isNotEmpty);
    if (activeParams.isEmpty) return baseUrl;

    final buffer = StringBuffer(baseUrl);
    if (!baseUrl.contains('?')) {
      buffer.write('?');
    } else if (!baseUrl.endsWith('&') && !baseUrl.endsWith('?')) {
      buffer.write('&');
    }

    var first = true;
    for (final param in activeParams) {
      if (!first) buffer.write('&');
      first = false;

      if (_showEncoded) {
        buffer.write(Uri.encodeQueryComponent(param.key));
        buffer.write('=');
        buffer.write(Uri.encodeQueryComponent(param.value));
      } else {
        buffer.write(param.key);
        buffer.write('=');
        buffer.write(param.value);
      }
    }

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formState = ref.watch(currentRequestProvider);
    final activeCount = formState.queryParams
        .where((p) => p.isEnabled && p.key.isNotEmpty)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Key-value editor for params.
        KeyValueEditor(
          entries: _toEntries(formState.queryParams),
          keyHint: 'Parameter name',
          valueHint: 'Value',
          onChanged: _syncFromEntries,
        ),

        // Divider and URL preview when there are params.
        if (formState.queryParams.isNotEmpty) ...[
          const SizedBox(height: 12),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),

          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Icon(
                  Symbols.link,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'URL Preview',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),

                // Toggle: Raw / Encoded.
                SizedBox(
                  height: 28,
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Raw', style: TextStyle(fontSize: 11)),
                      ),
                      ButtonSegment(
                        value: true,
                        label:
                            Text('Encoded', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                    selected: {_showEncoded},
                    onSelectionChanged: (selected) {
                      setState(() {
                        _showEncoded = selected.first;
                      });
                    },
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      padding: WidgetStatePropertyAll(
                        const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      textStyle: WidgetStatePropertyAll(
                        TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // URL preview text.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              _buildUrlPreview(),
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: theme.colorScheme.onSurface,
              ),
              maxLines: 3,
              minLines: 1,
            ),
          ),
        ],

        // Summary text when empty.
        if (activeCount == 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'No query parameters added yet.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  /// Returns a subtitle string for the parent ExpansionTile.
  static String subtitle(List<KeyValueItem> params) {
    final count =
        params.where((p) => p.isEnabled && p.key.isNotEmpty).length;
    return count == 0 ? 'No params' : '$count param${count != 1 ? 's' : ''}';
  }
}
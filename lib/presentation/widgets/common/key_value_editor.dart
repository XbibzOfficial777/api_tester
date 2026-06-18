/// @file key_value_editor.dart
/// @brief Animated list editor for key-value pairs with per-row enable
/// toggles. Used for headers, query parameters, and form fields.
///
/// Each row exposes a [Switch] to enable/disable the entry, two text
/// fields for key and value, and a delete button. An "Add row" button
/// at the bottom appends a new blank entry.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_theme.dart';

/// A single key-value entry managed by [KeyValueEditor].
class KeyValueEntry {
  /// Unique identifier for this entry.
  String id;

  /// The key (header name, param name, etc.).
  String key;

  /// The value associated with [key].
  String value;

  /// Whether this entry is active and should be included in requests.
  bool isEnabled;

  /// Creates a [KeyValueEntry].
  KeyValueEntry({
    String? id,
    this.key = '',
    this.value = '',
    this.isEnabled = true,
  }) : id = id ?? const Uuid().v4();

  /// Creates a copy with optional field overrides.
  KeyValueEntry copyWith({
    String? id,
    String? key,
    String? value,
    bool? isEnabled,
  }) {
    return KeyValueEntry(
      id: id ?? this.id,
      key: key ?? this.key,
      value: value ?? this.value,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}

/// An animated, reusable editor for a list of [KeyValueEntry] items.
///
/// The editor displays each entry in a row with:
/// - A [Switch] to toggle [KeyValueEntry.isEnabled].
/// - A text field for [KeyValueEntry.key].
/// - A text field for [KeyValueEntry.value].
/// - A delete [IconButton].
///
/// New rows are appended via an "Add" button at the bottom.
///
/// Example:
/// ```dart
/// KeyValueEditor(
///   entries: headers,
///   onChanged: (updated) => setState(() => headers = updated),
///   keyHint: 'Header name',
///   valueHint: 'Header value',
/// )
/// ```
class KeyValueEditor extends StatefulWidget {
  /// The current list of key-value entries.
  final List<KeyValueEntry> entries;

  /// Callback invoked whenever the list changes (add, remove, edit, toggle).
  final ValueChanged<List<KeyValueEntry>> onChanged;

  /// Placeholder text for the key text field.
  final String keyHint;

  /// Placeholder text for the value text field.
  final String valueHint;

  /// Optional title displayed above the editor.
  final String? title;

  /// Creates a [KeyValueEditor].
  const KeyValueEditor({
    super.key,
    required this.entries,
    required this.onChanged,
    this.keyHint = 'Key',
    this.valueHint = 'Value',
    this.title,
  });

  @override
  State<KeyValueEditor> createState() => _KeyValueEditorState();
}

class _KeyValueEditorState extends State<KeyValueEditor> {
  late List<KeyValueEntry> _entries;

  @override
  void initState() {
    super.initState();
    _entries = List.of(widget.entries);
  }

  @override
  void didUpdateWidget(covariant KeyValueEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entries != widget.entries) {
      _entries = List.of(widget.entries);
    }
  }

  void _notifyChanged() {
    widget.onChanged(List.unmodifiable(_entries));
  }

  void _addEntry() {
    setState(() {
      _entries.add(KeyValueEntry());
    });
    _notifyChanged();
  }

  void _removeEntry(int index) {
    setState(() {
      _entries.removeAt(index);
    });
    _notifyChanged();
  }

  void _updateKey(int index, String key) {
    setState(() {
      _entries[index] = _entries[index].copyWith(key: key);
    });
    _notifyChanged();
  }

  void _updateValue(int index, String value) {
    setState(() {
      _entries[index] = _entries[index].copyWith(value: value);
    });
    _notifyChanged();
  }

  void _toggleEnabled(int index, bool enabled) {
    setState(() {
      _entries[index] = _entries[index].copyWith(isEnabled: enabled);
    });
    _notifyChanged();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Optional title row.
        if (widget.title != null) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              widget.title!,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],

        // List header labels.
        Padding(
          padding: const EdgeInsets.only(left: 48, bottom: 4),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  widget.keyHint,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  widget.valueHint,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(width: 36), // Space for delete button.
            ],
          ),
        ),

        // Entry rows.
        ...List.generate(_entries.length, (index) {
          final entry = _entries[index];
          return _KeyValueRow(
            entry: entry,
            keyHint: widget.keyHint,
            valueHint: widget.valueHint,
            onKeyChanged: (v) => _updateKey(index, v),
            onValueChanged: (v) => _updateValue(index, v),
            onEnabledChanged: (v) => _toggleEnabled(index, v),
            onDeleted: () => _removeEntry(index),
            isEnabled: entry.isEnabled,
          )
              .animate(
                key: ValueKey(entry.id),
              )
              .fadeIn(duration: 200.ms)
              .slideY(begin: 0.1, end: 0, duration: 200.ms);
        }),

        // Add button.
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _addEntry,
          icon: const Icon(Symbols.add, size: 18),
          label: Text('Add ${widget.keyHint.toLowerCase()}'),
        ),
      ],
    );
  }
}

/// A single row in the [KeyValueEditor] list.
class _KeyValueRow extends StatelessWidget {
  /// The entry being edited.
  final KeyValueEntry entry;

  /// Placeholder for the key field.
  final String keyHint;

  /// Placeholder for the value field.
  final String valueHint;

  /// Called when the key text changes.
  final ValueChanged<String> onKeyChanged;

  /// Called when the value text changes.
  final ValueChanged<String> onValueChanged;

  /// Called when the enable switch is toggled.
  final ValueChanged<bool> onEnabledChanged;

  /// Called when the delete button is pressed.
  final VoidCallback onDeleted;

  /// Whether this row's fields are currently enabled.
  final bool isEnabled;

  /// Creates a [_KeyValueRow].
  const _KeyValueRow({
    required this.entry,
    required this.keyHint,
    required this.valueHint,
    required this.onKeyChanged,
    required this.onValueChanged,
    required this.onEnabledChanged,
    required this.onDeleted,
    required this.isEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          // Enable / disable switch.
          SizedBox(
            width: 40,
            child: Switch(
              value: isEnabled,
              onChanged: onEnabledChanged,
              visualDensity: VisualDensity.compact,
            ),
          ),

          // Key field.
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: TextFormField(
                initialValue: entry.key,
                onChanged: onKeyChanged,
                enabled: isEnabled,
                decoration: InputDecoration(
                  hintText: keyHint,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                style: TextStyle(
                  fontSize: 13,
                  color: isEnabled
                      ? colorScheme.onSurface
                      : colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ),
          ),

          // Value field.
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: TextFormField(
                initialValue: entry.value,
                onChanged: onValueChanged,
                enabled: isEnabled,
                decoration: InputDecoration(
                  hintText: valueHint,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                style: TextStyle(
                  fontSize: 13,
                  color: isEnabled
                      ? colorScheme.onSurface
                      : colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ),
          ),

          // Delete button.
          IconButton(
            icon: Icon(
              Symbols.close,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            tooltip: 'Remove',
            onPressed: onDeleted,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }
}
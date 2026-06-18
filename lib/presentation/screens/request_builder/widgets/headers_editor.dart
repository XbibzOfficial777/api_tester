/// @file headers_editor.dart
/// @brief Headers section for the request builder.
///
/// Displays the request's header key-value pairs using the shared
/// [KeyValueEditor] widget (which uses [KeyValueEntry] internally).
/// Automatically manages a Content-Type header based on the current
/// body type, and shows the count of active headers.

library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:api_tester/domain/entities/api_request.dart';
import 'package:api_tester/domain/entities/key_value_item.dart';
import 'package:api_tester/presentation/providers/request_provider.dart';
import 'package:api_tester/presentation/widgets/common/key_value_editor.dart';

/// A collapsible section that manages the request's HTTP headers.
///
/// Pre-populates Content-Type based on the current [BodyType] when the
/// section is first expanded. Converts between domain [KeyValueItem] and
/// the widget-layer [KeyValueEntry] model.
class HeadersEditor extends ConsumerStatefulWidget {
  /// Creates a [HeadersEditor].
  const HeadersEditor({super.key});

  @override
  ConsumerState<HeadersEditor> createState() => _HeadersEditorState();
}

class _HeadersEditorState extends ConsumerState<HeadersEditor> {
  bool _initialised = false;

  /// Returns the default Content-Type for a given body type.
  String _contentTypeForBodyType(BodyType type) {
    switch (type) {
      case BodyType.none:
        return '';
      case BodyType.formData:
        return 'multipart/form-data';
      case BodyType.urlEncoded:
        return 'application/x-www-form-urlencoded';
      case BodyType.raw:
        return 'application/json';
      case BodyType.binary:
        return 'application/octet-stream';
    }
  }

  /// Ensures a Content-Type header matching the current body type exists.
  void _ensureContentType() {
    if (_initialised) return;
    _initialised = true;

    final formState = ref.read(currentRequestProvider);
    final ct = _contentTypeForBodyType(formState.bodyType);
    if (ct.isEmpty) return;

    final notifier = ref.read(currentRequestProvider.notifier);

    final existingIndex = formState.headers.indexWhere(
      (h) => h.key.toLowerCase() == 'content-type',
    );

    if (existingIndex >= 0) {
      final existing = formState.headers[existingIndex];
      if (existing.value != ct) {
        notifier.updateHeader(existingIndex, key: existing.key, value: ct);
      }
    } else {
      notifier.addHeader(key: 'Content-Type', value: ct);
    }
  }

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

  /// Converts widget [KeyValueEntry] list back to domain [KeyValueItem] list
  /// and syncs with the provider.
  void _syncFromEntries(List<KeyValueEntry> entries) {
    final notifier = ref.read(currentRequestProvider.notifier);
    final current = ref.read(currentRequestProvider);

    // Remove all existing headers.
    while (current.headers.isNotEmpty) {
      notifier.removeHeader(0);
    }

    // Re-add all from the entries.
    for (final entry in entries) {
      notifier.addHeader(key: entry.key, value: entry.value);
      // Toggle enabled state for each header.
      if (!entry.isEnabled) {
        // The most recently added header is at index (entries.indexOf(entry)).
        // Since we remove all first, the index matches.
        notifier.toggleHeaderEnabled(current.headers.length);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(currentRequestProvider);

    // Auto-populate Content-Type on first build.
    _ensureContentType();

    return KeyValueEditor(
      entries: _toEntries(formState.headers),
      keyHint: 'Header name',
      valueHint: 'Header value',
      onChanged: _syncFromEntries,
    );
  }

  /// Returns a subtitle string showing the count of active headers.
  static String subtitle(List<KeyValueItem> headers) {
    final count =
        headers.where((h) => h.isEnabled && h.key.isNotEmpty).length;
    return count == 0 ? 'No headers' : '$count header${count != 1 ? 's' : ''}';
  }
}
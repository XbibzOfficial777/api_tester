/// @file json_tree_view.dart
/// @brief Recursive, collapsible tree view for JSON data.
///
/// Renders parsed JSON into a tree of expandable/collapsible nodes.
/// Each node shows the key (if applicable), the value type, and the
/// value itself (for primitives). Types are colour-coded:
///
/// - **String** → green
/// - **Number** → blue
/// - **Boolean** → orange
/// - **null** → grey
/// - **Object/Array** → default text colour with children indented
///
/// Supports:
/// - Animated expand/collapse via [AnimationController]
/// - Copy-on-long-press for leaf values
/// - Search highlighting
/// - Line numbers

library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

// ---------------------------------------------------------------------------
// JSON Tree Node
// ---------------------------------------------------------------------------

/// Represents a single node in the JSON tree.
class _JsonNode {
  /// Display key (empty for the root node).
  final String key;

  /// The parsed value. May be a `Map`, `List`, or primitive.
  final dynamic value;

  /// Nesting depth (0 for root).
  final int depth;

  /// 1-based line number within the pretty-printed output.
  final int lineNumber;

  const _JsonNode({
    required this.key,
    required this.value,
    required this.depth,
    required this.lineNumber,
  });
}

// ---------------------------------------------------------------------------
// JSON Tree View Widget
// ---------------------------------------------------------------------------

/// A recursive, animated tree view for JSON data.
///
/// Provide either [jsonString] (a JSON-encoded string) or [jsonData]
/// (already-parsed `Map`/`List`). The tree will recursively render all
/// nested objects and arrays with collapsible nodes.
///
/// Use [searchQuery] to highlight matching keys and values in the tree.
class JsonTreeView extends StatefulWidget {
  /// A JSON-encoded string to display as a tree.
  final String? jsonString;

  /// Pre-parsed JSON data (takes precedence over [jsonString]).
  final dynamic jsonData;

  /// Optional search text – keys/values containing this substring will be
  /// highlighted.
  final String? searchQuery;

  /// Initial expanded depth (0 = all collapsed, 1 = first level expanded).
  /// Defaults to 2.
  final int initialExpandedDepth;

  /// Creates a [JsonTreeView].
  const JsonTreeView({
    super.key,
    this.jsonString,
    this.jsonData,
    this.searchQuery,
    this.initialExpandedDepth = 2,
  }) : assert(jsonString != null || jsonData != null);

  @override
  State<JsonTreeView> createState() => JsonTreeViewState();
}

class JsonTreeViewState extends State<JsonTreeView> {
  /// Controls which nodes are expanded. Keys are "$lineNumber".
  final Set<String> _expandedNodes = {};

  /// The root parsed JSON value.
  dynamic _root;

  @override
  void initState() {
    super.initState();
    _parseJson();
  }

  @override
  void didUpdateWidget(covariant JsonTreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.jsonString != widget.jsonString ||
        oldWidget.jsonData != widget.jsonData) {
      _parseJson();
    }
  }

  /// Parses the JSON input and pre-expands nodes to [initialExpandedDepth].
  void _parseJson() {
    try {
      _root = widget.jsonData ?? jsonDecode(widget.jsonString!);
    } catch (_) {
      _root = null;
    }

    // Pre-expand nodes up to the initial depth.
    if (_root != null) {
      _expandedNodes.clear();
      _preExpand(_root, 0, '');
    }
  }

  /// Recursively marks nodes for expansion up to [maxDepth].
  void _preExpand(dynamic value, int depth, String path) {
    if (depth >= widget.initialExpandedDepth) return;
    if (value is Map || value is List) {
      _expandedNodes.add(path);
      final items = value is Map
          ? value.entries.map((e) => MapEntry(e.key.toString(), e.value))
          : value.asMap().map((k, v) => MapEntry(k.toString(), v));
      for (final entry in items) {
        _preExpand(entry.value, depth + 1, '$path/${entry.key}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_root == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          widget.jsonString?.isNotEmpty == true
              ? 'Invalid JSON – cannot display tree view'
              : 'No data to display',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    return SingleChildScrollView(
      child: _buildNode(
        key: '',
        value: _root,
        depth: 0,
        lineNumber: 1,
        path: 'root',
        isLast: true,
      ),
    );
  }

  /// Recursively builds a tree node widget for [value].
  Widget _buildNode({
    required String key,
    required dynamic value,
    required int depth,
    required int lineNumber,
    required String path,
    required bool isLast,
  }) {
    final theme = Theme.of(context);
    final indent = depth * 24.0;
    final isExpanded = _expandedNodes.contains(path);
    final isContainer = value is Map || value is List;
    final query = widget.searchQuery?.toLowerCase();

    // Determine value text and colour for primitives.
    String? valueText;
    Color? valueColor;

    if (value is String) {
      valueText = '"$value"';
      valueColor = const Color(0xFF98C379); // green
    } else if (value is num) {
      valueText = value.toString();
      valueColor = const Color(0xFF61AFEF); // blue
    } else if (value is bool) {
      valueText = value.toString();
      valueColor = const Color(0xFFD19A66); // orange
    } else if (value == null) {
      valueText = 'null';
      valueColor = const Color(0xFFABB2BF); // grey
    }

    // Search highlighting helper.
    TextSpan _highlighted(String text, TextStyle baseStyle) {
      if (query == null || query.isEmpty || !text.toLowerCase().contains(query)) {
        return TextSpan(text: text, style: baseStyle);
      }
      // Split around matches.
      final spans = <TextSpan>[];
      final lower = text.toLowerCase();
      var lastEnd = 0;
      for (final match in query.allMatches(lower)) {
        if (match.start > lastEnd) {
          spans.add(TextSpan(text: text.substring(lastEnd, match.start), style: baseStyle));
        }
        spans.add(TextSpan(
          text: text.substring(match.start, match.end),
          style: baseStyle.copyWith(
            backgroundColor: const Color(0xFFFFEB3B).withOpacity(0.5),
          ),
        ));
        lastEnd = match.end;
      }
      if (lastEnd < text.length) {
        spans.add(TextSpan(text: text.substring(lastEnd), style: baseStyle));
      }
      return TextSpan(children: spans, style: baseStyle);
    }

    final children = <Widget>[];

    // Line number.
    children.add(
      SizedBox(
        width: 40,
        child: Text(
          '$lineNumber',
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'monospace',
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
            height: 1.6,
          ),
          textAlign: TextAlign.right,
        ),
      ),
    );

    // Expand/collapse arrow for containers.
    if (isContainer) {
      children.add(
        GestureDetector(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedNodes.remove(path);
              } else {
                _expandedNodes.add(path);
              }
            });
          },
          child: AnimatedRotation(
            turns: isExpanded ? 0.25 : 0,
            duration: const Duration(milliseconds: 200),
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                Symbols.expand_more,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    } else {
      children.add(const SizedBox(width: 22));
    }

    // Key label (skip for root).
    if (key.isNotEmpty) {
      final keyStr = isContainer ? '$key:' : '$key: ';
      children.add(
        Flexible(
          child: GestureDetector(
            onLongPress: valueText != null
                ? () {
                    Clipboard.setData(ClipboardData(text: value is String ? value.toString() : valueText!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Value copied'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                : null,
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'monospace',
                  height: 1.6,
                  color: theme.colorScheme.onSurface,
                ),
                children: [
                  _highlighted(keyStr, const TextStyle(
                    color: Color(0xFFE06C75), // red-ish for keys
                    fontWeight: FontWeight.w600,
                  )),
                  if (valueText != null)
                    _highlighted(valueText, TextStyle(color: valueColor)),
                ],
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ),
      );
    }

    // Container count badge.
    if (isContainer) {
      final count = value is Map ? value.length : (value as List).length;
      final typeLabel = value is Map ? 'Object' : 'Array';
      final summary = '$typeLabel {$count ${value is Map ? 'key' : 'item'}${count != 1 ? 's' : ''}}';
      children.add(
        Flexible(
          child: Text(
            ' $summary',
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
              height: 1.6,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    final row = Padding(
      padding: EdgeInsets.only(left: indent, top: 1, bottom: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );

    if (!isContainer) return row;

    // Build children when expanded.
    final childWidgets = <Widget>[];
    if (isExpanded) {
      final entries = value is Map
          ? value.entries.toList()
          : (value as List).asMap().entries.toList();

      var childLine = lineNumber + 1;
      for (var i = 0; i < entries.length; i++) {
        final entry = entries[i];
        final childKey = value is Map ? entry.key.toString() : entry.key.toString();
        final childPath = '$path/$childKey';
        childWidgets.add(
          _buildNode(
            key: childKey,
            value: entry.value,
            depth: depth + 1,
            lineNumber: childLine,
            path: childPath,
            isLast: i == entries.length - 1,
          ),
        );
        childLine += _countLines(entry.value);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        row,
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.topLeft,
          child: isExpanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: childWidgets,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  /// Approximates the number of pretty-printed lines a JSON value occupies.
  int _countLines(dynamic value) {
    if (value is Map || value is List) {
      int count = 2; // opening + closing braces
      final items = value is Map ? value.values : value;
      for (final item in items) {
        count += _countLines(item);
      }
      return count;
    }
    return 1;
  }
}
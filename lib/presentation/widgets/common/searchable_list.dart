/// @file searchable_list.dart
/// @brief Generic searchable list widget with real-time filtering.
///
/// Provides a search bar at the top and a filtered [ListView] below.
/// The generic type [T] allows reuse across workspaces, collections,
/// history entries, and any other list-based data.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/constants/app_constants.dart';
import 'empty_state_widget.dart';

/// A generic, reusable searchable list with a filter-as-you-type bar.
///
/// [T] is the item type. The caller supplies:
/// - [items] — the full list of items.
/// - [filterPredicate] — returns `true` when an item matches the query.
/// - [itemBuilder] — builds a widget for each visible item.
/// - [searchHint] — placeholder in the search field.
/// - [emptyMessage] — shown when no items match the query.
///
/// Example:
/// ```dart
/// SearchableList<Workspace>(
///   items: workspaces,
///   searchHint: 'Search workspaces…',
///   filterPredicate: (ws, query) => ws.name.toLowerCase().contains(query),
///   itemBuilder: (context, ws) => WorkspaceTile(workspace: ws),
///   emptyMessage: 'No workspaces found',
/// )
/// ```
class SearchableList<T> extends StatefulWidget {
  /// The full, unfiltered list of items.
  final List<T> items;

  /// Returns `true` when [item] should be included for the given [query].
  final bool Function(T item, String query) filterPredicate;

  /// Builds a widget for the given [item] at [index] in the filtered list.
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  /// Placeholder text in the search field.
  final String searchHint;

  /// Message shown when [items] is empty or nothing matches the query.
  final String emptyMessage;

  /// Optional subtitle for the empty state.
  final String? emptySubtitle;

  /// Icon for the empty state. Defaults to [Symbols.search_off].
  final IconData emptyIcon;

  /// Optional callback when the search query changes.
  final ValueChanged<String>? onQueryChanged;

  /// Optional trailing widget in the app bar / search bar row.
  final Widget? trailing;

  /// Whether to show the search bar. Defaults to `true`.
  final bool showSearchBar;

  /// Creates a [SearchableList].
  const SearchableList({
    super.key,
    required this.items,
    required this.filterPredicate,
    required this.itemBuilder,
    this.searchHint = 'Search…',
    this.emptyMessage = 'No items found',
    this.emptySubtitle,
    this.emptyIcon = Symbols.search_off,
    this.onQueryChanged,
    this.trailing,
    this.showSearchBar = true,
  });

  @override
  State<SearchableList<T>> createState() => _SearchableListState<T>();
}

class _SearchableListState<T> extends State<SearchableList<T>> {
  String _query = '';
  String _debouncedQuery = '';

  @override
  void initState() {
    super.initState();
    _query = '';
    _debouncedQuery = '';
  }

  /// Updates the raw query and triggers a debounced filter.
  void _onQueryChanged(String value) {
    setState(() => _query = value);
    widget.onQueryChanged?.call(value);

    // Simple debounce using a future.
    Future.delayed(
      const Duration(milliseconds: AppConstants.searchDebounceMs),
      () {
        if (mounted && _query == value) {
          setState(() => _debouncedQuery = value.toLowerCase().trim());
        }
      },
    );
  }

  /// Returns the filtered list of items.
  List<T> get _filteredItems {
    if (_debouncedQuery.isEmpty) return widget.items;
    return widget.items
        .where((item) => widget.filterPredicate(item, _debouncedQuery))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems;

    return Column(
      children: [
        // Search bar.
        if (widget.showSearchBar)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _SearchBar(
                    query: _query,
                    hint: widget.searchHint,
                    onChanged: _onQueryChanged,
                  ),
                ),
                if (widget.trailing != null) ...[
                  const SizedBox(width: 8),
                  widget.trailing!,
                ],
              ],
            ),
          ),

        // List or empty state.
        Expanded(
          child: filtered.isEmpty
              ? EmptyStateWidget(
                  icon: widget.emptyIcon,
                  title: widget.emptyMessage,
                  subtitle: widget.emptySubtitle,
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return widget.itemBuilder(context, filtered[index], index)
                        .animate(
                          key: ValueKey(filtered[index]),
                        )
                        .fadeIn(duration: 200.ms, delay: (index * 30).ms);
                  },
                ),
        ),
      ],
    );
  }
}

/// The search input field used by [SearchableList].
class _SearchBar extends StatelessWidget {
  /// Current query text.
  final String query;

  /// Placeholder hint.
  final String hint;

  /// Called when the user types.
  final ValueChanged<String> onChanged;

  /// Creates a [_SearchBar].
  const _SearchBar({
    required this.query,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Symbols.search, size: 20),
        suffixIcon: query.isNotEmpty
            ? IconButton(
                icon: const Icon(Symbols.close, size: 18),
                onPressed: () => onChanged(''),
              )
            : null,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}
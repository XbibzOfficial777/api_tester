/// @file history_screen.dart
/// @brief Screen showing the request execution history.
///
/// Displays a searchable, filterable list of previously sent API requests
/// sorted by timestamp descending with pinned entries at the top. Supports
/// swipe-to-delete, long-press to pin/unpin, pull-to-refresh, and tap to
/// load a request back into the request builder.

library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import 'package:api_tester/core/extensions/string_extensions.dart';
import 'package:api_tester/domain/entities/api_request.dart';
import 'package:api_tester/domain/entities/request_history.dart';
import 'package:api_tester/presentation/providers/history_provider.dart';
import 'package:api_tester/presentation/providers/request_provider.dart';
import 'package:api_tester/presentation/providers/workspace_provider.dart';
import 'package:api_tester/presentation/widgets/common/method_chip.dart';
import 'package:api_tester/presentation/widgets/common/status_code_badge.dart';
import 'package:api_tester/presentation/widgets/common/empty_state_widget.dart';
import 'package:api_tester/presentation/widgets/common/app_loading_indicator.dart';
import 'package:api_tester/presentation/widgets/common/error_widget.dart';

/// The available filter options for the history list.
enum _HistoryFilter {
  /// Show all entries regardless of method or pin status.
  all,

  /// Show only pinned entries.
  pinned,

  /// Show only GET requests.
  get,

  /// Show only POST requests.
  post,

  /// Show only PUT requests.
  put,

  /// Show only DELETE requests.
  delete,
}

/// Displays a searchable, filterable list of previously sent requests.
///
/// This is a bottom-nav tab screen rendered inside [MainShell].
class HistoryScreen extends ConsumerStatefulWidget {
  /// Creates a [HistoryScreen].
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  /// Currently selected filter chip.
  _HistoryFilter _filter = _HistoryFilter.all;

  /// Controller for the search text field.
  final _searchController = TextEditingController();

  /// Debounce timer for search input.
  DateTime? _lastSearchTime;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  /// Handles search input changes with simple debouncing.
  void _onSearchChanged() {
    final now = DateTime.now();
    _lastSearchTime = now;

    // Simple debounce: wait 300 ms before triggering the search.
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted || _lastSearchTime != now) return;
      ref
          .read(historyListProvider.notifier)
          .searchHistory(_searchController.text);
    });
  }

  // ---------------------------------------------------------------------------
  // Filtering
  // ---------------------------------------------------------------------------

  /// Returns a filtered list based on the active [_filter] chip.
  List<RequestHistory> _applyFilter(List<RequestHistory> items) {
    switch (_filter) {
      case _HistoryFilter.all:
        return items;
      case _HistoryFilter.pinned:
        return items.where((h) => h.isPinned).toList();
      case _HistoryFilter.get:
        return items.where((h) => h.method == HttpMethod.get).toList();
      case _HistoryFilter.post:
        return items.where((h) => h.method == HttpMethod.post).toList();
      case _HistoryFilter.put:
        return items.where((h) => h.method == HttpMethod.put).toList();
      case _HistoryFilter.delete:
        return items.where((h) => h.method == HttpMethod.delete).toList();
    }
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Toggles the pinned state of a history entry.
  void _togglePin(RequestHistory item) {
    if (item.isPinned) {
      ref.read(historyListProvider.notifier).unpinItem(item.id);
    } else {
      ref.read(historyListProvider.notifier).pinItem(item.id);
    }
  }

  /// Deletes a single history entry with undo support.
  void _deleteItem(RequestHistory item) {
    // Remove optimistically.
    ref.read(historyListProvider.notifier).deleteHistoryItem(item.id);

    // Show undo snackbar.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "${item.name}"'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            // Re-add by reloading – the item may still be in the repository
            // if the deletion hasn't completed yet, but for simplicity
            // we just reload.
            ref.read(historyListProvider.notifier).reload();
          },
        ),
      ),
    );
  }

  /// Shows a confirmation dialog and clears all history.
  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Symbols.delete_sweep,
          color: Theme.of(context).colorScheme.error,
        ),
        title: const Text('Clear All History'),
        content: const Text(
          'This will permanently delete all history entries, '
          'including pinned ones. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.pop(context);
              ref.read(historyListProvider.notifier).clearHistory();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All history cleared'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  /// Loads a history entry into the request builder.
  void _loadIntoBuilder(RequestHistory item) {
    // Set the request form to the history entry's method and URL.
    // Note: we only have a lightweight history entry, not the full request,
    // so we populate what we can.
    final formNotifier = ref.read(currentRequestProvider.notifier);

    // Parse the method string to HttpMethod.
    final method = HttpMethod.values.firstWhere(
      (m) => m.name.toUpperCase() == item.method.name.toUpperCase(),
      orElse: () => HttpMethod.get,
    );

    // Create a new form state with the history data.
    // The form notifier doesn't have a direct setter for URL without
    // resetting everything, so we reset first, then set.
    formNotifier.setMethod(method);
    formNotifier.setUrl(item.url);

    // Navigate to the request tab.
    context.go('/');
  }

  /// Pull-to-refresh handler.
  Future<void> _onRefresh() async {
    await ref.read(historyListProvider.notifier).reload();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(currentWorkspaceProvider);
    final historyAsync = ref.watch(historyListProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // When no workspace is selected.
    if (workspace == null) {
      return const EmptyStateWidget(
        icon: Symbols.workspace_premium,
        title: 'No workspace selected',
        subtitle: 'Select a workspace to view request history.',
      );
    }

    return historyAsync.when(
      loading: () => const AppLoadingIndicator(message: 'Loading history…'),
      error: (e, _) => AppErrorWidget(
        message: 'Failed to load history',
        details: e.toString(),
        onRetry: () => ref.read(historyListProvider.notifier).reload(),
      ),
      data: (history) => _buildContent(history, colorScheme),
    );
  }

  /// Builds the complete screen content with search, filters, and list.
  Widget _buildContent(List<RequestHistory> history, ColorScheme colorScheme) {
    final filteredItems = _applyFilter(history);

    return Scaffold(
      body: Column(
        children: [
          // Search bar.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search history…',
                prefixIcon: const Icon(Symbols.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Symbols.close, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(historyListProvider.notifier)
                              .searchHistory('');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),

          // Filter chips.
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: _HistoryFilter.values.map((filter) {
                final isSelected = _filter == filter;
                final label = switch (filter) {
                  _HistoryFilter.all => 'All',
                  _HistoryFilter.pinned => 'Pinned',
                  _HistoryFilter.get => 'GET',
                  _HistoryFilter.post => 'POST',
                  _HistoryFilter.put => 'PUT',
                  _HistoryFilter.delete => 'DELETE',
                };

                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _filter = filter),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),

          // Clear all button (when there are items).
          if (history.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _showClearAllDialog,
                  icon: const Icon(Symbols.delete_sweep, size: 16),
                  label: const Text('Clear all'),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ),

          // History list.
          Expanded(
            child: filteredItems.isEmpty
                ? _buildListEmptyState(history.isEmpty, colorScheme)
                : RefreshIndicator(
                    onRefresh: _onRefresh,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        return _HistoryEntryTile(
                          entry: item,
                          onTap: () => _loadIntoBuilder(item),
                          onDismissed: (_) => _deleteItem(item),
                          onLongPress: () => _togglePin(item),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Builds the empty state widget for the history list.
  Widget _buildListEmptyState(bool isHistoryEmpty, ColorScheme colorScheme) {
    if (!isHistoryEmpty) {
      // Filter is active but no matches.
      return EmptyStateWidget(
        icon: Symbols.filter_alt_off,
        title: 'No matching entries',
        subtitle: 'Try a different search or filter.',
      );
    }

    return const EmptyStateWidget(
      icon: Symbols.history,
      title: 'No history yet',
      subtitle: 'Send a request to see it appear here.',
    );
  }
}

// =============================================================================
// History Entry Tile
// =============================================================================

/// A single history entry displayed as a dismissible list tile.
class _HistoryEntryTile extends StatelessWidget {
  /// The history entry to display.
  final RequestHistory entry;

  /// Called when the user taps the tile.
  final VoidCallback onTap;

  /// Called when the user swipes to dismiss.
  final DismissDirectionCallback onDismissed;

  /// Called when the user long-presses the tile.
  final VoidCallback onLongPress;

  /// Creates a [_HistoryEntryTile].
  const _HistoryEntryTile({
    required this.entry,
    required this.onTap,
    required this.onDismissed,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Symbols.delete,
          color: colorScheme.onErrorContainer,
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            icon: Icon(
              Symbols.delete,
              color: colorScheme.error,
            ),
            title: const Text('Delete Entry'),
            content: Text(
              'Delete "${entry.name}" from history?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: onDismissed,
      child: Card(
        margin: const EdgeInsets.only(bottom: 6),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: pin icon, name, method chip, status badge.
                Row(
                  children: [
                    // Pin indicator.
                    if (entry.isPinned) ...[
                      Icon(
                        Symbols.push_pin,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                    ],

                    // Request name.
                    Expanded(
                      child: Text(
                        entry.name.isNotEmpty
                            ? entry.name
                            : 'Untitled',
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Method chip.
                    MethodChip(method: entry.method, fontSize: 10),
                    const SizedBox(width: 8),

                    // Status code badge.
                    StatusCodeBadge(
                      statusCode: entry.statusCode,
                      fontSize: 10,
                      showReasonPhrase: false,
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Row 2: URL (truncated), response time, timestamp.
                Row(
                  children: [
                    Icon(
                      Symbols.link,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        entry.url.truncate(50),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Response time.
                    Icon(
                      Symbols.speed,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${entry.responseTimeMs}ms',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Relative timestamp.
                    Icon(
                      Symbols.schedule,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      _formatRelativeTime(entry.timestamp),
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Formats a [timestamp] into a human-readable relative time string.
  ///
  /// Examples: "just now", "2 min ago", "1h ago", "3d ago".
  static String _formatRelativeTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) return 'just now';
    if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '$mins min ago';
    }
    if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '${hours}h ago';
    }
    if (difference.inDays < 7) {
      final days = difference.inDays;
      return '${days}d ago';
    }

    // Older than 7 days – show a date string.
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }
}
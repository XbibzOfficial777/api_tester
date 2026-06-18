/// @file collections_screen.dart
/// @brief Main collections list screen displayed in the bottom navigation.
///
/// Shows all collections in the current workspace with a FAB for creating
/// new collections. Each collection card displays its name, description,
/// request count, and provides actions for editing, running, and deleting.

library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import 'package:api_tester/domain/entities/collection.dart';
import 'package:api_tester/presentation/providers/collection_provider.dart';
import 'package:api_tester/presentation/providers/workspace_provider.dart';
import 'package:api_tester/presentation/widgets/common/empty_state_widget.dart';
import 'package:api_tester/presentation/widgets/common/app_loading_indicator.dart';
import 'package:api_tester/presentation/widgets/common/error_widget.dart';

/// Displays all collections in the current workspace as a navigable list.
///
/// This is a bottom-nav tab screen rendered inside [MainShell].
class CollectionsScreen extends ConsumerWidget {
  /// Creates a [CollectionsScreen].
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(currentWorkspaceProvider);
    final collectionsAsync = ref.watch(collectionListProvider);

    // When no workspace is selected, prompt the user.
    if (workspace == null) {
      return const EmptyStateWidget(
        icon: Symbols.workspace_premium,
        title: 'No workspace selected',
        subtitle: 'Create or select a workspace to manage collections.',
      );
    }

    return collectionsAsync.when(
      loading: () => const AppLoadingIndicator(message: 'Loading collections…'),
      error: (e, _) => AppErrorWidget(
        message: 'Failed to load collections',
        details: e.toString(),
        onRetry: () => ref.read(collectionListProvider.notifier).reload(),
      ),
      data: (collections) => _CollectionsContent(collections: collections),
    );
  }
}

/// Internal stateful widget that manages the collection list UI.
class _CollectionsContent extends ConsumerStatefulWidget {
  /// The list of collections to display.
  final List<Collection> collections;

  /// Creates a [_CollectionsContent].
  const _CollectionsContent({required this.collections});

  @override
  ConsumerState<_CollectionsContent> createState() => _CollectionsContentState();
}

class _CollectionsContentState extends ConsumerState<_CollectionsContent> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (widget.collections.isEmpty) {
      return EmptyStateWidget(
        icon: Symbols.folder_off,
        title: 'No collections yet',
        subtitle: 'Create your first collection to group and run API requests.',
        actionLabel: 'Create Collection',
        onAction: _showCreateDialog,
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Import button row.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Text(
                    '${widget.collections.length} collection${widget.collections.length != 1 ? 's' : ''}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => context.push('/import'),
                    icon: const Icon(Symbols.file_upload, size: 16),
                    label: const Text('Import'),
                  ),
                ],
              ),
            ),
          ),

          // Collection cards.
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final collection = widget.collections[index];
                  return _CollectionCard(
                    collection: collection,
                    onTap: () => context
                        .push('/collection/edit/${collection.id}'),
                    onRun: () => context
                        .push('/collection/runner/${collection.id}'),
                    onLongPress: () => _showDeleteDialog(collection),
                  );
                },
                childCount: widget.collections.length,
              ),
            ),
          ),

          // Bottom padding.
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        tooltip: 'New Collection',
        child: const Icon(Symbols.create_new_folder),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Create collection
  // ---------------------------------------------------------------------------

  /// Shows a dialog to create a new collection.
  void _showCreateDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Symbols.create_new_folder),
        title: const Text('New Collection'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value?.trim().isEmpty ?? true) {
                    return 'Name is required';
                  }
                  return null;
                },
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. User API Tests',
                  prefixIcon: Icon(Symbols.edit, size: 20),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descriptionController,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'What does this collection test?',
                  prefixIcon: Icon(Symbols.notes, size: 20),
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final name = nameController.text.trim();
              final description = descriptionController.text.trim();

              Navigator.pop(context);

              final created = await ref
                  .read(collectionListProvider.notifier)
                  .createCollection(
                    name: name,
                    description: description,
                  );

              if (created != null && mounted) {
                context.push('/collection/edit/${created.id}');
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Delete collection
  // ---------------------------------------------------------------------------

  /// Shows a confirmation dialog before deleting a collection.
  void _showDeleteDialog(Collection collection) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Symbols.delete,
          color: Theme.of(context).colorScheme.error,
        ),
        title: const Text('Delete Collection'),
        content: Text(
          'Are you sure you want to delete "${collection.name}"? '
          'The individual requests will NOT be deleted.',
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
              ref
                  .read(collectionListProvider.notifier)
                  .deleteCollection(collection.id);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('"${collection.name}" deleted'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Collection Card
// =============================================================================

/// A card widget representing a single collection in the list.
class _CollectionCard extends StatelessWidget {
  /// The collection to display.
  final Collection collection;

  /// Called when the user taps the card (navigate to editor).
  final VoidCallback onTap;

  /// Called when the user taps the run button.
  final VoidCallback onRun;

  /// Called when the user long-presses the card (delete action).
  final VoidCallback onLongPress;

  /// Creates a [_CollectionCard].
  const _CollectionCard({
    required this.collection,
    required this.onTap,
    required this.onRun,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final requestCount = collection.requestIds.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: icon, name, run button.
              Row(
                children: [
                  Icon(
                    Symbols.folder,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      collection.name,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Run button.
                  IconButton.filledTonal(
                    icon: const Icon(Symbols.play_arrow, size: 18),
                    tooltip: 'Run collection',
                    onPressed: onRun,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(36, 36),
                      maximumSize: const Size(36, 36),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),

              // Row 2: description (if any).
              if (collection.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  collection.description,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Row 3: request count, delay, stop-on-error badges.
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  // Request count badge.
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Symbols.request_quote,
                          size: 13,
                          color: colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$requestCount request${requestCount != 1 ? 's' : ''}',
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Delay badge (if > 0).
                  if (collection.delayBetweenRequestsMs > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Symbols.timer,
                            size: 13,
                            color: colorScheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${collection.delayBetweenRequestsMs}ms delay',
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Stop on error badge.
                  if (collection.stopOnError)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Symbols.block,
                            size: 13,
                            color: colorScheme.onTertiaryContainer,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Stop on error',
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onTertiaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
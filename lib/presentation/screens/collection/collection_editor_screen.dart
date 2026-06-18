/// @file collection_editor_screen.dart
/// @brief Screen for editing an existing collection.
///
/// Allows the user to change the collection name and description, reorder
/// requests via drag-and-drop ([ReorderableListView]), add requests from the
/// current workspace, remove individual requests, and configure the delay
/// and stop-on-error settings.

library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import 'package:api_tester/core/di/injection.dart';
import 'package:api_tester/core/extensions/string_extensions.dart';
import 'package:api_tester/domain/entities/api_request.dart';
import 'package:api_tester/domain/entities/collection.dart';
import 'package:api_tester/domain/repositories/collection_repository.dart';
import 'package:api_tester/domain/repositories/request_repository.dart';
import 'package:api_tester/presentation/providers/collection_provider.dart';
import 'package:api_tester/presentation/widgets/common/method_chip.dart';
import 'package:api_tester/presentation/widgets/common/app_loading_indicator.dart';
import 'package:api_tester/presentation/widgets/common/error_widget.dart';

/// Allows users to edit an existing collection's metadata and request list.
///
/// Requires a [collectionId] that identifies the collection to edit.
class CollectionEditorScreen extends ConsumerStatefulWidget {
  /// ID of the collection to edit.
  final String collectionId;

  /// Creates a [CollectionEditorScreen].
  const CollectionEditorScreen({super.key, required this.collectionId});

  @override
  ConsumerState<CollectionEditorScreen> createState() =>
      _CollectionEditorScreenState();
}

class _CollectionEditorScreenState
    extends ConsumerState<CollectionEditorScreen> {
  // ---------------------------------------------------------------------------
  // Form controllers
  // ---------------------------------------------------------------------------

  /// Controller for the collection name text field.
  final _nameController = TextEditingController();

  /// Controller for the description text field.
  final _descriptionController = TextEditingController();

  /// Form key for validation.
  final _formKey = GlobalKey<FormState>();

  // ---------------------------------------------------------------------------
  // Local state
  // ---------------------------------------------------------------------------

  /// The collection being edited, loaded from the repository.
  Collection? _collection;

  /// Requests currently in the collection, in display order.
  List<ApiRequest> _collectionRequests = [];

  /// All requests available in the current workspace (for the add picker).
  List<ApiRequest> _workspaceRequests = [];

  /// Local delay value (ms).
  int _delayMs = 0;

  /// Local stop-on-error toggle.
  bool _stopOnError = false;

  /// Whether the initial data is loading.
  bool _isLoading = true;

  /// Error message if loading failed.
  String? _loadError;

  /// Whether a save operation is in progress.
  bool _isSaving = false;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Loads the collection and its requests from repositories.
  Future<void> _loadData() async {
    try {
      final collectionRepo = getIt<CollectionRepository>();
      final requestRepo = getIt<RequestRepository>();

      final collection =
          await collectionRepo.getCollection(widget.collectionId);
      final collectionReqs =
          await requestRepo.getRequestsByCollection(widget.collectionId);

      // Load all workspace requests for the "add request" picker.
      final workspaceReqs =
          await requestRepo.getRequestsByWorkspace(collection.workspaceId);

      if (mounted) {
        setState(() {
          _collection = collection;
          _collectionRequests = collectionReqs;
          _workspaceRequests = workspaceReqs;
          _delayMs = collection.delayBetweenRequestsMs;
          _stopOnError = collection.stopOnError;

          // Populate form controllers.
          _nameController.text = collection.name;
          _descriptionController.text = collection.description;

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Validates the form and persists changes.
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_collection == null) return;

    setState(() => _isSaving = true);

    try {
      final updated = _collection!.copyWith(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        delayBetweenRequestsMs: _delayMs,
        stopOnError: _stopOnError,
        updatedAt: DateTime.now(),
      );

      await ref
          .read(collectionListProvider.notifier)
          .updateCollection(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Collection saved'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Shows a dialog to pick a request from the workspace to add.
  void _showAddRequestDialog() {
    // Exclude requests already in the collection.
    final existingIds = _collectionRequests.map((r) => r.id).toSet();
    final available = _workspaceRequests
        .where((r) => !existingIds.contains(r.id))
        .toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No more requests available to add'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(16),
            ),
          ),
          child: Column(
            children: [
              // Drag handle.
              Padding(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      'Add Request',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      '${available.length} available',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: available.length,
                  itemBuilder: (context, index) {
                    final req = available[index];
                    return ListTile(
                      leading: MethodChip(method: req.method, fontSize: 10),
                      title: Text(
                        req.name.isNotEmpty ? req.name : 'Untitled',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        req.url.truncate(50),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      trailing: const Icon(Symbols.add, size: 20),
                      onTap: () async {
                        Navigator.pop(context);
                        await _addRequest(req.id);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Adds a request to the collection and refreshes the list.
  Future<void> _addRequest(String requestId) async {
    try {
      await ref
          .read(collectionListProvider.notifier)
          .addRequestToCollection(widget.collectionId, requestId);

      // Reload the collection requests list.
      final requestRepo = getIt<RequestRepository>();
      final updated = await requestRepo.getRequestsByCollection(
        widget.collectionId,
      );

      if (mounted) {
        setState(() => _collectionRequests = updated);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request added to collection'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add request: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Removes a request from the collection.
  Future<void> _removeRequest(String requestId) async {
    try {
      await ref
          .read(collectionListProvider.notifier)
          .removeRequestFromCollection(widget.collectionId, requestId);

      // Update local state.
      setState(() {
        _collectionRequests =
            _collectionRequests.where((r) => r.id != requestId).toList();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request removed from collection'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove request: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Handles request reordering within the collection.
  Future<void> _onReorder(int oldIndex, int newIndex) async {
    // Adjust index when dragging down (ReorderableListView inserts before).
    if (oldIndex < newIndex) newIndex--;

    // Update local state optimistically.
    final updatedList = List<ApiRequest>.from(_collectionRequests);
    final item = updatedList.removeAt(oldIndex);
    updatedList.insert(newIndex, item);
    setState(() => _collectionRequests = updatedList);

    // Persist the new order.
    try {
      final newOrder = updatedList.map((r) => r.id).toList();
      final collectionRepo = getIt<CollectionRepository>();
      await collectionRepo.reorderRequests(widget.collectionId, newOrder);
    } catch (e) {
      // Revert on failure.
      if (mounted) {
        setState(() {
          _collectionRequests = List<ApiRequest>.from(
            _collectionRequests..removeAt(newIndex)..insert(oldIndex, item),
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reorder: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Collection'),
        actions: [
          // Run button – opens the collection runner.
          IconButton(
            icon: const Icon(Symbols.play_arrow),
            tooltip: 'Run collection',
            onPressed: () =>
                context.push('/collection/runner/${widget.collectionId}'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const AppLoadingIndicator(message: 'Loading collection…')
          : _loadError != null
              ? AppErrorWidget(
                  message: 'Failed to load collection',
                  details: _loadError,
                  onRetry: _loadData,
                )
              : _buildForm(colorScheme),
      bottomNavigationBar: _buildBottomBar(colorScheme),
    );
  }

  /// Builds the main scrollable form content.
  Widget _buildForm(ColorScheme colorScheme) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Collection name.
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isEmpty) return 'Name is required';
              return null;
            },
            decoration: const InputDecoration(
              labelText: 'Collection Name',
              hintText: 'e.g. User API Tests',
              prefixIcon: Icon(Symbols.edit, size: 20),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Description.
          TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              hintText: 'Describe what this collection tests…',
              prefixIcon: Icon(Symbols.notes, size: 20),
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

          // -----------------------------------------------------------------
          // Requests section header
          // -----------------------------------------------------------------
          Row(
            children: [
              Text(
                'Requests',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              Text(
                '${_collectionRequests.length} request${_collectionRequests.length != 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: _showAddRequestDialog,
                icon: const Icon(Symbols.add, size: 16),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Reorderable request list.
          _collectionRequests.isEmpty
              ? _buildEmptyRequests(colorScheme)
              : ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  onReorder: _onReorder,
                  children: [
                    for (int i = 0; i < _collectionRequests.length; i++)
                      _buildRequestTile(_collectionRequests[i], i, colorScheme),
                  ],
                ),

          const SizedBox(height: 24),

          // -----------------------------------------------------------------
          // Configuration section
          // -----------------------------------------------------------------
          Text(
            'Configuration',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),

          // Delay slider.
          Row(
            children: [
              Icon(
                Symbols.timer,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Delay between requests: ${_delayMs}ms',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          Slider(
            value: _delayMs.toDouble(),
            min: 0,
            max: 10000,
            divisions: 100,
            label: '${_delayMs}ms',
            onChanged: (v) => setState(() => _delayMs = v.round()),
          ),

          // Stop on error toggle.
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Stop on error',
                style: Theme.of(context).textTheme.bodyMedium),
            subtitle: Text(
              'Abort the run if any request fails',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            value: _stopOnError,
            onChanged: (v) => setState(() => _stopOnError = v),
          ),

          // Bottom padding for the save button area.
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  /// Builds a tile for a single request in the collection.
  Widget _buildRequestTile(
    ApiRequest request,
    int index,
    ColorScheme colorScheme,
  ) {
    return Card(
      key: ValueKey(request.id),
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            // Drag handle.
            ReorderableDragStartListener(
              index: index,
              child: Icon(
                Symbols.drag_handle,
                color: colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),

            // Index number.
            Text(
              '${index + 1}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(width: 8),

            // Method chip.
            MethodChip(method: request.method, fontSize: 10),
            const SizedBox(width: 8),

            // Request name and URL.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.name.isNotEmpty ? request.name : 'Untitled',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    request.url.truncate(50),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Remove button.
            IconButton(
              icon: Icon(
                Symbols.close,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              tooltip: 'Remove from collection',
              onPressed: () => _removeRequest(request.id),
            ),
          ],
        ),
      ),
    );
  }

  /// Empty state for the requests list.
  Widget _buildEmptyRequests(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Symbols.list_alt_add,
            size: 40,
            color: colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            'No requests in this collection',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap "Add" to include requests from this workspace.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  /// Builds the bottom bar with Save and Cancel buttons.
  Widget _buildBottomBar(ColorScheme colorScheme) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            top: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        child: Row(
          children: [
            // Cancel button.
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving ? null : () => context.pop(),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),

            // Save button.
            Expanded(
              child: FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
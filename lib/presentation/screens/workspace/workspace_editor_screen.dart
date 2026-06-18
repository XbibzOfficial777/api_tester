/// @file workspace_editor_screen.dart
/// @brief Screen for creating or editing a workspace.
///
/// Provides a form with a required name field and optional description.
/// In edit mode, a destructive "Delete Workspace" button is displayed at
/// the bottom with a confirmation dialog. On save, the workspace is
/// persisted via [WorkspaceListNotifier] and the user is navigated back.

library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import 'package:api_tester/core/di/injection.dart';
import 'package:api_tester/domain/entities/workspace.dart';
import 'package:api_tester/domain/repositories/workspace_repository.dart';
import 'package:api_tester/presentation/providers/workspace_provider.dart';
import 'package:api_tester/presentation/widgets/common/app_loading_indicator.dart';
import 'package:api_tester/presentation/widgets/common/error_widget.dart';

/// Allows users to create a new workspace or edit an existing one.
///
/// When [workspaceId] is `null`, the screen operates in "create" mode.
/// When provided, it loads the existing workspace for editing.
class WorkspaceEditorScreen extends ConsumerStatefulWidget {
  /// Optional ID of the workspace to edit. `null` for create mode.
  final String? workspaceId;

  /// Creates a [WorkspaceEditorScreen].
  const WorkspaceEditorScreen({super.key, this.workspaceId});

  @override
  ConsumerState<WorkspaceEditorScreen> createState() =>
      _WorkspaceEditorScreenState();
}

class _WorkspaceEditorScreenState extends ConsumerState<WorkspaceEditorScreen> {
  // ---------------------------------------------------------------------------
  // Controllers
  // ---------------------------------------------------------------------------

  /// Controller for the workspace name field.
  final _nameController = TextEditingController();

  /// Controller for the description field.
  final _descriptionController = TextEditingController();

  /// Form key for validation.
  final _formKey = GlobalKey<FormState>();

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  /// The workspace being edited (null in create mode).
  Workspace? _workspace;

  /// Whether the initial data is loading.
  bool _isLoading = false;

  /// Error message if loading failed.
  String? _loadError;

  /// Whether a save operation is in progress.
  bool _isSaving = false;

  /// Whether this is edit mode (vs. create mode).
  bool get _isEditMode => widget.workspaceId != null;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _loadWorkspace();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Loads the workspace from the repository in edit mode.
  Future<void> _loadWorkspace() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final repo = getIt<WorkspaceRepository>();
      final workspace = await repo.getWorkspace(widget.workspaceId!);

      if (mounted) {
        setState(() {
          _workspace = workspace;
          _nameController.text = workspace.name;
          _descriptionController.text = workspace.description ?? '';
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

  /// Validates the form and saves the workspace.
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();
      final description = _descriptionController.text.trim();

      if (_isEditMode && _workspace != null) {
        // Update existing workspace.
        final updated = _workspace!.copyWith(
          name: name,
          description: description.isNotEmpty ? description : null,
          updatedAt: DateTime.now(),
        );
        await ref.read(workspaceListProvider.notifier).updateWorkspace(updated);
      } else {
        // Create new workspace.
        final created = await ref
            .read(workspaceListProvider.notifier)
            .createWorkspace(name: name, description: description);

        // Set the new workspace as current.
        if (created != null) {
          ref.read(currentWorkspaceProvider.notifier).state = created;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditMode ? 'Workspace updated' : 'Workspace created',
            ),
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

  /// Shows a confirmation dialog and deletes the workspace.
  void _showDeleteDialog() {
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Symbols.delete,
          color: colorScheme.error,
        ),
        title: const Text('Delete Workspace'),
        content: Text(
          'Are you sure you want to delete "${_workspace?.name}"? '
          'All collections, requests, environments, and history in this '
          'workspace will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(context);

              try {
                await ref
                    .read(workspaceListProvider.notifier)
                    .deleteWorkspace(widget.workspaceId!);

                // Clear the current workspace if it was the deleted one.
                if (ref.read(currentWorkspaceProvider)?.id ==
                    widget.workspaceId) {
                  ref.read(currentWorkspaceProvider.notifier).state = null;
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Workspace deleted'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  context.pop();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete: $e'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Workspace' : 'New Workspace'),
      ),
      body: _isLoading
          ? const AppLoadingIndicator(message: 'Loading workspace…')
          : _loadError != null
              ? AppErrorWidget(
                  message: 'Failed to load workspace',
                  details: _loadError,
                  onRetry: _loadWorkspace,
                )
              : _buildForm(),
      bottomNavigationBar: _isEditMode
          ? _buildEditBottomBar()
          : _buildCreateBottomBar(),
    );
  }

  /// Builds the main form content.
  Widget _buildForm() {
    final colorScheme = Theme.of(context).colorScheme;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Workspace icon/illustration.
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Symbols.workspace_premium,
                size: 40,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Name field.
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            autofocus: !_isEditMode,
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isEmpty) return 'Workspace name is required';
              if (trimmed.length < 2) {
                return 'Name must be at least 2 characters';
              }
              return null;
            },
            decoration: const InputDecoration(
              labelText: 'Workspace Name',
              hintText: 'e.g. My Project API',
              prefixIcon: Icon(Symbols.edit, size: 20),
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),

          // Description field.
          TextFormField(
            controller: _descriptionController,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              hintText:
                  'Describe the purpose of this workspace, the API being tested, etc.',
              prefixIcon: Icon(Symbols.notes, size: 20),
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),

          // Extra spacing for the bottom bar.
          if (_isEditMode) const SizedBox(height: 100),
        ],
      ),
    );
  }

  /// Builds the bottom bar for create mode with Save only.
  Widget _buildCreateBottomBar() {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            top: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        child: FilledButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Symbols.check, size: 18),
          label: Text(_isSaving ? 'Saving…' : 'Create Workspace'),
        ),
      ),
    );
  }

  /// Builds the bottom bar for edit mode with Save and Delete.
  Widget _buildEditBottomBar() {
    final colorScheme = Theme.of(context).colorScheme;

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
            // Delete button.
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showDeleteDialog,
                icon: Icon(
                  Symbols.delete,
                  size: 18,
                  color: colorScheme.error,
                ),
                label: Text(
                  'Delete',
                  style: TextStyle(color: colorScheme.error),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colorScheme.error),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Save button.
            Expanded(
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Symbols.check, size: 18),
                label: Text(_isSaving ? 'Saving…' : 'Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
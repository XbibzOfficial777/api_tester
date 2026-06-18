/// @file environment_editor_screen.dart
/// @brief Screen for editing environment variables.
///
/// Provides a form to manage an environment's name and global flag, plus a
/// dynamic list of key-value variables with type selectors and enable
/// toggles. Includes a "Set from Response" feature that allows extracting
/// values from JSON response bodies using JSON path expressions.

library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import 'package:api_tester/core/di/injection.dart';
import 'package:api_tester/domain/entities/environment.dart';
import 'package:api_tester/domain/entities/environment_variable.dart';
import 'package:api_tester/domain/repositories/environment_repository.dart';
import 'package:api_tester/presentation/providers/environment_provider.dart';
import 'package:api_tester/presentation/providers/request_provider.dart';
import 'package:api_tester/presentation/widgets/common/app_loading_indicator.dart';
import 'package:api_tester/presentation/widgets/common/error_widget.dart';

/// Allows users to manage key-value variables scoped to a workspace.
///
/// When [environmentId] is provided, the environment is loaded for editing.
/// When `null`, the screen operates in create mode.
class EnvironmentEditorScreen extends ConsumerStatefulWidget {
  /// Optional ID of the environment to edit. `null` for create mode.
  final String? environmentId;

  /// Creates an [EnvironmentEditorScreen].
  const EnvironmentEditorScreen({super.key, this.environmentId});

  @override
  ConsumerState<EnvironmentEditorScreen> createState() =>
      _EnvironmentEditorScreenState();
}

class _EnvironmentEditorScreenState
    extends ConsumerState<EnvironmentEditorScreen> {
  // ---------------------------------------------------------------------------
  // Controllers
  // ---------------------------------------------------------------------------

  /// Controller for the environment name field.
  final _nameController = TextEditingController();

  /// Controller for the JSON path input (Set from Response).
  final _jsonPathController = TextEditingController();

  /// Controller for new variable key.
  final _newKeyController = TextEditingController();

  /// Controller for new variable value.
  final _newValueController = TextEditingController();

  /// Form key for validation.
  final _formKey = GlobalKey<FormState>();

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  /// The environment being edited (null in create mode).
  Environment? _environment;

  /// Mutable list of variables for editing.
  List<EnvironmentVariable> _variables = [];

  /// Whether the environment is global.
  bool _isGlobal = false;

  /// Whether initial data is loading.
  bool _isLoading = false;

  /// Error message if loading failed.
  String? _loadError;

  /// Whether a save operation is in progress.
  bool _isSaving = false;

  /// Whether this is edit mode.
  bool get _isEditMode => widget.environmentId != null;

  /// Preview value extracted from JSON path.
  String _extractedValue = '';

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _loadEnvironment();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _jsonPathController.dispose();
    _newKeyController.dispose();
    _newValueController.dispose();
    super.dispose();
  }

  /// Loads the environment from the repository in edit mode.
  Future<void> _loadEnvironment() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final repo = getIt<EnvironmentRepository>();
      final env = await repo.getEnvironment(widget.environmentId!);

      if (mounted) {
        setState(() {
          _environment = env;
          _nameController.text = env.name;
          _variables = List<EnvironmentVariable>.from(env.variables);
          _isGlobal = env.isGlobal;
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

  /// Validates and saves the environment.
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();
      final now = DateTime.now();

      if (_isEditMode && _environment != null) {
        // Update existing environment.
        final updated = _environment!.copyWith(
          name: name,
          isGlobal: _isGlobal,
          variables: _variables,
          updatedAt: now,
        );
        await ref
            .read(environmentListProvider.notifier)
            .updateEnvironment(updated);
      } else {
        // Create new environment.
        final created = await ref
            .read(environmentListProvider.notifier)
            .createEnvironment(
              name: name,
              variables: _variables,
              isGlobal: _isGlobal,
            );

        // Navigate to the edit screen for the new environment.
        if (created != null && mounted) {
          // Replace current route with edit route.
          context.pushReplacement('/environment/edit/${created.id}');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(_isEditMode ? 'Environment saved' : 'Environment created'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (_isEditMode) context.pop();
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

  /// Adds a new empty variable to the list.
  void _addVariable({String key = '', String value = ''}) {
    setState(() {
      _variables.add(EnvironmentVariable(
        key: key,
        value: value,
        type: VariableType.string,
        isEnabled: true,
      ));
    });
  }

  /// Removes a variable at the given [index].
  void _removeVariable(int index) {
    setState(() => _variables.removeAt(index));
  }

  /// Updates a variable at the given [index].
  void _updateVariable(int index, {String? key, String? value}) {
    setState(() {
      final updated = _variables[index];
      _variables[index] = updated.copyWith(
        key: key ?? updated.key,
        value: value ?? updated.value,
      );
    });
  }

  /// Toggles the enabled state of a variable.
  void _toggleVariableEnabled(int index) {
    setState(() {
      final v = _variables[index];
      _variables[index] = v.copyWith(isEnabled: !v.isEnabled);
    });
  }

  /// Updates the type of a variable at the given [index].
  void _updateVariableType(int index, VariableType type) {
    setState(() {
      _variables[index] = _variables[index].copyWith(type: type);
    });
  }

  /// Attempts to extract a value from the last response using a JSON path.
  void _extractFromResponse() {
    final response = ref.read(responseProvider);
    final path = _jsonPathController.text.trim();

    if (response == null || response.body == null || path.isEmpty) {
      setState(() => _extractedValue = 'No response available');
      return;
    }

    try {
      final json = jsonDecode(response.body!);
      final result = _resolveJsonPath(json, path);

      setState(() {
        _extractedValue = result != null
            ? result.toString()
            : 'Path not found in response';
      });
    } catch (e) {
      setState(() => _extractedValue = 'Invalid JSON or path: $e');
    }
  }

  /// Simple JSON path resolver supporting dot notation (e.g., $.data.token).
  ///
  /// Supports numeric array indices (e.g., $.items[0].name).
  dynamic _resolveJsonPath(dynamic json, String path) {
    // Strip leading "$." if present.
    String normalizedPath = path;
    if (normalizedPath.startsWith('\$.')) {
      normalizedPath = normalizedPath.substring(2);
    } else if (normalizedPath == '\$') {
      return json;
    }

    dynamic current = json;
    final parts = normalizedPath.split('.');

    for (final part in parts) {
      if (current == null) return null;

      // Handle array index notation: "items[0]".
      final arrayMatch = RegExp(r'^(\w+)\[(\d+)\]$').firstMatch(part);
      if (arrayMatch != null && current is Map) {
        final key = arrayMatch.group(1)!;
        final index = int.parse(arrayMatch.group(2)!);
        final list = current[key];
        if (list is List && index < list.length) {
          current = list[index];
        } else {
          return null;
        }
      } else if (current is Map) {
        current = current[part];
      } else if (current is List) {
        final index = int.tryParse(part);
        if (index != null && index < current.length) {
          current = current[index];
        } else {
          return null;
        }
      } else {
        return null;
      }
    }

    return current;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Environment' : 'New Environment'),
      ),
      body: _isLoading
          ? const AppLoadingIndicator(message: 'Loading environment…')
          : _loadError != null
              ? AppErrorWidget(
                  message: 'Failed to load environment',
                  details: _loadError,
                  onRetry: _loadEnvironment,
                )
              : _buildForm(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  /// Builds the main scrollable form.
  Widget _buildForm() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Environment name.
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            autofocus: !_isEditMode,
            validator: (value) {
              if (value?.trim().isEmpty ?? true) {
                return 'Environment name is required';
              }
              return null;
            },
            decoration: const InputDecoration(
              labelText: 'Environment Name',
              hintText: 'e.g. Development, Staging, Production',
              prefixIcon: Icon(Symbols.edit, size: 20),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Is Global toggle.
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Global Environment',
                style: textTheme.bodyMedium),
            subtitle: Text(
              'Global variables are available across all workspaces',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            value: _isGlobal,
            onChanged: (v) => setState(() => _isGlobal = v),
            secondary: const Icon(Symbols.public),
          ),

          const SizedBox(height: 24),

          // -----------------------------------------------------------------
          // Variables section
          // -----------------------------------------------------------------
          Row(
            children: [
              Text(
                'Variables',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${_variables.length} variable${_variables.length != 1 ? 's' : ''}',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Variable list.
          ..._variables.asMap().entries.map((entry) {
            final index = entry.key;
            final variable = entry.value;
            return _VariableTile(
              variable: variable,
              index: index,
              onChangedKey: (key) => _updateVariable(index, key: key),
              onChangedValue: (value) => _updateVariable(index, value: value),
              onChangedType: (type) => _updateVariableType(index, type),
              onToggleEnabled: () => _toggleVariableEnabled(index),
              onDeleted: () => _removeVariable(index),
            );
          }),

          // Add variable section.
          const SizedBox(height: 12),
          Card(
            color: colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newKeyController,
                          decoration: const InputDecoration(
                            hintText: 'Key',
                            isDense: true,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _newValueController,
                          decoration: const InputDecoration(
                            hintText: 'Value',
                            isDense: true,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                          onSubmitted: (_) => _onAddVariable(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        icon: const Icon(Symbols.add, size: 18),
                        tooltip: 'Add variable',
                        onPressed: _onAddVariable,
                        style: IconButton.styleFrom(
                          minimumSize: const Size(40, 40),
                          maximumSize: const Size(40, 40),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // -----------------------------------------------------------------
          // Set from Response section
          // -----------------------------------------------------------------
          Text(
            'Set from Response',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Extract a value from the last API response using a JSON path.',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          // JSON path input.
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _jsonPathController,
                  decoration: const InputDecoration(
                    hintText: '\$.data.token',
                    labelText: 'JSON Path',
                    prefixIcon: Icon(Symbols.data_object, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: _extractFromResponse,
                child: const Text('Extract'),
              ),
            ],
          ),

          // Extracted value preview.
          if (_extractedValue.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Symbols.data_object,
                        size: 14,
                        color: colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Extracted Value',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      // Copy to new variable.
                      if (_extractedValue != 'Path not found in response' &&
                          _extractedValue != 'No response available' &&
                          !_extractedValue.startsWith('Invalid'))
                        IconButton(
                          icon: const Icon(Symbols.content_copy, size: 16),
                          tooltip: 'Copy to new variable',
                          onPressed: () {
                            _newKeyController.text = _jsonPathController.text
                                .split('.')
                                .last
                                .replaceAll(RegExp(r'[\[\]]'), '');
                            _newValueController.text = _extractedValue;
                            setState(() => _extractedValue = '');
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    _extractedValue,
                    style: textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Bottom padding for save button area.
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  /// Adds a variable from the quick-add fields.
  void _onAddVariable() {
    final key = _newKeyController.text.trim();
    final value = _newValueController.text.trim();

    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Variable key is required'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _addVariable(key: key, value: value);
    _newKeyController.clear();
    _newValueController.clear();

    // Scroll to the new variable.
    // (A scroll controller could be added for this.)
  }

  /// Builds the bottom navigation bar with Save and Cancel.
  Widget _buildBottomBar() {
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
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving ? null : () => context.pop(),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
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
                label: Text(_isSaving ? 'Saving…' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Variable Tile
// =============================================================================

/// A single variable row in the environment editor.
class _VariableTile extends StatefulWidget {
  /// The variable to edit.
  final EnvironmentVariable variable;

  /// The index of this variable in the list.
  final int index;

  /// Called when the key changes.
  final ValueChanged<String> onChangedKey;

  /// Called when the value changes.
  final ValueChanged<String> onChangedValue;

  /// Called when the type changes.
  final ValueChanged<VariableType> onChangedType;

  /// Called when the enabled toggle is flipped.
  final VoidCallback onToggleEnabled;

  /// Called when the delete button is pressed.
  final VoidCallback onDeleted;

  /// Creates a [_VariableTile].
  const _VariableTile({
    required this.variable,
    required this.index,
    required this.onChangedKey,
    required this.onChangedValue,
    required this.onChangedType,
    required this.onToggleEnabled,
    required this.onDeleted,
  });

  @override
  State<_VariableTile> createState() => _VariableTileState();
}

class _VariableTileState extends State<_VariableTile> {
  /// Controllers for inline editing.
  late TextEditingController _keyController;
  late TextEditingController _valueController;

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController(text: widget.variable.key);
    _valueController = TextEditingController(text: widget.variable.value);
  }

  @override
  void didUpdateWidget(covariant _VariableTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.variable.key != widget.variable.key) {
      _keyController.text = widget.variable.key;
    }
    if (oldWidget.variable.value != widget.variable.value) {
      _valueController.text = widget.variable.value;
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final v = widget.variable;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: v.isEnabled
          ? null
          : colorScheme.surfaceContainerHighest.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: enable toggle, key input, type selector, delete.
            Row(
              children: [
                // Enable toggle.
                SizedBox(
                  width: 32,
                  height: 32,
                  child: Switch(
                    value: v.isEnabled,
                    onChanged: (_) => widget.onToggleEnabled(),
                  ),
                ),
                const SizedBox(width: 8),

                // Key input.
                Expanded(
                  child: TextField(
                    controller: _keyController,
                    decoration: const InputDecoration(
                      hintText: 'key',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    style: textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                    onChanged: widget.onChangedKey,
                  ),
                ),
                const SizedBox(width: 8),

                // Type selector dropdown.
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.outline),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<VariableType>(
                      value: v.type,
                      isDense: true,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      borderRadius: BorderRadius.circular(8),
                      items: VariableType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(
                            type.name,
                            style: textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (type) {
                        if (type != null) widget.onChangedType(type);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Delete button.
                IconButton(
                  icon: Icon(
                    Symbols.close,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  tooltip: 'Remove variable',
                  onPressed: widget.onDeleted,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Row 2: Value input.
            Row(
              children: [
                const SizedBox(width: 40), // Align with key input.
                Expanded(
                  child: TextField(
                    controller: _valueController,
                    decoration: InputDecoration(
                      hintText: 'value',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      border: const OutlineInputBorder(),
                      suffixText: v.isEnabled ? null : 'disabled',
                      suffixStyle: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    style: textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                    ),
                    obscureText: false,
                    onChanged: widget.onChangedValue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
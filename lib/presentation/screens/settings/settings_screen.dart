/// @file settings_screen.dart
/// @brief Application settings screen with organized sections.
///
/// Provides controls for appearance (theme, font size), general request
/// defaults (timeout, redirects, SSL), floating window, proxy, data
/// management (export, import, clear), about information, and environment
/// variable management. All changes are persisted immediately via
/// [SettingsNotifier].

library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:api_tester/core/constants/app_constants.dart';
import 'package:api_tester/core/di/injection.dart';
import 'package:api_tester/domain/entities/app_settings.dart' as domain;
import 'package:api_tester/domain/entities/environment.dart';
import 'package:api_tester/domain/entities/proxy_settings.dart';
import 'package:api_tester/domain/repositories/settings_repository.dart';
import 'package:api_tester/domain/repositories/workspace_repository.dart';
import 'package:api_tester/presentation/providers/environment_provider.dart';
import 'package:api_tester/presentation/providers/floating_window_provider.dart';
import 'package:api_tester/presentation/providers/settings_provider.dart';
import 'package:api_tester/presentation/providers/workspace_provider.dart';

/// Central settings screen exposing all application preferences.
///
/// Organised into clearly labelled sections: Appearance, General,
/// Floating Window, Proxy, Data, About, and Environment Variables.
class SettingsScreen extends ConsumerStatefulWidget {
  /// Creates a [SettingsScreen].
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // ---------------------------------------------------------------------------
  // Floating window permission state
  // ---------------------------------------------------------------------------

  /// Tracks the overlay permission status for the floating window.
  bool _overlayPermissionGranted = false;
  bool _permissionChecked = false;

  @override
  void initState() {
    super.initState();
    _checkOverlayPermission();
  }

  /// Checks whether the overlay permission has been granted.
  Future<void> _checkOverlayPermission() async {
    try {
      final status = await Permission.systemAlertWindow.status;
      if (mounted) {
        setState(() {
          _overlayPermissionGranted = status.isGranted;
          _permissionChecked = true;
        });
      }
    } catch (_) {
      // On unsupported platforms, assume granted.
      if (mounted) {
        setState(() {
          _overlayPermissionGranted = true;
          _permissionChecked = true;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Requests overlay permission for the floating window feature.
  Future<void> _requestOverlayPermission() async {
    try {
      final status = await Permission.systemAlertWindow.request();
      if (mounted) {
        setState(() => _overlayPermissionGranted = status.isGranted);
      }
      if (status.isGranted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission granted'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission not available on this platform'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Shows a double-confirmation dialog before clearing all data.
  void _showClearAllDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Symbols.warning,
          color: Theme.of(context).colorScheme.error,
        ),
        title: const Text('Clear All Data'),
        content: const Text(
          'This will permanently delete ALL workspaces, requests, collections, '
          'environments, and history. This cannot be undone.',
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
              _showFinalClearConfirmation();
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  /// Second confirmation step for clearing all data.
  void _showFinalClearConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Symbols.error,
          color: Theme.of(context).colorScheme.error,
        ),
        title: const Text('Are you absolutely sure?'),
        content: const Text(
          'All your data will be permanently deleted. '
          'Please type "DELETE" to confirm.',
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
            onPressed: () async {
              Navigator.pop(context);
              await _performClearAllData();
            },
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );
  }

  /// Performs the actual data clear operation.
  Future<void> _performClearAllData() async {
    try {
      final workspaceRepo = getIt<WorkspaceRepository>();
      final settingsRepo = getIt<SettingsRepository>();

      // Delete all workspaces (cascading to collections, requests, etc.).
      final workspaces = await workspaceRepo.getWorkspaces();
      for (final ws in workspaces) {
        await workspaceRepo.deleteWorkspace(ws.id);
      }

      // Reset settings to defaults.
      await settingsRepo.updateAppSettings(const domain.AppSettings());

      // Refresh providers and clear current workspace reference.
      ref.read(currentWorkspaceProvider.notifier).state = null;
      ref.read(workspaceListProvider.notifier).reload();
      ref.read(settingsProvider.notifier).loadSettings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All data cleared successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear data: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Exports all data as JSON to the clipboard.
  void _exportAllData() {
    try {
      // Build a simple JSON export of settings.
      final settings = ref.read(settingsProvider);
      final exportData = settings.toJson();

      final jsonString = const JsonEncoder.withIndent('  ')
          .convert(exportData);

      Clipboard.setData(ClipboardData(text: jsonString));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings exported to clipboard'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Creates a new environment via a dialog and navigates to the editor.
  void _createEnvironment() {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Symbols.add_circle),
        title: const Text('New Environment'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            validator: (value) {
              if (value?.trim().isEmpty ?? true) return 'Name is required';
              return null;
            },
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'e.g. Development',
              prefixIcon: Icon(Symbols.edit, size: 20),
              border: OutlineInputBorder(),
            ),
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
              Navigator.pop(context);

              final created = await ref
                  .read(environmentListProvider.notifier)
                  .createEnvironment(name: name);

              if (created != null && mounted) {
                context.push('/environment/edit/${created.id}');
              }
            },
            child: const Text('Create'),
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
    final settings = ref.watch(settingsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // =====================================================================
        // Appearance
        // =====================================================================
        _SectionHeader(title: 'Appearance', icon: Symbols.palette),
        const SizedBox(height: 8),

        // Theme mode selector.
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Symbols.dark_mode, size: 20, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Text('Theme', style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
                  ],
                ),
                const SizedBox(height: 12),
                // SegmentedButton for theme selection.
                SegmentedButton<domain.ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: domain.ThemeMode.system,
                      label: Text('System'),
                      icon: Icon(Symbols.brightness_auto, size: 18),
                    ),
                    ButtonSegment(
                      value: domain.ThemeMode.light,
                      label: Text('Light'),
                      icon: Icon(Symbols.light_mode, size: 18),
                    ),
                    ButtonSegment(
                      value: domain.ThemeMode.dark,
                      label: Text('Dark'),
                      icon: Icon(Symbols.dark_mode, size: 18),
                    ),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (selection) {
                    ref
                        .read(settingsProvider.notifier)
                        .updateThemeMode(selection.first);
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Font size slider.
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Symbols.format_size, size: 20, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Text('Font Size', style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
                    const Spacer(),
                    Text(
                      '${settings.fontSize.toInt()}px',
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Slider(
                  value: settings.fontSize,
                  min: 10,
                  max: 20,
                  divisions: 10,
                  label: '${settings.fontSize.toInt()}px',
                  onChanged: (v) =>
                      ref.read(settingsProvider.notifier).updateFontSize(v),
                ),
                // Labels below slider.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Small', style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    )),
                    Text('Normal', style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    )),
                    Text('Large', style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    )),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // =====================================================================
        // General
        // =====================================================================
        _SectionHeader(title: 'General', icon: Symbols.tune),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              // Default timeout.
              ListTile(
                leading: const Icon(Symbols.timer),
                title: const Text('Default Timeout'),
                subtitle: Text('${settings.defaultTimeout} seconds'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Symbols.remove, size: 18),
                      onPressed: settings.defaultTimeout > 5
                          ? () => ref
                              .read(settingsProvider.notifier)
                              .updateDefaultTimeout(
                                  settings.defaultTimeout - 5)
                          : null,
                    ),
                    Text(
                      '${settings.defaultTimeout}s',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Symbols.add, size: 18),
                      onPressed: settings.defaultTimeout < 300
                          ? () => ref
                              .read(settingsProvider.notifier)
                              .updateDefaultTimeout(
                                  settings.defaultTimeout + 5)
                          : null,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, indent: 56),

              // Follow redirects.
              SwitchListTile(
                secondary: const Icon(Symbols.arrow_forward),
                title: const Text('Follow Redirects'),
                subtitle: const Text('Automatically follow HTTP 3xx responses'),
                value: settings.defaultFollowRedirects,
                onChanged: (v) => ref
                    .read(settingsProvider.notifier)
                    .updateFollowRedirects(v),
              ),
              const Divider(height: 1, indent: 56),

              // Verify SSL.
              SwitchListTile(
                secondary: const Icon(Symbols.verified_user),
                title: const Text('Verify SSL Certificates'),
                subtitle: const Text('Validate server SSL/TLS certificates'),
                value: settings.defaultVerifySsl,
                onChanged: (v) => ref
                    .read(settingsProvider.notifier)
                    .updateVerifySsl(v),
              ),
              const Divider(height: 1, indent: 56),

              // Send analytics.
              SwitchListTile(
                secondary: const Icon(Symbols.analytics),
                title: const Text('Send Analytics'),
                subtitle: const Text(
                    'Help improve the app with anonymous usage data'),
                value: settings.sendAnalytics,
                onChanged: (v) => ref
                    .read(settingsProvider.notifier)
                    .toggleAnalytics(v),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // =====================================================================
        // Floating Window
        // =====================================================================
        _SectionHeader(title: 'Floating Window', icon: Symbols.picture_in_picture),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Symbols.open_in_new),
                title: const Text('Enable Floating Window'),
                subtitle: const Text(
                    'Show a floating window for quick API testing'),
                value: settings.floatingWindowEnabled,
                onChanged: (v) => ref
                    .read(settingsProvider.notifier)
                    .toggleFloatingWindow(v),
              ),
              const Divider(height: 1, indent: 56),

              // Permission status.
              ListTile(
                leading: Icon(
                  _overlayPermissionGranted
                      ? Symbols.check_circle
                      : Symbols.block,
                  color: _overlayPermissionGranted
                      ? Colors.green
                      : colorScheme.error,
                ),
                title: const Text('Overlay Permission'),
                subtitle: Text(
                  _permissionChecked
                      ? (_overlayPermissionGranted
                          ? 'Permission granted'
                          : 'Permission not granted')
                      : 'Checking…',
                ),
              ),

              // Request permission button.
              if (_permissionChecked && !_overlayPermissionGranted)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _requestOverlayPermission,
                      icon: const Icon(Symbols.lock_open, size: 18),
                      label: const Text('Request Permission'),
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // =====================================================================
        // Proxy
        // =====================================================================
        _SectionHeader(title: 'Proxy', icon: Symbols.vpn_lock),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Symbols.vpn_lock),
            title: const Text('Global Proxy Settings'),
            subtitle: Text(
              settings.globalProxy != null && settings.globalProxy!.enabled
                  ? 'Enabled – ${settings.globalProxy!.host}:${settings.globalProxy!.port}'
                  : 'Disabled',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status indicator dot.
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: settings.globalProxy != null &&
                            settings.globalProxy!.enabled
                        ? Colors.green
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Symbols.chevron_right),
              ],
            ),
            onTap: () => context.push('/settings/proxy'),
          ),
        ),

        const SizedBox(height: 24),

        // =====================================================================
        // Data
        // =====================================================================
        _SectionHeader(title: 'Data', icon: Symbols.database),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Symbols.file_download),
                title: const Text('Export All Data'),
                subtitle: const Text('Copy settings to clipboard'),
                trailing: const Icon(Symbols.chevron_right),
                onTap: _exportAllData,
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Symbols.file_upload),
                title: const Text('Import Data'),
                subtitle: const Text('Import from Postman, OpenAPI, or cURL'),
                trailing: const Icon(Symbols.chevron_right),
                onTap: () => context.push('/import'),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: Icon(
                  Symbols.delete_forever,
                  color: colorScheme.error,
                ),
                title: Text(
                  'Clear All Data',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
                subtitle: const Text(
                    'Delete all workspaces, requests, and history'),
                trailing: const Icon(Symbols.chevron_right),
                onTap: _showClearAllDataDialog,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // =====================================================================
        // About
        // =====================================================================
        _SectionHeader(title: 'About', icon: Symbols.info),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Symbols.api),
                title: Text(
                  AppConstants.appName,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: const Text('API Testing Tool'),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Symbols.verified),
                title: const Text('Version'),
                subtitle: Text(
                  '${AppConstants.appVersion} (Build ${AppConstants.buildNumber})',
                ),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Symbols.code),
                title: const Text('Package'),
                subtitle: Text(AppConstants.packageName),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Symbols.description),
                title: const Text('Open Source Licenses'),
                trailing: const Icon(Symbols.chevron_right),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: AppConstants.appName,
                  applicationVersion: AppConstants.appVersion,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // =====================================================================
        // Environment Variables
        // =====================================================================
        _SectionHeader(
            title: 'Environment Variables', icon: Symbols.data_object),
        const SizedBox(height: 8),
        _EnvironmentsSection(
          onCreateEnvironment: _createEnvironment,
        ),

        // Bottom padding.
        const SizedBox(height: 40),
      ],
    );
  }
}

// =============================================================================
// Section Header
// =============================================================================

/// A section header label used to group related settings.
class _SectionHeader extends StatelessWidget {
  /// Section title text.
  final String title;

  /// Material Symbols icon.
  final IconData icon;

  /// Creates a [_SectionHeader].
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Environments Section
// =============================================================================

/// Displays the list of environments in the current workspace with controls
/// for creating, editing, and setting the active environment.
class _EnvironmentsSection extends ConsumerWidget {
  /// Callback invoked when the user creates a new environment.
  final VoidCallback onCreateEnvironment;

  /// Creates an [_EnvironmentsSection].
  const _EnvironmentsSection({required this.onCreateEnvironment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final environmentsAsync = ref.watch(environmentListProvider);
    final activeEnv = ref.watch(activeEnvironmentProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return environmentsAsync.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Failed to load environments: $e',
            style: TextStyle(color: colorScheme.error),
          ),
        ),
      ),
      data: (environments) => Column(
        children: [
          if (environments.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Symbols.data_object,
                      size: 40,
                      color: colorScheme.outline,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No environments',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create an environment to manage variables like base URLs and API keys.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: onCreateEnvironment,
                      icon: const Icon(Symbols.add, size: 16),
                      label: const Text('Create Environment'),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Environment list.
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: environments.map((env) {
                  final isActive = activeEnv?.id == env.id;
                  return Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          isActive
                              ? Symbols.radio_button_checked
                              : Symbols.radio_button_unchecked,
                          color: isActive
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                        title: Row(
                          children: [
                            Text(env.name),
                            if (env.isGlobal) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.tertiaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'GLOBAL',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onTertiaryContainer,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          '${env.variables.length} variable${env.variables.length != 1 ? 's' : ''}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isActive)
                              IconButton(
                                icon: const Icon(Symbols.check_circle_outline,
                                    size: 20),
                                tooltip: 'Set as active',
                                onPressed: () => ref
                                    .read(environmentListProvider.notifier)
                                    .setActiveEnvironment(env.id),
                              ),
                            IconButton(
                              icon: const Icon(Symbols.edit, size: 20),
                              tooltip: 'Edit environment',
                              onPressed: () => context
                                  .push('/environment/edit/${env.id}'),
                            ),
                          ],
                        ),
                        selected: isActive,
                        onTap: () => ref
                            .read(environmentListProvider.notifier)
                            .setActiveEnvironment(env.id),
                      ),
                      if (env != environments.last)
                        const Divider(height: 1, indent: 56),
                    ],
                  );
                }).toList(),
              ),
            ),

            // Create new environment button.
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onCreateEnvironment,
                icon: const Icon(Symbols.add, size: 18),
                label: const Text('New Environment'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
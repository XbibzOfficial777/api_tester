/// @file floating_window_controls.dart
/// @brief Widget for controlling the floating window from the main app.
///
/// Provides a settings-panel-style widget with:
/// - A toggle switch to enable / disable the floating window feature.
/// - A permission status indicator showing whether the system overlay
///   permission has been granted.
/// - A "Request Permission" button (shown only when permission is denied).
/// - A test button to show / hide the floating bubble.
/// - Explanatory text about the floating window feature.
///
/// This widget is intended to be placed on the Settings screen and
/// integrates with the app's Riverpod providers for state management.

library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/floating_window_service.dart';
import '../../providers/floating_window_provider.dart';
import '../../providers/settings_provider.dart';
import 'floating_window_panel.dart';

/// A widget that provides controls for the floating window feature.
///
/// Placed in the settings screen, it lets the user:
/// 1. Toggle the floating window feature on/off (persisted in [AppSettings]).
/// 2. Request the Android "draw over other apps" permission if needed.
/// 3. Test the floating bubble by showing/hiding it.
/// 4. Preview the floating panel layout within the app.
///
/// The widget reacts to changes in [floatingWindowEnabledProvider] and
/// [floatingWindowStateProvider] and updates the UI accordingly.
class FloatingWindowControls extends ConsumerStatefulWidget {
  /// Creates a [FloatingWindowControls] widget.
  const FloatingWindowControls({super.key});

  @override
  ConsumerState<FloatingWindowControls> createState() =>
      _FloatingWindowControlsState();
}

class _FloatingWindowControlsState
    extends ConsumerState<FloatingWindowControls> {
  /// Whether the overlay permission is currently granted.
  bool _hasPermission = false;

  /// Whether we are in the process of checking / requesting permission.
  bool _isCheckingPermission = false;

  /// Whether the floating bubble is currently visible.
  bool _isBubbleVisible = false;

  /// Whether a permission check has been performed at least once.
  bool _permissionChecked = false;

  @override
  void initState() {
    super.initState();
    // Perform an initial permission check.
    _checkPermission();
  }

  /// Checks the current overlay permission status.
  Future<void> _checkPermission() async {
    setState(() => _isCheckingPermission = true);
    try {
      final granted =
          await FloatingWindowService.instance.checkPermission();
      if (mounted) {
        setState(() {
          _hasPermission = granted;
          _permissionChecked = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _permissionChecked = true);
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingPermission = false);
      }
    }
  }

  /// Requests the system overlay permission from the user.
  Future<void> _requestPermission() async {
    setState(() => _isCheckingPermission = true);
    try {
      await requestFloatingWindowPermission();
      await _checkPermission();
    } catch (_) {
      // Swallow — _checkPermission will update the state.
    } finally {
      if (mounted) {
        setState(() => _isCheckingPermission = false);
      }
    }
  }

  /// Toggles the floating window feature on/off.
  Future<void> _toggleFeature(bool enabled) async {
    await ref.read(settingsProvider.notifier).toggleFloatingWindow(enabled);

    // If the user disabled the feature, also hide the bubble.
    if (!enabled) {
      await _hideBubble();
    }
  }

  /// Shows the floating bubble for testing.
  Future<void> _showBubble() async {
    try {
      await FloatingWindowService.instance.showBubble();
      if (mounted) {
        setState(() => _isBubbleVisible = true);
        ref.read(floatingWindowStateProvider.notifier).state = true;
      }
    } on StateError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to show floating window.'),
          ),
        );
      }
    }
  }

  /// Hides the floating bubble.
  Future<void> _hideBubble() async {
    await FloatingWindowService.instance.hideBubble();
    if (mounted) {
      setState(() => _isBubbleVisible = false);
      ref.read(floatingWindowStateProvider.notifier).state = false;
    }
  }

  /// Shows a preview dialog of the floating panel.
  void _showPreview() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Align(
          alignment: Alignment.bottomRight,
          child: FloatingWindowPanel.preview(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEnabled = ref.watch(floatingWindowEnabledProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -- Title row --
            Row(
              children: [
                Icon(
                  Icons.picture_in_picture_alt_rounded,
                  color: colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  'Floating Window',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                // Preview button
                if (isEnabled)
                  TextButton.icon(
                    onPressed: _showPreview,
                    icon: const Icon(Icons.visibility_rounded, size: 16),
                    label: const Text('Preview'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            // -- Description --
            Text(
              'Show a floating overlay bubble that lets you send quick API '
              'requests without leaving the current app. The bubble stays on '
              'top of all apps and provides a compact panel with method '
              'selection, URL input, and response preview.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 16),

            // -- Enable/Disable toggle --
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Enable floating window',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                isEnabled ? 'Floating window is active' : 'Floating window is disabled',
                style: theme.textTheme.bodySmall,
              ),
              value: isEnabled,
              onChanged: _toggleFeature,
              activeColor: colorScheme.primary,
            ),

            // -- Permission & controls (shown only when feature is enabled) --
            if (isEnabled) ...[
              const Divider(height: 24),

              // Permission status
              _buildPermissionSection(theme, colorScheme),

              const SizedBox(height: 12),

              // Bubble test controls
              _buildBubbleControls(theme, colorScheme),
            ],
          ],
        ),
      ),
    );
  }

  /// Builds the permission status section with indicator and request button.
  Widget _buildPermissionSection(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Permission',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            // Status indicator
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _permissionChecked
                    ? (_hasPermission
                        ? AppTheme.status2xx
                        : colorScheme.error)
                    : Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _isCheckingPermission
                    ? 'Checking permission...'
                    : _hasPermission
                        ? 'Overlay permission granted'
                        : 'Overlay permission not granted',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _hasPermission
                      ? AppTheme.status2xx
                      : colorScheme.error,
                ),
              ),
            ),
            if (!_hasPermission && _permissionChecked)
              FilledButton.tonal(
                onPressed: _isCheckingPermission ? null : _requestPermission,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: const Text('Request'),
              ),
          ],
        ),
      ],
    );
  }

  /// Builds the test controls for showing/hiding the floating bubble.
  Widget _buildBubbleControls(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isBubbleVisible
                ? _hideBubble
                : (_hasPermission ? _showBubble : null),
            icon: Icon(
              _isBubbleVisible
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              size: 16,
            ),
            label: Text(
              _isBubbleVisible ? 'Hide Bubble' : 'Show Bubble',
              style: const TextStyle(fontSize: 12),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              side: BorderSide(
                color: _isBubbleVisible
                    ? colorScheme.error
                    : colorScheme.outline,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Status pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _isBubbleVisible
                ? AppTheme.status2xx.withOpacity(0.1)
                : colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _isBubbleVisible ? 'Active' : 'Inactive',
            style: theme.textTheme.labelSmall?.copyWith(
              color: _isBubbleVisible
                  ? AppTheme.status2xx
                  : colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
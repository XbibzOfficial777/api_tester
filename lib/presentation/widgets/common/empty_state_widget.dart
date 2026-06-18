/// @file empty_state_widget.dart
/// @brief Placeholder widget shown when a list or section has no data.
///
/// Renders a large icon, a title, an optional subtitle, and an optional
/// action button. Used consistently across workspaces, collections,
/// history, and other list-based screens.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

/// A visually appealing empty-state placeholder.
///
/// The widget fades in with a subtle scale animation so that the
/// transition from a loading state to an empty state feels smooth.
///
/// Example:
/// ```dart
/// if (workspaces.isEmpty) {
///   return EmptyStateWidget(
///     icon: Symbols.folder_off,
///     title: 'No workspaces yet',
///     subtitle: 'Create your first workspace to start testing APIs.',
///     actionLabel: 'Create Workspace',
///     onAction: () => context.push('/workspace/new'),
///   );
/// }
/// ```
class EmptyStateWidget extends StatelessWidget {
  /// Material Symbols icon displayed above the title.
  final IconData icon;

  /// Primary headline text.
  final String title;

  /// Optional secondary text providing more context.
  final String? subtitle;

  /// Label for the optional action [FilledButton].
  final String? actionLabel;

  /// Callback invoked when the user taps the action button.
  final VoidCallback? onAction;

  /// Colour override for the icon. Defaults to the theme's outline colour.
  final Color? iconColor;

  /// Creates an [EmptyStateWidget].
  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 72,
              color: iconColor ?? colorScheme.outline,
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Symbols.add, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, curve: Curves.easeOut)
        .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1), duration: 400.ms);
  }
}
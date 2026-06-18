/// @file error_widget.dart
/// @brief Reusable error display widget with an optional retry action.
///
/// Shows an error icon, a human-readable message, and a [FilledButton]
/// to retry the failed operation. This is the standard way to surface
/// [Failure] or [Exception] objects throughout the presentation layer.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

/// A full-area error display with a retry button.
///
/// Use this widget when an async operation fails and the user should be
/// given the option to retry.
///
/// Example:
/// ```dart
/// if (state.hasError) {
///   return AppErrorWidget(
///     message: 'Failed to load workspaces',
///     onRetry: () => ref.read(workspacesProvider.notifier).load(),
///   );
/// }
/// ```
class AppErrorWidget extends StatelessWidget {
  /// Human-readable error description shown below the icon.
  final String message;

  /// Optional detailed error (e.g. stack trace snippet) shown in a
  /// smaller, dimmer font for debugging.
  final String? details;

  /// Label for the retry button. Defaults to `'Retry'`.
  final String retryLabel;

  /// Callback invoked when the user taps the retry button.
  final VoidCallback? onRetry;

  /// Icon displayed above the message. Defaults to [Symbols.error].
  final IconData icon;

  /// Creates an [AppErrorWidget].
  const AppErrorWidget({
    super.key,
    required this.message,
    this.details,
    this.retryLabel = 'Retry',
    this.onRetry,
    this.icon = Symbols.error,
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
              size: 64,
              color: colorScheme.error,
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
            if (details != null) ...[
              const SizedBox(height: 8),
              Text(
                details!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Symbols.refresh, size: 18),
                label: Text(retryLabel),
              ),
            ],
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms, curve: Curves.easeOut)
        .scale(begin: const Offset(0.96, 0.96), end: const Offset(1, 1), duration: 300.ms);
  }
}

/// A compact inline error widget for use inside cards or list tiles.
///
/// Unlike [AppErrorWidget], this does not centre itself and omits the
/// large icon — suitable for embedding in tight spaces.
class InlineErrorWidget extends StatelessWidget {
  /// The error message to display.
  final String message;

  /// Creates an [InlineErrorWidget].
  const InlineErrorWidget({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Symbols.warning, size: 16, color: colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.error,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
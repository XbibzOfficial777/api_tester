/// @file app_loading_indicator.dart
/// @brief A centred loading indicator with a shimmer effect.
///
/// Displays a Material 3 [CircularProgressIndicator] surrounded by an
/// optional shimmer backdrop to communicate that content is being fetched.
library;

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// A full-area loading widget with an optional shimmer overlay.
///
/// Use this widget when an entire screen or section is waiting for data.
/// The [message] parameter displays a line of text below the spinner.
///
/// Example:
/// ```dart
/// if (state.isLoading) {
///   return const AppLoadingIndicator(message: 'Fetching workspaces…');
/// }
/// ```
class AppLoadingIndicator extends StatelessWidget {
  /// Optional message displayed below the spinner.
  final String? message;

  /// Size of the circular indicator. Defaults to 36.
  final double size;

  /// Whether to render a shimmer overlay behind the indicator.
  /// Defaults to `true`.
  final bool showShimmer;

  /// Creates an [AppLoadingIndicator].
  const AppLoadingIndicator({
    super.key,
    this.message,
    this.size = 36,
    this.showShimmer = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final indicator = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: colorScheme.primary,
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(
            message!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ],
    );

    if (!showShimmer) {
      return Center(child: indicator);
    }

    return Shimmer.fromColors(
      baseColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
      highlightColor: colorScheme.surfaceContainerHighest.withOpacity(0.1),
      child: Center(child: indicator),
    );
  }
}

/// A small inline loading indicator for buttons or list tiles.
///
/// Unlike [AppLoadingIndicator] this does **not** centre itself and
/// omits the shimmer effect for a lighter visual footprint.
class InlineLoadingIndicator extends StatelessWidget {
  /// Stroke width of the indicator ring. Defaults to 2.
  final double strokeWidth;

  /// Size of the indicator. Defaults to 16.
  final double size;

  /// Creates an [InlineLoadingIndicator].
  const InlineLoadingIndicator({
    super.key,
    this.strokeWidth = 2,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
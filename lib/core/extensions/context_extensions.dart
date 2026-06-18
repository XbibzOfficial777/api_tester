/// @file context_extensions.dart
/// @brief Extension methods on [BuildContext] for UI utilities.
///
/// Adds convenience methods to Flutter's [BuildContext] for common UI
/// patterns such as showing snack bars, confirmation dialogs, and querying
/// screen dimensions. Keeps widget code clean by eliminating boilerplate.
///
/// ```dart
/// context.showSnackBar('Request completed!');
/// final confirmed = await context.showConfirmationDialog(
///   title: 'Delete?',
///   message: 'This action cannot be undone.',
/// );
/// ```

import 'package:flutter/material.dart';

/// Extension that adds UI utility methods to [BuildContext].
extension ContextExtensions on BuildContext {
  // ---------------------------------------------------------------------------
  // SnackBar
  // ---------------------------------------------------------------------------

  /// Displays a [SnackBar] with the given [message].
  ///
  /// When [isError] is `true` the bar uses the error colour from the
  /// current theme. Otherwise it uses the default colour.
  ///
  /// The bar is dismissed automatically after 3 seconds.
  ///
  /// ```dart
  /// context.showSnackBar('Item saved successfully');
  /// context.showSnackBar('Upload failed', isError: true);
  /// ```
  void showSnackBar(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(this);

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError
            ? Theme.of(this).colorScheme.error
            : null, // null = default
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Confirmation Dialog
  // ---------------------------------------------------------------------------

  /// Displays a Material 3 confirmation dialog and returns the user's
  /// choice as a [Future<bool>].
  ///
  /// - **`true`** — the user tapped "Confirm" / "OK".
  /// - **`false`** — the user tapped "Cancel", dismissed the dialog, or
  ///   navigated away (e.g. back button on Android).
  ///
  /// ```dart
  /// final confirmed = await context.showConfirmationDialog(
  ///   title: 'Delete Collection?',
  ///   message: 'All requests inside will be permanently removed.',
  /// );
  /// if (confirmed) { /* proceed with deletion */ }
  /// ```
  Future<bool> showConfirmationDialog({
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: this,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colorScheme = theme.colorScheme;

        return AlertDialog(
          title: Text(title),
          content: Text(message),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            // Cancel button.
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(cancelText),
            ),
            // Confirm button — red for destructive actions.
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: colorScheme.error,
                    )
                  : null,
              child: Text(confirmText),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  // ---------------------------------------------------------------------------
  // Screen Dimensions
  // ---------------------------------------------------------------------------

  /// Returns the logical screen width in pixels from [MediaQuery].
  ///
  /// ```dart
  /// final w = context.screenWidth;
  /// ```
  double get screenWidth => MediaQuery.of(this).size.width;

  /// Returns the logical screen height in pixels from [MediaQuery].
  double get screenHeight => MediaQuery.of(this).size.height;

  /// Returns the shortest screen dimension (useful for square layouts).
  double get shortestSide =>
      MediaQuery.of(this).size.shortestSide;

  /// Returns the longest screen dimension.
  double get longestSide =>
      MediaQuery.of(this).size.longestSide;

  // ---------------------------------------------------------------------------
  // Form Factor Helpers
  // ---------------------------------------------------------------------------

  /// Returns `true` when the device is considered a tablet.
  ///
  /// The threshold is 600 logical pixels (the Material Design breakpoint
  /// for medium-width layouts). Values >= 600 are treated as tablets.
  ///
  /// ```dart
  /// if (context.isTablet) { showSideNavigation(); }
  /// ```
  bool get isTablet => shortestSide >= 600;

  /// Returns `true` when the device is in landscape orientation.
  ///
  /// ```dart
  /// if (context.isLandscape) { adjustLayout(); }
  /// ```
  bool get isLandscape =>
      MediaQuery.of(this).orientation == Orientation.landscape;

  /// Returns `true` when the device is in portrait orientation.
  bool get isPortrait =>
      MediaQuery.of(this).orientation == Orientation.portrait;

  // ---------------------------------------------------------------------------
  // Theme Accessors
  // ---------------------------------------------------------------------------

  /// Convenience accessor for the current [ThemeData].
  ThemeData get theme => Theme.of(this);

  /// Convenience accessor for the current [ColorScheme].
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// Convenience accessor for the current [TextTheme].
  TextTheme get textTheme => Theme.of(this).textTheme;

  // ---------------------------------------------------------------------------
  // Padding Helpers
  /// Returns the system-level padding insets (notch, gesture bar, etc).
  EdgeInsets get padding => MediaQuery.of(this).padding;

  /// Returns the view insets (keyboard, system UI overlays).
  EdgeInsets get viewInsets => MediaQuery.of(this).viewInsets;
  // ---------------------------------------------------------------------------

  /// Returns `true` when the software keyboard is currently visible.
  bool get isKeyboardVisible => viewInsets.bottom > 0;
}

/// @file theme_provider.dart
/// @brief Riverpod providers for application theming.
///
/// Derives the active [ThemeMode] (from settings) and a boolean
/// `isDarkMode` flag (considering system brightness). Also exposes
/// pre-built light and dark [ThemeData] from [AppTheme].

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:api_tester/core/theme/app_theme.dart';
import 'package:api_tester/domain/entities/app_settings.dart' as domain;
import 'package:api_tester/presentation/providers/settings_provider.dart';

// ---------------------------------------------------------------------------
// Theme Mode Provider
// ---------------------------------------------------------------------------

/// Maps the domain [domain.ThemeMode] to Flutter's [ThemeMode].
///
/// Reads the user's theme preference from [settingsProvider] and converts
/// it to the Material [ThemeMode] expected by [MaterialApp.themeMode].
final themeModeProvider = Provider<ThemeMode>((ref) {
  final settings = ref.watch(settingsProvider);
  return _mapThemeMode(settings.themeMode);
});

/// Converts the domain ThemeMode enum to Flutter's ThemeMode.
ThemeMode _mapThemeMode(domain.ThemeMode mode) {
  switch (mode) {
    case domain.ThemeMode.system:
      return ThemeMode.system;
    case domain.ThemeMode.light:
      return ThemeMode.light;
    case domain.ThemeMode.dark:
      return ThemeMode.dark;
  }
}

// ---------------------------------------------------------------------------
// Dark Mode Detection
// ---------------------------------------------------------------------------

/// Whether the app should render in dark mode right now.
///
/// When the user's setting is [domain.ThemeMode.dark] this is always `true`.
/// When [domain.ThemeMode.light] it is always `false`.
/// When [domain.ThemeMode.system] it depends on the platform's current
/// brightness, obtained from [MediaQuery.platformBrightness].
///
/// Usage in widgets:
/// ```dart
/// final isDark = ref.watch(isDarkModeProvider);
/// ```
final isDarkModeProvider = Provider<bool>((ref) {
  final settings = ref.watch(settingsProvider);

  switch (settings.themeMode) {
    case domain.ThemeMode.dark:
      return true;
    case domain.ThemeMode.light:
      return false;
    case domain.ThemeMode.system:
      // Default to light; the provider will be overridden by
      // [isDarkModeWithPlatformProvider] when a BuildContext is available.
      return false;
  }
});

/// Platform-aware dark mode detection that requires a [BuildContext].
///
/// This provider uses [MediaQuery.platformBrightness] to determine
/// the system's current brightness when the theme mode is set to
/// [domain.ThemeMode.system]. Wrap the [ProviderScope] or a parent
/// widget with a [MediaQuery] so this has access to the platform data.
///
/// Because this depends on a [BuildContext], it should be accessed via
/// a family or by using [ProviderScope.overrides] in the widget tree.
/// A simpler approach is to call [isDarkModeFromContext] in a widget's
/// build method:
/// ```dart
/// final isDark = isDarkModeFromContext(context, ref);
/// ```
bool isDarkModeFromContext(BuildContext context, WidgetRef ref) {
  final settings = ref.watch(settingsProvider);

  switch (settings.themeMode) {
    case domain.ThemeMode.dark:
      return true;
    case domain.ThemeMode.light:
      return false;
    case domain.ThemeMode.system:
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }
}

// ---------------------------------------------------------------------------
// Theme Data Providers
// ---------------------------------------------------------------------------

/// The light [ThemeData] from [AppTheme].
///
/// Use this for `MaterialApp.theme` or to style individual widgets
/// in light mode.
final lightThemeProvider = Provider<ThemeData>((ref) {
  return AppTheme.light;
});

/// The dark [ThemeData] from [AppTheme].
///
/// Use this for `MaterialApp.darkTheme` or to style individual widgets
/// in dark mode.
final darkThemeProvider = Provider<ThemeData>((ref) {
  return AppTheme.dark;
});
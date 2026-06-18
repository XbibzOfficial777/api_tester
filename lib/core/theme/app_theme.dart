/// @file app_theme.dart
/// @brief Central Material 3 theme definition for the API Tester application.
///
/// Provides both light and dark [ThemeData] configurations using Material
/// Design 3 (Material You). Includes a custom colour palette optimised for
/// API testing workflows (status-code colouring, syntax highlighting), the
/// Inter typeface via Google Fonts, and component-level theme overrides.
///
/// Usage:
/// ```dart
/// MaterialApp(
///   theme: AppTheme.light,
///   darkTheme: AppTheme.dark,
///   themeMode: ThemeMode.system,
/// );
/// ```

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralised theme configuration for the API Tester application.
///
/// Exposes static accessors for both light and dark [ThemeData] instances.
/// The colour system uses professional blues and greys with semantic status
/// colours (green for 2xx, orange for 4xx, red for 5xx, etc.) to help users
/// quickly identify HTTP response outcomes at a glance.
class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------------
  // Brand Colours
  // ---------------------------------------------------------------------------

  /// Primary brand colour — a vivid blue that conveys trust & technology.
  static const Color primarySeed = Color(0xFF1A73E8);

  /// Secondary accent — a teal-green used for success indicators.
  static const Color secondarySeed = Color(0xFF00BFA5);

  /// Tertiary accent — a warm amber for warnings and caution states.
  static const Color tertiarySeed = Color(0xFFFFB300);

  // ---------------------------------------------------------------------------
  // Status-Code Colours
  // ---------------------------------------------------------------------------

  /// Colour for informational responses (1xx).
  static const Color status1xx = Color(0xFF78909C);

  /// Colour for successful responses (2xx) — green.
  static const Color status2xx = Color(0xFF43A047);

  /// Colour for redirection responses (3xx) — blue.
  static const Color status3xx = Color(0xFF1E88E5);

  /// Colour for client-error responses (4xx) — orange.
  static const Color status4xx = Color(0xFFFB8C00);

  /// Colour for server-error responses (5xx) — red.
  static const Color status5xx = Color(0xFFE53935);

  // ---------------------------------------------------------------------------
  // Surface / Background Tints
  // ---------------------------------------------------------------------------

  /// Darker shade used for code / response body containers.
  static const Color codeBackgroundLight = Color(0xFFF5F7FA);
  static const Color codeBackgroundDark = Color(0xFF1E1E2E);

  /// Subtle surface tint applied to cards and dialogs.
  static const Color surfaceTint = Color(0xFF1A73E8);

  // ---------------------------------------------------------------------------
  // Inter Typefaces
  // ---------------------------------------------------------------------------

  /// Returns the canonical [TextTheme] built from Google Fonts Inter.
  ///
  /// All font weights map to Inter's corresponding styles, ensuring a
  /// consistent and readable typographic hierarchy throughout the app.
  static TextTheme _buildTextTheme(Brightness brightness) {
    final baseColor = brightness == Brightness.dark
        ? const Color(0xFFE0E0E0)
        : const Color(0xFF212121);

    return GoogleFonts.interTextTheme(
      brightness == Brightness.dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    ).apply(
      bodyColor: baseColor,
      displayColor: baseColor,
    );
  }

  // ---------------------------------------------------------------------------
  // Light Theme
  // ---------------------------------------------------------------------------

  /// Material 3 light theme configuration.
  ///
  /// Uses the [primarySeed] blue as the colour seed for the Material You
  /// colour scheme generator, producing a harmonious palette automatically.
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primarySeed,
      brightness: Brightness.light,
      primary: const Color(0xFF1565C0),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFD1E4FF),
      onPrimaryContainer: const Color(0xFF001D3F),
      secondary: const Color(0xFF00897B),
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFA7FFEB),
      onSecondaryContainer: const Color(0xFF00201B),
      tertiary: const Color(0xFF7C5800),
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFFFDEA3),
      onTertiaryContainer: const Color(0xFF271900),
      error: const Color(0xFFBA1A1A),
      onError: Colors.white,
      errorContainer: const Color(0xFFFFDAD6),
      onErrorContainer: const Color(0xFF410002),
      surface: const Color(0xFFFAFBFF),
      onSurface: const Color(0xFF1B1B1F),
      surfaceContainerHighest: const Color(0xFFE1E2EC),
      outline: const Color(0xFF757583),
      outlineVariant: const Color(0xFFC5C5D3),
    );

    final textTheme = _buildTextTheme(Brightness.light);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: const Color(0xFFF8F9FC),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
        ),
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          side: BorderSide(color: colorScheme.outline),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        elevation: 0,
        selectedLabelStyle: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: textTheme.labelSmall,
        type: BottomNavigationBarType.fixed,
        landscapeLayout: BottomNavigationBarLandscapeLayout.centered,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surface,
        selectedIconTheme: IconThemeData(color: colorScheme.primary),
        unselectedIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
        selectedLabelTextStyle: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: colorScheme.primary,
        ),
        unselectedLabelTextStyle: textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        labelStyle: textTheme.labelMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      dialogTheme: DialogTheme(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: colorScheme.surface,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dark Theme
  // ---------------------------------------------------------------------------

  /// Material 3 dark theme configuration.
  ///
  /// Generated from the same [primarySeed] but with [Brightness.dark],
  /// producing desaturated dark-mode surfaces that reduce eye strain.
  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primarySeed,
      brightness: Brightness.dark,
      primary: const Color(0xFF9ECAFF),
      onPrimary: const Color(0xFF003258),
      primaryContainer: const Color(0xFF00497E),
      onPrimaryContainer: const Color(0xFFD1E4FF),
      secondary: const Color(0xFF80DDC9),
      onSecondary: const Color(0xFF003731),
      secondaryContainer: const Color(0xFF005048),
      onSecondaryContainer: const Color(0xFFA7FFEB),
      tertiary: const Color(0xFFFFB951),
      onTertiary: const Color(0xFF422C00),
      tertiaryContainer: const Color(0xFF5F4000),
      onTertiaryContainer: const Color(0xFFFFDEA3),
      error: const Color(0xFFFFB4AB),
      onError: const Color(0xFF690005),
      errorContainer: const Color(0xFF93000A),
      onErrorContainer: const Color(0xFFFFDAD6),
      surface: const Color(0xFF1B1B1F),
      onSurface: const Color(0xFFE3E2E6),
      surfaceContainerHighest: const Color(0xFF3B3B43),
      outline: const Color(0xFF8F8F9B),
      outlineVariant: const Color(0xFF44444E),
    );

    final textTheme = _buildTextTheme(Brightness.dark);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: const Color(0xFF121216),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
        ),
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          side: BorderSide(color: colorScheme.outline),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius(10),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        elevation: 0,
        selectedLabelStyle: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: textTheme.labelSmall,
        type: BottomNavigationBarType.fixed,
        landscapeLayout: BottomNavigationBarLandscapeLayout.centered,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surface,
        selectedIconTheme: IconThemeData(color: colorScheme.primary),
        unselectedIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
        selectedLabelTextStyle: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: colorScheme.primary,
        ),
        unselectedLabelTextStyle: textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        labelStyle: textTheme.labelMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      dialogTheme: DialogTheme(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: colorScheme.surface,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Status Code Colour Helpers
  // ---------------------------------------------------------------------------

  /// Returns a semantic colour for the given HTTP status code.
  ///
  /// - **1xx** → grey ([status1xx])
  /// - **2xx** → green ([status2xx])
  /// - **3xx** → blue ([status3xx])
  /// - **4xx** → orange ([status4xx])
  /// - **5xx** → red ([status5xx])
  /// - **0 or other** → neutral grey
  ///
  /// ```dart
  /// final color = AppTheme.statusCodeColor(response.statusCode ?? 0);
  /// ```
  static Color statusCodeColor(int statusCode) {
    if (statusCode >= 100 && statusCode < 200) return status1xx;
    if (statusCode >= 200 && statusCode < 300) return status2xx;
    if (statusCode >= 300 && statusCode < 400) return status3xx;
    if (statusCode >= 400 && statusCode < 500) return status4xx;
    if (statusCode >= 500) return status5xx;
    return Colors.grey;
  }

  /// Returns a background colour with low opacity for status-code badges.
  ///
  /// Useful for chip / badge backgrounds that pair with [statusCodeColor].
  static Color statusCodeBackgroundColor(int statusCode) {
    if (statusCode >= 100 && statusCode < 200) return status1xx.withOpacity(0.15);
    if (statusCode >= 200 && statusCode < 300) return status2xx.withOpacity(0.15);
    if (statusCode >= 300 && statusCode < 400) return status3xx.withOpacity(0.15);
    if (statusCode >= 400 && statusCode < 500) return status4xx.withOpacity(0.15);
    if (statusCode >= 500) return status5xx.withOpacity(0.15);
    return Colors.grey.withOpacity(0.15);
  }
}

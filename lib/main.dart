/// @file main.dart
/// @brief Application entry point and root widget configuration.
///
/// Bootstraps the dependency injection container, wraps the widget tree in
/// a [ProviderScope] for Riverpod state management, and configures the
/// [MaterialApp.router] with Material 3 theming, the Inter typeface, and
/// the [GoRouter] instance defined in [app_router].
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/di/injection.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/routes/app_router.dart';

/// Application entry point.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await configureDependencies();

  runApp(const ProviderScope(child: ApiTesterApp()));
}

/// Root widget for the API Tester application.
///
/// Configures [MaterialApp.router] with:
/// - Material 3 theming from [AppTheme] (light & dark variants).
/// - [ThemeMode] driven by [themeModeProvider].
/// - [GoRouter] from [appRouter].
/// - System overlay style that adapts to the current theme.
/// - Debug banner disabled.
class ApiTesterApp extends ConsumerWidget {
  /// Creates the root [ApiTesterApp] widget.
  const ApiTesterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      routerConfig: appRouter,

      // ---- Theming --------------------------------------------------------
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,

      // ---- General --------------------------------------------------------
      debugShowCheckedModeBanner: false,
      title: 'API Tester',

      // ---- Builder: system overlay style ----------------------------------
      builder: (context, child) {
        // Adapt status bar / navigation bar icons to the current brightness.
        final brightness = Theme.of(context).brightness;
        final overlayStyle = brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark;
        SystemChrome.setSystemUIOverlayStyle(overlayStyle.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
        ));
        return child!;
      },
    );
  }
}
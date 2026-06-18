/// @file settings_provider.dart
/// @brief Riverpod provider for application-wide settings.
///
/// Exposes a [SettingsNotifier] that loads [AppSettings] on first access
/// and provides fine-grained update methods (theme, timeout, proxy, etc.).
/// All mutations are persisted via [SettingsRepository].

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:api_tester/core/di/injection.dart';
import 'package:api_tester/domain/entities/app_settings.dart';
import 'package:api_tester/domain/entities/proxy_settings.dart';
import 'package:api_tester/domain/repositories/settings_repository.dart';

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// Manages the [AppSettings] state and persists every change.
///
/// Settings are loaded from the repository on first access. Subsequent
/// mutations update the in-memory state and persist to storage
/// immediately so they survive app restarts.
class SettingsNotifier extends StateNotifier<AppSettings> {
  final SettingsRepository _repo;

  /// Creates a [SettingsNotifier] and eagerly loads the persisted settings.
  ///
  /// If loading fails (e.g. first launch), the default [AppSettings] is
  /// used and persisted as the initial state.
  SettingsNotifier(this._repo) : super(const AppSettings()) {
    _loadSettings();
  }

  /// Loads settings from the repository, falling back to defaults.
  Future<void> _loadSettings() async {
    try {
      final settings = await _repo.getAppSettings();
      state = settings;
    } catch (_) {
      // Use default settings on first launch or error.
      state = const AppSettings();
      // Persist the defaults so they are available on next launch.
      try {
        await _repo.updateAppSettings(state);
      } catch (_) {
        // Ignore persistence errors during initialization.
      }
    }
  }

  /// Public reload method – useful after a settings reset.
  Future<void> loadSettings() async {
    try {
      final settings = await _repo.getAppSettings();
      state = settings;
    } catch (e) {
      // Keep the current state on error.
    }
  }

  /// Updates the theme mode and persists the change.
  Future<void> updateThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _persist();
  }

  /// Updates the default request timeout (in seconds).
  Future<void> updateDefaultTimeout(int timeoutSeconds) async {
    state = state.copyWith(defaultTimeout: timeoutSeconds);
    await _persist();
  }

  /// Updates whether new requests follow HTTP redirects by default.
  Future<void> updateFollowRedirects(bool follow) async {
    state = state.copyWith(defaultFollowRedirects: follow);
    await _persist();
  }

  /// Updates whether new requests verify SSL certificates by default.
  Future<void> updateVerifySsl(bool verify) async {
    state = state.copyWith(defaultVerifySsl: verify);
    await _persist();
  }

  /// Updates the global proxy settings (pass `null` to disable).
  Future<void> updateGlobalProxy(ProxySettings? proxy) async {
    state = state.copyWith(globalProxy: proxy);
    await _persist();
  }

  /// Updates the base font size for code/body editors.
  Future<void> updateFontSize(double size) async {
    state = state.copyWith(fontSize: size);
    await _persist();
  }

  /// Toggles anonymous usage analytics on or off.
  Future<void> toggleAnalytics(bool enabled) async {
    state = state.copyWith(sendAnalytics: enabled);
    await _persist();
  }

  /// Toggles the floating window feature on or off.
  Future<void> toggleFloatingWindow(bool enabled) async {
    state = state.copyWith(floatingWindowEnabled: enabled);
    await _persist();
  }

  /// Persists the current in-memory state to the repository.
  Future<void> _persist() async {
    try {
      await _repo.updateAppSettings(state);
    } catch (e) {
      // Persistence failures are non-fatal – the in-memory state
      // remains valid and will be retried on the next mutation.
    }
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Provides the application-wide [AppSettings].
///
/// Settings are loaded eagerly when this provider is first read. All
/// subsequent mutations via [SettingsNotifier] are persisted immediately.
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  final repo = getIt<SettingsRepository>();
  return SettingsNotifier(repo);
});
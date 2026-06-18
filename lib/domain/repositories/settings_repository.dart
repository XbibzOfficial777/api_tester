/// @file settings_repository.dart
/// @brief Repository interface for application settings persistence.
///
/// Provides a simple interface for reading and updating the global
/// [AppSettings] entity, which controls app-wide defaults and preferences.
library;

import '../entities/app_settings.dart';

/// Abstract repository for persisting and retrieving [AppSettings].
///
/// Implementations typically use SharedPreferences or similar key-value
/// storage since there is only one settings instance.
abstract class SettingsRepository {
  /// Retrieves the current application settings.
  ///
  /// Returns the persisted settings, or a default [AppSettings] instance
  /// if no settings have been saved yet.
  Future<AppSettings> getAppSettings();

  /// Persists updated application settings.
  ///
  /// [settings] - The complete settings object to save. The entire
  /// object is replaced (partial updates are not supported).
  ///
  /// Returns the saved settings instance.
  Future<AppSettings> updateAppSettings(AppSettings settings);
}
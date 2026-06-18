/// Implementation of [SettingsRepository] backed by the Drift local database.
///
/// The settings table is a simple key-value store; this repository wraps
/// the [SettingsDao] with domain-appropriate error handling.
library;

import 'dart:convert';

import '../../../domain/entities/app_settings.dart';
import '../../../domain/repositories/settings_repository.dart';
import '../datasources/local/database/app_database.dart';

/// Concrete [SettingsRepository] that persists settings to SQLite.
class SettingsRepositoryImpl implements SettingsRepository {
  /// The Drift database instance, typically injected via a DI container.
  final AppDatabase _db;

  /// Creates a [SettingsRepositoryImpl] backed by [_db].
  SettingsRepositoryImpl(this._db);

  // ---------------------------------------------------------------------------
  // SettingsRepository
  // ---------------------------------------------------------------------------

  @override
  Future<AppSettings> getAppSettings() async {
    try {
      final jsonStr = await _db.settingsDao.getValue('app_settings');
      if (jsonStr == null || jsonStr.isEmpty) {
        return const AppSettings();
      }
      final decoded = json.decode(jsonStr) as Map<String, dynamic>;
      return AppSettings.fromJson(decoded);
    } catch (e) {
      throw Exception('Failed to get app settings: $e');
    }
  }

  @override
  Future<AppSettings> updateAppSettings(AppSettings settings) async {
    try {
      final jsonStr = json.encode(settings.toJson());
      await _db.settingsDao.setValue('app_settings', jsonStr);
      return settings;
    } catch (e) {
      throw Exception('Failed to update app settings: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Extra key-value helpers (not in the interface but used internally)
  // ---------------------------------------------------------------------------

  Future<String?> getValue(String key) async {
    try {
      return await _db.settingsDao.getValue(key);
    } catch (e) {
      throw Exception('Failed to get setting "$key": $e');
    }
  }

  Future<String> getValueOrDefault(String key, String defaultValue) async {
    try {
      return await _db.settingsDao.getValueOrDefault(key, defaultValue);
    } catch (e) {
      throw Exception('Failed to get setting "$key": $e');
    }
  }

  Future<void> setValue(String key, String value) async {
    try {
      await _db.settingsDao.setValue(key, value);
    } catch (e) {
      throw Exception('Failed to set setting "$key": $e');
    }
  }

  Future<void> removeValue(String key) async {
    try {
      await _db.settingsDao.removeValue(key);
    } catch (e) {
      throw Exception('Failed to remove setting "$key": $e');
    }
  }

  Future<bool> containsKey(String key) async {
    try {
      return await _db.settingsDao.containsKey(key);
    } catch (e) {
      throw Exception('Failed to check setting "$key": $e');
    }
  }

  Future<Map<String, String>> getAllSettings() async {
    try {
      return await _db.settingsDao.getAllSettings();
    } catch (e) {
      throw Exception('Failed to fetch all settings: $e');
    }
  }

  Future<void> clearAll() async {
    try {
      await _db.settingsDao.clearAll();
    } catch (e) {
      throw Exception('Failed to clear all settings: $e');
    }
  }
}
/// Data Access Object for the [Settings] table.
///
/// The settings table is a simple key-value store. This DAO provides
/// typed getters, setters, and bulk operations.
library;

import 'package:drift/drift.dart';
import '../tables.dart';
import '../app_database.dart';

part 'settings_dao.g.dart';

/// DAO encapsulating all database operations on the **settings** table.
@DriftAccessor(tables: [Settings])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  /// Creates a [SettingsDao] bound to the given [db] instance.
  SettingsDao(super.db);

  /// Returns the value for [key], or `null` if the key does not exist.
  Future<String?> getValue(String key) async {
    final row = await (select(settings)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  /// Returns the value for [key], falling back to [defaultValue] when the
  /// key is absent from the database.
  Future<String> getValueOrDefault(String key, String defaultValue) async {
    return (await getValue(key)) ?? defaultValue;
  }

  /// Persists a setting. If a row with [key] already exists its value is
  /// overwritten (upsert semantics).
  Future<void> setValue(String key, String value) {
    return into(settings).insert(
      SettingsCompanion(
        key: Value(key),
        value: Value(value),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  /// Removes the setting identified by [key].
  Future<void> removeValue(String key) {
    return (delete(settings)..where((t) => t.key.equals(key))).go();
  }

  /// Returns `true` when a row with [key] exists.
  Future<bool> containsKey(String key) async {
    final result = await (select(settings)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return result != null;
  }

  /// Returns **all** stored settings as a `Map<String, String>`.
  Future<Map<String, String>> getAllSettings() async {
    final rows = await select(settings).get();
    return {for (final row in rows) row.key: row.value};
  }

  /// Removes every row from the settings table.
  Future<void> clearAll() {
    return delete(settings).go();
  }
}
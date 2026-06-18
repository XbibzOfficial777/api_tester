/// Implementation of [EnvironmentRepository] backed by the Drift local
/// database.
///
/// Handles variable resolution, active-environment toggling, and cascading
/// deactivation when a new environment is activated.
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../domain/entities/environment.dart';
import '../../../domain/entities/key_value.dart';
import '../../../domain/repositories/environment_repository.dart';
import '../datasources/local/database/app_database.dart';
import '../datasources/local/database/tables.dart';
import '../mappers/environment_mapper.dart';

/// Concrete [EnvironmentRepository] that persists environments to SQLite.
class EnvironmentRepositoryImpl implements EnvironmentRepository {
  /// The Drift database instance, typically injected via a DI container.
  final AppDatabase _db;

  /// Creates an [EnvironmentRepositoryImpl] backed by [_db].
  EnvironmentRepositoryImpl(this._db);

  // ---------------------------------------------------------------------------
  // EnvironmentRepository
  // ---------------------------------------------------------------------------

  @override
  Future<List<Environment>> getEnvironmentsByWorkspace(
      String workspaceId) async {
    try {
      final rows =
          await _db.environmentDao.getEnvironmentsByWorkspace(workspaceId);
      return EnvironmentMapper.toEntityList(rows);
    } catch (e) {
      throw Exception(
          'Failed to fetch environments for workspace "$workspaceId": $e');
    }
  }

  @override
  Future<Environment> getEnvironment(String id) async {
    try {
      final row = await _db.environmentDao.getEnvironmentById(id);
      if (row == null) {
        throw Exception('Environment with id "$id" not found.');
      }
      return EnvironmentMapper.toEntity(row);
    } catch (e) {
      throw Exception('Failed to fetch environment with id "$id": $e');
    }
  }

  Future<Environment?> getEnvironmentById(String id) async {
    try {
      final row = await _db.environmentDao.getEnvironmentById(id);
      return row != null ? EnvironmentMapper.toEntity(row) : null;
    } catch (e) {
      throw Exception('Failed to fetch environment with id "$id": $e');
    }
  }

  @override
  Future<Environment?> getActiveEnvironment(String workspaceId) async {
    try {
      final row = await _db.environmentDao.getActiveEnvironment(workspaceId);
      return row != null ? EnvironmentMapper.toEntity(row) : null;
    } catch (e) {
      throw Exception(
          'Failed to fetch active environment for workspace "$workspaceId": $e');
    }
  }

  @override
  Future<Environment> createEnvironment(Environment environment) async {
    try {
      final companion = EnvironmentMapper.fromEntity(environment);
      await _db.environmentDao.insertEnvironment(companion);
      return environment;
    } catch (e) {
      throw Exception(
          'Failed to create environment "${environment.name}": $e');
    }
  }

  @override
  Future<Environment> updateEnvironment(Environment environment) async {
    try {
      // If the environment is being set as active, deactivate all other
      // environments in the same workspace first.
      if (environment.isActive) {
        await _db.environmentDao.setActiveEnvironment(
          environment.workspaceId,
          environment.id,
        );
        // Re-read from DB to get the consistent state.
        final updatedRow =
            await _db.environmentDao.getEnvironmentById(environment.id);
        if (updatedRow == null) {
          throw Exception(
              'Environment with id "${environment.id}" not found after activation.');
        }
        return EnvironmentMapper.toEntity(updatedRow);
      }

      // Normal update path (not activating).
      final companion = EnvironmentMapper.fromEntity(environment);
      final updated = await _db.environmentDao.updateEnvironment(companion);
      if (!updated) {
        throw Exception(
            'Environment with id "${environment.id}" not found.');
      }
      return environment;
    } catch (e) {
      throw Exception(
          'Failed to update environment "${environment.name}": $e');
    }
  }

  @override
  Future<void> setActiveEnvironment(String workspaceId, String environmentId) async {
    try {
      await _db.environmentDao.setActiveEnvironment(workspaceId, environmentId);
    } catch (e) {
      throw Exception(
          'Failed to set active environment "$environmentId" for workspace "$workspaceId": $e');
    }
  }

  @override
  Future<void> deleteEnvironment(String id) async {
    try {
      await _db.environmentDao.deleteEnvironment(id);
    } catch (e) {
      throw Exception('Failed to delete environment with id "$id": $e');
    }
  }

  @override
  Future<String> resolveVariables(String workspaceId, String input) async {
    try {
      final variables = <String, String>{};

      // 1. Load global environment variables (lower priority).
      final global =
          await _db.environmentDao.getGlobalEnvironment(workspaceId);
      if (global != null) {
        final kvs = _parseVariables(global.variables);
        for (final kv in kvs) {
          if (kv.enabled && kv.key.isNotEmpty) {
            variables[kv.key] = kv.value;
          }
        }
      }

      // 2. Load active environment variables (higher priority –
      //    overwrites global duplicates).
      final active =
          await _db.environmentDao.getActiveEnvironment(workspaceId);
      if (active != null) {
        final kvs = _parseVariables(active.variables);
        for (final kv in kvs) {
          if (kv.enabled && kv.key.isNotEmpty) {
            variables[kv.key] = kv.value;
          }
        }
      }

      // 3. Replace all {{variable}} placeholders in the input string.
      String result = input;
      for (final entry in variables.entries) {
        result = result.replaceAll('{{${entry.key}}}', entry.value);
      }
      return result;
    } catch (e) {
      throw Exception(
          'Failed to resolve variables for workspace "$workspaceId": $e');
    }
  }

  Stream<List<Environment>> watchEnvironmentsByWorkspace(String workspaceId) {
    try {
      return _db.environmentDao
          .watchEnvironmentsByWorkspace(workspaceId)
          .map(EnvironmentMapper.toEntityList);
    } catch (e) {
      throw Exception(
          'Failed to watch environments for workspace "$workspaceId": $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Parses the JSON-encoded variable list from a database row into
  /// a list of [KeyValue] objects.
  List<KeyValue> _parseVariables(String jsonString) {
    if (jsonString.isEmpty) return [];
    try {
      final decoded = json.decode(jsonString) as List<dynamic>;
      return decoded.map((item) {
        final map = item as Map<String, dynamic>;
        return KeyValue(
          key: map['key'] as String? ?? '',
          value: map['value'] as String? ?? '',
          enabled: map['enabled'] as bool? ?? true,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
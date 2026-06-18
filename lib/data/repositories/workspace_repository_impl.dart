/// Implementation of [WorkspaceRepository] backed by the Drift local
/// database.
///
/// All methods delegate to [WorkspaceDao] and use [WorkspaceMapper] to
/// translate between domain entities and Drift data-classes.
library;

import '../../../domain/entities/workspace.dart';
import '../../../domain/repositories/workspace_repository.dart';
import '../datasources/local/database/app_database.dart';
import '../mappers/workspace_mapper.dart';

/// Concrete [WorkspaceRepository] that persists workspaces to SQLite via
/// Drift.
class WorkspaceRepositoryImpl implements WorkspaceRepository {
  /// The Drift database instance, typically injected via a DI container.
  final AppDatabase _db;

  /// Creates a [WorkspaceRepositoryImpl] backed by [_db].
  WorkspaceRepositoryImpl(this._db);

  // ---------------------------------------------------------------------------
  // WorkspaceRepository
  // ---------------------------------------------------------------------------

  @override
  Future<List<Workspace>> getAllWorkspaces() async {
    try {
      final rows = await _db.workspaceDao.getAllWorkspaces();
      return WorkspaceMapper.toEntityList(rows);
    } catch (e) {
      throw Exception('Failed to fetch workspaces: $e');
    }
  }

  @override
  Future<Workspace?> getWorkspaceById(String id) async {
    try {
      final row = await _db.workspaceDao.getWorkspaceById(id);
      return row != null ? WorkspaceMapper.toEntity(row) : null;
    } catch (e) {
      throw Exception('Failed to fetch workspace with id "$id": $e');
    }
  }

  @override
  Future<Workspace> createWorkspace(Workspace workspace) async {
    try {
      final companion = WorkspaceMapper.fromEntity(workspace);
      await _db.workspaceDao.insertWorkspace(companion);
      return workspace;
    } catch (e) {
      throw Exception('Failed to create workspace "${workspace.name}": $e');
    }
  }

  @override
  Future<Workspace> updateWorkspace(Workspace workspace) async {
    try {
      final companion = WorkspaceMapper.fromEntity(workspace);
      final updated = await _db.workspaceDao.updateWorkspace(companion);
      if (!updated) {
        throw Exception('Workspace with id "${workspace.id}" not found.');
      }
      return workspace;
    } catch (e) {
      throw Exception('Failed to update workspace "${workspace.name}": $e');
    }
  }

  @override
  Future<void> deleteWorkspace(String id) async {
    try {
      // Delete related data first to avoid foreign-key violations.
      // The order matters: history → requests → assertions → collections →
      // environments → workspace.
      await _db.historyDao.deleteHistoryByWorkspace(id);
      await _db.requestDao.deleteRequestsByWorkspace(id);
      await _db.collectionDao.deleteCollectionsByWorkspace(id);
      await _db.environmentDao.deleteEnvironmentsByWorkspace(id);
      await _db.workspaceDao.deleteWorkspace(id);
    } catch (e) {
      throw Exception('Failed to delete workspace with id "$id": $e');
    }
  }

  @override
  Stream<List<Workspace>> watchAllWorkspaces() {
    try {
      return _db.workspaceDao
          .watchAllWorkspaces()
          .map(WorkspaceMapper.toEntityList);
    } catch (e) {
      throw Exception('Failed to watch workspaces: $e');
    }
  }
}
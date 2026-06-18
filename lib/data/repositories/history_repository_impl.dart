/// Implementation of [HistoryRepository] backed by the Drift local database.
library;

import '../../../domain/entities/request_history.dart';
import '../../../domain/repositories/history_repository.dart';
import '../datasources/local/database/app_database.dart';
import '../mappers/history_mapper.dart';

/// Concrete [HistoryRepository] that persists request history entries to
/// SQLite.
class HistoryRepositoryImpl implements HistoryRepository {
  /// The Drift database instance, typically injected via a DI container.
  final AppDatabase _db;

  /// Creates a [HistoryRepositoryImpl] backed by [_db].
  HistoryRepositoryImpl(this._db);

  // ---------------------------------------------------------------------------
  // HistoryRepository
  // ---------------------------------------------------------------------------

  @override
  Future<List<RequestHistoryTableData>> getHistoryByWorkspace(
      String workspaceId) async {
    try {
      final rows =
          await _db.historyDao.getHistoryByWorkspace(workspaceId);
      return HistoryMapper.toEntityList(rows);
    } catch (e) {
      throw Exception(
          'Failed to fetch history for workspace "$workspaceId": $e');
    }
  }

  @override
  Future<RequestHistoryTableData?> getHistoryById(String id) async {
    try {
      final row = await _db.historyDao.getHistoryById(id);
      return row != null ? HistoryMapper.toEntity(row) : null;
    } catch (e) {
      throw Exception('Failed to fetch history entry with id "$id": $e');
    }
  }

  @override
  Future<List<RequestHistoryTableData>> getHistoryByRequest(
      String requestId) async {
    try {
      final rows = await _db.historyDao.getHistoryByRequest(requestId);
      return HistoryMapper.toEntityList(rows);
    } catch (e) {
      throw Exception(
          'Failed to fetch history for request "$requestId": $e');
    }
  }

  @override
  Future<RequestHistoryTableData> createHistoryEntry(
      RequestHistoryTableData entry) async {
    try {
      final companion = HistoryMapper.fromEntity(entry);
      await _db.historyDao.insertHistoryEntry(companion);
      return entry;
    } catch (e) {
      throw Exception('Failed to create history entry: $e');
    }
  }

  @override
  Future<void> togglePin(String id) async {
    try {
      await _db.historyDao.togglePin(id);
    } catch (e) {
      throw Exception('Failed to toggle pin for history entry "$id": $e');
    }
  }

  @override
  Future<void> deleteHistoryEntry(String id) async {
    try {
      await _db.historyDao.deleteHistoryEntry(id);
    } catch (e) {
      throw Exception(
          'Failed to delete history entry with id "$id": $e');
    }
  }

  @override
  Future<void> deleteHistoryByWorkspace(String workspaceId) async {
    try {
      await _db.historyDao.deleteHistoryByWorkspace(workspaceId);
    } catch (e) {
      throw Exception(
          'Failed to delete history for workspace "$workspaceId": $e');
    }
  }

  @override
  Stream<List<RequestHistoryTableData>> watchHistoryByWorkspace(
      String workspaceId) {
    try {
      return _db.historyDao
          .watchHistoryByWorkspace(workspaceId)
          .map(HistoryMapper.toEntityList);
    } catch (e) {
      throw Exception(
          'Failed to watch history for workspace "$workspaceId": $e');
    }
  }
}
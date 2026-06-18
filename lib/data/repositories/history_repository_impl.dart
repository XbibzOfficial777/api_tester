/// Implementation of [HistoryRepository] backed by the Drift local database.
library;

import 'package:drift/drift.dart';

import '../../../domain/entities/api_request.dart';
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
  // HistoryRepository interface methods
  // ---------------------------------------------------------------------------

  @override
  Future<List<RequestHistory>> getHistory(
    String workspaceId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final rows =
          await _db.historyDao.getHistoryByWorkspace(workspaceId);
      return rows
          .skip(offset)
          .take(limit)
          .map(_tableDataToDomain)
          .toList();
    } catch (e) {
      throw Exception(
          'Failed to fetch history for workspace "$workspaceId": $e');
    }
  }

  @override
  Future<void> addToHistory(RequestHistory history) async {
    try {
      await _db.historyDao.insertHistoryEntry(_domainToCompanion(history));
    } catch (e) {
      throw Exception('Failed to add history entry: $e');
    }
  }

  @override
  Future<void> deleteHistoryItem(String id) async {
    try {
      await _db.historyDao.deleteHistoryEntry(id);
    } catch (e) {
      throw Exception(
          'Failed to delete history entry with id "$id": $e');
    }
  }

  @override
  Future<void> clearHistory(String workspaceId) async {
    try {
      await _db.historyDao.deleteHistoryByWorkspace(workspaceId);
    } catch (e) {
      throw Exception(
          'Failed to clear history for workspace "$workspaceId": $e');
    }
  }

  @override
  Future<void> pinHistoryItem(String id) async {
    try {
      final entry = await _db.historyDao.getHistoryById(id);
      if (entry != null && !entry.isPinned) {
        await _db.historyDao.togglePin(id);
      }
    } catch (e) {
      throw Exception('Failed to pin history entry "$id": $e');
    }
  }

  @override
  Future<void> unpinHistoryItem(String id) async {
    try {
      final entry = await _db.historyDao.getHistoryById(id);
      if (entry != null && entry.isPinned) {
        await _db.historyDao.togglePin(id);
      }
    } catch (e) {
      throw Exception('Failed to unpin history entry "$id": $e');
    }
  }

  @override
  Future<List<RequestHistory>> searchHistory(
    String query,
    String workspaceId,
  ) async {
    try {
      final rows =
          await _db.historyDao.getHistoryByWorkspace(workspaceId);
      final lowerQuery = query.toLowerCase();
      return rows
          .where((r) =>
              (r.requestName?.toLowerCase().contains(lowerQuery) ??
                  false) ||
              r.url.toLowerCase().contains(lowerQuery) ||
              r.method.toLowerCase().contains(lowerQuery))
          .map(_tableDataToDomain)
          .toList();
    } catch (e) {
      throw Exception('Failed to search history: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Additional methods (beyond the interface)
  // ---------------------------------------------------------------------------

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

  Future<RequestHistoryTableData?> getHistoryById(String id) async {
    try {
      final row = await _db.historyDao.getHistoryById(id);
      return row != null ? HistoryMapper.toEntity(row) : null;
    } catch (e) {
      throw Exception('Failed to fetch history entry with id "$id": $e');
    }
  }

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

  Future<void> togglePin(String id) async {
    try {
      await _db.historyDao.togglePin(id);
    } catch (e) {
      throw Exception('Failed to toggle pin for history entry "$id": $e');
    }
  }

  Future<void> deleteHistoryEntry(String id) async {
    try {
      await _db.historyDao.deleteHistoryEntry(id);
    } catch (e) {
      throw Exception(
          'Failed to delete history entry with id "$id": $e');
    }
  }

  Future<void> deleteHistoryByWorkspace(String workspaceId) async {
    try {
      await _db.historyDao.deleteHistoryByWorkspace(workspaceId);
    } catch (e) {
      throw Exception(
          'Failed to delete history for workspace "$workspaceId": $e');
    }
  }

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

  // ---------------------------------------------------------------------------
  // Private helpers – domain ↔ Drift conversion
  // ---------------------------------------------------------------------------

  /// Converts a Drift [RequestHistoryTableData] row to a domain
  /// [RequestHistory] entity.
  static RequestHistory _tableDataToDomain(RequestHistoryTableData data) {
    return RequestHistory(
      id: data.id,
      workspaceId: data.workspaceId,
      requestId: data.requestId ?? '',
      name: data.requestName ?? '',
      method: HttpMethod.values.firstWhere(
        (e) => e.name.toUpperCase() == data.method.toUpperCase(),
        orElse: () => HttpMethod.get,
      ),
      url: data.url,
      statusCode: data.statusCode,
      responseTimeMs: data.responseTimeMs ?? 0,
      timestamp: data.timestamp,
      isPinned: data.isPinned,
    );
  }

  /// Converts a domain [RequestHistory] entity to a Drift
  /// [RequestHistoryCompanion] for insertion.
  static RequestHistoryCompanion _domainToCompanion(RequestHistory entity) {
    return RequestHistoryCompanion(
      id: Value(entity.id),
      workspaceId: Value(entity.workspaceId),
      requestId: Value(entity.requestId),
      requestName: Value(entity.name),
      method: Value(entity.method.name.toUpperCase()),
      url: Value(entity.url),
      statusCode: Value(entity.statusCode),
      responseTimeMs: Value(entity.responseTimeMs),
      timestamp: Value(entity.timestamp),
      isPinned: Value(entity.isPinned),
    );
  }
}
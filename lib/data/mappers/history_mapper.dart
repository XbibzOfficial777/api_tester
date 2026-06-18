/// Mapper that converts between [RequestHistoryTableData] (Drift data-class)
/// and the domain [RequestHistory] entity.
library;

import 'package:drift/drift.dart';

import '../../../domain/entities/request_history.dart';
import '../datasources/local/database/app_database.dart';

/// Stateless helper providing bidirectional mapping for [RequestHistoryTableData].
class HistoryMapper {
  HistoryMapper._();

  // ---------------------------------------------------------------------------
  // Data → Domain
  // ---------------------------------------------------------------------------

  /// Converts a Drift [RequestHistoryTableData] row into a domain
  /// [RequestHistoryTableData].
  static RequestHistoryTableData toEntity(RequestHistoryTableData data) {
    return RequestHistoryTableData(
      id: data.id,
      workspaceId: data.workspaceId,
      requestId: data.requestId,
      requestName: data.requestName,
      method: data.method,
      url: data.url,
      statusCode: data.statusCode,
      responseTimeMs: data.responseTimeMs,
      timestamp: data.timestamp,
      isPinned: data.isPinned,
    );
  }

  /// Converts a list of Drift rows into a list of domain entities.
  static List<RequestHistoryTableData> toEntityList(
      List<RequestHistoryTableData> data) {
    return data.map(toEntity).toList();
  }

  // ---------------------------------------------------------------------------
  // Domain → Data
  // ---------------------------------------------------------------------------

  /// Converts a domain [RequestHistoryTableData] into a Drift
  /// [RequestHistoryCompanion] suitable for insertion.
  static RequestHistoryCompanion fromEntity(RequestHistoryTableData entity) {
    return RequestHistoryCompanion(
      id: Value(entity.id),
      workspaceId: Value(entity.workspaceId),
      requestId: Value(entity.requestId),
      requestName: Value(entity.requestName),
      method: Value(entity.method),
      url: Value(entity.url),
      statusCode: Value(entity.statusCode),
      responseTimeMs: Value(entity.responseTimeMs),
      timestamp: Value(entity.timestamp),
      isPinned: Value(entity.isPinned),
    );
  }
}
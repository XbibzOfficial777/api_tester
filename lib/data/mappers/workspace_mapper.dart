/// Mapper that converts between [WorkspaceTableData] (Drift data-class)
/// and the domain [Workspace] entity.
///
/// All domain-layer ↔ data-layer conversions for workspaces are centralised
/// here so that the repository stays thin and testable.
library;

import 'package:drift/drift.dart';

import '../../../domain/entities/workspace.dart';
import '../datasources/local/database/tables.dart';

/// Stateless helper providing bidirectional mapping for [Workspace].
class WorkspaceMapper {
  WorkspaceMapper._();

  // ---------------------------------------------------------------------------
  // Data → Domain
  // ---------------------------------------------------------------------------

  /// Converts a Drift [WorkspaceTableData] row into a domain [Workspace].
  ///
  /// Drift stores `DateTime` columns as integers internally; the getter
  /// already returns a parsed `DateTime`, so no extra conversion is needed.
  static Workspace toEntity(WorkspaceTableData data) {
    return Workspace(
      id: data.id,
      name: data.name,
      description: data.description,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
    );
  }

  /// Converts a list of Drift rows into a list of domain entities.
  static List<Workspace> toEntityList(List<WorkspaceTableData> data) {
    return data.map(toEntity).toList();
  }

  // ---------------------------------------------------------------------------
  // Domain → Data
  // ---------------------------------------------------------------------------

  /// Converts a domain [Workspace] into a Drift [WorkspacesCompanion] that
  /// can be passed to `insert` or `update` on the workspace DAO.
  ///
  /// The companion wraps every non-nullable field in a [Value] and leaves
  /// nullable fields as [Value.absent()] when the domain value is `null`,
  /// which tells Drift to keep the existing database value.
  static WorkspacesCompanion fromEntity(Workspace entity) {
    return WorkspacesCompanion(
      id: Value(entity.id),
      name: Value(entity.name),
      description: Value(entity.description),
      createdAt: Value(entity.createdAt),
      updatedAt: Value(entity.updatedAt),
    );
  }
}
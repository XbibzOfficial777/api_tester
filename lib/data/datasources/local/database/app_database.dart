/// Root Drift database class for the API Tester application.
///
/// This single class owns the SQLite connection and exposes typed DAOs
/// for every table. All database interaction from the repository layer
/// MUST go through these DAOs – raw SQL queries should be avoided.
///
/// ## Schema versioning
/// - **Version 1** – initial schema with all seven tables.
///
/// ## Usage
/// ```dart
/// final db = AppDatabase();
/// final workspaces = await db.workspaceDao.getAllWorkspaces();
/// ```
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';
import 'daos/workspace_dao.dart';
import 'daos/request_dao.dart';
import 'daos/collection_dao.dart';
import 'daos/environment_dao.dart';
import 'daos/history_dao.dart';
import 'daos/settings_dao.dart';

part 'app_database.g.dart';

/// Central Drift database definition.
///
/// Annotated with `@DriftDatabase` so that the build runner can generate
/// the `$AppDatabase` super-class, the `_$AppDatabaseMixin`, and the
/// `.g.dart` part file.
@DriftDatabase(
  tables: [
    Workspaces,
    ApiRequests,
    Collections,
    Environments,
    RequestHistory,
    Assertions,
    Settings,
  ],
  daos: [
    WorkspaceDao,
    RequestDao,
    CollectionDao,
    EnvironmentDao,
    HistoryDao,
    SettingsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Constructs the database.
  ///
  /// When [executor] is provided it overrides the default native SQLite
  /// connection – this is useful for testing with an in-memory database.
  AppDatabase({QueryExecutor? executor}) : super(executor ?? _openConnection());

  /// Current schema version. Bump this number and add a corresponding
  /// entry in [migration] whenever the table definitions change.
  @override
  int get schemaVersion => 1;

  /// Migration strategy.
  ///
  /// - **onCreate**: runs the initial DDL (handled automatically by Drift).
  /// - **onUpgrade**: if the database file exists with an older schema
  ///   version, we simply recreate all tables by deleting and re-creating
  ///   the database. For production apps you would implement proper
  ///   incremental migrations using `m.createTable(...)`, `m.addColumn(...)`,
  ///   etc.
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          // Drift automatically creates all tables declared in the
          // `@DriftDatabase(tables: [...])` annotation.
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // For schema version 1 there are no prior versions to migrate
          // from. If `from < to` ever happens (e.g. due to a corrupted
          // version number), we recreate from scratch.
          if (from < 1) {
            await m.createAll();
          }
        },
        beforeOpen: (details) async {
          // Enable foreign-key enforcement for every connection.
          // This is off by default in SQLite.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  // ---------------------------------------------------------------------------
  // Singleton-like lazy connection opener
  // ---------------------------------------------------------------------------

  /// Opens (or creates) the SQLite database file in the application's
  /// document directory.
  ///
  /// The file is named `api_tester.db` and stored under
  /// `<app_documents_dir>/databases/`.
  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      // Resolve the platform-appropriate documents directory.
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'databases', 'api_tester.db'));

      // Ensure the parent directory exists.
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }

      // Connect using the native SQLite binding provided by
      // `sqlite3_flutter_libs`.
      return NativeDatabase.createInBackground(
        file,
        // Optionally enable WAL mode for better concurrent read
        // performance. This is safe for single-writer scenarios.
        setup: (db) {
          db.execute('PRAGMA journal_mode = WAL');
        },
      );
    });
  }
}
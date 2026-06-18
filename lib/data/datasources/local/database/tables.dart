/// Drift table definitions for the API Tester local database.
///
/// Each class maps 1:1 to a SQLite table. The generated data-class names are
/// configured via `@DataClassName` so they read naturally (e.g. `Workspace`
/// instead of `WorkspaceTableData`).
///
/// JSON-heavy columns (headers, query_params, form_data, request_ids,
/// variables) are stored as TEXT and serialised / deserialised by the
/// mappers in the data layer.
library;

import 'package:drift/drift.dart';

// ---------------------------------------------------------------------------
// Workspaces
// ---------------------------------------------------------------------------

/// Top-level organisational unit. Every request, collection, and environment
/// belongs to exactly one workspace.
@DataClassName('WorkspaceTableData')
class Workspaces extends Table {
  /// UUID v4 primary key.
  TextColumn get id => text()();

  /// Human-readable workspace name.
  TextColumn get name => text().withLength(min: 1)();

  /// Optional description.
  TextColumn get description => text().nullable()();

  /// Unix epoch milliseconds – creation timestamp.
  DateTimeColumn get createdAt =>
      dateTime().withDefault(Constant(DateTime.now()))();

  /// Unix epoch milliseconds – last-modified timestamp.
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(Constant(DateTime.now()))();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// API Requests
// ---------------------------------------------------------------------------

/// Stores the full definition of an API request including method, URL,
/// headers, body configuration, proxy, and timing settings.
@DataClassName('ApiRequestTableData')
class ApiRequests extends Table {
  /// UUID v4 primary key.
  TextColumn get id => text()();

  /// Foreign key – the owning workspace.
  TextColumn get workspaceId => text().references(Workspaces, #id)();

  /// Optional foreign key – the parent collection.
  TextColumn get collectionId => text().nullable()();

  /// Display name.
  TextColumn get name => text()();

  /// Optional notes.
  TextColumn get description => text().nullable()();

  /// HTTP method: GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS.
  TextColumn get method => text()();

  /// Target URL – may contain `{{variable}}` placeholders.
  TextColumn get url => text()();

  /// JSON-encoded list of `{key, value, enabled}` header objects.
  TextColumn get headers => text().withDefault(const Constant('[]'))();

  /// JSON-encoded list of `{key, value, enabled}` query-parameter objects.
  TextColumn get queryParams => text().withDefault(const Constant('[]'))();

  /// Body type enum stored as its name string (none, formData, …).
  TextColumn get bodyType => text().withDefault(const Constant('none'))();

  /// Raw body text (used when `bodyType == 'raw'`).
  TextColumn get bodyContent => text().nullable()();

  /// JSON-encoded list of `{key, value, enabled}` form-data objects.
  TextColumn get formData => text().withDefault(const Constant('[]'))();

  /// File-system path to a binary payload file.
  TextColumn get binaryFilePath => text().nullable()();

  /// Optional pre-request Dart script.
  TextColumn get preRequestScript => text().nullable()();

  // -- Proxy settings --------------------------------------------------------

  /// Whether a proxy should be used (stored as 0 / 1).
  BoolColumn get useProxy => boolean().withDefault(const Constant(false))();

  /// Proxy hostname / IP.
  TextColumn get proxyHost => text().nullable()();

  /// Proxy port number.
  IntColumn get proxyPort => integer().nullable()();

  /// Proxy type string: http, socks5, https.
  TextColumn get proxyType => text().nullable()();

  // -- Behaviour settings ----------------------------------------------------

  /// Request timeout in seconds (null = no explicit timeout).
  IntColumn get timeoutSeconds => integer().nullable()();

  /// Whether to follow 3xx redirects (0 / 1).
  BoolColumn get followRedirects =>
      boolean().withDefault(const Constant(true))();

  /// Whether to verify the server SSL certificate (0 / 1).
  BoolColumn get verifySsl => boolean().withDefault(const Constant(true))();

  // -- Timestamps -------------------------------------------------------------

  DateTimeColumn get createdAt =>
      dateTime().withDefault(Constant(DateTime.now()))();

  DateTimeColumn get updatedAt =>
      dateTime().withDefault(Constant(DateTime.now()))();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// Collections
// ---------------------------------------------------------------------------

/// An ordered group of request IDs that can be executed sequentially.
@DataClassName('CollectionTableData')
class Collections extends Table {
  /// UUID v4 primary key.
  TextColumn get id => text()();

  /// Owning workspace.
  TextColumn get workspaceId => text().references(Workspaces, #id)();

  /// Display name.
  TextColumn get name => text()();

  /// Optional notes.
  TextColumn get description => text().nullable()();

  /// JSON-encoded `List<String>` of request IDs in execution order.
  TextColumn get requestIds => text().withDefault(const Constant('[]'))();

  /// Delay (ms) between consecutive requests.
  IntColumn get delayMs => integer().withDefault(const Constant(0))();

  /// Stop on first error (0 / 1).
  BoolColumn get stopOnError => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(Constant(DateTime.now()))();

  DateTimeColumn get updatedAt =>
      dateTime().withDefault(Constant(DateTime.now()))();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// Environments
// ---------------------------------------------------------------------------

/// A named variable set that can be activated per-workspace. Variables are
/// referenced as `{{variable_name}}` inside requests.
@DataClassName('EnvironmentTableData')
class Environments extends Table {
  /// UUID v4 primary key.
  TextColumn get id => text()();

  /// Owning workspace.
  TextColumn get workspaceId => text().references(Workspaces, #id)();

  /// Display name.
  TextColumn get name => text()();

  /// JSON-encoded list of `{key, value, enabled}` variable objects.
  TextColumn get variables => text().withDefault(const Constant('[]'))();

  /// Whether this is the shared global environment (0 / 1).
  BoolColumn get isGlobal => boolean().withDefault(const Constant(false))();

  /// Whether this environment is currently active (0 / 1).
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(Constant(DateTime.now()))();

  DateTimeColumn get updatedAt =>
      dateTime().withDefault(Constant(DateTime.now()))();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// Request History
// ---------------------------------------------------------------------------

/// Immutable snapshot of a previously executed request and its response
/// metadata. Entries are primarily used for auditing and debugging.
@DataClassName('RequestHistoryTableData')
class RequestHistory extends Table {
  /// UUID v4 primary key.
  TextColumn get id => text()();

  /// Workspace context at the time of execution.
  TextColumn get workspaceId => text()();

  /// ID of the [ApiRequests] row that was executed (may be null if the
  /// request was ad-hoc and not saved).
  TextColumn get requestId => text().nullable()();

  /// Snapshot of the request name at execution time.
  TextColumn get requestName => text().nullable()();

  /// HTTP method that was used.
  TextColumn get method => text()();

  /// Fully resolved URL (variables already substituted).
  TextColumn get url => text()();

  /// HTTP status code received (null on network failure).
  IntColumn get statusCode => integer().nullable()();

  /// Response time in milliseconds.
  IntColumn get responseTimeMs => integer().nullable()();

  /// Unix epoch millisecond timestamp.
  DateTimeColumn get timestamp =>
      dateTime().withDefault(Constant(DateTime.now()))();

  /// Whether the user has pinned / bookmarked this entry (0 / 1).
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// Assertions
// ---------------------------------------------------------------------------

/// Test assertions attached to individual API requests.
@DataClassName('AssertionTableData')
class Assertions extends Table {
  /// UUID v4 primary key.
  TextColumn get id => text()();

  /// The request this assertion belongs to.
  TextColumn get requestId => text().references(ApiRequests, #id)();

  /// What part of the response is being evaluated.
  TextColumn get type => text()();

  /// The expected value / pattern.
  TextColumn get expectedValue => text().nullable()();

  /// Comparison operator enum name (equals, contains, …).
  TextColumn get comparisonOperator => text().named('operator')();

  /// The actual value extracted at evaluation time.
  TextColumn get actualValue => text().nullable()();

  /// Whether the assertion passed (null = not yet evaluated).
  BoolColumn get passed => boolean().nullable()();

  /// Human-readable error message on failure.
  TextColumn get errorMessage => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

/// Simple key-value store for application-wide configuration.
@DataClassName('SettingsTableData')
class Settings extends Table {
  /// Setting key (also the primary key).
  TextColumn get key => text()();

  /// Setting value as a plain string.
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
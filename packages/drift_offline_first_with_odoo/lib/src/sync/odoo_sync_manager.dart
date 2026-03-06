import 'package:drift/drift.dart';
import 'package:drift_odoo_core/drift_odoo_core.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:synchronized/synchronized.dart';

const _table = 'odoo_sync_state';
const _colModel = 'model';
const _colLastSync = 'last_sync_at';

/// Persists the last successful sync timestamp per Odoo model.
/// Used by [OfflineFirstWithOdooRepository.hydrateRemote] for incremental sync.
///
/// **Option A — dedicated database file (recommended for production):**
/// ```dart
/// final syncManager = OdooSyncManager(
///   NativeDatabase.createInBackground(File('odoo_sync_state.sqlite')),
/// );
/// ```
///
/// **Option B — reuse the main app Drift database** to keep everything in one
/// file (simpler setup, acceptable for most apps):
/// ```dart
/// // AppDatabase is your @DriftDatabase class.
/// final appDb = AppDatabase(NativeDatabase.createInBackground(File('app.db')));
/// final syncManager = OdooSyncManager(appDb.executor);
/// ```
/// `OdooSyncManager` creates its own `odoo_sync_state` table inside whatever
/// [QueryExecutor] you provide, so it coexists safely with Drift-managed tables.
///
/// All database access uses the Drift [QueryExecutor] API — no sqflite_common
/// types are imported by this file.
class OdooSyncManager {
  final QueryExecutor _executor;
  bool _migrated = false;
  final Lock _lock = Lock();

  @protected
  final Logger logger;

  OdooSyncManager(QueryExecutor executor)
      : _executor = executor,
        logger = Logger('OdooSyncManager');

  Future<void> _ensureMigrated() async {
    if (_migrated) return;
    await _executor.ensureOpen(_NoOpUser());
    await _executor.runCustom(
      '''
      CREATE TABLE IF NOT EXISTS $_table (
        $_colModel    TEXT PRIMARY KEY,
        $_colLastSync TEXT NOT NULL
      )
      ''',
      [],
    );
    _migrated = true;
  }

  /// Return the last sync time for [odooModel], or `null` if never synced.
  Future<DateTime?> lastSyncAt(String odooModel) async {
    await _ensureMigrated();
    final rows = await _executor.runSelect(
      'SELECT $_colLastSync FROM $_table WHERE $_colModel = ? LIMIT 1',
      [odooModel],
    );
    if (rows.isEmpty) return null;
    return DateTime.tryParse(rows.first[_colLastSync] as String);
  }

  /// Record a successful sync for [odooModel] at [syncedAt] (defaults to now).
  Future<void> updateLastSync(String odooModel, {DateTime? syncedAt}) async {
    await _ensureMigrated();
    final ts = (syncedAt ?? DateTime.now().toUtc()).toIso8601String();
    await _lock.synchronized(() => _executor.runInsert(
          'INSERT INTO $_table ($_colModel, $_colLastSync) VALUES (?, ?)'
          ' ON CONFLICT($_colModel) DO UPDATE SET $_colLastSync = excluded.$_colLastSync',
          [odooModel, ts],
        ));
    logger.finer('Sync state updated: $odooModel → $ts');
  }

  /// Reset sync state for [odooModel] (forces full re-sync on next hydrate).
  Future<void> reset(String odooModel) async {
    await _ensureMigrated();
    await _executor.runDelete(
      'DELETE FROM $_table WHERE $_colModel = ?',
      [odooModel],
    );
  }

  /// Reset all sync state.
  Future<void> resetAll() async {
    await _ensureMigrated();
    await _executor.runDelete('DELETE FROM $_table', []);
  }

  /// Build an incremental domain filter based on the last sync time.
  /// Returns `null` if this is the first sync (full sync needed).
  Future<OdooDomain?> incrementalDomain(String odooModel) async {
    final lastSync = await lastSyncAt(odooModel);
    if (lastSync == null) return null;
    return OdooDomainBuilder.writtenAfter(lastSync);
  }

  /// Close the underlying database executor.
  Future<void> close() => _executor.close();
}

// ---------------------------------------------------------------------------
// Internal: minimal QueryExecutorUser required by ensureOpen.
// ---------------------------------------------------------------------------

class _NoOpUser implements QueryExecutorUser {
  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}

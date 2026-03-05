import 'dart:async';

import 'package:logging/logging.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:synchronized/synchronized.dart';

/// Column names for the offline queue table.
const kQueueTable = 'odoo_offline_queue';
const kColId = '_id';
const kColModel = 'model';
const kColMethod = 'method';
const kColIds = 'ids';
const kColPayload = 'payload';
const kColAttempts = 'attempts';
const kColCreatedAt = 'created_at';
const kColUpdatedAt = 'updated_at';
const kColLocked = 'locked';

/// Manages the SQLite-backed offline queue for Odoo requests.
///
/// Uses a separate SQLite database file to persist pending mutations
/// (create, write, unlink) across app restarts.
class OdooRequestSqliteCacheManager {
  final String databaseName;
  final DatabaseFactory databaseFactory;

  /// How often the queue processor checks for pending jobs. Defaults to 5s.
  final Duration processingInterval;

  /// When `true`, jobs are processed one at a time in creation order.
  final bool serialProcessing;

  Database? _db;
  final Lock _lock = Lock();
  final Logger _logger;

  OdooRequestSqliteCacheManager(
    this.databaseName, {
    required this.databaseFactory,
    Duration? processingInterval,
    this.serialProcessing = true,
  })  : processingInterval = processingInterval ?? const Duration(seconds: 5),
        _logger = Logger('OdooOfflineQueue#$databaseName');

  Future<Database> getDb() async {
    if (_db != null) return _db!;
    _db = await databaseFactory.openDatabase(databaseName);
    return _db!;
  }

  /// Create the queue table if it doesn't exist.
  Future<void> migrate() async {
    final db = await getDb();
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $kQueueTable (
        $kColId       INTEGER PRIMARY KEY AUTOINCREMENT,
        $kColModel    TEXT    NOT NULL,
        $kColMethod   TEXT    NOT NULL,
        $kColIds      TEXT    NOT NULL DEFAULT '[]',
        $kColPayload  TEXT    NOT NULL DEFAULT '{}',
        $kColAttempts INTEGER NOT NULL DEFAULT 0,
        $kColCreatedAt INTEGER NOT NULL,
        $kColUpdatedAt INTEGER NOT NULL,
        $kColLocked   INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  /// Insert a new pending job or increment attempts if it already exists.
  ///
  /// Returns the row ID of the inserted or updated job.
  Future<int> insertOrUpdate({
    required String model,
    required String method,
    required String ids,
    required String payload,
    Logger? logger,
  }) async {
    final db = await getDb();
    return _lock.synchronized(() async {
      final now = DateTime.now().millisecondsSinceEpoch;

      final existing = await db.query(
        kQueueTable,
        columns: [kColId, kColAttempts],
        where:
            '$kColModel = ? AND $kColMethod = ? AND $kColIds = ? AND $kColPayload = ?',
        whereArgs: [model, method, ids, payload],
        limit: 1,
      );

      if (existing.isEmpty) {
        logger?.fine('OdooQueue: adding $method $model ids=$ids');
        return db.insert(kQueueTable, {
          kColModel: model,
          kColMethod: method,
          kColIds: ids,
          kColPayload: payload,
          kColAttempts: 0,
          kColCreatedAt: now,
          kColUpdatedAt: now,
          kColLocked: 1,
        });
      } else {
        final row = existing.first;
        final rowId = row[kColId] as int;
        final attempt = (row[kColAttempts] as int) + 1;
        logger?.warning('OdooQueue: attempt #$attempt for $method $model');
        await db.update(
          kQueueTable,
          {kColAttempts: attempt, kColUpdatedAt: now, kColLocked: 1},
          where: '$kColId = ?',
          whereArgs: [rowId],
        );
        return rowId;
      }
    });
  }

  /// Delete a processed job by its row ID.
  Future<void> delete(int rowId) async {
    final db = await getDb();
    await db.delete(kQueueTable, where: '$kColId = ?', whereArgs: [rowId]);
    _logger.finest('OdooQueue: removed job $rowId');
  }

  /// Unlock a job so it can be retried.
  Future<void> unlock(int rowId) async {
    final db = await getDb();
    await db.update(
      kQueueTable,
      {kColLocked: 0},
      where: '$kColId = ?',
      whereArgs: [rowId],
    );
  }

  /// Fetch and lock the next pending job. Returns `null` if queue is empty.
  Future<Map<String, dynamic>?> prepareNextRequestToProcess() async {
    final db = await getDb();
    return _lock.synchronized(() async {
      // Auto-unlock stale locks (locked for more than 2 minutes).
      final staleThreshold =
          DateTime.now().millisecondsSinceEpoch - const Duration(minutes: 2).inMilliseconds;
      final stale = await db.query(
        kQueueTable,
        columns: [kColId],
        where: '$kColLocked = 1 AND $kColUpdatedAt < ?',
        whereArgs: [staleThreshold],
      );
      for (final row in stale) {
        await db.update(
          kQueueTable,
          {kColLocked: 0},
          where: '$kColId = ?',
          whereArgs: [row[kColId]],
        );
      }

      if (serialProcessing) {
        final locked = await db.query(
          kQueueTable,
          columns: [kColId],
          where: '$kColLocked = 1',
          limit: 1,
        );
        if (locked.isNotEmpty) return null;
      }

      final nowMinusPoll =
          DateTime.now().millisecondsSinceEpoch - processingInterval.inMilliseconds;
      final rows = await db.query(
        kQueueTable,
        where: '$kColLocked = 0 AND $kColCreatedAt <= ?',
        whereArgs: [nowMinusPoll],
        orderBy: '$kColCreatedAt ASC',
        limit: 1,
      );

      if (rows.isEmpty) return null;

      final row = rows.first;
      await db.update(
        kQueueTable,
        {kColLocked: 1, kColUpdatedAt: DateTime.now().millisecondsSinceEpoch},
        where: '$kColId = ?',
        whereArgs: [row[kColId]],
      );

      return Map<String, dynamic>.from(row);
    });
  }

  /// All jobs in the queue ordered by creation time (for inspection/debugging).
  Future<List<Map<String, dynamic>>> unprocessedRequests() async {
    final db = await getDb();
    return db.query(kQueueTable, orderBy: '$kColCreatedAt ASC');
  }

  /// Remove a specific job by ID (for manual queue management).
  Future<bool> deleteUnprocessedRequest(int id) async {
    final db = await getDb();
    final count = await db.delete(kQueueTable, where: '$kColId = ?', whereArgs: [id]);
    return count > 0;
  }
}

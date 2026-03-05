// ignore_for_file: constant_identifier_names
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:sqflite_common/sqlite_api.dart';

const HTTP_JOBS_TABLE_NAME = 'HttpJobs';
const HTTP_JOBS_PRIMARY_KEY_COLUMN = 'id';
const HTTP_JOBS_METHOD_COLUMN = 'request_method';
const HTTP_JOBS_URL_COLUMN = 'url';
const HTTP_JOBS_HEADERS_COLUMN = 'headers';
const HTTP_JOBS_BODY_COLUMN = 'body';
const HTTP_JOBS_ENCODING_COLUMN = 'encoding';
const HTTP_JOBS_ATTEMPTS_COLUMN = 'attempts';
const HTTP_JOBS_CREATED_AT_COLUMN = 'created_at';
const HTTP_JOBS_UPDATED_AT_COLUMN = 'updated_at';
const HTTP_JOBS_LOCKED_COLUMN = 'locked';

/// SQLite-backed persistence for queued HTTP requests.
///
/// Each row represents one pending write request (POST/PUT/PATCH/DELETE) that
/// could not be sent while offline. Requests are processed serially and
/// protected by a lock to prevent concurrent replay.
///
/// Used by [HttpOfflineQueueClient] to store requests and by
/// [HttpOfflineRequestQueue] to replay them.
class HttpRequestSqliteCacheManager {
  /// Path to the SQLite database file.
  final String databasePath;

  /// The factory used to open the SQLite database.
  final DatabaseFactory databaseFactory;

  /// When `true` (default), requests are processed one at a time in
  /// creation order. When `false`, they are processed by update time (parallel).
  final bool serialProcessing;

  Database? _db;
  final Logger _logger;

  HttpRequestSqliteCacheManager(
    this.databasePath, {
    required this.databaseFactory,
    this.serialProcessing = true,
    String? loggerName,
  }) : _logger = Logger(loggerName ?? 'HttpRequestSqliteCacheManager');

  String get _orderBy =>
      serialProcessing ? '$HTTP_JOBS_CREATED_AT_COLUMN ASC' : '$HTTP_JOBS_UPDATED_AT_COLUMN ASC';

  /// Return the database name (used for logging).
  String get databaseName => databasePath;

  Future<Database> getDb() async {
    return _db ??= await databaseFactory.openDatabase(databasePath);
  }

  /// Create the jobs table if it does not exist.
  Future<void> migrate() async {
    final db = await getDb();
    await db.execute('''
      CREATE TABLE IF NOT EXISTS `$HTTP_JOBS_TABLE_NAME` (
        `$HTTP_JOBS_PRIMARY_KEY_COLUMN`  INTEGER PRIMARY KEY AUTOINCREMENT,
        `$HTTP_JOBS_METHOD_COLUMN`       TEXT NOT NULL,
        `$HTTP_JOBS_URL_COLUMN`          TEXT NOT NULL,
        `$HTTP_JOBS_HEADERS_COLUMN`      TEXT,
        `$HTTP_JOBS_BODY_COLUMN`         TEXT,
        `$HTTP_JOBS_ENCODING_COLUMN`     TEXT,
        `$HTTP_JOBS_ATTEMPTS_COLUMN`     INTEGER DEFAULT 1,
        `$HTTP_JOBS_CREATED_AT_COLUMN`   INTEGER DEFAULT 0,
        `$HTTP_JOBS_UPDATED_AT_COLUMN`   INTEGER DEFAULT 0,
        `$HTTP_JOBS_LOCKED_COLUMN`       INTEGER DEFAULT 0
      )
    ''');

    // Idempotent column additions for databases migrated from older versions.
    final info = await db.rawQuery('PRAGMA table_info("$HTTP_JOBS_TABLE_NAME");');
    final columns = info.map((r) => r['name'] as String).toSet();
    if (!columns.contains(HTTP_JOBS_CREATED_AT_COLUMN)) {
      await db.execute(
          'ALTER TABLE `$HTTP_JOBS_TABLE_NAME` ADD `$HTTP_JOBS_CREATED_AT_COLUMN` INTEGER DEFAULT 0');
    }
    _logger.fine('migrate: table ready at $databasePath');
  }

  /// Persist a new HTTP request into the queue and return its row id.
  Future<int> insertOrUpdate({
    required String method,
    required String url,
    required Map<String, String> headers,
    String? body,
    String? encoding,
  }) async {
    final db = await getDb();
    final now = DateTime.now().millisecondsSinceEpoch;

    // Check if identical request is already pending (deduplicate).
    final existing = await db.query(
      HTTP_JOBS_TABLE_NAME,
      where:
          '$HTTP_JOBS_METHOD_COLUMN = ? AND $HTTP_JOBS_URL_COLUMN = ? AND $HTTP_JOBS_BODY_COLUMN = ?',
      whereArgs: [method, url, body],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final id = existing.first[HTTP_JOBS_PRIMARY_KEY_COLUMN] as int;
      await db.update(
        HTTP_JOBS_TABLE_NAME,
        {HTTP_JOBS_UPDATED_AT_COLUMN: now},
        where: '$HTTP_JOBS_PRIMARY_KEY_COLUMN = ?',
        whereArgs: [id],
      );
      _logger.fine('insertOrUpdate: updated existing id=$id');
      return id;
    }

    final id = await db.insert(HTTP_JOBS_TABLE_NAME, {
      HTTP_JOBS_METHOD_COLUMN: method,
      HTTP_JOBS_URL_COLUMN: url,
      HTTP_JOBS_HEADERS_COLUMN: jsonEncode(headers),
      HTTP_JOBS_BODY_COLUMN: body,
      HTTP_JOBS_ENCODING_COLUMN: encoding,
      HTTP_JOBS_ATTEMPTS_COLUMN: 1,
      HTTP_JOBS_CREATED_AT_COLUMN: now,
      HTTP_JOBS_UPDATED_AT_COLUMN: now,
      HTTP_JOBS_LOCKED_COLUMN: 0,
    });
    _logger.fine('insertOrUpdate: inserted id=$id $method $url');
    return id;
  }

  /// Find and lock the next pending request for processing.
  ///
  /// Unlocks any job locked for more than 2 minutes (stale lock recovery).
  /// Returns `null` when there are no pending jobs.
  Future<Map<String, dynamic>?> prepareNextRequestToProcess() async {
    final db = await getDb();
    final twoMinutesAgo =
        DateTime.now().subtract(const Duration(minutes: 2)).millisecondsSinceEpoch;

    return await db.transaction<Map<String, dynamic>?>((txn) async {
      // Auto-unlock stale locks.
      await txn.update(
        HTTP_JOBS_TABLE_NAME,
        {HTTP_JOBS_LOCKED_COLUMN: 0},
        where: '$HTTP_JOBS_LOCKED_COLUMN = 1 AND $HTTP_JOBS_UPDATED_AT_COLUMN < ?',
        whereArgs: [twoMinutesAgo],
      );

      // If serial processing and something is currently locked, skip.
      if (serialProcessing) {
        final locked = await txn.query(
          HTTP_JOBS_TABLE_NAME,
          where: '$HTTP_JOBS_LOCKED_COLUMN = 1',
          limit: 1,
        );
        if (locked.isNotEmpty) return null;
      }

      final rows = await txn.query(
        HTTP_JOBS_TABLE_NAME,
        where: '$HTTP_JOBS_LOCKED_COLUMN = 0',
        orderBy: _orderBy,
        limit: 1,
      );
      if (rows.isEmpty) return null;

      final row = rows.first;
      final id = row[HTTP_JOBS_PRIMARY_KEY_COLUMN] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      await txn.update(
        HTTP_JOBS_TABLE_NAME,
        {HTTP_JOBS_LOCKED_COLUMN: 1, HTTP_JOBS_UPDATED_AT_COLUMN: now},
        where: '$HTTP_JOBS_PRIMARY_KEY_COLUMN = ?',
        whereArgs: [id],
      );
      return row;
    });
  }

  Future<void> unlock(int id) async {
    final db = await getDb();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      HTTP_JOBS_TABLE_NAME,
      {HTTP_JOBS_LOCKED_COLUMN: 0, HTTP_JOBS_UPDATED_AT_COLUMN: now},
      where: '$HTTP_JOBS_PRIMARY_KEY_COLUMN = ?',
      whereArgs: [id],
    );
  }

  /// Remove a successfully processed request from the queue.
  Future<bool> delete(int id) async {
    final db = await getDb();
    final count = await db.delete(
      HTTP_JOBS_TABLE_NAME,
      where: '$HTTP_JOBS_PRIMARY_KEY_COLUMN = ?',
      whereArgs: [id],
    );
    _logger.fine('delete: removed id=$id');
    return count > 0;
  }

  /// Returns all unprocessed requests. Useful for queue-length inspection.
  Future<List<Map<String, dynamic>>> unprocessedRequests({bool onlyLocked = false}) async {
    final db = await getDb();
    return db.query(
      HTTP_JOBS_TABLE_NAME,
      where: onlyLocked ? '$HTTP_JOBS_LOCKED_COLUMN = 1' : null,
      orderBy: _orderBy,
    );
  }

  /// Decode headers stored as JSON string.
  static Map<String, String> headersFromRow(Map<String, dynamic> row) {
    final raw = row[HTTP_JOBS_HEADERS_COLUMN];
    if (raw == null) return {};
    return (jsonDecode(raw as String) as Map<String, dynamic>).cast<String, String>();
  }
}

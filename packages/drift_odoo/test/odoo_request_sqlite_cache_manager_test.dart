import 'package:drift_odoo/src/offline_queue/odoo_request_sqlite_cache_manager.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

void main() {
  late OdooRequestSqliteCacheManager manager;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    manager = OdooRequestSqliteCacheManager(
      inMemoryDatabasePath,
      databaseFactory: databaseFactoryFfi,
      processingInterval: Duration.zero,
    );
    await manager.migrate();
  });

  tearDown(() async {
    final db = await manager.getDb();
    await db.close();
  });

  group('insertOrUpdate', () {
    test('inserts a new job and returns its rowId', () async {
      final id = await manager.insertOrUpdate(
        model: 'res.partner',
        method: 'create',
        ids: '[]',
        payload: '{"vals_list": [{"name": "ACME"}]}',
      );

      expect(id, greaterThan(0));
      final jobs = await manager.unprocessedRequests();
      expect(jobs, hasLength(1));
      expect(jobs.first[kColId], id);
      expect(jobs.first[kColModel], 'res.partner');
      expect(jobs.first[kColMethod], 'create');
      expect(jobs.first[kColAttempts], 0);
      expect(jobs.first[kColLocked], 1);
    });

    test('increments attempts for duplicate jobs', () async {
      final id1 = await manager.insertOrUpdate(
        model: 'res.partner',
        method: 'write',
        ids: '[1]',
        payload: '{"vals": {"name": "X"}}',
      );

      final id2 = await manager.insertOrUpdate(
        model: 'res.partner',
        method: 'write',
        ids: '[1]',
        payload: '{"vals": {"name": "X"}}',
      );

      expect(id1, equals(id2), reason: 'same rowId returned for duplicate');
      final jobs = await manager.unprocessedRequests();
      expect(jobs, hasLength(1));
      expect(jobs.first[kColAttempts], 1);
    });

    test('treats different payloads as separate jobs', () async {
      await manager.insertOrUpdate(
        model: 'res.partner',
        method: 'write',
        ids: '[1]',
        payload: '{"vals": {"name": "A"}}',
      );
      await manager.insertOrUpdate(
        model: 'res.partner',
        method: 'write',
        ids: '[1]',
        payload: '{"vals": {"name": "B"}}',
      );

      final jobs = await manager.unprocessedRequests();
      expect(jobs, hasLength(2));
    });
  });

  group('delete', () {
    test('removes a job by rowId', () async {
      final id = await manager.insertOrUpdate(
        model: 'sale.order',
        method: 'create',
        ids: '[]',
        payload: '{}',
      );
      await manager.delete(id);
      expect(await manager.unprocessedRequests(), isEmpty);
    });
  });

  group('unlock', () {
    test('sets locked=0 for a job', () async {
      final id = await manager.insertOrUpdate(
        model: 'account.move',
        method: 'write',
        ids: '[5]',
        payload: '{}',
      );
      await manager.unlock(id);
      final db = await manager.getDb();
      final rows = await db.query(
        kQueueTable,
        where: '$kColId = ?',
        whereArgs: [id],
      );
      expect(rows.first[kColLocked], 0);
    });
  });

  group('prepareNextRequestToProcess', () {
    test('returns null when queue is empty', () async {
      expect(await manager.prepareNextRequestToProcess(), isNull);
    });

    test('returns null when all jobs are locked', () async {
      // insertOrUpdate creates a locked job by default
      await manager.insertOrUpdate(
        model: 'res.partner',
        method: 'create',
        ids: '[]',
        payload: '{}',
      );
      // Serial mode → locked job blocks queue
      expect(await manager.prepareNextRequestToProcess(), isNull);
    });

    test('returns and locks the oldest unlocked job', () async {
      final id = await manager.insertOrUpdate(
        model: 'res.partner',
        method: 'create',
        ids: '[]',
        payload: '{}',
      );
      // Unlock and backdate so processingInterval passes
      await manager.unlock(id);
      final db = await manager.getDb();
      await db.update(
        kQueueTable,
        {kColCreatedAt: 0, kColUpdatedAt: 0},
        where: '$kColId = ?',
        whereArgs: [id],
      );

      final job = await manager.prepareNextRequestToProcess();
      expect(job, isNotNull);
      expect(job![kColId], id);
      expect(job[kColLocked], 1);
    });
  });

  group('deleteUnprocessedRequest', () {
    test('returns true when job exists and deletes it', () async {
      final id = await manager.insertOrUpdate(
        model: 'res.partner',
        method: 'create',
        ids: '[]',
        payload: '{}',
      );
      final deleted = await manager.deleteUnprocessedRequest(id);
      expect(deleted, isTrue);
      expect(await manager.unprocessedRequests(), isEmpty);
    });

    test('returns false when job does not exist', () async {
      final deleted = await manager.deleteUnprocessedRequest(9999);
      expect(deleted, isFalse);
    });
  });
}

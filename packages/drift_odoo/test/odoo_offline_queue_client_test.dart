import 'dart:convert';
import 'dart:io';

import 'package:drift_odoo/src/odoo_client.dart';
import 'package:drift_odoo/src/offline_queue/odoo_offline_queue_client.dart';
import 'package:drift_odoo/src/offline_queue/odoo_request_sqlite_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

// ── Minimal HTTP stub ─────────────────────────────────────────────────────────

class _StubClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest) handler;
  _StubClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

http.Client _jsonResponse(dynamic body, {int status = 200}) =>
    _StubClient((_) async => http.Response(
          jsonEncode(body),
          status,
          headers: {'content-type': 'application/json'},
        ));

http.Client _networkError() =>
    _StubClient((_) async => throw const SocketException('No network'));

// ── Helpers ───────────────────────────────────────────────────────────────────

OdooOfflineQueueClient _makeClient(
  http.Client httpClient,
  OdooRequestSqliteCacheManager manager,
) {
  final inner = OdooClient(
    baseUrl: 'https://test.odoo.com',
    apiKey: 'key',
    httpClient: httpClient,
  );
  return OdooOfflineQueueClient(inner: inner, requestManager: manager);
}

void main() {
  late OdooRequestSqliteCacheManager manager;
  late OdooOfflineQueueClient client;

  setUpAll(sqfliteFfiInit);

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

  group('isPushMethod', () {
    setUp(() => client = _makeClient(_jsonResponse(null), manager));

    test('read methods return false', () {
      for (final m in [
        'search', 'read', 'search_read', 'fields_get', 'name_search',
      ]) {
        expect(client.isPushMethod(m), isFalse, reason: '$m should not be queued');
      }
    });

    test('write methods return true', () {
      for (final m in ['create', 'write', 'unlink', 'action_confirm']) {
        expect(client.isPushMethod(m), isTrue, reason: '$m should be queued');
      }
    });
  });

  group('call — online', () {
    test('create succeeds, job is removed from queue', () async {
      client = _makeClient(_jsonResponse([42]), manager);

      final result = await client.create('res.partner', [{'name': 'ACME'}]);

      expect(result, [42]);
      expect(await manager.unprocessedRequests(), isEmpty);
    });

    test('write succeeds, job is removed from queue', () async {
      client = _makeClient(_jsonResponse(true), manager);

      final ok = await client.write('res.partner', [1], {'name': 'X'});

      expect(ok, isTrue);
      expect(await manager.unprocessedRequests(), isEmpty);
    });

    test('unlink succeeds, job is removed from queue', () async {
      client = _makeClient(_jsonResponse(true), manager);

      final ok = await client.unlink('res.partner', [1]);

      expect(ok, isTrue);
      expect(await manager.unprocessedRequests(), isEmpty);
    });
  });

  group('call — offline (SocketException)', () {
    test('job is persisted and unlocked for later retry', () async {
      client = _makeClient(_networkError(), manager);
      Object? capturedException;
      client.onRequestException = (_, __, e) => capturedException = e;

      final result = await client.create('res.partner', [{'name': 'ACME'}]);

      expect(result, isEmpty, reason: 'null → empty list via typed helper');
      expect(capturedException, isA<SocketException>());

      final jobs = await manager.unprocessedRequests();
      expect(jobs, hasLength(1));
      expect(jobs.first[kColLocked], 0, reason: 'unlocked for retry');
    });
  });

  group('call — read methods', () {
    test('search_read bypasses queue completely', () async {
      final records = [
        {'id': 1, 'name': 'Partner A', 'write_date': '2026-01-01 10:00:00'},
      ];
      client = _makeClient(_jsonResponse(records), manager);

      final result = await client.searchRead('res.partner', fields: ['name']);

      expect(result, hasLength(1));
      expect(await manager.unprocessedRequests(), isEmpty);
    });
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:drift_odoo/src/odoo_client.dart';
import 'package:drift_odoo/src/offline_queue/odoo_request_sqlite_cache_manager.dart';
import 'package:logging/logging.dart';

/// Read-only Odoo methods that should NOT be queued.
const _kReadMethods = {
  'search',
  'read',
  'search_read',
  'search_fetch',
  'fields_get',
  'name_search',
  'name_get',
  'default_get',
  'onchange',
  'check_access_rights',
  'check_access_rule',
  'get_views',
  'read_group',
};

/// A decorator around [OdooClient] that intercepts mutating calls
/// (create, write, unlink, and custom methods) and stores them in an
/// SQLite queue when the device is offline.
///
/// The queue is automatically drained by [OdooOfflineRequestQueue].
///
/// Usage:
/// ```dart
/// final queueClient = OdooOfflineQueueClient(
///   inner: OdooClient(baseUrl: '...', apiKey: '...'),
///   requestManager: OdooRequestSqliteCacheManager(
///     'odoo_offline_queue.sqlite',
///     databaseFactory: databaseFactory,
///   ),
/// );
/// ```
class OdooOfflineQueueClient {
  final OdooClient _inner;
  final OdooRequestSqliteCacheManager requestManager;

  /// Status codes that trigger a reattempt instead of removing from queue.
  /// Defaults to `[404, 501, 502, 503, 504]`.
  final List<int> reattemptForStatusCodes;

  /// Called when a response has a status in [reattemptForStatusCodes].
  void Function(String model, String method, int statusCode)? onReattempt;

  /// Called when a request throws an exception (e.g. [SocketException]).
  void Function(String model, String method, Object error)? onRequestException;

  final Logger _logger;

  OdooOfflineQueueClient({
    required OdooClient inner,
    required this.requestManager,
    List<int>? reattemptForStatusCodes,
    this.onReattempt,
    this.onRequestException,
  })  : _inner = inner,
        reattemptForStatusCodes = reattemptForStatusCodes ?? [404, 501, 502, 503, 504],
        _logger = Logger('OdooOfflineQueueClient');

  /// Whether [method] is a mutating (push) operation that should be queued.
  bool isPushMethod(String method) => !_kReadMethods.contains(method);

  /// Delegate read-only properties to the inner client.
  String get baseUrl => _inner.baseUrl;
  String get apiKey => _inner.apiKey;
  String? get database => _inner.database;

  /// Call an Odoo method, queuing it if it's a push operation.
  Future<dynamic> call(
    String model,
    String method, {
    List<int> ids = const [],
    Map<String, dynamic> kwargs = const {},
  }) async {
    if (!isPushMethod(method)) {
      return _inner.call(model, method, ids: ids, kwargs: kwargs);
    }

    final idsJson = jsonEncode(ids);
    final payloadJson = jsonEncode(kwargs);

    // Persist to queue before attempting
    await requestManager.insertOrUpdate(
      model: model,
      method: method,
      ids: idsJson,
      payload: payloadJson,
      logger: _logger,
    );

    try {
      final result = await _inner.call(model, method, ids: ids, kwargs: kwargs);

      // Success — remove from queue
      final jobs = await requestManager.unprocessedRequests();
      final matching = jobs.where((j) =>
          j[kColModel] == model &&
          j[kColMethod] == method &&
          j[kColIds] == idsJson &&
          j[kColPayload] == payloadJson);
      for (final job in matching) {
        await requestManager.delete(job[kColId] as int);
      }

      return result;
    } on SocketException catch (e) {
      onRequestException?.call(model, method, e);
      _logger.warning('OdooOfflineQueueClient: offline, queued $method $model');
      // Unlock for later retry by the queue processor
      final jobs = await requestManager.unprocessedRequests();
      final matching = jobs.where((j) =>
          j[kColModel] == model &&
          j[kColMethod] == method &&
          j[kColIds] == idsJson &&
          j[kColPayload] == payloadJson);
      for (final job in matching) {
        await requestManager.unlock(job[kColId] as int);
      }
      return null;
    } catch (e) {
      onRequestException?.call(model, method, e);
      _logger.warning('OdooOfflineQueueClient: error $method $model: $e');
      final jobs = await requestManager.unprocessedRequests();
      final matching = jobs.where((j) =>
          j[kColModel] == model &&
          j[kColMethod] == method &&
          j[kColIds] == idsJson &&
          j[kColPayload] == payloadJson);
      for (final job in matching) {
        await requestManager.unlock(job[kColId] as int);
      }
      rethrow;
    }
  }

  // Delegate read methods directly to inner client
  Future<List<Map<String, dynamic>>> searchRead(
    String model, {
    dynamic domain = const [],
    List<String>? fields,
    int? offset,
    int? limit,
    String? order,
    String load = '',
  }) =>
      _inner.searchRead(model,
          domain: domain,
          fields: fields,
          offset: offset,
          limit: limit,
          order: order,
          load: load);

  Future<List<int>> create(String model, List<Map<String, dynamic>> valsList) =>
      call(model, 'create', kwargs: {'vals_list': valsList}).then((r) {
        if (r == null) return <int>[];
        if (r is int) return [r];
        return (r as List).cast<int>();
      });

  Future<bool> write(String model, List<int> ids, Map<String, dynamic> vals) =>
      call(model, 'write', ids: ids, kwargs: {'vals': vals}).then((r) => r as bool? ?? false);

  Future<bool> unlink(String model, List<int> ids) =>
      call(model, 'unlink', ids: ids).then((r) => r as bool? ?? false);
}

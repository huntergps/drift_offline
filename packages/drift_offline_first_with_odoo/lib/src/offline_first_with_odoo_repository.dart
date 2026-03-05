import 'dart:async';
import 'dart:io';

import 'package:drift_odoo/drift_odoo.dart';
import 'package:drift_odoo_core/drift_odoo_core.dart';
import 'package:drift_offline_first/drift_offline_first.dart';
import 'package:meta/meta.dart';

import 'models/offline_first_with_odoo_model.dart';
import 'sync/odoo_sync_manager.dart';

/// Offline-first repository backed by Drift (local) and the Odoo JSON-2 API (remote).
///
/// Subclass this in your app and implement [getLocal], [upsertLocal],
/// [deleteLocal], and [existsLocal] using your Drift database.
///
/// ```dart
/// class MyRepository extends OfflineFirstWithOdooRepository<OfflineFirstWithOdooModel> {
///   @override
///   final OdooModelDictionary modelDictionary;
///
///   MyRepository({required super.remoteProvider, required super.syncManager})
///       : modelDictionary = OdooModelDictionary(odooMappings);
///
///   @override
///   Future<List<T>> getLocal<T extends OfflineFirstWithOdooModel>({...}) => ...;
/// }
/// ```
abstract class OfflineFirstWithOdooRepository<
        TRepositoryModel extends OfflineFirstWithOdooModel>
    extends OfflineFirstRepository<TRepositoryModel> {
  /// The Odoo provider (wraps [OdooOfflineQueueClient]).
  @protected
  final OdooOfflineQueueClient remoteProvider;

  /// The offline queue processor. Start/stop with [initialize]/[dispose].
  @protected
  late final OdooOfflineRequestQueue offlineRequestQueue;

  /// Manages incremental sync timestamps per model.
  @protected
  final OdooSyncManager syncManager;

  /// The model dictionary mapping types to adapters.
  OdooModelDictionary get modelDictionary;

  OfflineFirstWithOdooRepository({
    required this.remoteProvider,
    required this.syncManager,
    super.autoHydrate,
    super.loggerName,
    OdooOfflineRequestQueue? offlineRequestQueueOverride,
  }) {
    offlineRequestQueue =
        offlineRequestQueueOverride ?? OdooOfflineRequestQueue(client: remoteProvider);
  }

  // ---------------------------------------------------------------------------
  // Remote operations
  // ---------------------------------------------------------------------------

  @override
  Future<List<T>> hydrateRemote<T extends TRepositoryModel>({
    Query? query,
    bool deserializeLocal = true,
  }) async {
    final adapter = modelDictionary.adapterFor[T];
    if (adapter == null) throw StateError('No adapter registered for $T');

    final domain = query?.providerArgs['domain'] as OdooDomain? ?? const [];
    final limit = query?.limitBy?.amount;
    final order = query?.orderBy?.conditions.firstOrNull?.evaluatedField;

    // Build domain: combine provided domain with incremental sync filter
    final incrementalDomain = await syncManager.incrementalDomain(adapter.odooModel);
    final effectiveDomain = _mergeDomains(
      incrementalDomain ?? [],
      domain,
    );

    logger.finest('#hydrateRemote: ${adapter.odooModel} domain=$effectiveDomain');

    // Build a local query from the extracted Odoo providerArgs
    final localQuery = Query(
      limitBy: limit != null ? LimitBy(limit) : null,
      orderBy: order != null ? OrderBy.asc(order) : null,
      providerArgs: query?.providerArgs ?? const {},
    );

    try {
      final rawRecords = await remoteProvider.searchRead(
        adapter.odooModel,
        domain: effectiveDomain,
        fields: adapter.odooFields,
        limit: limit,
        order: order ?? 'write_date asc',
      );

      final models = await Future.wait(rawRecords.map(
        (r) => adapter.fromOdoo(r, provider: remoteProvider, repository: this) as Future<T>,
      ));

      // Upsert to local storage
      for (final model in models) {
        await upsertLocal<T>(model);
      }

      // Update sync timestamp
      await syncManager.updateLastSync(adapter.odooModel);

      if (!deserializeLocal) return models;
      return getLocal<T>(query: localQuery);
    } on SocketException catch (e) {
      logger.warning('#hydrateRemote socket failure: $e');
      return deserializeLocal ? getLocal<T>(query: localQuery) : [];
    } on OdooException catch (e) {
      logger.warning('#hydrateRemote odoo failure: $e');
      if (e.statusCode >= 500 || e.statusCode == 0) {
        return deserializeLocal ? getLocal<T>(query: localQuery) : [];
      }
      rethrow;
    }
  }

  @override
  Future<T?> upsertRemote<T extends TRepositoryModel>(
    T instance, {
    Query? query,
  }) async {
    final adapter = modelDictionary.adapterFor[T];
    if (adapter == null) throw StateError('No adapter registered for $T');

    final data = await adapter.toOdoo(instance, provider: remoteProvider, repository: this);

    if (instance.odooId == null) {
      final ids = await remoteProvider.create(adapter.odooModel, [data]);
      if (ids.isNotEmpty) instance.odooId = ids.first;
    } else {
      await remoteProvider.write(adapter.odooModel, [instance.odooId!], data);
    }

    return instance;
  }

  @override
  Future<void> deleteRemote<T extends TRepositoryModel>(
    T instance, {
    Query? query,
  }) async {
    final adapter = modelDictionary.adapterFor[T];
    if (adapter == null) throw StateError('No adapter registered for $T');

    if (instance.odooId == null) return;
    await remoteProvider.unlink(adapter.odooModel, [instance.odooId!]);
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  @mustCallSuper
  Future<void> initialize() async {
    await super.initialize();
    await offlineRequestQueue.client.requestManager.migrate();
    offlineRequestQueue.start();
  }

  /// Stop the queue processor. Call when the repository is no longer needed.
  Future<void> dispose() async {
    offlineRequestQueue.stop();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  OdooDomain _mergeDomains(OdooDomain a, OdooDomain b) {
    if (a.isEmpty && b.isEmpty) return [];
    if (a.isEmpty) return b;
    if (b.isEmpty) return a;
    return OdooDomainBuilder.and([a, b]);
  }
}

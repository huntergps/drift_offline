import 'dart:async';
import 'dart:io';

import 'package:drift_offline_first/drift_offline_first.dart';
import 'package:drift_supabase/drift_supabase.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:supabase/supabase.dart';

import 'models/offline_first_with_supabase_model.dart';

/// Offline-first repository backed by Drift (local) and Supabase (remote).
///
/// Subclass this in your app and implement [getLocal], [upsertLocal],
/// [deleteLocal], and [existsLocal] using your Drift database.
///
/// **Setup:**
/// ```dart
/// class MyRepository extends OfflineFirstWithSupabaseRepository<OfflineFirstWithSupabaseModel> {
///   @override
///   final SupabaseModelDictionary modelDictionary;
///
///   MyRepository._({required super.supabaseProvider, required super.offlineQueueClient})
///       : modelDictionary = SupabaseModelDictionary(supabaseMappings);
///
///   /// Factory that wires up the offline queue client.
///   static Future<MyRepository> clientQueue({
///     required String supabaseUrl,
///     required String supabaseKey,
///     required SupabaseRequestSqliteCacheManager requestManager,
///   }) async {
///     return OfflineFirstWithSupabaseRepository.clientQueue(
///       supabaseUrl: supabaseUrl,
///       supabaseKey: supabaseKey,
///       requestManager: requestManager,
///       buildRepository: (provider, queueClient) =>
///           MyRepository._(supabaseProvider: provider, offlineQueueClient: queueClient),
///     );
///   }
///
///   @override
///   Future<List<T>> getLocal<T extends OfflineFirstWithSupabaseModel>({...}) => ...;
/// }
/// ```
abstract class OfflineFirstWithSupabaseRepository<
        TRepositoryModel extends OfflineFirstWithSupabaseModel>
    extends OfflineFirstRepository<TRepositoryModel> {
  @protected
  final SupabaseProvider supabaseProvider;

  @protected
  final SupabaseOfflineQueueClient offlineQueueClient;

  @protected
  late final SupabaseOfflineRequestQueue offlineRequestQueue;

  /// The model dictionary mapping types to adapters.
  SupabaseModelDictionary get modelDictionary;

  /// Maps a dedup key (type+primaryKey) to the time it was upserted locally.
  /// Realtime events arriving within [_realtimeDeduplicationWindow] after a
  /// local write are ignored to prevent double-event emissions.
  final _recentLocalWrites = <String, DateTime>{};
  static const _realtimeDeduplicationWindow = Duration(seconds: 2);

  OfflineFirstWithSupabaseRepository({
    required this.supabaseProvider,
    required this.offlineQueueClient,
    super.autoHydrate,
    super.loggerName,
    SupabaseOfflineRequestQueue? offlineRequestQueueOverride,
  }) {
    offlineRequestQueue = offlineRequestQueueOverride ??
        SupabaseOfflineRequestQueue(client: offlineQueueClient);
  }

  // ---------------------------------------------------------------------------
  // Factory
  // ---------------------------------------------------------------------------

  /// Convenience factory that wires [SupabaseOfflineQueueClient] around
  /// Supabase's internal HTTP client and constructs [SupabaseProvider].
  ///
  /// [requestManager] is a pre-built [SupabaseRequestSqliteCacheManager] (or
  /// [HttpRequestSqliteCacheManager]) that owns the offline queue database.
  /// Constructing it outside this factory keeps sqflite_common types out of
  /// this package — callers import sqflite_common only where they need it.
  ///
  /// [buildRepository] receives the configured [SupabaseProvider] and
  /// [SupabaseOfflineQueueClient] and must return the concrete repository.
  static Future<TRepo> clientQueue<TRepo extends OfflineFirstWithSupabaseRepository>({
    required String supabaseUrl,
    required String supabaseKey,
    required SupabaseRequestSqliteCacheManager requestManager,
    required SupabaseModelDictionary modelDictionary,
    required TRepo Function(SupabaseProvider, SupabaseOfflineQueueClient) buildRepository,
    String? loggerName,
  }) async {
    await requestManager.migrate();

    final innerClient = http.Client();
    final queueClient = SupabaseOfflineQueueClient(
      innerClient,
      requestManager,
      loggerName: loggerName,
    );

    final supabaseClient = SupabaseClient(
      supabaseUrl,
      supabaseKey,
      httpClient: queueClient,
    );

    final provider = SupabaseProvider(
      supabaseClient,
      modelDictionary: modelDictionary,
      loggerName: loggerName,
    );

    return buildRepository(provider, queueClient);
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

    logger.finest('#hydrateRemote: ${adapter.supabaseTableName}');

    try {
      final results = await supabaseProvider.get<T>(
        query: query,
        repository: this,
      );

      if (!deserializeLocal) {
        for (final model in results) {
          await upsertLocal<T>(model);
        }
        unawaited(notifySubscriptionsWithLocalData<T>(query: query));
        return results;
      }
      // storeRemoteResults persists all models, notifies subscribers,
      // and returns the re-read local results.
      return storeRemoteResults<T>(results, query: query);
    } on SocketException catch (e) {
      logger.warning('#hydrateRemote socket failure: $e');
      return deserializeLocal ? getLocal<T>(query: query) : [];
    } on PostgrestException catch (e) {
      logger.warning('#hydrateRemote postgrest failure: $e');
      if (_isTransientPostgrestError(e)) {
        return deserializeLocal ? getLocal<T>(query: query) : [];
      }
      rethrow;
    }
  }

  @override
  Future<T?> upsertRemote<T extends TRepositoryModel>(
    T instance, {
    Query? query,
  }) async {
    logger.finest('#upsertRemote: ${T.toString()}');
    try {
      final updated = await supabaseProvider.upsert<T>(instance, repository: this);
      // Mark this record so realtime doesn't double-process it.
      // We use the adapter to get the serialized form for key extraction.
      final adapter = modelDictionary.adapterFor[T];
      if (adapter != null) {
        final serialized = await adapter.toSupabase(
          updated,
          provider: supabaseProvider,
          repository: this,
        );
        _markRecentLocalWrite(updated, serialized);
      }
      return updated;
    } on SocketException {
      // Queued by SupabaseOfflineQueueClient — return optimistically.
      return instance;
    }
  }

  @override
  Future<void> deleteRemote<T extends TRepositoryModel>(
    T instance, {
    Query? query,
  }) async {
    logger.finest('#deleteRemote: ${T.toString()}');
    try {
      await supabaseProvider.delete<T>(instance, repository: this);
      // ignore: discarded_futures
      notifySubscriptionsWithLocalData<T>();
    } on SocketException {
      // Queued by SupabaseOfflineQueueClient.
    }
  }

  // ---------------------------------------------------------------------------
  // Realtime
  // ---------------------------------------------------------------------------

  /// Subscribe to Supabase Realtime changes for [T] and upsert/delete locally.
  ///
  /// Handles three event types:
  /// - **INSERT / UPDATE**: deserializes `newRecord` and upserts locally.
  ///   Deduplicated against recent local writes to prevent echo updates.
  /// - **DELETE**: deletes the local record using `oldRecord` data.
  ///   When `oldRecord` is empty (table REPLICA IDENTITY is not FULL),
  ///   falls back to a full [reconcileWithRemote] to remove stale locals.
  /// - **ALL** (synthetic full-refresh event): triggers [reconcileWithRemote]
  ///   to diff the complete remote set against local and delete stale records.
  ///
  /// Returns the [RealtimeChannel] so the caller can cancel with [cancelRealtime].
  RealtimeChannel subscribeToRealtime<T extends TRepositoryModel>({
    String? schema,
    String? filter,
    void Function(T model, PostgresChangePayload event)? onUpdate,
  }) {
    final adapter = modelDictionary.adapterFor[T];
    if (adapter == null) throw StateError('No adapter registered for $T');

    final channel = supabaseProvider.client.channel('table-changes');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: schema ?? 'public',
      table: adapter.supabaseTableName,
      filter: filter != null
          ? PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: filter.split('=').first,
              value: filter.split('=').last,
            )
          : null,
      callback: (payload) async {
        try {
          if (payload.eventType == PostgresChangeEvent.delete) {
            final oldData = payload.oldRecord;
            if (oldData.isNotEmpty) {
              // Targeted delete using the old record's data.
              final model = await adapter.fromSupabase(
                oldData,
                provider: supabaseProvider,
                repository: this,
              ) as T;
              await deleteLocal<T>(model);
            } else {
              // oldRecord is empty — REPLICA IDENTITY is not FULL.
              // Fall back to full reconciliation to remove the stale local record.
              logger.fine(
                'subscribeToRealtime: DELETE with empty oldRecord for $T, '
                'running reconcileWithRemote',
              );
              await reconcileWithRemote<T>();
            }
          } else if (payload.eventType == PostgresChangeEvent.all) {
            // Synthetic full-refresh event: diff remote vs local and delete extras.
            logger.fine('subscribeToRealtime: full-refresh event for $T, reconciling');
            await reconcileWithRemote<T>();
          } else {
            // INSERT or UPDATE.
            final newData = payload.newRecord;

            // DEDUPLICATION: skip if this record was just written locally.
            if (_isRecentLocalWrite(T, newData)) {
              logger.finest('subscribeToRealtime: skipping deduplicated event for $T');
              return;
            }

            final model = await adapter.fromSupabase(
              newData,
              provider: supabaseProvider,
              repository: this,
            ) as T;
            await upsertLocal<T>(model);
            onUpdate?.call(model, payload);
          }
        } catch (e) {
          logger.warning('subscribeToRealtime: error processing event: $e');
        }
      },
    );

    channel.subscribe();
    return channel;
  }

  /// Fetch all [T] records from Supabase and delete any local records that no
  /// longer exist on the server.
  ///
  /// This implements a "server wins" set reconciliation useful after:
  /// - Reconnecting after an extended offline period (missed DELETE events).
  /// - Receiving a Supabase Realtime `PostgresChangeEvent.all` event.
  /// - Receiving a DELETE event with an empty `oldRecord` (no REPLICA IDENTITY FULL).
  ///
  /// **Requirement:** models must override [OfflineFirstModel.primaryKey] to
  /// return a non-null unique identifier. Records with `primaryKey == null` are
  /// skipped during the diff.
  ///
  /// ```dart
  /// // Call after reconnection:
  /// await repository.reconcileWithRemote<Partner>();
  /// ```
  Future<void> reconcileWithRemote<T extends TRepositoryModel>({
    Query? query,
  }) async {
    logger.fine('#reconcileWithRemote: $T');

    // hydrateRemote fetches remote, upserts all locally, returns re-read locals.
    final remoteModels = await hydrateRemote<T>(query: query);
    final localModels = await getLocal<T>(query: query);

    // Build the set of remote primary keys for fast lookup.
    final remotePrimaryKeys = remoteModels
        .map((m) => m.primaryKey)
        .whereType<Object>()
        .toSet();

    // Delete any local record whose primary key is not in the remote set.
    for (final local in localModels) {
      final pk = local.primaryKey;
      if (pk != null && !remotePrimaryKeys.contains(pk)) {
        logger.fine('#reconcileWithRemote: deleting stale local $T pk=$pk');
        await deleteLocal<T>(local);
      }
    }

    await notifySubscriptionsWithLocalData<T>(query: query);
  }

  /// Cancel a realtime subscription.
  Future<void> cancelRealtime(RealtimeChannel channel) async {
    await supabaseProvider.client.removeChannel(channel);
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  @mustCallSuper
  Future<void> initialize() async {
    await super.initialize();
    await offlineQueueClient.requestManager.migrate();
    offlineRequestQueue.start();
  }

  /// Stop the queue processor and release resources.
  Future<void> dispose() async {
    offlineRequestQueue.stop();
    _recentLocalWrites.clear();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  bool _isTransientPostgrestError(PostgrestException e) {
    // Network-level failures or server errors should fall back to local.
    return e.code == null || e.code!.startsWith('5');
  }

  // ---------------------------------------------------------------------------
  // Deduplication helpers
  // ---------------------------------------------------------------------------

  /// Register that [instance] was just written locally.
  /// The key is built from the runtime type and the primary-key fields.
  void _markRecentLocalWrite(Object instance, Map<String, dynamic> serialized) {
    final pk = _extractPrimaryKey(serialized);
    if (pk == null) return;
    final key = '${instance.runtimeType}:$pk';
    _recentLocalWrites[key] = DateTime.now();
  }

  /// Returns `true` if [data] (raw Supabase payload) was written locally
  /// within [_realtimeDeduplicationWindow].
  bool _isRecentLocalWrite(Type type, Map<String, dynamic> data) {
    final pk = _extractPrimaryKey(data);
    if (pk == null) return false;
    final key = '$type:$pk';
    final written = _recentLocalWrites[key];
    if (written == null) return false;
    final age = DateTime.now().difference(written);
    if (age > _realtimeDeduplicationWindow) {
      _recentLocalWrites.remove(key);
      return false;
    }
    return true;
  }

  /// Extract a string primary key from a Supabase data map.
  /// Tries common primary key field names: 'id', then any field named '*_id'.
  String? _extractPrimaryKey(Map<String, dynamic> data) {
    if (data.containsKey('id')) return data['id']?.toString();
    // Fallback: first field ending in '_id'
    for (final entry in data.entries) {
      if (entry.key.endsWith('_id') && entry.value != null) {
        return entry.value.toString();
      }
    }
    return null;
  }
}

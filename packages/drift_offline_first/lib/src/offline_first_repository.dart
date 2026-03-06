import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

import 'memory_cache_provider.dart';
import 'offline_first_exception.dart';
import 'offline_first_model.dart';
import 'offline_first_policy.dart';
import 'query/query.dart';
import 'query/where.dart';

/// Abstract offline-first repository. Provider-agnostic base class.
///
/// Subclasses (e.g. [OfflineFirstWithOdooRepository]) provide:
/// - [getLocal] — read from local Drift storage
/// - [upsertLocal] — write to local Drift storage
/// - [deleteLocal] — remove from local Drift storage
/// - [existsLocal] — check local existence
/// - [hydrateRemote] — fetch from remote and store locally
/// - [upsertRemote] — send to remote provider
/// - [deleteRemote] — remove from remote provider
///
/// The [OfflineFirstRepository] handles the policy logic on top.
abstract class OfflineFirstRepository<TRepositoryModel extends OfflineFirstModel> {
  /// Refetch from remote on every [get] call (unawaited). Defaults to `false`.
  final bool autoHydrate;

  /// Optional in-memory L1 cache. When set, [get] returns cached results
  /// (where policy permits) and [upsert]/[delete] keep the cache in sync.
  final MemoryCacheProvider<TRepositoryModel>? memoryCacheProvider;

  @protected
  final Logger logger;

  /// Before-save triggers keyed by model [Type].
  ///
  /// Register via [addBeforeSaveTrigger]. Each trigger receives the incoming
  /// instance and the existing local instance (or null) and may return a
  /// modified instance. If null is returned the incoming instance is used as-is.
  final Map<Type, Future<Object?> Function(Object incoming, Object? existing)>
      _beforeSaveTriggers = {};

  /// Subscription broadcast controllers keyed by model [Type] and query string.
  final Map<Type, Map<String, StreamController<List<Object>>>> _subscriptionControllers = {};

  /// Tracks the policy used by the most recent [get] call.
  ///
  /// [getAssociation] propagates this policy so that all models in the same
  /// object graph are hydrated with the same strategy. For example, when
  /// `get<Order>(policy: awaitRemote)` resolves an associated `Customer`, it
  /// also fetches the `Customer` from remote instead of falling back to local.
  OfflineFirstGetPolicy? _latestGetPolicy;

  OfflineFirstRepository({
    bool? autoHydrate,
    String? loggerName,
    this.memoryCacheProvider,
  })  : autoHydrate = autoHydrate ?? false,
        logger = Logger(loggerName ?? 'OfflineFirstRepository');

  // ---------------------------------------------------------------------------
  // Abstract — implemented by subclasses
  // ---------------------------------------------------------------------------

  /// Read models from local storage (Drift).
  Future<List<T>> getLocal<T extends TRepositoryModel>({Query? query});

  /// Check if any matching records exist locally.
  Future<bool> existsLocal<T extends TRepositoryModel>({Query? query});

  /// Upsert a model to local storage. Returns the local primary key.
  Future<int?> upsertLocal<T extends TRepositoryModel>(T instance);

  /// Delete a model from local storage.
  Future<void> deleteLocal<T extends TRepositoryModel>(T instance);

  /// Fetch from remote, persist locally, return the upserted models.
  Future<List<T>> hydrateRemote<T extends TRepositoryModel>({
    Query? query,
    bool deserializeLocal = true,
  });

  /// Send an upsert to the remote provider.
  Future<T?> upsertRemote<T extends TRepositoryModel>(
    T instance, {
    Query? query,
  });

  /// Send a delete to the remote provider.
  Future<void> deleteRemote<T extends TRepositoryModel>(
    T instance, {
    Query? query,
  });

  // ---------------------------------------------------------------------------
  // Before-save trigger
  // ---------------------------------------------------------------------------

  /// Register a callback invoked before every [upsertLocal] call for [T].
  ///
  /// The trigger receives the incoming instance and the existing local instance
  /// (or null if not found). If it returns a non-null value, that value is
  /// persisted instead of the original incoming instance.
  void addBeforeSaveTrigger<T extends TRepositoryModel>(
    Future<T?> Function(T incoming, T? existing) trigger,
  ) {
    _beforeSaveTriggers[T] = (incoming, existing) async =>
        await trigger(incoming as T, existing as T?);
  }

  /// Apply the before-save trigger for [T] if one is registered.
  ///
  /// Returns [instance] (possibly modified by the trigger) ready to persist.
  @protected
  Future<T> applyBeforeSaveTrigger<T extends TRepositoryModel>(
    T instance,
  ) async {
    final trigger = _beforeSaveTriggers[T];
    if (trigger == null) return instance;

    // Try to find the existing local record for the same identity.
    // Subclasses that need existing-record lookup should override this method.
    final result = await trigger(instance, null);
    return (result as T?) ?? instance;
  }

  // ---------------------------------------------------------------------------
  // Subscriptions
  // ---------------------------------------------------------------------------

  /// Returns a reactive stream of local [T] models.
  ///
  /// The **default implementation** wraps an internal [StreamController] that
  /// only emits when [notifySubscriptionsWithLocalData] is called explicitly.
  ///
  /// **Override this** in Drift-backed repositories to use Drift's native
  /// `.watch()` — which emits automatically on every DB write without any
  /// manual notification:
  ///
  /// ```dart
  /// @override
  /// Stream<List<T>> watchLocal<T extends MyModel>({Query? query}) {
  ///   if (T == Partner) {
  ///     return _transformer
  ///         .applyToWatch(db.select(db.partners), query)
  ///         .map((rows) => rows.map(rowToPartner).toList().cast<T>());
  ///   }
  ///   return super.watchLocal<T>(query: query);
  /// }
  /// ```
  ///
  /// When overridden with Drift's watch, calls to
  /// [notifySubscriptionsWithLocalData] become harmless no-ops for that type.
  @protected
  Stream<List<T>> watchLocal<T extends TRepositoryModel>({Query? query}) {
    final key = query?.toString() ?? '';
    _subscriptionControllers
        .putIfAbsent(T, () => {})
        .putIfAbsent(key, () => StreamController<List<Object>>.broadcast());
    return _subscriptionControllers[T]![key]!.stream.cast<List<T>>();
  }

  /// Returns a stream that emits the local [T] list on every change.
  ///
  /// Delegates to [watchLocal]. When [watchLocal] is overridden with Drift's
  /// `.watch()`, this stream auto-emits on every DB mutation. Otherwise,
  /// trigger emissions manually via [notifySubscriptionsWithLocalData].
  Stream<List<T>> subscribe<T extends TRepositoryModel>({Query? query}) =>
      watchLocal<T>(query: query);

  /// Push the current local [T] data to all [subscribe] listeners.
  ///
  /// Only relevant when [watchLocal] uses the default [StreamController]-based
  /// implementation. When [watchLocal] is overridden with Drift's `.watch()`,
  /// this is a no-op for that type (Drift emits automatically).
  Future<void> notifySubscriptionsWithLocalData<T extends TRepositoryModel>({
    Query? query,
  }) async {
    final byQuery = _subscriptionControllers[T];
    if (byQuery == null || byQuery.isEmpty) return;
    for (final entry in byQuery.entries) {
      if (!entry.value.hasListener) continue;
      final results = await getLocal<T>(query: query);
      entry.value.add(results as List<Object>);
    }
  }

  // ---------------------------------------------------------------------------
  // Core operations with policy logic
  // ---------------------------------------------------------------------------

  /// Fetch models with offline-first semantics.
  Future<List<T>> get<T extends TRepositoryModel>({
    bool forceLocalSyncFromRemote = false,
    OfflineFirstGetPolicy policy = OfflineFirstGetPolicy.awaitRemoteWhenNoneExist,
    Query? query,
    bool seedOnly = false,
  }) async {
    logger.finest('#get: $T policy=$policy query=$query');
    _latestGetPolicy = policy;

    if (forceLocalSyncFromRemote) {
      logger.warning(
        '#get: forceLocalSyncFromRemote=true has no effect unless '
        'DestructiveLocalSyncFromRemoteMixin is mixed into this repository.',
      );
    }

    final requireRemote = policy == OfflineFirstGetPolicy.awaitRemote;
    final hydrateWhenEmpty = policy == OfflineFirstGetPolicy.awaitRemoteWhenNoneExist;
    final alwaysHydratePolicy = policy == OfflineFirstGetPolicy.alwaysHydrate;

    // Check L1 cache before any I/O — skip only for policies that require fresh remote data.
    if (!requireRemote && !alwaysHydratePolicy) {
      final cached = memoryCacheProvider?.getAll<T>();
      if (cached != null && cached.isNotEmpty) return cached;
    }

    if (requireRemote) {
      final results = await hydrateRemote<T>(query: query, deserializeLocal: !seedOnly);
      _populateCache<T>(results);
      return results;
    }

    final modelExists = await existsLocal<T>(query: query);

    if (hydrateWhenEmpty && !modelExists) {
      final results = await hydrateRemote<T>(query: query, deserializeLocal: !seedOnly);
      _populateCache<T>(results);
      return results;
    }

    if (alwaysHydratePolicy) {
      unawaited(hydrateRemote<T>(query: query).then(_populateCache));
    } else if (autoHydrate) {
      unawaited(hydrateRemote<T>(query: query).then(_populateCache));
    }

    final results = await getLocal<T>(query: query);
    _populateCache<T>(results);
    return results;
  }

  /// Upsert a model with offline-first semantics.
  Future<T> upsert<T extends TRepositoryModel>(
    T instance, {
    OfflineFirstUpsertPolicy policy = OfflineFirstUpsertPolicy.optimisticLocal,
    Query? query,
  }) async {
    logger.finest('#upsert: $T policy=$policy');

    final optimistic = policy == OfflineFirstUpsertPolicy.optimisticLocal;
    final requireRemote = policy == OfflineFirstUpsertPolicy.requireRemote;
    final localOnly = policy == OfflineFirstUpsertPolicy.localOnly;

    final prepared = await applyBeforeSaveTrigger<T>(instance);

    if (optimistic || localOnly) {
      await upsertLocal<T>(prepared);
      memoryCacheProvider?.upsert<T>(prepared);
      unawaited(notifySubscriptionsWithLocalData<T>(query: query));
    }

    if (localOnly) return prepared;

    try {
      await upsertRemote<T>(prepared, query: query);

      if (requireRemote) {
        await upsertLocal<T>(prepared);
        memoryCacheProvider?.upsert<T>(prepared);
        unawaited(notifySubscriptionsWithLocalData<T>(query: query));
      }
    } on SocketException catch (e) {
      logger.warning('#upsert socket failure: $e');
      if (requireRemote) throw OfflineFirstException(e);
    } catch (e) {
      logger.warning('#upsert remote failure: $e');
      if (requireRemote) throw OfflineFirstException(e);
    }

    if (autoHydrate) unawaited(hydrateRemote<T>());

    return prepared;
  }

  /// Delete a model with offline-first semantics.
  Future<bool> delete<T extends TRepositoryModel>(
    T instance, {
    OfflineFirstDeletePolicy policy = OfflineFirstDeletePolicy.optimisticLocal,
    Query? query,
  }) async {
    logger.finest('#delete: $T policy=$policy');

    final optimistic = policy == OfflineFirstDeletePolicy.optimisticLocal;
    final requireRemote = policy == OfflineFirstDeletePolicy.requireRemote;
    final localOnly = policy == OfflineFirstDeletePolicy.localOnly;

    if (optimistic || localOnly) {
      await deleteLocal<T>(instance);
      memoryCacheProvider?.delete<T>(instance);
    }

    if (localOnly) return true;

    try {
      await deleteRemote<T>(instance, query: query);

      if (requireRemote) {
        await deleteLocal<T>(instance);
        memoryCacheProvider?.delete<T>(instance);
      }
    } on SocketException catch (e) {
      logger.warning('#delete socket failure: $e');
      if (requireRemote) throw OfflineFirstException(e);
    } catch (e) {
      logger.warning('#delete remote failure: $e');
      if (requireRemote) throw OfflineFirstException(e);
    }

    if (autoHydrate) unawaited(hydrateRemote<T>());

    return true;
  }

  /// Check local existence.
  Future<bool> exists<T extends TRepositoryModel>({Query? query}) =>
      existsLocal<T>(query: query);

  /// Prepare the repository. Call during app initialization.
  Future<void> initialize() async {
    await migrate();
  }

  /// Run any pending migrations.
  Future<void> migrate() async {}

  // ---------------------------------------------------------------------------
  // Association helpers
  // ---------------------------------------------------------------------------

  /// Fetch associated [T] models using the same policy as the enclosing [get] call.
  ///
  /// When called from within an adapter's `fromX` method (i.e. during
  /// deserialization triggered by [get]), the policy set by that [get] call is
  /// propagated here via [_latestGetPolicy]. This ensures the entire object
  /// graph is hydrated consistently — e.g. `awaitRemote` on the root model
  /// also fetches its associations from remote.
  ///
  /// Falls back to [OfflineFirstGetPolicy.localOnly] when invoked outside of a
  /// [get] call (e.g. in tests or background jobs).
  Future<List<T>> getAssociation<T extends TRepositoryModel>(Query query) =>
      get<T>(query: query, policy: _latestGetPolicy ?? OfflineFirstGetPolicy.localOnly);

  /// Convenience: fetch a single associated [T] by exact field match.
  Future<T?> getAssociationOrNull<T extends TRepositoryModel>(
      String field, dynamic value) async {
    final results = await getLocal<T>(
      query: Query(where: [Where.exact(field, value)]),
    );
    return results.isEmpty ? null : results.first;
  }

  // ---------------------------------------------------------------------------
  // Remote result storage helper
  // ---------------------------------------------------------------------------

  /// Persist a list of remote models to local storage and notify subscribers.
  ///
  /// Call this from [hydrateRemote] implementations instead of manually
  /// iterating and calling [upsertLocal].
  @protected
  Future<List<T>> storeRemoteResults<T extends TRepositoryModel>(
    List<T> models, {
    Query? query,
  }) async {
    for (final model in models) {
      await upsertLocal(model);
    }
    // ignore: discarded_futures
    notifySubscriptionsWithLocalData<T>(query: query);
    return getLocal<T>(query: query);
  }

  /// Upsert [results] into the L1 memory cache (no-op when cache is absent).
  void _populateCache<T extends TRepositoryModel>(List<T> results) {
    for (final item in results) {
      memoryCacheProvider?.upsert<T>(item);
    }
  }

  /// Reset all local data and dispose subscription controllers.
  Future<void> reset() async {
    for (final byQuery in _subscriptionControllers.values) {
      for (final controller in byQuery.values) {
        await controller.close();
      }
    }
    _subscriptionControllers.clear();
    memoryCacheProvider?.clearAll();
  }
}

// Avoids analyzer warning for unawaited futures.
void unawaited(Future<void> future) {}

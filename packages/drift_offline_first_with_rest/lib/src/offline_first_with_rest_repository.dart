import 'package:drift_offline_first/drift_offline_first.dart';
import 'package:drift_rest/drift_rest.dart';
import 'package:logging/logging.dart';

import 'models/offline_first_with_rest_model.dart';

/// Repository that combines a local Drift database with a remote REST provider.
///
/// Subclass this and implement [remoteGet], [remoteUpsert], [remoteDelete] to
/// plug in the [RestProvider]-backed network calls.
///
/// For offline queuing, wrap the [RestProvider]'s HTTP client with
/// [HttpOfflineQueueClient] from `drift_offline_first`.
///
/// ```dart
/// class UserRepository extends OfflineFirstWithRestRepository {
///   UserRepository({required RestProvider restProvider})
///       : super(restProvider: restProvider);
///
///   @override
///   Future<List<User>> remoteGet<User extends OfflineFirstWithRestModel>({
///     Query? query,
///   }) => restProvider.get<User>(query: query);
/// }
/// ```
abstract class OfflineFirstWithRestRepository
    extends OfflineFirstRepository<OfflineFirstWithRestModel> {
  static final _logger = Logger('OfflineFirstWithRestRepository');

  final RestProvider restProvider;

  OfflineFirstWithRestRepository({
    required this.restProvider,
    super.memoryCacheProvider,
  });

  // ---------------------------------------------------------------------------
  // Remote operations — override in subclass
  // ---------------------------------------------------------------------------

  /// Fetch models from the REST API. Override to customize.
  Future<List<TModel>> remoteGet<TModel extends OfflineFirstWithRestModel>({
    Query? query,
  }) =>
      restProvider.get<TModel>(query: query);

  /// Push [instance] to the REST API. Override to customize.
  Future<TModel?> remoteUpsert<TModel extends OfflineFirstWithRestModel>(
    TModel instance, {
    Query? query,
  }) =>
      restProvider.upsert<TModel>(instance);

  /// Delete [instance] from the REST API. Override to customize.
  Future<void> remoteDelete<TModel extends OfflineFirstWithRestModel>(
    TModel instance, {
    Query? query,
  }) =>
      restProvider.delete<TModel>(instance);

  // ---------------------------------------------------------------------------
  // OfflineFirstRepository overrides
  // ---------------------------------------------------------------------------

  @override
  Future<List<T>> hydrateRemote<T extends OfflineFirstWithRestModel>({
    Query? query,
    bool deserializeLocal = true,
  }) async {
    try {
      final remoteModels = await remoteGet<T>(query: query);
      if (!deserializeLocal) {
        for (final model in remoteModels) {
          await upsertLocal(model);
        }
        unawaited(notifySubscriptionsWithLocalData<T>(query: query));
        return remoteModels;
      }
      // storeRemoteResults persists all models, notifies subscribers,
      // and returns the re-read local results.
      return storeRemoteResults<T>(remoteModels, query: query);
    } on RestException catch (e) {
      _logger.warning('REST hydration failed', e);
      return deserializeLocal ? getLocal<T>(query: query) : [];
    }
  }

  @override
  Future<T?> upsertRemote<T extends OfflineFirstWithRestModel>(
    T instance, {
    Query? query,
  }) async {
    try {
      return await remoteUpsert<T>(instance, query: query);
    } on RestException catch (e) {
      _logger.warning('REST upsert failed', e);
      return null;
    }
  }

  @override
  Future<void> deleteRemote<T extends OfflineFirstWithRestModel>(
    T instance, {
    Query? query,
  }) async {
    try {
      await remoteDelete<T>(instance, query: query);
      // ignore: discarded_futures
      notifySubscriptionsWithLocalData<T>();
    } on RestException catch (e) {
      _logger.warning('REST delete failed', e);
    }
  }
}

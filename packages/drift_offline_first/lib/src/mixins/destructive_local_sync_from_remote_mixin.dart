import 'package:drift_offline_first/src/offline_first_model.dart';
import 'package:drift_offline_first/src/offline_first_policy.dart';
import 'package:drift_offline_first/src/offline_first_repository.dart';
import 'package:drift_offline_first/src/query/query.dart';

/// Mixin that adds a destructive sync strategy: local records missing from
/// the remote are deleted locally.
///
/// Use this for models where the remote uses hard deletes rather than soft
/// archiving. Comparison is done via [OfflineFirstModel.primaryKey].
///
/// **Warning**: Requires fetching ALL remote records, so avoid using this for
/// large datasets without a restricting [query].
mixin DestructiveLocalSyncFromRemoteMixin<TModel extends OfflineFirstModel>
    on OfflineFirstRepository<TModel> {
  @override
  Future<List<T>> get<T extends TModel>({
    bool forceLocalSyncFromRemote = false,
    OfflineFirstGetPolicy policy = OfflineFirstGetPolicy.awaitRemoteWhenNoneExist,
    Query? query,
    bool seedOnly = false,
  }) async {
    if (!forceLocalSyncFromRemote) {
      return super.get<T>(
        policy: policy,
        query: query,
        seedOnly: seedOnly,
      );
    }

    return destructiveLocalSyncFromRemote<T>(query: query);
  }

  /// Fetch all remote records, delete locals not in remote, upsert everything.
  Future<List<T>> destructiveLocalSyncFromRemote<T extends TModel>({
    Query? query,
  }) async {
    logger.finest('#destructiveLocalSyncFromRemote: $T query=$query');

    final remoteResults = await hydrateRemote<T>(query: query);
    final remoteIds = remoteResults.map((r) => r.primaryKey).whereType<Object>().toSet();

    final localResults = await getLocal<T>(query: query);
    final toDelete = localResults.where((r) => !remoteIds.contains(r.primaryKey));

    for (final deletable in toDelete) {
      await deleteLocal(deletable);
    }

    return remoteResults;
  }
}

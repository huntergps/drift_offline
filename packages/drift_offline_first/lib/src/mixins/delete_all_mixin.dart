import '../offline_first_model.dart';
import '../offline_first_policy.dart';
import '../offline_first_repository.dart';
import '../query/query.dart';

/// Adds a [deleteAll] convenience method that removes every matching [T].
///
/// ```dart
/// class MyRepository extends OfflineFirstWithSupabaseRepository
///     with DeleteAllMixin {
///   ...
/// }
///
/// await repo.deleteAll<Order>(
///   query: Query(where: [Where.exact('status', 'cancelled')]),
/// );
/// ```
mixin DeleteAllMixin<TModel extends OfflineFirstModel>
    on OfflineFirstRepository<TModel> {
  /// Deletes every [T] instance matching [query].
  ///
  /// Each deletion respects [policy] — use [OfflineFirstDeletePolicy.localOnly]
  /// to only purge the local Drift database without contacting the remote.
  Future<void> deleteAll<T extends TModel>({
    OfflineFirstDeletePolicy policy = OfflineFirstDeletePolicy.optimisticLocal,
    Query? query,
  }) async {
    final instances = await getLocal<T>(query: query);
    for (final instance in instances) {
      await delete<T>(instance, policy: policy);
    }
  }

  /// Deletes every [T] instance that does NOT match [query].
  ///
  /// Fetches all [T] from local storage, then deletes those that don't appear
  /// in the results of [query].
  Future<void> deleteAllExcept<T extends TModel>({
    required Query query,
    OfflineFirstDeletePolicy policy = OfflineFirstDeletePolicy.optimisticLocal,
  }) async {
    final all = await getLocal<T>();
    final keep = await getLocal<T>(query: query);
    final keepSet = keep.toSet();
    for (final instance in all) {
      if (!keepSet.contains(instance)) {
        await delete<T>(instance, policy: policy);
      }
    }
  }
}

import '../offline_first_model.dart';
import '../offline_first_policy.dart';
import '../offline_first_repository.dart';
import '../query/limit_by.dart';
import '../query/query.dart';
import '../query/query_action.dart';

/// Adds [getFirst] and [getFirstOrNull] convenience methods.
///
/// ```dart
/// class MyRepository extends OfflineFirstWithSupabaseRepository
///     with GetFirstMixin {
///   ...
/// }
///
/// final user = await repo.getFirstOrNull<User>(
///   query: Query(where: [Where.exact('email', 'tom@example.com')]),
/// );
/// ```
mixin GetFirstMixin<TModel extends OfflineFirstModel>
    on OfflineFirstRepository<TModel> {
  /// Returns the first matching [T] or `null` if none exist.
  Future<T?> getFirstOrNull<T extends TModel>({
    OfflineFirstGetPolicy policy = OfflineFirstGetPolicy.awaitRemoteWhenNoneExist,
    Query? query,
  }) async {
    final results = await get<T>(
      policy: policy,
      query: Query(
        where: query?.where ?? const [],
        orderBy: query?.orderBy,
        limitBy: const LimitBy(1),
        providerArgs: query?.providerArgs ?? const {},
        action: query?.action ?? QueryAction.get,
      ),
    );
    return results.isEmpty ? null : results.first;
  }

  /// Returns the first matching [T]. Throws [StateError] if none exist.
  Future<T> getFirst<T extends TModel>({
    OfflineFirstGetPolicy policy = OfflineFirstGetPolicy.awaitRemoteWhenNoneExist,
    Query? query,
  }) async {
    final result = await getFirstOrNull<T>(policy: policy, query: query);
    if (result == null) throw StateError('No $T found for the provided query.');
    return result;
  }
}

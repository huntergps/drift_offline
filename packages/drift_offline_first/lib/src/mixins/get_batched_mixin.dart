import '../offline_first_model.dart';
import '../offline_first_policy.dart';
import '../offline_first_repository.dart';
import '../query/limit_by.dart';
import '../query/query.dart';

/// Adds a [getBatched] convenience method that fetches [T] in pages.
///
/// ```dart
/// class MyRepository extends OfflineFirstWithOdooRepository
///     with GetBatchedMixin {
///   ...
/// }
///
/// final all = await repo.getBatched<Order>(batchSize: 100);
/// ```
mixin GetBatchedMixin<TModel extends OfflineFirstModel>
    on OfflineFirstRepository<TModel> {
  /// Fetch [T] in batches from the remote and persist each batch locally.
  /// [batchSize] controls how many records per request (via LimitBy).
  Future<List<T>> getBatched<T extends TModel>({
    int batchSize = 50,
    OfflineFirstGetPolicy policy = OfflineFirstGetPolicy.awaitRemoteWhenNoneExist,
    Query? query,
  }) async {
    final results = <T>[];
    var offset = 0;
    while (true) {
      final batchQuery = Query(
        where: query?.where ?? const [],
        orderBy: query?.orderBy,
        limitBy: LimitBy(batchSize, offset: offset),
        providerArgs: query?.providerArgs ?? const {},
        action: query?.action ?? QueryAction.get,
      );
      final batch = await get<T>(policy: policy, query: batchQuery);
      results.addAll(batch);
      if (batch.length < batchSize) break;
      offset += batchSize;
    }
    return results;
  }
}

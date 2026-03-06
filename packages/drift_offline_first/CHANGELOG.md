# CHANGELOG

## 0.1.0

- Initial release.
- `OfflineFirstModel` base class with `primaryKey` getter.
- `OfflineFirstRepository` with `get`, `upsert`, `delete` and full policy support.
- `OfflineFirstGetPolicy`: localOnly, awaitRemoteWhenNoneExist, awaitRemote, alwaysHydrate.
- `OfflineFirstUpsertPolicy`: optimisticLocal, requireRemote, localOnly.
- `OfflineFirstDeletePolicy`: optimisticLocal, requireRemote, localOnly.
- `MemoryCacheProvider` L1 in-memory cache.
- `subscribe` / `watchLocal` / `notifySubscriptionsWithLocalData` reactive subscriptions.
- `storeRemoteResults` helper for batch remote-to-local persistence.
- `DestructiveLocalSyncFromRemoteMixin`, `DeleteAllMixin`, `GetBatchedMixin`, `GetFirstMixin`.
- `@OfflineFirst(where, applyToRemoteDeserialization)` field-level annotation.
- `Query`, `Where`, `LimitBy`, `OrderBy`, `Compare` query primitives.
- `HttpOfflineQueueClient`, `HttpOfflineRequestQueue`, `HttpRequestSqliteCacheManager` for REST offline queuing.

/// Behaviors for delete operations.
enum OfflineFirstDeletePolicy {
  /// Delete locally first, then send to remote (fire-and-forget).
  optimisticLocal,

  /// Send to remote first; only delete locally if remote succeeds.
  requireRemote,

  /// Delete only locally; never contact the remote provider.
  localOnly,
}

/// Behaviors for get/read operations.
///
/// Data is **always** returned from local storage, never directly from remote.
enum OfflineFirstGetPolicy {
  /// Fetch from remote in background on every call (unawaited).
  /// Returns local data immediately.
  alwaysHydrate,

  /// Await remote fetch before returning if app is online.
  /// Returns empty list if offline.
  awaitRemote,

  /// Fetch from remote only if local returns no results.
  awaitRemoteWhenNoneExist,

  /// Never contact the remote provider.
  localOnly,
}

/// Behaviors for upsert (create/update) operations.
enum OfflineFirstUpsertPolicy {
  /// Save locally first, then send to remote (fire-and-forget).
  optimisticLocal,

  /// Send to remote first; only save locally if remote succeeds.
  requireRemote,

  /// Save only locally; never contact the remote provider.
  localOnly,
}

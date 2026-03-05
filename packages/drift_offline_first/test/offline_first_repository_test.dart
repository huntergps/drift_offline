import 'dart:io';

import 'package:drift_offline_first/drift_offline_first.dart';
import 'package:test/test.dart';

// ── Minimal model ─────────────────────────────────────────────────────────────

class _Item extends OfflineFirstModel {
  final int id;
  final String name;
  const _Item(this.id, this.name);
}

// ── In-memory repository for testing ─────────────────────────────────────────

class _Repo extends OfflineFirstRepository<_Item> {
  final List<_Item> local;
  final List<_Item> remote;

  /// If set, the next remote call throws this error.
  Object? remoteError;

  _Repo({List<_Item>? local, List<_Item>? remote, super.memoryCacheProvider})
      : local = local ?? [],
        remote = remote ?? [],
        super(loggerName: 'TestRepo');

  @override
  Future<List<T>> getLocal<T extends _Item>({Query? query}) async =>
      local.cast<T>();

  @override
  Future<bool> existsLocal<T extends _Item>({Query? query}) async =>
      local.isNotEmpty;

  @override
  Future<int?> upsertLocal<T extends _Item>(T instance) async {
    local.removeWhere((i) => i.id == instance.id);
    local.add(instance);
    return instance.id;
  }

  @override
  Future<void> deleteLocal<T extends _Item>(T instance) async {
    local.removeWhere((i) => i.id == instance.id);
  }

  @override
  Future<List<T>> hydrateRemote<T extends _Item>({
    Query? query,
    bool deserializeLocal = true,
  }) async {
    if (remoteError != null) throw remoteError!;
    for (final item in remote.cast<T>()) {
      await upsertLocal<T>(item);
    }
    return getLocal<T>(query: query);
  }

  @override
  Future<T?> upsertRemote<T extends _Item>(T instance, {Query? query}) async {
    if (remoteError != null) throw remoteError!;
    remote.removeWhere((i) => i.id == instance.id);
    remote.add(instance);
    return instance;
  }

  @override
  Future<void> deleteRemote<T extends _Item>(T instance, {Query? query}) async {
    if (remoteError != null) throw remoteError!;
    remote.removeWhere((i) => i.id == instance.id);
  }
}

void main() {
  group('get', () {
    test('awaitRemoteWhenNoneExist: returns local when data exists', () async {
      final repo = _Repo(local: [const _Item(1, 'Local')]);

      final results = await repo.get<_Item>(
        policy: OfflineFirstGetPolicy.awaitRemoteWhenNoneExist,
      );

      expect(results.single.name, 'Local');
      expect(repo.remote, isEmpty, reason: 'remote not called');
    });

    test('awaitRemoteWhenNoneExist: hydrates when local is empty', () async {
      final repo = _Repo(remote: [const _Item(1, 'Remote')]);

      final results = await repo.get<_Item>(
        policy: OfflineFirstGetPolicy.awaitRemoteWhenNoneExist,
      );

      expect(results.single.name, 'Remote');
      expect(repo.local, hasLength(1));
    });

    test('awaitRemote: always fetches from remote', () async {
      final repo = _Repo(
        local: [const _Item(1, 'Stale')],
        remote: [const _Item(1, 'Fresh')],
      );

      final results = await repo.get<_Item>(
        policy: OfflineFirstGetPolicy.awaitRemote,
      );

      expect(results.single.name, 'Fresh');
    });

    test('localOnly: never contacts remote', () async {
      final repo = _Repo(local: [const _Item(1, 'CachedOnly')]);
      repo.remoteError = Exception('Should not be called');

      final results = await repo.get<_Item>(
        policy: OfflineFirstGetPolicy.localOnly,
      );

      expect(results.single.name, 'CachedOnly');
    });

    test('memoryCacheProvider: returns cached items on second call', () async {
      final cache = MemoryCacheProvider<_Item>()..manage<_Item>((i) => i.id);
      final repo = _Repo(
        local: [const _Item(1, 'FromDB')],
        memoryCacheProvider: cache,
      );

      // Populate cache
      await repo.get<_Item>(policy: OfflineFirstGetPolicy.awaitRemoteWhenNoneExist);
      // Mutate local to verify cache is used, not DB
      repo.local.clear();

      final cached = await repo.get<_Item>(
        policy: OfflineFirstGetPolicy.awaitRemoteWhenNoneExist,
      );
      expect(cached.single.name, 'FromDB');
    });
  });

  group('upsert', () {
    test('optimisticLocal: saves locally then sends to remote', () async {
      final repo = _Repo();

      final result = await repo.upsert(
        const _Item(1, 'New'),
        policy: OfflineFirstUpsertPolicy.optimisticLocal,
      );

      expect(result.name, 'New');
      expect(repo.local.single.name, 'New');
      // Allow time for fire-and-forget remote call
      await Future<void>.delayed(Duration.zero);
      expect(repo.remote.single.name, 'New');
    });

    test('localOnly: skips remote entirely', () async {
      final repo = _Repo();
      repo.remoteError = Exception('Should not call remote');

      await repo.upsert(
        const _Item(1, 'Local'),
        policy: OfflineFirstUpsertPolicy.localOnly,
      );

      expect(repo.local.single.name, 'Local');
      expect(repo.remote, isEmpty);
    });

    test('requireRemote: saves locally only after remote succeeds', () async {
      final repo = _Repo();

      await repo.upsert(
        const _Item(1, 'Required'),
        policy: OfflineFirstUpsertPolicy.requireRemote,
      );

      expect(repo.local.single.name, 'Required');
      expect(repo.remote.single.name, 'Required');
    });

    test('requireRemote: throws OfflineFirstException on SocketException', () async {
      final repo = _Repo();
      repo.remoteError = const SocketException('offline');

      expect(
        () => repo.upsert(
          const _Item(1, 'X'),
          policy: OfflineFirstUpsertPolicy.requireRemote,
        ),
        throwsA(isA<OfflineFirstException>()),
      );
    });
  });

  group('delete', () {
    test('optimisticLocal: removes locally and from remote', () async {
      final repo = _Repo(
        local: [const _Item(1, 'A')],
        remote: [const _Item(1, 'A')],
      );

      final ok = await repo.delete(
        const _Item(1, 'A'),
        policy: OfflineFirstDeletePolicy.optimisticLocal,
      );

      expect(ok, isTrue);
      expect(repo.local, isEmpty);
      await Future<void>.delayed(Duration.zero);
      expect(repo.remote, isEmpty);
    });

    test('localOnly: only removes locally', () async {
      final repo = _Repo(
        local: [const _Item(1, 'A')],
        remote: [const _Item(1, 'A')],
      );
      repo.remoteError = Exception('Should not call remote');

      await repo.delete(const _Item(1, 'A'), policy: OfflineFirstDeletePolicy.localOnly);

      expect(repo.local, isEmpty);
      expect(repo.remote, hasLength(1), reason: 'remote untouched');
    });
  });

  group('subscribe / notifySubscriptionsWithLocalData', () {
    test('emits current local data when notified', () async {
      final repo = _Repo(local: [const _Item(1, 'Watch')]);

      final stream = repo.subscribe<_Item>();
      final future = stream.first;

      await repo.notifySubscriptionsWithLocalData<_Item>();

      final emitted = await future;
      expect(emitted.single.name, 'Watch');
    });

    test('no emission when there are no listeners', () async {
      final repo = _Repo(local: [const _Item(1, 'X')]);
      // No subscriber — should complete without error
      await expectLater(
        repo.notifySubscriptionsWithLocalData<_Item>(),
        completes,
      );
    });
  });

  group('exists', () {
    test('returns true when local has items', () async {
      final repo = _Repo(local: [const _Item(1, 'X')]);
      expect(await repo.exists<_Item>(), isTrue);
    });

    test('returns false when local is empty', () async {
      final repo = _Repo();
      expect(await repo.exists<_Item>(), isFalse);
    });
  });
}

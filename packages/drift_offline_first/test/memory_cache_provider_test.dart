import 'package:drift_offline_first/src/memory_cache_provider.dart';
import 'package:drift_offline_first/src/offline_first_model.dart';
import 'package:test/test.dart';

// ── Test model ────────────────────────────────────────────────────────────────

class _Item extends OfflineFirstModel {
  final int id;
  final String name;
  const _Item(this.id, this.name);
}

class _Tag extends OfflineFirstModel {
  final String slug;
  const _Tag(this.slug);
}

void main() {
  late MemoryCacheProvider<OfflineFirstModel> cache;

  setUp(() {
    cache = MemoryCacheProvider<OfflineFirstModel>();
    cache.manage<_Item>((i) => i.id);
    cache.manage<_Tag>((t) => t.slug);
  });

  group('manage / manages', () {
    test('registered types are managed', () {
      expect(cache.manages(_Item), isTrue);
      expect(cache.manages(_Tag), isTrue);
    });

    test('unregistered types are not managed', () {
      expect(cache.manages(String), isFalse);
    });
  });

  group('upsert / getAll', () {
    test('inserted item is returned by getAll', () {
      cache.upsert(_Item(1, 'Alpha'));
      final items = cache.getAll<_Item>();
      expect(items, isNotNull);
      expect(items!.single.name, 'Alpha');
    });

    test('upsert replaces existing item with same key', () {
      cache.upsert(_Item(1, 'Alpha'));
      cache.upsert(_Item(1, 'Beta'));
      expect(cache.getAll<_Item>()!.single.name, 'Beta');
    });

    test('multiple items accumulate', () {
      cache.upsert(_Item(1, 'A'));
      cache.upsert(_Item(2, 'B'));
      expect(cache.getAll<_Item>()!.length, 2);
    });

    test('upsert is no-op for unmanaged type', () {
      // _UnmanagedModel extends OfflineFirstModel but is not registered
      expect(() => cache.upsert(const _Item(99, 'x')), returnsNormally);
    });

    test('getAll returns null when type has no cached entries', () {
      expect(cache.getAll<_Tag>(), isNull);
    });
  });

  group('getById', () {
    test('returns item by key', () {
      cache.upsert(_Item(7, 'Seven'));
      expect(cache.getById<_Item>(7)?.name, 'Seven');
    });

    test('returns null for missing key', () {
      expect(cache.getById<_Item>(99), isNull);
    });
  });

  group('delete', () {
    test('removes item with matching key', () {
      cache.upsert(_Item(1, 'A'));
      cache.upsert(_Item(2, 'B'));
      cache.delete(_Item(1, 'ignored'));
      final items = cache.getAll<_Item>()!;
      expect(items.map((i) => i.id), [2]);
    });

    test('delete of non-existent key is harmless', () {
      cache.upsert(_Item(1, 'A'));
      expect(() => cache.delete(_Item(99, 'x')), returnsNormally);
      expect(cache.getAll<_Item>()!.length, 1);
    });
  });

  group('clear / clearAll', () {
    test('clear removes all items for one type', () {
      cache.upsert(_Item(1, 'A'));
      cache.upsert(_Tag('dart'));
      cache.clear<_Item>();
      expect(cache.getAll<_Item>(), isNull);
      expect(cache.getAll<_Tag>(), isNotNull);
    });

    test('clearAll removes all types', () {
      cache.upsert(_Item(1, 'A'));
      cache.upsert(_Tag('flutter'));
      cache.clearAll();
      expect(cache.getAll<_Item>(), isNull);
      expect(cache.getAll<_Tag>(), isNull);
    });
  });

  group('type isolation', () {
    test('_Item and _Tag caches are independent', () {
      cache.upsert(_Item(1, 'Only Item'));
      expect(cache.getAll<_Tag>(), isNull,
          reason: 'Tags cache must not be polluted by Item upserts');
    });
  });
}

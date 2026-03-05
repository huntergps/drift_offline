import 'package:drift/native.dart';
import 'package:drift_offline_first_with_odoo/src/sync/odoo_sync_manager.dart';
import 'package:test/test.dart';

OdooSyncManager _inMemory() => OdooSyncManager(NativeDatabase.memory());

void main() {
  late OdooSyncManager manager;

  setUp(() => manager = _inMemory());
  tearDown(() => manager.close());

  group('lastSyncAt', () {
    test('returns null before first sync', () async {
      expect(await manager.lastSyncAt('res.partner'), isNull);
    });

    test('returns null for unknown model after other model synced', () async {
      await manager.updateLastSync('res.partner');
      expect(await manager.lastSyncAt('sale.order'), isNull);
    });
  });

  group('updateLastSync', () {
    test('persists sync time and lastSyncAt returns it', () async {
      final before = DateTime.now().toUtc().subtract(const Duration(seconds: 1));

      await manager.updateLastSync('res.partner');

      final after = DateTime.now().toUtc().add(const Duration(seconds: 1));
      final ts = await manager.lastSyncAt('res.partner');

      expect(ts, isNotNull);
      expect(ts!.isAfter(before), isTrue);
      expect(ts.isBefore(after), isTrue);
    });

    test('accepts explicit syncedAt', () async {
      final t = DateTime(2025, 6, 15, 12, 0, 0, 0, 0).toUtc();
      await manager.updateLastSync('res.partner', syncedAt: t);
      final ts = await manager.lastSyncAt('res.partner');
      expect(ts?.toIso8601String(), t.toIso8601String());
    });

    test('overwrites previous sync time', () async {
      final first = DateTime(2025, 1, 1).toUtc();
      final second = DateTime(2026, 1, 1).toUtc();

      await manager.updateLastSync('res.partner', syncedAt: first);
      await manager.updateLastSync('res.partner', syncedAt: second);

      final ts = await manager.lastSyncAt('res.partner');
      expect(ts?.year, 2026);
    });

    test('tracks multiple models independently', () async {
      final t1 = DateTime(2025, 1, 1).toUtc();
      final t2 = DateTime(2025, 6, 1).toUtc();

      await manager.updateLastSync('res.partner', syncedAt: t1);
      await manager.updateLastSync('sale.order', syncedAt: t2);

      expect((await manager.lastSyncAt('res.partner'))?.year, 2025);
      expect((await manager.lastSyncAt('res.partner'))?.month, 1);
      expect((await manager.lastSyncAt('sale.order'))?.month, 6);
    });
  });

  group('incrementalDomain', () {
    test('returns null before first sync (full sync needed)', () async {
      expect(await manager.incrementalDomain('res.partner'), isNull);
    });

    test('returns a domain filter after first sync', () async {
      await manager.updateLastSync('res.partner');
      final domain = await manager.incrementalDomain('res.partner');
      expect(domain, isNotNull);
      expect(domain, isNotEmpty);
      // Domain should be [['write_date', '>', '<timestamp>']]
      expect((domain!.first as List).first, 'write_date');
      expect((domain.first as List)[1], '>');
    });
  });

  group('reset', () {
    test('clears sync state for one model', () async {
      await manager.updateLastSync('res.partner');
      await manager.updateLastSync('sale.order');

      await manager.reset('res.partner');

      expect(await manager.lastSyncAt('res.partner'), isNull);
      expect(await manager.lastSyncAt('sale.order'), isNotNull);
    });
  });

  group('resetAll', () {
    test('clears all sync state', () async {
      await manager.updateLastSync('res.partner');
      await manager.updateLastSync('sale.order');

      await manager.resetAll();

      expect(await manager.lastSyncAt('res.partner'), isNull);
      expect(await manager.lastSyncAt('sale.order'), isNull);
    });
  });
}

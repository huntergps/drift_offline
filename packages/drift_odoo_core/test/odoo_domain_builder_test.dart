import 'package:drift_odoo_core/drift_odoo_core.dart';
import 'package:test/test.dart';

void main() {
  group('OdooDomainBuilder.field', () {
    test('produces a single-condition list', () {
      final domain = OdooDomainBuilder.field('active', OdooOperator.eq, true);
      expect(domain, hasLength(1));
      expect(domain.first, ['active', '=', true]);
    });

    test('uses the correct operator string', () {
      final domain = OdooDomainBuilder.field('name', OdooOperator.ilike, 'alice');
      expect((domain.first as List)[1], 'ilike');
    });

    test('supports numeric values', () {
      final domain = OdooDomainBuilder.field('id', OdooOperator.gt, 100);
      expect((domain.first as List)[2], 100);
    });
  });

  group('OdooDomainBuilder.and', () {
    test('empty list returns empty domain', () {
      expect(OdooDomainBuilder.and([]), isEmpty);
    });

    test('single clause returns it unchanged (no & prefix)', () {
      final a = OdooDomainBuilder.field('active', OdooOperator.eq, true);
      expect(OdooDomainBuilder.and([a]), a);
    });

    test('two clauses produces & operator in Polish notation', () {
      final a = OdooDomainBuilder.field('active', OdooOperator.eq, true);
      final b = OdooDomainBuilder.field('is_company', OdooOperator.eq, false);
      final result = OdooDomainBuilder.and([a, b]);
      expect(result.first, '&');
      expect(result.length, 3);
    });

    test('three clauses produces two & operators', () {
      final a = OdooDomainBuilder.field('a', OdooOperator.eq, 1);
      final b = OdooDomainBuilder.field('b', OdooOperator.eq, 2);
      final c = OdooDomainBuilder.field('c', OdooOperator.eq, 3);
      final result = OdooDomainBuilder.and([a, b, c]);
      expect(result.where((e) => e == '&').length, 2);
    });
  });

  group('OdooDomainBuilder.or', () {
    test('empty list returns empty domain', () {
      expect(OdooDomainBuilder.or([]), isEmpty);
    });

    test('single clause returns it unchanged (no | prefix)', () {
      final a = OdooDomainBuilder.field('active', OdooOperator.eq, true);
      expect(OdooDomainBuilder.or([a]), a);
    });

    test('two clauses produces | operator', () {
      final a = OdooDomainBuilder.field('name', OdooOperator.ilike, 'Alice');
      final b = OdooDomainBuilder.field('name', OdooOperator.ilike, 'Bob');
      final result = OdooDomainBuilder.or([a, b]);
      expect(result.first, '|');
      expect(result.length, 3);
    });
  });

  group('OdooDomainBuilder.writtenAfter', () {
    test('produces a write_date > condition', () {
      final t = DateTime.utc(2025, 6, 15, 8, 30, 0);
      final domain = OdooDomainBuilder.writtenAfter(t);
      expect(domain, hasLength(1));
      final condition = domain.first as List;
      expect(condition[0], 'write_date');
      expect(condition[1], '>');
      expect(condition[2], '2025-06-15 08:30:00');
    });

    test('converts local time to UTC', () {
      final t = DateTime.utc(2026, 1, 1, 0, 0, 0);
      final domain = OdooDomainBuilder.writtenAfter(t);
      expect((domain.first as List)[2], '2026-01-01 00:00:00');
    });
  });

  group('OdooDomainBuilder.includeArchived', () {
    test('produces active in [true, false] condition', () {
      final domain = OdooDomainBuilder.includeArchived();
      expect(domain, hasLength(1));
      final condition = domain.first as List;
      expect(condition[0], 'active');
      expect(condition[1], 'in');
      expect(condition[2], [true, false]);
    });
  });

  group('OdooOperator values', () {
    test('all operators map to expected strings', () {
      expect(OdooOperator.eq.value, '=');
      expect(OdooOperator.neq.value, '!=');
      expect(OdooOperator.lt.value, '<');
      expect(OdooOperator.lte.value, '<=');
      expect(OdooOperator.gt.value, '>');
      expect(OdooOperator.gte.value, '>=');
      expect(OdooOperator.like.value, 'like');
      expect(OdooOperator.ilike.value, 'ilike');
      expect(OdooOperator.notLike.value, 'not like');
      expect(OdooOperator.notIlike.value, 'not ilike');
      expect(OdooOperator.inList.value, 'in');
      expect(OdooOperator.notIn.value, 'not in');
      expect(OdooOperator.childOf.value, 'child_of');
      expect(OdooOperator.parentOf.value, 'parent_of');
    });
  });
}

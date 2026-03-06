import 'package:drift_offline_first/drift_offline_first.dart';
import 'package:test/test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // toSnakeCase — pure Dart, no DB needed
  // ---------------------------------------------------------------------------

  group('QueryDriftTransformer.toSnakeCase', () {
    test('leaves already snake_case unchanged', () {
      expect(QueryDriftTransformer.toSnakeCase('name'), 'name');
      expect(QueryDriftTransformer.toSnakeCase('odoo_id'), 'odoo_id');
    });

    test('converts camelCase to snake_case', () {
      expect(QueryDriftTransformer.toSnakeCase('odooId'), 'odoo_id');
      expect(QueryDriftTransformer.toSnakeCase('isCompany'), 'is_company');
      expect(QueryDriftTransformer.toSnakeCase('writeDate'), 'write_date');
    });

    test('handles leading capital (PascalCase)', () {
      expect(QueryDriftTransformer.toSnakeCase('MyField'), 'my_field');
    });

    test('single word stays unchanged', () {
      expect(QueryDriftTransformer.toSnakeCase('email'), 'email');
    });
  });

  // ---------------------------------------------------------------------------
  // buildWhere — logic tests that don't need a real DB connection.
  // We pass an empty column map so all fields resolve to null → skipped.
  // This validates the structural logic (null guards, AND/OR reduction).
  // ---------------------------------------------------------------------------

  group('QueryDriftTransformer.buildWhere (no DB)', () {
    const transformer = QueryDriftTransformer({});

    test('returns null for empty conditions', () {
      expect(transformer.buildWhere([]), isNull);
    });

    test('returns null when all fields are unresolvable (not in columnMap)', () {
      final conditions = [
        Where('unknownField').isExactly('value'),
        Where('anotherUnknown').isExactly(42),
      ];
      expect(transformer.buildWhere(conditions), isNull);
    });

    test('WherePhrase with no resolvable children returns null', () {
      final phrase = WherePhrase.and([
        Where('x').isExactly(1),
        Where('y').isExactly(2),
      ]);
      expect(transformer.buildWhere([phrase]), isNull);
    });

    test('nested WherePhrase — all unresolvable — returns null', () {
      final inner = WherePhrase.or([
        Where('a').isExactly(1),
        Where('b').isExactly(2),
      ]);
      final outer = WherePhrase.and([inner]);
      expect(transformer.buildWhere([outer]), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // applyToSelect / applyToWatch — full integration tests require a Drift DB
  // with generated table classes. Those live in example_odoo_contacts and
  // require `dart run build_runner build` first.
  //
  // The pure-Dart tests above validate all the structural logic. The dynamic
  // dispatch to Drift column methods (equals, like, isBiggerThanValue, …) is
  // validated through the working example and the existing repository tests.
  // ---------------------------------------------------------------------------
}

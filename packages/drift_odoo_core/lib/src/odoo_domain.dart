/// An Odoo search domain — a list of filter conditions.
///
/// Odoo domains use Polish notation with logical operators:
/// `['&', ['field', 'op', value], ['field2', 'op2', value2]]`
///
/// Example:
/// ```dart
/// final domain = OdooDomain.and([
///   OdooDomain.field('is_company', OdooOperator.eq, true),
///   OdooDomain.field('active', OdooOperator.eq, true),
/// ]);
/// ```
typedef OdooDomain = List<dynamic>;

/// Comparison and membership operators for Odoo domain filters.
enum OdooOperator {
  eq('='),
  neq('!='),
  lt('<'),
  lte('<='),
  gt('>'),
  gte('>='),
  like('like'),
  ilike('ilike'),
  notLike('not like'),
  notIlike('not ilike'),
  inList('in'),
  notIn('not in'),
  childOf('child_of'),
  parentOf('parent_of');

  final String value;
  const OdooOperator(this.value);
}

/// Helpers for building Odoo domain filters.
abstract class OdooDomainBuilder {
  /// A single field condition: `[field, operator, value]`
  static OdooDomain field(String name, OdooOperator op, dynamic value) {
    return [
      [name, op.value, value],
    ];
  }

  /// AND of multiple domain clauses: `['&', clause1, clause2, ...]`
  static OdooDomain and(List<OdooDomain> clauses) {
    if (clauses.isEmpty) return [];
    if (clauses.length == 1) return clauses.first;
    final result = <dynamic>[];
    for (var i = 0; i < clauses.length - 1; i++) {
      result.add('&');
    }
    for (final c in clauses) {
      result.addAll(c);
    }
    return result;
  }

  /// OR of multiple domain clauses: `['|', clause1, clause2, ...]`
  static OdooDomain or(List<OdooDomain> clauses) {
    if (clauses.isEmpty) return [];
    if (clauses.length == 1) return clauses.first;
    final result = <dynamic>[];
    for (var i = 0; i < clauses.length - 1; i++) {
      result.add('|');
    }
    for (final c in clauses) {
      result.addAll(c);
    }
    return result;
  }

  /// Convenience: filter records modified after [since].
  /// Used for incremental sync.
  static OdooDomain writtenAfter(DateTime since) {
    return field('write_date', OdooOperator.gt, _formatDatetime(since));
  }

  /// Convenience: include archived records too (models with `active` field).
  static OdooDomain includeArchived() {
    return field('active', OdooOperator.inList, [true, false]);
  }

  static String _formatDatetime(DateTime dt) {
    final utc = dt.toUtc();
    final y = utc.year.toString().padLeft(4, '0');
    final mo = utc.month.toString().padLeft(2, '0');
    final d = utc.day.toString().padLeft(2, '0');
    final h = utc.hour.toString().padLeft(2, '0');
    final mi = utc.minute.toString().padLeft(2, '0');
    final s = utc.second.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi:$s';
  }
}

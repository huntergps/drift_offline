import 'package:drift/drift.dart' hide Query, Where, OrderBy;
import 'package:meta/meta.dart';

import 'compare.dart';
import 'order_by.dart';
import 'query.dart';
import 'where.dart';

/// Translates drift_offline [Query] objects into Drift SQL expressions.
///
/// ## Why this exists
///
/// Brick's `QuerySqlTransformer` generates raw SQL strings because Brick owns
/// its own SQLite provider. In drift_offline, Drift already owns SQL
/// generation — so this transformer produces **`Expression<bool>`** objects
/// that plug directly into Drift's type-safe query builder.
///
/// ## Usage — single-table queries
///
/// Instantiate once per repository (or per model) with the column map:
///
/// ```dart
/// final _transformer = QueryDriftTransformer({
///   'odooId':    db.partners.odooId    as GeneratedColumn<Object>,
///   'name':      db.partners.name      as GeneratedColumn<Object>,
///   'email':     db.partners.email     as GeneratedColumn<Object>,
///   'isCompany': db.partners.isCompany as GeneratedColumn<Object>,
/// });
/// ```
///
/// Then apply to any Drift select statement:
///
/// ```dart
/// // In getLocal<T>():
/// final stmt = db.select(db.partners);
/// _transformer.applyToSelect(stmt, query);
/// return (await stmt.get()).map(rowToPartner).toList();
///
/// // In watchLocal<T>():
/// return _transformer
///     .applyToWatch(db.select(db.partners), query)
///     .map((rows) => rows.map(rowToPartner).toList().cast<T>());
/// ```
///
/// ## Usage — cross-table (JOIN) queries
///
/// To filter on association fields (e.g. `Where('customer.city', 'Quito')`),
/// register the foreign columns in the map with dotted-path keys, then use
/// [applyToJoinedSelect] on a pre-built `JoinedSelectStatement`:
///
/// ```dart
/// final _transformer = QueryDriftTransformer({
///   'id':              db.orders.id           as GeneratedColumn<Object>,
///   'status':          db.orders.status       as GeneratedColumn<Object>,
///   'customer.city':   db.customers.city      as GeneratedColumn<Object>,
///   'customer.name':   db.customers.name      as GeneratedColumn<Object>,
/// });
///
/// // In getLocal<T>():
/// final stmt = db.select(db.orders).join([
///   innerJoin(db.customers, db.orders.customerId.equalsExp(db.customers.id)),
/// ]);
/// _transformer.applyToJoinedSelect(stmt, query);
/// return (await stmt.get()).map((row) => rowToOrder(row)).toList();
/// ```
///
/// ## Column map keys
///
/// Keys may be **camelCase** Dart field names, **snake_case** SQL column names,
/// or **dotted paths** for association fields (e.g. `'customer.city'`).
/// The transformer checks camelCase and snake_case automatically; dotted paths
/// must be registered exactly as used in the [Where] conditions.
@immutable
class QueryDriftTransformer {
  /// Maps Dart field names (or snake_case column names) to Drift columns.
  final Map<String, GeneratedColumn<Object>> columnMap;

  const QueryDriftTransformer(this.columnMap);

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Applies WHERE, ORDER BY, and LIMIT from [query] to [statement] in-place.
  ///
  /// Call before `.get()` or `.watch()`.
  void applyToSelect<T extends HasResultSet, R>(
    SimpleSelectStatement<T, R> statement,
    Query? query,
  ) {
    if (query == null) return;

    final whereExpr = buildWhere(query.where);
    if (whereExpr != null) {
      // Ignore the table argument — we use pre-resolved columns from the map.
      statement.where((_) => whereExpr);
    }

    if (query.orderBy != null) {
      final terms = query.orderBy!.conditions
          .map(_buildOrderingTerm)
          .whereType<OrderingTerm>()
          .toList();
      if (terms.isNotEmpty) {
        statement.orderBy(terms.map((t) => (_) => t).toList());
      }
    }

    if (query.limitBy != null) {
      statement.limit(
        query.limitBy!.amount,
        offset: query.limitBy!.offset,
      );
    }
  }

  /// Applies [query] constraints and returns a `.watch()` stream.
  ///
  /// Convenience wrapper for use in [watchLocal] overrides:
  /// ```dart
  /// return _transformer
  ///     .applyToWatch(db.select(db.partners), query)
  ///     .map((rows) => rows.map(rowToPartner).toList().cast<T>());
  /// ```
  Stream<List<R>> applyToWatch<T extends HasResultSet, R>(
    SimpleSelectStatement<T, R> statement,
    Query? query,
  ) {
    applyToSelect(statement, query);
    return statement.watch();
  }

  /// Applies WHERE, ORDER BY, and LIMIT from [query] to a [JoinedSelectStatement].
  ///
  /// Use this when filtering on association columns (cross-table queries).
  /// The JOIN itself must be set up by the caller; this method only applies
  /// the WHERE/ORDER BY/LIMIT expressions using columns registered in
  /// [columnMap] (including dotted-path keys like `'customer.city'`).
  ///
  /// ```dart
  /// final stmt = db.select(db.orders).join([
  ///   innerJoin(db.customers, db.orders.customerId.equalsExp(db.customers.id)),
  /// ]);
  /// _transformer.applyToJoinedSelect(stmt, query);
  /// final rows = await stmt.get();
  /// ```
  void applyToJoinedSelect<T extends HasResultSet, R>(
    JoinedSelectStatement<T, R> statement,
    Query? query,
  ) {
    if (query == null) return;

    final whereExpr = buildWhere(query.where);
    if (whereExpr != null) {
      statement.where(whereExpr);
    }

    if (query.orderBy != null) {
      final terms = query.orderBy!.conditions
          .map(_buildOrderingTerm)
          .whereType<OrderingTerm>()
          .toList();
      if (terms.isNotEmpty) {
        statement.orderBy(terms);
      }
    }

    if (query.limitBy != null) {
      statement.limit(query.limitBy!.amount, offset: query.limitBy!.offset);
    }
  }

  /// Converts [conditions] into a single `Expression<bool>`.
  ///
  /// Top-level conditions are combined with AND.
  /// Returns `null` when [conditions] is empty or no column is found for any
  /// condition (unresolvable fields are silently skipped).
  Expression<bool>? buildWhere(List<WhereCondition> conditions) {
    if (conditions.isEmpty) return null;
    final exprs = conditions
        .map(_buildCondition)
        .whereType<Expression<bool>>()
        .toList();
    if (exprs.isEmpty) return null;
    return exprs.reduce((a, b) => a & b);
  }

  // ---------------------------------------------------------------------------
  // Internal — WHERE
  // ---------------------------------------------------------------------------

  Expression<bool>? _buildCondition(WhereCondition condition) {
    if (condition is WherePhrase) {
      final exprs = condition.conditions
          .map(_buildCondition)
          .whereType<Expression<bool>>()
          .toList();
      if (exprs.isEmpty) return null;
      return condition.isRequired
          ? exprs.reduce((a, b) => a & b)
          : exprs.reduce((a, b) => a | b);
    }
    if (condition is Where) {
      final col = _resolveColumn(condition.evaluatedField);
      if (col == null) return null;
      return _applyCompare(col, condition.compare, condition.value);
    }
    return null;
  }

  /// Look up column by camelCase field name, falling back to snake_case.
  GeneratedColumn<Object>? _resolveColumn(String fieldName) {
    return columnMap[fieldName] ?? columnMap[_toSnakeCase(fieldName)];
  }

  Expression<bool>? _applyCompare(
    GeneratedColumn<Object> col,
    Compare compare,
    dynamic value,
  ) {
    switch (compare) {
      case Compare.exact:
        if (value == null) return col.isNull();
        // Dynamic dispatch: Dart erases type param at runtime; the underlying
        // Drift column type still enforces correct SQL casting internally.
        // ignore: avoid_dynamic_calls
        return (col as dynamic).equals(value) as Expression<bool>;

      case Compare.notEqual:
        if (value == null) return col.isNotNull();
        // ignore: avoid_dynamic_calls
        return ((col as dynamic).equals(value) as Expression<bool>).not();

      case Compare.contains:
        return (col as GeneratedColumn<String>).like('%$value%');

      case Compare.doesNotContain:
        return (col as GeneratedColumn<String>).like('%$value%').not();

      case Compare.greaterThan:
        // ignore: avoid_dynamic_calls
        return (col as dynamic).isBiggerThanValue(value) as Expression<bool>;

      case Compare.greaterThanOrEqualTo:
        // ignore: avoid_dynamic_calls
        return (col as dynamic).isBiggerOrEqualValue(value) as Expression<bool>;

      case Compare.lessThan:
        // ignore: avoid_dynamic_calls
        return (col as dynamic).isSmallerThanValue(value) as Expression<bool>;

      case Compare.lessThanOrEqualTo:
        // ignore: avoid_dynamic_calls
        return (col as dynamic).isSmallerOrEqualValue(value) as Expression<bool>;

      case Compare.between:
        if (value is List && value.length == 2) {
          // ignore: avoid_dynamic_calls
          return (col as dynamic).isBetweenValues(value[0], value[1])
              as Expression<bool>;
        }
        return null;

      case Compare.inIterable:
        if (value is List) {
          return col.isIn(value.cast<Object>());
        }
        return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Internal — ORDER BY
  // ---------------------------------------------------------------------------

  OrderingTerm? _buildOrderingTerm(OrderByCondition condition) {
    final col = _resolveColumn(condition.evaluatedField);
    if (col == null) return null;
    return OrderingTerm(
      expression: col,
      mode: condition.ascending ? OrderingMode.asc : OrderingMode.desc,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Converts `camelCase` → `snake_case` for column name fallback lookup.
  @visibleForTesting
  static String toSnakeCase(String input) {
    return input
        .replaceAllMapped(
          RegExp(r'[A-Z]'),
          (m) => '_${m.group(0)!.toLowerCase()}',
        )
        .replaceFirst(RegExp(r'^_'), '');
  }

  // Private alias used internally.
  static String _toSnakeCase(String input) => toSnakeCase(input);
}

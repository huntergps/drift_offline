import 'limit_by.dart';
import 'order_by.dart';
import 'query_action.dart';
import 'where.dart';

/// Uniform query object passed to repositories and providers.
///
/// ```dart
/// Query(
///   where: [Where.exact('status', 'active')],
///   orderBy: OrderBy.desc('createdAt'),
///   limitBy: LimitBy(20),
///   providerArgs: {'myParam': 'value'},
/// )
/// ```
class Query {
  /// List of conditions to filter results.
  final List<WhereCondition> where;

  /// Ordering specification.
  final OrderBy? orderBy;

  /// Limit/offset specification.
  final LimitBy? limitBy;

  /// Provider-specific arguments (e.g. extra Supabase filter params, REST URL params).
  final Map<String, dynamic> providerArgs;

  /// The intended operation. Providers can use this to select the right
  /// endpoint or SQL statement. Defaults to [QueryAction.get].
  final QueryAction action;

  const Query({
    this.where = const [],
    this.orderBy,
    this.limitBy,
    this.providerArgs = const {},
    this.action = QueryAction.get,
  });

  /// Convenience factory: single [Where.exact] condition.
  factory Query.where(String field, dynamic value) =>
      Query(where: [Where.exact(field, value)]);

  /// Convenience factory: build from an existing list of conditions.
  factory Query.fromWhere(List<WhereCondition> conditions) =>
      Query(where: conditions);

  bool get hasWhere => where.isNotEmpty;

  /// Extract the first [Where] for the given field, or null.
  Where? whereField(String field) {
    for (final c in where) {
      if (c is Where && c.evaluatedField == field) return c;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        if (where.isNotEmpty) 'where': where.map((c) => c.toJson()).toList(),
        if (orderBy != null) 'orderBy': orderBy!.toJson(),
        if (limitBy != null) 'limitBy': limitBy!.toJson(),
        if (providerArgs.isNotEmpty) 'providerArgs': providerArgs,
        'action': action.name,
      };

  factory Query.fromJson(Map<String, dynamic> json) => Query(
        where: (json['where'] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .map(WhereCondition.fromJson)
            .toList(),
        orderBy: json['orderBy'] != null
            ? OrderBy.fromJson(json['orderBy'] as Map<String, dynamic>)
            : null,
        limitBy: json['limitBy'] != null
            ? LimitBy.fromJson(json['limitBy'] as Map<String, dynamic>)
            : null,
        providerArgs: (json['providerArgs'] as Map<String, dynamic>?) ?? const {},
        action: QueryAction.values.byName(json['action'] as String? ?? 'get'),
      );
}

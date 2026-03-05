import 'compare.dart';

/// Union type for [Where] and [WherePhrase].
abstract class WhereCondition {
  const WhereCondition();

  Map<String, dynamic> toJson();

  static WhereCondition fromJson(Map<String, dynamic> json) {
    if (json.containsKey('isRequired')) {
      return WherePhrase.fromJson(json);
    }
    return Where.fromJsonMap(json);
  }
}

/// A single filter condition for a query.
///
/// Example:
/// ```dart
/// Where('name').isExactly('Tom')
/// Where('age').isGreaterThan(18)
/// Where.exact('status', 'active')
/// ```
class Where extends WhereCondition {
  /// The field name to filter on (Dart field name, not column name).
  final String evaluatedField;

  /// The comparison operator.
  final Compare compare;

  /// The value to compare against.
  final dynamic value;

  /// Sub-conditions (used for AND/OR grouping).
  final List<WhereCondition> conditions;

  const Where(
    this.evaluatedField, {
    this.value,
    this.compare = Compare.exact,
    this.conditions = const [],
  });

  /// Shorthand for [Compare.exact].
  const Where.exact(String field, this.value)
      : evaluatedField = field,
        compare = Compare.exact,
        conditions = const [];

  Where isExactly(dynamic v) =>
      Where(evaluatedField, value: v, compare: Compare.exact);

  Where isNot(dynamic v) =>
      Where(evaluatedField, value: v, compare: Compare.notEqual);

  Where contains(dynamic v) =>
      Where(evaluatedField, value: v, compare: Compare.contains);

  Where doesNotContain(dynamic v) =>
      Where(evaluatedField, value: v, compare: Compare.doesNotContain);

  Where isGreaterThan(dynamic v) =>
      Where(evaluatedField, value: v, compare: Compare.greaterThan);

  Where isGreaterThanOrEqualTo(dynamic v) =>
      Where(evaluatedField, value: v, compare: Compare.greaterThanOrEqualTo);

  Where isLessThan(dynamic v) =>
      Where(evaluatedField, value: v, compare: Compare.lessThan);

  Where isLessThanOrEqualTo(dynamic v) =>
      Where(evaluatedField, value: v, compare: Compare.lessThanOrEqualTo);

  Where isBetween(dynamic lower, dynamic upper) =>
      Where(evaluatedField, value: [lower, upper], compare: Compare.between);

  Where isIn(List<dynamic> values) =>
      Where(evaluatedField, value: values, compare: Compare.inIterable);

  @override
  Map<String, dynamic> toJson() => {
        'evaluatedField': evaluatedField,
        'compare': compare.name,
        'value': value,
        if (conditions.isNotEmpty)
          'conditions': conditions.map((c) => c.toJson()).toList(),
      };

  factory Where.fromJsonMap(Map<String, dynamic> json) => Where(
        json['evaluatedField'] as String,
        value: json['value'],
        compare: Compare.values.byName(json['compare'] as String),
        conditions: (json['conditions'] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .map(WhereCondition.fromJson)
            .toList(),
      );
}

/// Groups multiple [WhereCondition]s with AND or OR.
class WherePhrase extends WhereCondition {
  final List<WhereCondition> conditions;

  /// true = AND, false = OR
  final bool isRequired;

  const WherePhrase(this.conditions, {this.isRequired = true});

  /// Convenience: AND group.
  static WherePhrase and(List<WhereCondition> conditions) =>
      WherePhrase(conditions, isRequired: true);

  /// Convenience: OR group.
  static WherePhrase or(List<WhereCondition> conditions) =>
      WherePhrase(conditions, isRequired: false);

  @override
  Map<String, dynamic> toJson() => {
        'isRequired': isRequired,
        'conditions': conditions.map((c) => c.toJson()).toList(),
      };

  factory WherePhrase.fromJson(Map<String, dynamic> json) => WherePhrase(
        (json['conditions'] as List)
            .cast<Map<String, dynamic>>()
            .map(WhereCondition.fromJson)
            .toList(),
        isRequired: json['isRequired'] as bool? ?? true,
      );
}

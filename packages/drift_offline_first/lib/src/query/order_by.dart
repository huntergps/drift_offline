/// Specifies ordering for query results.
class OrderBy {
  final List<OrderByCondition> conditions;

  const OrderBy(this.conditions);

  factory OrderBy.asc(String field, {String? associationField}) =>
      OrderBy([OrderByCondition(field, ascending: true, associationField: associationField)]);

  factory OrderBy.desc(String field, {String? associationField}) =>
      OrderBy([OrderByCondition(field, ascending: false, associationField: associationField)]);

  Map<String, dynamic> toJson() => {
        'conditions': conditions.map((c) => c.toJson()).toList(),
      };

  factory OrderBy.fromJson(Map<String, dynamic> json) => OrderBy(
        (json['conditions'] as List)
            .cast<Map<String, dynamic>>()
            .map(OrderByCondition.fromJson)
            .toList(),
      );
}

class OrderByCondition {
  final String evaluatedField;
  final bool ascending;

  /// When set, indicates the field belongs to an associated model.
  final String? associationField;

  const OrderByCondition(
    this.evaluatedField, {
    this.ascending = true,
    this.associationField,
  });

  Map<String, dynamic> toJson() => {
        'evaluatedField': evaluatedField,
        'ascending': ascending,
        if (associationField != null) 'associationField': associationField,
      };

  factory OrderByCondition.fromJson(Map<String, dynamic> json) => OrderByCondition(
        json['evaluatedField'] as String,
        ascending: json['ascending'] as bool? ?? true,
        associationField: json['associationField'] as String?,
      );
}

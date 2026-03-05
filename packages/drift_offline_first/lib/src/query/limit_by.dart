/// Limits the number of results returned by a query.
class LimitBy {
  /// Maximum number of results to return.
  final int amount;

  /// Number of results to skip (for offset-based pagination).
  final int? offset;

  const LimitBy(this.amount, {this.offset});

  Map<String, dynamic> toJson() => {
        'amount': amount,
        if (offset != null) 'offset': offset,
      };

  factory LimitBy.fromJson(Map<String, dynamic> json) => LimitBy(
        json['amount'] as int,
        offset: json['offset'] as int?,
      );
}

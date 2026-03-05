/// Base class for complex Dart types that need custom serialization per
/// storage provider.
///
/// Extend this when a field's type is not a Dart primitive and requires
/// different representations in different backends. Each provider calls
/// the corresponding `to*` method for serialization, and a custom factory
/// (e.g. `fromRest`) for deserialization.
///
/// Example:
/// ```dart
/// class Money extends OfflineFirstSerdes<Map<String, dynamic>, String> {
///   final double amount;
///   final String currency;
///
///   Money(this.amount, this.currency);
///
///   @override
///   Map<String, dynamic>? toRest() => {'amount': amount, 'currency': currency};
///
///   @override
///   Map<String, dynamic>? toSupabase() => toRest();
///
///   @override
///   String? toSqlite() => '$amount:$currency';   // Compact local format
///
///   factory Money.fromRest(Map<String, dynamic> data) =>
///       Money(data['amount'] as double, data['currency'] as String);
///
///   factory Money.fromSqlite(String data) {
///     final parts = data.split(':');
///     return Money(double.parse(parts[0]), parts[1]);
///   }
/// }
/// ```
///
/// [RemoteType] is the format used by REST and Supabase (often
/// `Map<String, dynamic>` or a JSON-compatible primitive).
/// [LocalType] is the format used by the local SQLite/Drift store
/// (often `String` for a serialized blob or a primitive).
abstract class OfflineFirstSerdes<RemoteType, LocalType> {
  const OfflineFirstSerdes();

  /// Serialize for a generic REST API. Returns `null` to omit the field.
  RemoteType? toRest() => null;

  /// Serialize for Supabase (PostgREST). Defaults to [toRest].
  RemoteType? toSupabase() => toRest();

  /// Serialize for an Odoo JSON-RPC API. Defaults to [toRest].
  RemoteType? toOdoo() => toRest();

  /// Serialize for local Drift/SQLite storage.
  LocalType? toSqlite();
}

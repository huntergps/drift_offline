import 'package:brick_core/field_serializable.dart';

/// Annotation for configuring how a field is serialized to/from Supabase (PostgREST).
///
/// Example:
/// ```dart
/// class User extends OfflineFirstWithSupabaseModel {
///   // Map Dart field to a different column name
///   @Supabase(name: 'full_name')
///   final String name;
///
///   // Use foreign key column for association
///   @Supabase(foreignKey: 'address_id')
///   final Address address;
///
///   // Ignore in all Supabase operations
///   @Supabase(ignore: true)
///   final String localOnlyField;
/// }
/// ```
class Supabase implements FieldSerializable {
  /// The Supabase column name. Defaults to snake_case of the Dart field name.
  @override
  final String? name;

  @override
  final bool ignore;

  @override
  final bool ignoreFrom;

  @override
  final bool ignoreTo;

  /// Treat enums as their string name instead of index.
  @override
  final bool enumAsString;

  @override
  final String? defaultValue;

  @override
  final String? fromGenerator;

  @override
  final String? toGenerator;

  /// The foreign key column on this model for an association.
  /// For example, `'address_id'` in `customer:customers!address_id(...)`.
  final String? foreignKey;

  /// Override the generated PostgREST query for this field.
  /// Advanced use only — replaces all generated query content.
  final String? query;

  /// Whether this field maps to a unique/primary key column.
  /// Used to target upserts and deletes.
  final bool unique;

  const Supabase({
    this.name,
    bool? ignore,
    bool? ignoreFrom,
    bool? ignoreTo,
    bool? enumAsString,
    this.defaultValue,
    this.fromGenerator,
    this.toGenerator,
    this.foreignKey,
    this.query,
    bool? unique,
  })  : ignore = ignore ?? false,
        ignoreFrom = ignoreFrom ?? false,
        ignoreTo = ignoreTo ?? false,
        enumAsString = enumAsString ?? false,
        unique = unique ?? false;

  static const defaults = Supabase();
}

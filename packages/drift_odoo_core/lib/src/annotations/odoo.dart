import 'package:brick_core/field_serializable.dart';

/// Annotation for configuring how a field is serialized to/from the Odoo JSON-2 API.
///
/// Example:
/// ```dart
/// @Odoo(name: 'email_from')
/// final String? email;
///
/// @Odoo(ignore: true)
/// final String? localOnlyField;
/// ```
class Odoo implements FieldSerializable {
  /// The Odoo field name. Defaults to snake_case of the Dart field name.
  @override
  final String? name;

  /// Whether to completely ignore this field for Odoo serialization.
  @override
  final bool ignore;

  /// Ignore this field only during deserialization (fromOdoo).
  @override
  final bool ignoreFrom;

  /// Ignore this field only during serialization (toOdoo).
  @override
  final bool ignoreTo;

  /// Treat enum as its string name rather than its index.
  @override
  final bool enumAsString;

  /// Default value if Odoo returns `false` or `null` for this field.
  /// Must be a primitive type or null.
  @override
  final String? defaultValue;

  /// Custom Dart expression for deserialization (fromOdoo).
  /// The variable `data` refers to the raw JSON map.
  @override
  final String? fromGenerator;

  /// Custom Dart expression for serialization (toOdoo).
  /// The variable `instance` refers to the model instance.
  @override
  final String? toGenerator;

  const Odoo({
    this.name,
    bool? ignore,
    bool? ignoreFrom,
    bool? ignoreTo,
    bool? enumAsString,
    this.defaultValue,
    this.fromGenerator,
    this.toGenerator,
  })  : ignore = ignore ?? false,
        ignoreFrom = ignoreFrom ?? false,
        ignoreTo = ignoreTo ?? false,
        enumAsString = enumAsString ?? false;

  static const defaults = Odoo();
}

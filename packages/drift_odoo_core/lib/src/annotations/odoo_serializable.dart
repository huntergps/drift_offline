import 'package:brick_core/field_rename.dart';

/// Class-level annotation for configuring Odoo serialization defaults.
///
/// Example:
/// ```dart
/// @ConnectOfflineFirstWithOdoo(
///   odooConfig: OdooSerializable(
///     odooModel: 'res.partner',
///     fieldRename: FieldRename.snake,
///   ),
/// )
/// class Partner extends OfflineFirstWithOdooModel { ... }
/// ```
class OdooSerializable {
  /// The Odoo model technical name (e.g. `'res.partner'`, `'account.move'`).
  /// If null, defaults to the snake_case class name.
  final String? odooModel;

  /// How Dart field names are converted to Odoo field names by default.
  /// Defaults to [FieldRename.snake] since Odoo uses snake_case.
  final FieldRename fieldRename;

  /// Whether fields are nullable by default.
  /// Odoo returns `false` (not `null`) for empty fields, so defaults to `true`.
  final bool nullable;

  const OdooSerializable({
    this.odooModel,
    FieldRename? fieldRename,
    bool? nullable,
  })  : fieldRename = fieldRename ?? FieldRename.snake,
        nullable = nullable ?? true;

  static const defaults = OdooSerializable();
}

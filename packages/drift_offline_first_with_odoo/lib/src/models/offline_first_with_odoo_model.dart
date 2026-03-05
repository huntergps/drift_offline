import 'package:drift_offline_first/drift_offline_first.dart';
import 'package:drift_odoo_core/drift_odoo_core.dart';

/// Base model for all models using the offline-first Odoo integration.
///
/// Annotate subclasses with `@ConnectOfflineFirstWithOdoo`.
///
/// Example:
/// ```dart
/// @ConnectOfflineFirstWithOdoo(
///   odooConfig: OdooSerializable(odooModel: 'res.partner'),
/// )
/// class Partner extends OfflineFirstWithOdooModel {
///   final String name;
///   Partner({required this.name, super.odooId});
/// }
/// ```
abstract class OfflineFirstWithOdooModel extends OfflineFirstModel
    implements OdooModel {
  /// The server-side Odoo record ID. Null before the first successful create.
  @override
  int? odooId;

  OfflineFirstWithOdooModel({this.odooId});

  @override
  Object? get primaryKey => odooId;
}

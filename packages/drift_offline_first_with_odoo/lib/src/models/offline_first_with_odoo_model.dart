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
  /// The server-side Odoo record ID (`null` before the first successful create).
  ///
  /// This field is **intentionally mutable**: [OfflineFirstWithOdooRepository.upsertRemote]
  /// sets it after a successful `create` call so the in-memory instance stays
  /// consistent without requiring a full local re-read.
  ///
  /// Contract:
  /// - Set by the framework after a successful remote `create`. Do not set
  ///   it manually in application code.
  /// - Once set to a non-null value it should not be changed to a different
  ///   non-null value (treat it as write-once from the remote perspective).
  @override
  int? odooId;

  OfflineFirstWithOdooModel({this.odooId});

  @override
  Object? get primaryKey => odooId;
}

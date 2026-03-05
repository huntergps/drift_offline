import 'package:drift_odoo_core/drift_odoo_core.dart';

/// Annotation that marks a class for offline-first Odoo code generation.
///
/// Applied to model classes that extend [OfflineFirstWithOdooModel].
/// The build system generates [fromOdoo]/[toOdoo] adapters and registers
/// the model in the [OdooModelDictionary].
///
/// Example:
/// ```dart
/// @ConnectOfflineFirstWithOdoo(
///   odooConfig: OdooSerializable(odooModel: 'res.partner'),
/// )
/// class Partner extends OfflineFirstWithOdooModel {
///   final String name;
///   @Odoo(name: 'email_from')
///   final String? email;
/// }
/// ```
class ConnectOfflineFirstWithOdoo {
  /// Odoo provider configuration.
  final OdooSerializable? odooConfig;

  const ConnectOfflineFirstWithOdoo({this.odooConfig});

  static const defaults = ConnectOfflineFirstWithOdoo(
    odooConfig: OdooSerializable.defaults,
  );

  ConnectOfflineFirstWithOdoo withDefaults() => ConnectOfflineFirstWithOdoo(
        odooConfig: odooConfig ?? defaults.odooConfig,
      );
}

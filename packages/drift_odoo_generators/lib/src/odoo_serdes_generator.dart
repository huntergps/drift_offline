import 'package:analyzer/dart/element/element.dart';
import 'package:brick_build/generators.dart';
import 'package:drift_odoo_core/drift_odoo_core.dart';

import 'odoo_fields.dart';

/// Base serdes generator for Odoo JSON-2 serialization.
abstract class OdooSerdesGenerator extends SerdesGenerator<Odoo, OdooModel> {
  @override
  final String providerName = 'Odoo';

  @override
  final String repositoryName;

  OdooSerdesGenerator(
    ClassElement super.element,
    OdooFields super.fields, {
    required this.repositoryName,
  });

  @override
  String get deserializeInputType => 'Map<String, dynamic>';

  @override
  String get serializeOutputType => 'Map<String, dynamic>';

  /// Convert Dart field name to Odoo field name using annotation or config.
  String odooFieldName(FieldElement field, Odoo annotation) {
    return annotation.name ?? field.name;
  }
}

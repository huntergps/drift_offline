import 'package:analyzer/dart/element/element.dart';
import 'package:drift_build/generators.dart';
import 'package:drift_odoo_core/drift_odoo_core.dart';
import 'package:source_gen/source_gen.dart';

/// Base serdes generator for Odoo JSON-2 serialization.
abstract class OdooSerdesGenerator extends SerdesGenerator<Odoo> {
  @override
  final String providerName = 'Odoo';

  @override
  final String providerClassName = 'OdooOfflineQueueClient';

  @override
  final String repositoryName;

  @override
  TypeChecker get siblingsChecker => TypeChecker.fromRuntime(OdooModel);

  OdooSerdesGenerator(
    super.element,
    super.fields, {
    required this.repositoryName,
  });

  @override
  String get deserializeInputType => 'Map<String, dynamic>';

  @override
  String get serializeOutputType => 'Map<String, dynamic>';

  /// Returns the Odoo field name for [field] from its annotation.
  String odooFieldName(FieldElement field, Odoo annotation) {
    return annotation.name ?? field.name;
  }
}

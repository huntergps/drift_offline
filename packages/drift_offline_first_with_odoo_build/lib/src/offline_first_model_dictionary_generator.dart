import 'package:drift_build/generators.dart';

/// Generates the `odooModelDictionary` and mappings file (`odoo.g.dart`).
class OfflineFirstModelDictionaryGenerator extends ModelDictionaryGenerator {
  @override
  String get requiredImports => """
// ignore: unused_import
import 'dart:convert';
import 'package:drift_odoo/drift_odoo.dart' show OdooOfflineQueueClient, OdooCommand;
import 'package:drift_odoo_core/drift_odoo_core.dart' show OdooModel, OdooAdapter, OdooModelDictionary;
import 'package:drift_offline_first_with_odoo/drift_offline_first_with_odoo.dart'
    show OfflineFirstWithOdooRepository, OfflineFirstWithOdooAdapter;""";

  const OfflineFirstModelDictionaryGenerator();

  @override
  String generate(Map<String, String> classNamesToFileNames) {
    final adapters = adaptersFromFiles(classNamesToFileNames);
    final dictionary = dictionaryFromFiles(classNamesToFileNames);
    final models = modelsFromFiles(classNamesToFileNames);

    return '''
${ModelDictionaryGenerator.headerComment}
$requiredImports

$models

$adapters

/// Odoo mappings — use when initializing [OdooOfflineQueueClient] / [OfflineFirstWithOdooRepository]
final Map<Type, OdooAdapter<OdooModel>> odooMappings = {
  $dictionary
};
final odooModelDictionary = OdooModelDictionary(odooMappings);
''';
  }
}

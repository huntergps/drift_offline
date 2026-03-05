import 'package:analyzer/dart/element/element.dart';
import 'package:brick_build/generators.dart';
import 'package:drift_offline_first_with_odoo/drift_offline_first_with_odoo.dart';
import 'package:drift_odoo_generators/generators.dart';
import 'package:drift_odoo_generators/odoo_model_serdes_generator.dart';

/// Generates `fromOdoo`/`toOdoo` for offline-first Odoo models,
/// mixing in any `@OfflineFirst` field-level overrides.
class OfflineFirstOdooModelSerdesGenerator extends OdooModelSerdesGenerator {
  OfflineFirstOdooModelSerdesGenerator(
    super.element,
    super.reader, {
    required String super.repositoryName,
  });

  @override
  List<SerdesGenerator> get generators {
    final classElement = element as ClassElement;
    final fields = OdooFields(classElement, config);
    return [
      _OfflineFirstOdooDeserialize(classElement, fields,
          repositoryName: repositoryName!),
      _OfflineFirstOdooSerialize(classElement, fields,
          repositoryName: repositoryName!),
    ];
  }
}

class _OfflineFirstOdooDeserialize extends OdooDeserialize {
  _OfflineFirstOdooDeserialize(
    super.element,
    super.fields, {
    required super.repositoryName,
  });

  @override
  List<String> get instanceFieldsAndMethods {
    final odooModel = (fields as OdooFields).config?.odooModel;
    return [
      if (odooModel != null)
        "@override\nfinal String odooModel = '$odooModel';",
    ];
  }
}

class _OfflineFirstOdooSerialize extends OdooSerialize {
  _OfflineFirstOdooSerialize(
    super.element,
    super.fields, {
    required super.repositoryName,
  });
}

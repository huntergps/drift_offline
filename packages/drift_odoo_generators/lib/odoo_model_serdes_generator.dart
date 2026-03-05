import 'package:analyzer/dart/element/element.dart';
import 'package:brick_core/field_rename.dart';
import 'package:drift_build/generators.dart';
import 'package:drift_odoo_core/drift_odoo_core.dart';

import 'src/odoo_deserialize.dart';
import 'src/odoo_fields.dart';
import 'src/odoo_serialize.dart';

/// Reads the `odooConfig` from `@ConnectOfflineFirstWithOdoo` and produces
/// [OdooDeserialize] and [OdooSerialize] generators for the annotated class.
class OdooModelSerdesGenerator
    extends ProviderSerializableGenerator<OdooSerializable> {
  OdooModelSerdesGenerator(
    super.element,
    super.reader, {
    super.repositoryName,
  }) : super(configKey: 'odooConfig');

  @override
  OdooSerializable get config {
    if (reader.peek(configKey) == null) {
      return const OdooSerializable();
    }

    final fieldRenameIndex =
        withinConfigKey('fieldRename')?.objectValue.getField('index')?.toIntValue();
    final fieldRename =
        fieldRenameIndex != null ? FieldRename.values[fieldRenameIndex] : null;
    final odooModel = withinConfigKey('odooModel')?.stringValue;
    final nullable = withinConfigKey('nullable')?.boolValue;

    return OdooSerializable(
      odooModel: odooModel,
      fieldRename: fieldRename ?? OdooSerializable.defaults.fieldRename,
      nullable: nullable ?? OdooSerializable.defaults.nullable,
    );
  }

  @override
  List<SerdesGenerator<dynamic>> get generators {
    final classElement = element as ClassElement;
    final fields = OdooFields(classElement, config);
    return [
      OdooDeserialize(classElement, fields, repositoryName: repositoryName!),
      OdooSerialize(classElement, fields, repositoryName: repositoryName!),
    ];
  }
}

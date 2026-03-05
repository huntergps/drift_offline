import 'package:analyzer/dart/element/element.dart';
import 'package:brick_build/generators.dart';
import 'package:brick_core/field_rename.dart';
import 'package:drift_odoo_core/drift_odoo_core.dart';

/// Reads the `@Odoo(...)` annotation from a field element.
class OdooAnnotationFinder extends AnnotationFinder<Odoo>
    with AnnotationFinderWithFieldRename<Odoo> {
  final OdooSerializable? config;

  OdooAnnotationFinder([this.config]);

  @override
  Odoo from(FieldElement element) {
    final obj = objectForField(element);

    if (obj == null) {
      return Odoo(
        name: renameField(
          element.name!,
          config?.fieldRename,
          OdooSerializable.defaults.fieldRename,
        ),
      );
    }

    return Odoo(
      defaultValue: obj.getField('defaultValue')?.toStringValue(),
      enumAsString: obj.getField('enumAsString')?.toBoolValue() ?? Odoo.defaults.enumAsString,
      fromGenerator: obj.getField('fromGenerator')?.toStringValue(),
      ignore: obj.getField('ignore')?.toBoolValue() ?? Odoo.defaults.ignore,
      ignoreFrom: obj.getField('ignoreFrom')?.toBoolValue() ?? Odoo.defaults.ignoreFrom,
      ignoreTo: obj.getField('ignoreTo')?.toBoolValue() ?? Odoo.defaults.ignoreTo,
      name: obj.getField('name')?.toStringValue() ??
          renameField(
            element.name!,
            config?.fieldRename,
            OdooSerializable.defaults.fieldRename,
          ),
      toGenerator: obj.getField('toGenerator')?.toStringValue(),
    );
  }
}

/// Collects all `@Odoo` annotations for a class.
class OdooFields extends FieldsForClass<Odoo> {
  @override
  final OdooAnnotationFinder finder;

  final OdooSerializable? config;

  OdooFields(ClassElement element, [this.config])
      : finder = OdooAnnotationFinder(config),
        super(element: element);
}

extension on OdooSerializable {
  FieldRename get fieldRename => this.fieldRename;
}

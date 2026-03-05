import 'package:analyzer/dart/element/element.dart';
import 'package:drift_build/generators.dart';
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
          element.name,
          config?.fieldRename,
          OdooSerializable.defaults.fieldRename,
        ),
      );
    }

    return Odoo(
      defaultValue: obj.peek('defaultValue')?.stringValue,
      enumAsString:
          obj.peek('enumAsString')?.boolValue ?? Odoo.defaults.enumAsString,
      fromGenerator: obj.peek('fromGenerator')?.stringValue,
      ignore: obj.peek('ignore')?.boolValue ?? Odoo.defaults.ignore,
      ignoreFrom:
          obj.peek('ignoreFrom')?.boolValue ?? Odoo.defaults.ignoreFrom,
      ignoreTo: obj.peek('ignoreTo')?.boolValue ?? Odoo.defaults.ignoreTo,
      name: obj.peek('name')?.stringValue ??
          renameField(
            element.name,
            config?.fieldRename,
            OdooSerializable.defaults.fieldRename,
          ),
      toGenerator: obj.peek('toGenerator')?.stringValue,
    );
  }
}

/// Collects all `@Odoo`-annotated (or unannotated) fields for a class.
class OdooFields extends FieldsForClass<Odoo> {
  final OdooSerializable? config;

  OdooFields(ClassElement element, [this.config])
      : super(element: element, finder: OdooAnnotationFinder(config));
}

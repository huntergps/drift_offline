import 'package:analyzer/dart/element/element.dart';
import 'package:brick_build/generators.dart';
import 'package:brick_core/field_rename.dart';
import 'package:drift_rest/drift_rest.dart';
import 'package:source_gen/source_gen.dart';

/// Finds [Rest] annotations on class fields.
class RestAnnotationFinder extends AnnotationFinder<Rest>
    with AnnotationFinderWithFieldRename<Rest> {
  final FieldRename? fieldRename;

  RestAnnotationFinder([this.fieldRename]);

  @override
  Rest from(element) {
    final obj = objectForField(element);
    if (obj == null) return Rest();

    return Rest(
      ignore: obj.getField('ignore')?.toBoolValue() ?? false,
      ignoreFrom: obj.getField('ignoreFrom')?.toBoolValue() ?? false,
      ignoreTo: obj.getField('ignoreTo')?.toBoolValue() ?? false,
      name: obj.getField('name')?.toStringValue(),
      nullable: obj.getField('nullable')?.toBoolValue(),
      defaultValue: obj.getField('defaultValue')?.toStringValue(),
      fromGenerator: obj.getField('fromGenerator')?.toStringValue(),
      toGenerator: obj.getField('toGenerator')?.toStringValue(),
      enumSerializeByName: obj.getField('enumSerializeByName')?.toBoolValue(),
    );
  }
}

/// Collects annotated fields and applies [RestSerializable]-level defaults.
class RestFields extends FieldsForClass<Rest> {
  @override
  final RestAnnotationFinder finder;

  final RestSerializable config;

  RestFields(ClassElement element, this.config)
      : finder = RestAnnotationFinder(config.fieldRename),
        super(element: element);
}

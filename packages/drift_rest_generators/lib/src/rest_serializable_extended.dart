import 'package:analyzer/dart/element/element.dart';
import 'package:drift_build/generators.dart';
import 'package:brick_core/field_rename.dart';
import 'package:drift_rest/drift_rest.dart';
import 'package:source_gen/source_gen.dart';

/// Internal representation of [RestSerializable] that stores the
/// `requestTransformer` as a resolved class name string.
///
/// [ConstantReader] cannot re-interpret function tear-offs at build time,
/// so we resolve the class name from the annotation's AST and store it here.
class RestSerializableExtended extends RestSerializable {
  /// The class name of the [RestRequestTransformer] subclass, or `null` if
  /// `requestTransformer` was not set on the annotation.
  ///
  /// Example: `'UserTransformer'`
  final String? requestName;

  const RestSerializableExtended({
    super.fieldRename,
    super.nullable,
    super.requestTransformer,
    this.requestName,
  });

  /// Build from a [ConstantReader] pointing at a [RestSerializable] annotation.
  factory RestSerializableExtended.fromAnnotation(
    ConstantReader annotation,
    ClassElement element,
  ) {
    final fieldRenameReader = annotation.read('fieldRename');
    final fieldRename = fieldRenameReader.isNull
        ? FieldRename.none
        : FieldRename.values.byName(
            fieldRenameReader.objectValue.getField('_name')!.toStringValue()!,
          );

    final nullable = annotation.read('nullable').literalValue as bool? ?? false;

    // Resolve requestTransformer class name from AST
    String? requestName;
    final requestTransformerReader = annotation.read('requestTransformer');
    if (!requestTransformerReader.isNull) {
      // The annotation stores a function tear-off (ClassName.new).
      // We extract the enclosing type name from the DartObject.
      final dartObj = requestTransformerReader.objectValue;
      final enclosingType = dartObj.type?.element?.name;
      requestName = enclosingType;
    }

    return RestSerializableExtended(
      fieldRename: fieldRename,
      nullable: nullable,
      requestName: requestName,
    );
  }
}

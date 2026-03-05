import 'package:analyzer/dart/element/element.dart';
import 'package:brick_core/field_rename.dart';
import 'package:brick_core/field_serializable.dart';
import 'package:source_gen/source_gen.dart';

/// Finds and reads a field-level annotation of type [T] from a [FieldElement].
///
/// Subclasses implement [from] to convert the raw [ConstantReader] (or null)
/// into a concrete [T] with defaults applied.
abstract class AnnotationFinder<T extends FieldSerializable> {
  const AnnotationFinder();

  /// Return an annotation instance for [element].
  /// Must never return null — apply defaults when no annotation is present.
  T from(FieldElement element);

  /// Returns the raw [ConstantReader] for the first annotation of type [T] on
  /// [element], or `null` if the field is not annotated.
  ConstantReader? objectForField(FieldElement element) {
    final checker = TypeChecker.fromRuntime(T);
    final annotations = checker.annotationsOf(element);
    if (annotations.isEmpty) return null;
    return ConstantReader(annotations.first);
  }
}

/// Mixin that adds field-name conversion support via [FieldRename].
///
/// Apply to an [AnnotationFinder] subclass to get [renameField].
mixin AnnotationFinderWithFieldRename<T extends FieldSerializable>
    on AnnotationFinder<T> {
  /// Convert [name] using [rename] (from the annotation), falling back to
  /// [defaultRename] when [rename] is null.
  String renameField(
    String name,
    FieldRename? rename,
    FieldRename defaultRename,
  ) {
    return _applyRename(name, rename ?? defaultRename);
  }

  static String _applyRename(String name, FieldRename rename) {
    switch (rename) {
      case FieldRename.none:
        return name;
      case FieldRename.snake:
        return _toSnakeCase(name);
      case FieldRename.pascal:
        return name[0].toUpperCase() + name.substring(1);
      case FieldRename.kebab:
        return _toSnakeCase(name).replaceAll('_', '-');
    }
  }

  static String _toSnakeCase(String name) {
    return name.replaceAllMapped(
      RegExp(r'(?<=[a-z0-9])([A-Z])'),
      (m) => '_${m.group(1)!.toLowerCase()}',
    );
  }
}

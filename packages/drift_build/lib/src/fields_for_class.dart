import 'package:analyzer/dart/element/element.dart';
import 'package:brick_core/field_serializable.dart';

import 'annotation_finder.dart';

/// Collects the non-static, non-private, non-synthetic fields directly
/// declared on [element] and maps each to its [TAnnotation] via [finder].
///
/// Only direct fields are included — inherited fields from framework base
/// classes are intentionally excluded so generators don't accidentally
/// serialise internal fields like `odooId`.
class FieldsForClass<TAnnotation extends FieldSerializable> {
  final ClassElement element;
  final AnnotationFinder<TAnnotation> finder;

  const FieldsForClass({required this.element, required this.finder});

  /// All serialisable fields in declaration order, each paired with the
  /// annotation returned by [finder] (defaults applied when unannotated).
  Map<FieldElement, TAnnotation> get stoneFields {
    final result = <FieldElement, TAnnotation>{};
    for (final field in element.fields) {
      if (field.isStatic) continue;
      if (field.name.startsWith('_')) continue;
      if (field.isSynthetic) continue;
      result[field] = finder.from(field);
    }
    return result;
  }
}

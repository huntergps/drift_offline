import 'package:analyzer/dart/element/element.dart';
import 'package:brick_build/generators.dart';
import 'package:drift_odoo_core/drift_odoo_core.dart';

import 'odoo_fields.dart';
import 'odoo_serdes_generator.dart';

/// Generates the `toOdoo(instance)` function for a model.
///
/// The output map is used as kwargs for `create` or `write`.
/// The `id` field is excluded (managed by the repository).
/// Many2one fields are serialized as their [odooId].
/// One2many/Many2many use OdooCommand tuples.
class OdooSerialize extends OdooSerdesGenerator {
  OdooSerialize(
    super.element,
    super.fields, {
    required super.repositoryName,
  });

  @override
  final bool doesDeserialize = false;

  @override
  String? coderForField(
    FieldElement field,
    SharedChecker<OdooModel> checker, {
    required bool wrappedInFuture,
    required Odoo fieldAnnotation,
  }) {
    final fieldName = odooFieldName(field, fieldAnnotation);
    final fieldValue = 'instance.${field.name}';

    if (fieldAnnotation.toGenerator != null) {
      return fieldAnnotation.toGenerator;
    }

    // DateTime → 'YYYY-MM-DD HH:MM:SS' (UTC, Odoo format)
    if (checker.isDateTime) {
      final nullable = checker.isNullable ? '?' : '';
      return '$fieldValue$nullable.toUtc().toIso8601String().replaceFirst(\'T\', \' \').substring(0, 19)';
    }

    // bool → bool (Odoo accepts native bool)
    if (checker.isBool) {
      return fieldValue;
    }

    // Primitive types — pass through
    if (checker.isDartCoreType) {
      return fieldValue;
    }

    // enum
    if (checker.isEnum) {
      final enumType = checker.unFuturedType.toString().replaceAll('?', '');
      if (fieldAnnotation.enumAsString) {
        final nullable = checker.isNullable ? '?' : '';
        return '$fieldValue$nullable.name';
      } else {
        if (checker.isNullable) {
          return '$fieldValue != null ? $enumType.values.indexOf($fieldValue!) : null';
        }
        return '$enumType.values.indexOf($fieldValue)';
      }
    }

    // Map
    if (checker.isMap) {
      return fieldValue;
    }

    // Iterable (One2many / Many2many siblings)
    if (checker.isIterable) {
      if (checker.isArgTypeASibling) {
        final nullable = checker.isNullable ? '?' : '';
        return '$fieldValue$nullable.map((s) => OdooCommand.link(s.odooId!)).toList()';
      }
      return fieldValue;
    }

    // Many2one sibling → send the odooId
    if (checker.isSibling) {
      final nullable = checker.isNullable ? '?' : '';
      return '$fieldValue$nullable.odooId';
    }

    return fieldValue;
  }
}

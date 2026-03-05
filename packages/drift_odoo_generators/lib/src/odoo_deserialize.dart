import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:brick_build/generators.dart';
import 'package:drift_odoo_core/drift_odoo_core.dart';

import 'odoo_fields.dart';
import 'odoo_serdes_generator.dart';

/// Generates the `fromOdoo(Map<String, dynamic> data)` function for a model.
///
/// Key Odoo-specific behaviors:
/// - Odoo returns `false` instead of `null` for empty fields
/// - Many2one fields return `[id, display_name]` list → extract the id
/// - One2many/Many2many fields return `[id1, id2, ...]`
/// - Datetime fields are `'YYYY-MM-DD HH:MM:SS'` strings (UTC)
class OdooDeserialize extends OdooSerdesGenerator {
  OdooDeserialize(
    super.element,
    super.fields, {
    required super.repositoryName,
  });

  @override
  final bool doesDeserialize = true;

  @override
  String get generateSuffix =>
      '..odooId = data[\'id\'] as int?;';

  @override
  String? coderForField(
    FieldElement field,
    SharedChecker<OdooModel> checker, {
    required bool wrappedInFuture,
    required Odoo fieldAnnotation,
  }) {
    final fieldName = odooFieldName(field, fieldAnnotation);
    final raw = "data['$fieldName']";

    if (fieldAnnotation.fromGenerator != null) {
      return fieldAnnotation.fromGenerator;
    }

    // Odoo returns `false` for null fields — normalize to null
    final nullablePrefix = checker.isNullable ? '' : '!';

    // DateTime
    if (checker.isDateTime) {
      if (checker.isNullable) {
        return '$raw == false || $raw == null ? null '
            ': DateTime.parse(($raw as String).replaceFirst(\' \', \'T\'))';
      }
      return 'DateTime.parse(($raw as String).replaceFirst(\' \', \'T\'))';
    }

    // bool
    if (checker.isBool) {
      if (checker.isNullable) {
        return '$raw == false ? null : $raw as bool?';
      }
      return '$raw as bool? ?? false';
    }

    // int, double, num, String — primitive types
    if (checker.isDartCoreType) {
      final type = checker.unFuturedType.toString().replaceAll('?', '');
      if (checker.isNullable) {
        return '$raw == false ? null : $raw as $type?';
      }
      return '$raw as $type';
    }

    // enum
    if (checker.isEnum) {
      final enumType = checker.unFuturedType.toString().replaceAll('?', '');
      if (fieldAnnotation.enumAsString) {
        if (checker.isNullable) {
          return '$raw == false || $raw == null ? null '
              ': $enumType.values.byName($raw as String)';
        }
        return '$enumType.values.byName($raw as String)';
      } else {
        if (checker.isNullable) {
          return '$raw == false || $raw == null ? null '
              ': $enumType.values[$raw as int]';
        }
        return '$enumType.values[$raw as int]';
      }
    }

    // Map
    if (checker.isMap) {
      if (checker.isNullable) {
        return '$raw == false ? null : Map<String, dynamic>.from($raw as Map)';
      }
      return 'Map<String, dynamic>.from($raw as Map)';
    }

    // Iterable (One2many, Many2many → list of int ids)
    if (checker.isIterable) {
      if (checker.isArgTypeASibling) {
        // Association — resolve via repository
        final argType = checker.unFuturedArgType.toString().replaceAll('?', '');
        if (checker.isNullable) {
          return '$raw == false || $raw == null ? null '
              ': await repository?.getAssociation<$argType>('
              'Query.where(\'odooId\', Where.exactList(($raw as List).cast<int>()))) '
              '?? <$argType>[]';
        }
        return 'await repository?.getAssociation<$argType>('
            'Query.where(\'odooId\', Where.exactList(($raw as List).cast<int>()))) '
            '?? <$argType>[]';
      }

      // Iterable<primitive>
      final argType = checker.unFuturedArgType.toString().replaceAll('?', '');
      if (checker.isNullable) {
        return '$raw == false ? null : ($raw as List).cast<$argType>()';
      }
      return '($raw as List).cast<$argType>()';
    }

    // Many2one sibling — returns [id, name] from Odoo
    if (checker.isSibling) {
      final siblingType = checker.unFuturedType.toString().replaceAll('?', '');
      if (checker.isNullable) {
        return '$raw == false || $raw == null ? null '
            ': await repository?.getAssociation<$siblingType>('
            'Query.where(\'odooId\', ($raw as List).first as int, limit1: true))'
            '?.then((r) => r?.isEmpty ?? true ? null : r!.first)';
      }
      return 'await repository!.getAssociation<$siblingType>('
          'Query.where(\'odooId\', ($raw as List).first as int, limit1: true))'
          '.then((r) => r!.first)';
    }

    if (checker.isNullable) {
      return '$raw == false ? null : $raw';
    }
    return raw;
  }
}

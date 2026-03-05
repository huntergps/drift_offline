import 'package:analyzer/dart/element/element.dart';
import 'package:drift_build/generators.dart';
import 'package:drift_odoo_core/drift_odoo_core.dart';

import 'odoo_serdes_generator.dart';

/// Generates the `fromOdoo(Map<String, dynamic> data)` function for a model.
///
/// Key Odoo-specific behaviours:
/// - Odoo returns `false` (not `null`) for empty fields
/// - Many2one fields return `[id, display_name]` — extract first element
/// - One2many / Many2many fields return `[id1, id2, ...]`
/// - DateTime fields are `'YYYY-MM-DD HH:MM:SS'` strings (UTC)
class OdooDeserialize extends OdooSerdesGenerator {
  OdooDeserialize(
    super.element,
    super.fields, {
    required super.repositoryName,
  });

  @override
  final bool doesDeserialize = true;

  @override
  String get generateSuffix => "odooId = data['id'] as int?";

  /// Generates the `odooFields` getter — the list of field names to request.
  @override
  List<String> get instanceFieldsAndMethods {
    final fieldNames = fields.stoneFields.entries
        .where((e) => !e.value.ignore && !e.value.ignoreFrom)
        .map((e) => "'${e.value.name ?? e.key.name}'")
        .toList();
    return [
      "@override\n"
          "List<String> get odooFields => const ['id', 'write_date', ${fieldNames.join(', ')}];",
    ];
  }

  @override
  String? coderForField(
    FieldElement field,
    SharedChecker<dynamic> checker, {
    required bool wrappedInFuture,
    required Odoo fieldAnnotation,
  }) {
    final fieldName = odooFieldName(field, fieldAnnotation);
    final raw = "data['$fieldName']";

    if (fieldAnnotation.fromGenerator != null) {
      return fieldAnnotation.fromGenerator;
    }

    // DateTime
    if (checker.isDateTime) {
      if (checker.isNullable) {
        return "$raw == false || $raw == null ? null "
            ": DateTime.parse(($raw as String).replaceFirst(' ', 'T'))";
      }
      return "DateTime.parse(($raw as String).replaceFirst(' ', 'T'))";
    }

    // bool
    if (checker.isBool) {
      if (checker.isNullable) {
        return "$raw == null ? null : $raw as bool? ?? false";
      }
      return "$raw as bool? ?? false";
    }

    // int, double, num, String
    if (checker.isDartCoreType) {
      final type = checker.unFuturedType.toString().replaceAll('?', '');
      if (checker.isNullable) {
        return "$raw == false ? null : $raw as $type?";
      }
      return "$raw as $type";
    }

    // enum
    if (checker.isEnum) {
      final enumType = checker.unFuturedType.toString().replaceAll('?', '');
      if (fieldAnnotation.enumAsString) {
        if (checker.isNullable) {
          return "$raw == false || $raw == null ? null "
              ": $enumType.values.byName($raw as String)";
        }
        return "$enumType.values.byName($raw as String)";
      } else {
        if (checker.isNullable) {
          return "$raw == false || $raw == null ? null "
              ": $enumType.values[$raw as int]";
        }
        return "$enumType.values[$raw as int]";
      }
    }

    // Map
    if (checker.isMap) {
      if (checker.isNullable) {
        return "$raw == false ? null : Map<String, dynamic>.from($raw as Map)";
      }
      return "Map<String, dynamic>.from($raw as Map)";
    }

    // Iterable (One2many / Many2many)
    if (checker.isIterable) {
      if (checker.isArgTypeASibling) {
        final argType = checker.unFuturedArgType.toString().replaceAll('?', '');
        if (checker.isNullable) {
          return "$raw == false || $raw == null ? null "
              ": await repository?.getAssociation<$argType>("
              "Query.where('odooId', Where.exactList(($raw as List).cast<int>()))) "
              "?? <$argType>[]";
        }
        final repoAccess = repositoryNonNullAccess;
        return "await $repoAccess.getAssociation<$argType>("
            "Query.where('odooId', Where.exactList(($raw as List).cast<int>())))"
            ".then((r) => r ?? <$argType>[])";
      }
      final argType = checker.unFuturedArgType.toString().replaceAll('?', '');
      if (checker.isNullable) {
        return "$raw == false ? null : ($raw as List).cast<$argType>()";
      }
      return "($raw as List).cast<$argType>()";
    }

    // Many2one sibling — Odoo returns [id, display_name]
    if (checker.isSibling) {
      final siblingType = checker.unFuturedType.toString().replaceAll('?', '');
      if (checker.isNullable) {
        return "$raw == false || $raw == null ? null "
            ": await repository?.getAssociation<$siblingType>("
            "Query.where('odooId', ($raw as List).first as int, limit1: true))"
            "?.then((r) => r?.isEmpty ?? true ? null : r!.first)";
      }
      final repoAccess = repositoryNonNullAccess;
      return "await $repoAccess.getAssociation<$siblingType>("
          "Query.where('odooId', ($raw as List).first as int, limit1: true))"
          ".then((r) => r!.first)";
    }

    if (checker.isNullable) {
      return "$raw == false ? null : $raw";
    }
    return raw;
  }
}

import 'package:analyzer/dart/element/element.dart';
import 'package:drift_build/generators.dart';
import 'package:drift_odoo_core/drift_odoo_core.dart';
import 'package:drift_offline_first/drift_offline_first.dart';
import 'package:source_gen/source_gen.dart';

import 'odoo_serdes_generator.dart';

const _offlineFirstChecker = TypeChecker.fromRuntime(OfflineFirst);

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

    // Iterable (One2many / Many2many) — Odoo returns [id1, id2, ...]
    if (checker.isIterable) {
      if (checker.isArgTypeASibling) {
        // Check for @OfflineFirst(where:) override first.
        final customWhere = _offlineFirstWhereFor(field);
        if (customWhere != null) {
          return _generateIterableWhereAssociation(checker, customWhere);
        }

        final argType = checker.unFuturedArgType.toString().replaceAll('?', '');
        if (checker.isNullable) {
          return "$raw == false || $raw == null ? null "
              ": await repository?.getAssociation<$argType>("
              "Query(where: [Where('odooId').isIn(($raw as List).cast<dynamic>())])) "
              "?? <$argType>[]";
        }
        final repoAccess = repositoryNonNullAccess;
        return "await $repoAccess.getAssociation<$argType>("
            "Query(where: [Where('odooId').isIn(($raw as List).cast<dynamic>())]))"
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
      // Check for @OfflineFirst(where:) override first.
      final customWhere = _offlineFirstWhereFor(field);
      if (customWhere != null) {
        return _generateSiblingWhereAssociation(checker, customWhere);
      }

      final siblingType = checker.unFuturedType.toString().replaceAll('?', '');
      if (checker.isNullable) {
        return "$raw == false || $raw == null ? null "
            ": await repository?.getAssociation<$siblingType>("
            "Query(where: [Where.exact('odooId', ($raw as List).first as int)], "
            "limitBy: LimitBy(1)))"
            "?.then((r) => r?.isEmpty ?? true ? null : r!.first)";
      }
      final repoAccess = repositoryNonNullAccess;
      return "await $repoAccess.getAssociation<$siblingType>("
          "Query(where: [Where.exact('odooId', ($raw as List).first as int)], "
          "limitBy: LimitBy(1)))"
          ".then((r) => r!.first)";
    }

    if (checker.isNullable) {
      return "$raw == false ? null : $raw";
    }
    return raw;
  }

  // ---------------------------------------------------------------------------
  // @OfflineFirst(where:) helpers
  // ---------------------------------------------------------------------------

  /// Returns the `where` map from `@OfflineFirst` on [field] if the annotation
  /// is present, has a non-null `where`, and `applyToRemoteDeserialization`
  /// is `true`. Returns `null` otherwise (use default Odoo lookup).
  Map<String, String>? _offlineFirstWhereFor(FieldElement field) {
    final annotation = _offlineFirstChecker.firstAnnotationOfExact(field);
    if (annotation == null) return null;

    final applyToRemote =
        annotation.getField('applyToRemoteDeserialization')?.toBoolValue() ?? true;
    if (!applyToRemote) return null;

    final whereValue = annotation.getField('where')?.toMapValue();
    if (whereValue == null || whereValue.isEmpty) return null;

    return whereValue.map(
      (k, v) => MapEntry(k!.toStringValue()!, v!.toStringValue()!),
    );
  }

  /// Generates a `getAssociation` call for a Many2one sibling field using a
  /// custom `where` map from `@OfflineFirst(where: {...})`.
  String _generateSiblingWhereAssociation(
    SharedChecker<dynamic> checker,
    Map<String, String> where,
  ) {
    final clauses = where.entries.map((e) => "Where.exact('${e.key}', ${e.value})").join(', ');
    final siblingType = checker.unFuturedType.toString().replaceAll('?', '');
    if (checker.isNullable) {
      return "await repository?.getAssociation<$siblingType>("
          "Query(where: [$clauses], limitBy: LimitBy(1)))"
          "?.then((r) => r?.isEmpty ?? true ? null : r!.first)";
    }
    final repoAccess = repositoryNonNullAccess;
    return "await $repoAccess.getAssociation<$siblingType>("
        "Query(where: [$clauses], limitBy: LimitBy(1)))"
        ".then((r) => r!.first)";
  }

  /// Generates a `getAssociation` call for an iterable sibling field using a
  /// custom `where` map from `@OfflineFirst(where: {...})`.
  String _generateIterableWhereAssociation(
    SharedChecker<dynamic> checker,
    Map<String, String> where,
  ) {
    final clauses = where.entries.map((e) => "Where.exact('${e.key}', ${e.value})").join(', ');
    final argType = checker.unFuturedArgType.toString().replaceAll('?', '');
    if (checker.isNullable) {
      return "await repository?.getAssociation<$argType>("
          "Query(where: [$clauses])) ?? <$argType>[]";
    }
    final repoAccess = repositoryNonNullAccess;
    return "await $repoAccess.getAssociation<$argType>("
        "Query(where: [$clauses]))"
        ".then((r) => r ?? <$argType>[])";
  }
}

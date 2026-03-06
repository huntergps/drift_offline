import 'package:analyzer/dart/element/element.dart';
import 'package:drift_build/generators.dart';
import 'package:drift_offline_first/drift_offline_first.dart';
import 'package:drift_odoo_generators/generators.dart';
import 'package:drift_odoo_generators/odoo_model_serdes_generator.dart';
import 'package:source_gen/source_gen.dart';

/// Generates `fromOdoo`/`toOdoo` for offline-first Odoo models.
class OfflineFirstOdooModelSerdesGenerator extends OdooModelSerdesGenerator {
  OfflineFirstOdooModelSerdesGenerator(
    super.element,
    super.reader, {
    required String super.repositoryName,
  });

  @override
  List<SerdesGenerator<dynamic>> get generators {
    final classElement = element as ClassElement;
    final fields = OdooFields(classElement, config);
    return [
      _OfflineFirstOdooDeserialize(classElement, fields,
          repositoryName: repositoryName!),
      _OfflineFirstOdooSerialize(classElement, fields,
          repositoryName: repositoryName!),
    ];
  }
}

// TypeChecker for the @OfflineFirst annotation (runtime type).
final _offlineFirstChecker = TypeChecker.fromRuntime(OfflineFirst);

class _OfflineFirstOdooDeserialize extends OdooDeserialize {
  _OfflineFirstOdooDeserialize(
    super.element,
    super.fields, {
    required super.repositoryName,
  });

  @override
  List<String> get instanceFieldsAndMethods {
    final odooModel = (fields as OdooFields).config?.odooModel;
    return [
      // odooFields from base — always include it
      ...super.instanceFieldsAndMethods,
      if (odooModel != null)
        "@override\nfinal String odooModel = '$odooModel';",
    ];
  }

  /// Read `@OfflineFirst` from [field] metadata.
  ///
  /// Returns the `where` map when the annotation is present and
  /// `applyToRemoteDeserialization` is `true` (the default).
  /// Returns `null` when the annotation is absent, has no `where`, or
  /// explicitly opts out of remote deserialization.
  Map<String, String>? _offlineFirstWhere(FieldElement field) {
    final annotation = _offlineFirstChecker.firstAnnotationOfExact(field);
    if (annotation == null) return null;
    final reader = ConstantReader(annotation);

    // Respect applyToRemoteDeserialization: false → skip remote override.
    final applyToRemote = reader.peek('applyToRemoteDeserialization')?.boolValue ?? true;
    if (!applyToRemote) return null;

    final whereValue = reader.peek('where');
    if (whereValue == null || whereValue.isNull) return null;
    return whereValue.mapValue.map(
      (k, v) => MapEntry(
        ConstantReader(k).stringValue,
        ConstantReader(v).stringValue,
      ),
    );
  }

  @override
  String? coderForField(
    FieldElement field,
    SharedChecker<dynamic> checker, {
    required bool wrappedInFuture,
    required fieldAnnotation,
  }) {
    final where = _offlineFirstWhere(field);
    if (where == null || where.isEmpty) {
      return super.coderForField(
        field,
        checker,
        wrappedInFuture: wrappedInFuture,
        fieldAnnotation: fieldAnnotation,
      );
    }

    final nullGuardExpr = where.values.first;

    // ── Iterable<Sibling> — e.g. List<Partner> ───────────────────────────────
    // @OfflineFirst(where: {'odooId': "data['partner_ids']"})
    // Odoo returns a flat list of IDs; use isIn() for the query.
    if (checker.isIterable && checker.isArgTypeASibling) {
      final argType = checker.unFuturedArgType.toString().replaceAll('?', '');
      final whereClauses = where.entries
          .map((e) => "Where('${e.key}').isIn((${e.value} as List).cast<dynamic>())")
          .join(', ');
      final queryExpr = 'Query(where: [$whereClauses])';

      if (checker.isNullable) {
        return "$nullGuardExpr == false || $nullGuardExpr == null ? null "
            ": await repository?.getAssociation<$argType>($queryExpr)";
      }
      final repoAccess = repositoryNonNullAccess;
      return "await $repoAccess.getAssociation<$argType>($queryExpr) ?? <$argType>[]";
    }

    // ── Single Sibling — e.g. Partner? ───────────────────────────────────────
    // @OfflineFirst(where: {'odooId': "data['partner_id']"})
    final siblingType = checker.unFuturedType.toString().replaceAll('?', '');
    final whereClauses = where.entries
        .map((e) => "Where('${e.key}').isExactly(${e.value})")
        .join(', ');
    final queryExpr = 'Query(where: [$whereClauses])';

    if (checker.isNullable) {
      return "$nullGuardExpr == false || $nullGuardExpr == null ? null "
          ": await repository?.getAssociation<$siblingType>($queryExpr)"
          ".then((r) => r?.isEmpty ?? true ? null : r?.first)";
    }
    final repoAccess = repositoryNonNullAccess;
    return "await $repoAccess.getAssociation<$siblingType>($queryExpr)"
        ".then((r) => r!.first)";
  }
}

class _OfflineFirstOdooSerialize extends OdooSerialize {
  _OfflineFirstOdooSerialize(
    super.element,
    super.fields, {
    required super.repositoryName,
  });
}

import 'package:analyzer/dart/element/element.dart';
import 'package:brick_core/field_serializable.dart';
import 'package:meta/meta.dart';
import 'package:source_gen/source_gen.dart';

import 'fields_for_class.dart';
import 'shared_checker.dart';

/// Base class for generating a single serialisation or deserialisation method
/// (e.g. `fromOdoo` or `toOdoo`) for an annotated model class.
///
/// Subclasses implement [coderForField] to return a Dart expression for each
/// field. The base [generate] assembles those expressions into a complete
/// `async` method body.
abstract class SerdesGenerator<TAnnotation extends FieldSerializable> {
  final ClassElement element;
  final FieldsForClass<TAnnotation> fields;

  /// Tracks whether `repository!` has already been emitted in the current
  /// `fromX` method body. Reset automatically at the start of each
  /// [_generateDeserialize] call.
  ///
  /// Subclass [coderForField] implementations must use [repositoryNonNullAccess]
  /// instead of hardcoding `repository!`, so that only the first association
  /// lookup emits a force-cast.
  @protected
  bool repositoryHasBeenForceCast = false;

  /// Returns the correct Dart expression for a non-nullable `repository` access.
  ///
  /// - First call within a `fromX` method → `'repository!'`
  /// - Subsequent calls → `'repository'` (cast already established)
  ///
  /// Call this exactly once per non-nullable association expression and
  /// capture the result before interpolating it into the string.
  @protected
  String get repositoryNonNullAccess {
    if (repositoryHasBeenForceCast) return 'repository';
    repositoryHasBeenForceCast = true;
    return 'repository!';
  }

  SerdesGenerator(this.element, this.fields);

  // ── Identity ──────────────────────────────────────────────────────────────

  /// Short name of the remote provider (e.g. `'Odoo'`, `'Rest'`).
  /// Used to build method names: `fromOdoo` / `toOdoo`.
  String get providerName;

  /// Name prefix for the repository type (e.g. `'OfflineFirstWithOdoo'`).
  /// The generated method signature uses `${repositoryName}Repository`.
  String get repositoryName;

  /// Concrete Dart type name for the provider parameter
  /// (e.g. `'OdooOfflineQueueClient'`).
  String get providerClassName;

  // ── Direction ─────────────────────────────────────────────────────────────

  /// `true` → generate `fromX`; `false` → generate `toX`.
  bool get doesDeserialize;

  /// Input parameter type for deserialisation (e.g. `'Map<String, dynamic>'`).
  String get deserializeInputType;

  /// Return type for serialisation (e.g. `'Map<String, dynamic>'`).
  String get serializeOutputType;

  // ── Optional hooks ────────────────────────────────────────────────────────

  /// [TypeChecker] that identifies "sibling" types (model subclasses).
  TypeChecker get siblingsChecker;

  /// Dart statement appended after the constructor in `fromX`, e.g.
  /// `'..odooId = data[\'id\'] as int?;'`.
  String? get generateSuffix => null;

  /// Extra field/method declarations to include in the adapter class body.
  /// Called once per generator; results from all generators are merged.
  List<String> get instanceFieldsAndMethods => const [];

  // ── Per-field code ────────────────────────────────────────────────────────

  /// Return the Dart expression to assign to a model constructor parameter
  /// (deserialization) or a map entry value (serialization).
  ///
  /// Return `null` to skip the field entirely.
  String? coderForField(
    FieldElement field,
    SharedChecker<dynamic> checker, {
    required bool wrappedInFuture,
    required TAnnotation fieldAnnotation,
  });

  // ── Code assembly ─────────────────────────────────────────────────────────

  /// Generate the complete method (`fromX` or `toX`) as a Dart string.
  String generate() {
    return doesDeserialize ? _generateDeserialize() : _generateSerialize();
  }

  String get _className => element.name;

  String _generateDeserialize() {
    repositoryHasBeenForceCast = false; // reset per-method
    final fieldCoders = <String>[];
    var hasAsync = false;

    for (final entry in fields.stoneFields.entries) {
      final field = entry.key;
      final annotation = entry.value;
      if (annotation.ignore || annotation.ignoreFrom) continue;

      final checker = SharedChecker<dynamic>(field.type, siblingsChecker);
      final wrappedInFuture = field.type.isDartAsyncFuture;
      final coder = coderForField(
        field,
        checker,
        wrappedInFuture: wrappedInFuture,
        fieldAnnotation: annotation,
      );
      if (coder == null) continue;
      if (coder.contains('await ')) hasAsync = true;
      fieldCoders.add('${field.name}: $coder');
    }

    final suffix =
        generateSuffix != null ? '\n      ..${generateSuffix!}' : '';
    final asyncKw = hasAsync ? 'async ' : '';

    return '''
@override
Future<$_className> from$providerName(
  $deserializeInputType data, {
  required $providerClassName provider,
  ${repositoryName}Repository? repository,
}) $asyncKw{
  return $_className(
    ${fieldCoders.join(',\n    ')},
  )$suffix;
}''';
  }

  String _generateSerialize() {
    final fieldCoders = <String>[];
    var hasAsync = false;

    for (final entry in fields.stoneFields.entries) {
      final field = entry.key;
      final annotation = entry.value;
      if (annotation.ignore || annotation.ignoreTo) continue;

      final checker = SharedChecker<dynamic>(field.type, siblingsChecker);
      final wrappedInFuture = field.type.isDartAsyncFuture;
      final coder = coderForField(
        field,
        checker,
        wrappedInFuture: wrappedInFuture,
        fieldAnnotation: annotation,
      );
      if (coder == null) continue;
      if (coder.contains('await ')) hasAsync = true;
      final key = annotation.name ?? field.name;
      fieldCoders.add("'$key': $coder");
    }

    final asyncKw = hasAsync ? 'async ' : '';

    return '''
@override
Future<$serializeOutputType> to$providerName(
  $_className instance, {
  required $providerClassName provider,
  ${repositoryName}Repository? repository,
}) $asyncKw{
  return {
    ${fieldCoders.join(',\n    ')},
  };
}''';
  }
}

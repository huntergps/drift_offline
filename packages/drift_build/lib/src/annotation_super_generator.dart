import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';
import 'package:source_gen/source_gen.dart';

import 'serdes_generator.dart';

/// A [GeneratorForAnnotation] that discovers classes annotated with
/// [TAnnotation] and delegates code generation to a list of [SerdesGenerator]s.
///
/// Subclasses implement [buildGenerators] to return the generators for each
/// annotated element. The output is a complete adapter class placed into a
/// part file (`.g.dart`).
///
/// ```dart
/// class OfflineFirstWithOdooGenerator
///     extends AnnotationSuperGenerator<ConnectOfflineFirstWithOdoo> {
///   @override
///   List<SerdesGenerator<dynamic>> buildGenerators(
///     Element element, ConstantReader annotation) { ... }
/// }
/// ```
abstract class AnnotationSuperGenerator<TAnnotation>
    extends GeneratorForAnnotation<TAnnotation> {
  /// The adapter superclass name prefix.
  /// E.g. `'OfflineFirstWithOdoo'` → extends `OfflineFirstWithOdooAdapter<T>`.
  String get superAdapterName;

  const AnnotationSuperGenerator();

  /// Return the [SerdesGenerator]s to run for [element].
  List<SerdesGenerator<dynamic>> buildGenerators(
    Element element,
    ConstantReader annotation,
  );

  @override
  Future<String> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '@$TAnnotation can only be applied to classes.',
        element: element,
      );
    }

    final generators = buildGenerators(element, annotation);
    if (generators.isEmpty) return '';

    final className = element.name;
    final adapterClassName = '${className}OdooAdapter';

    // Collect instance fields/methods from every generator (deduplicated).
    final allInstanceMembers = <String>{};
    for (final gen in generators) {
      allInstanceMembers.addAll(gen.instanceFieldsAndMethods);
    }

    // Generate fromX / toX method bodies.
    final methodBodies = generators.map((g) => g.generate()).join('\n\n  ');

    final raw = '''
// ignore_for_file: type=lint

class $adapterClassName
    extends ${superAdapterName}Adapter<$className> {
  ${allInstanceMembers.join('\n\n  ')}

  const $adapterClassName();

  $methodBodies
}
''';

    try {
      return DartFormatter().format(raw);
    } catch (_) {
      // Return unformatted if the formatter fails (e.g. syntax error in generated code).
      return raw;
    }
  }
}

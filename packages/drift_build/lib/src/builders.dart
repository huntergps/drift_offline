import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';
import 'package:glob/glob.dart';
import 'package:source_gen/source_gen.dart';

import 'annotation_super_generator.dart';
import 'model_dictionary_generator.dart';

// ── AggregateBuilder ─────────────────────────────────────────────────────────

/// Scans `lib/` for all `.model.dart` files and writes a single aggregate
/// dart file that imports all of them. The model dictionary builder uses this
/// aggregate as input so it can discover every annotated class in one pass.
///
/// Build output: `$lib$ → models_and_migrations.odoo_aggregate.dart`
class AggregateBuilder implements Builder {
  final List<String> requiredImports;

  const AggregateBuilder({this.requiredImports = const []});

  @override
  Map<String, List<String>> get buildExtensions => const {
        r'$lib$': ['models_and_migrations.odoo_aggregate.dart'],
      };

  @override
  Future<void> build(BuildStep buildStep) async {
    final modelFiles = <String>[];

    await for (final input in buildStep.findAssets(
      Glob('lib/**/*.model.dart'),
    )) {
      modelFiles.add(input.uri.toString());
    }

    if (modelFiles.isEmpty) return;

    final imports = [
      ...requiredImports,
      ...modelFiles.map((u) => "import '$u';"),
    ].join('\n');

    final content = '''
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_import

$imports
''';

    final output = AssetId(
      buildStep.inputId.package,
      'lib/models_and_migrations.odoo_aggregate.dart',
    );
    await buildStep.writeAsString(output, content);
  }
}

// ── AdapterBuilder ────────────────────────────────────────────────────────────

/// Wraps an [AnnotationSuperGenerator] in a [LibraryBuilder] that writes
/// adapter part files (`*.adapter_build_odoo.dart`) for each `.model.dart`.
///
/// The generated files are intermediate — source_gen's `combining_builder`
/// merges them into the final `.g.dart` part files.
Builder adapterBuilder(
  AnnotationSuperGenerator<dynamic> generator, {
  String generatedExtension = '.adapter_build_odoo.dart',
}) {
  return LibraryBuilder(
    generator,
    generatedExtension: generatedExtension,
    formatOutput: (s) {
      try {
        return DartFormatter().format(s);
      } catch (_) {
        return s;
      }
    },
  );
}

// ── ModelDictionaryBuilder ────────────────────────────────────────────────────

/// Reads the aggregate file produced by [AggregateBuilder], discovers all
/// annotated classes within it, and writes the provider model dictionary.
///
/// Build input:  `*.odoo_aggregate.dart`
/// Build output: `*.model_dictionary_build_odoo.dart`
class ModelDictionaryBuilder<TAnnotation> implements Builder {
  final ModelDictionaryGenerator generator;
  final TypeChecker _annotationChecker;

  /// Import strings to strip from the generated output (deduplication).
  final List<String> expectedImportRemovals;

  ModelDictionaryBuilder(
    this.generator, {
    List<String>? expectedImportRemovals,
  })  : _annotationChecker = TypeChecker.fromRuntime(TAnnotation),
        expectedImportRemovals = expectedImportRemovals ?? const [];

  @override
  Map<String, List<String>> get buildExtensions => const {
        '.odoo_aggregate.dart': [
          '.odoo_aggregate.model_dictionary_build_odoo.dart',
        ],
      };

  @override
  Future<void> build(BuildStep buildStep) async {
    final library = await buildStep.inputLibrary;
    final classNamesToFileNames = <String, String>{};

    for (final element in library.topLevelElements) {
      if (element is! ClassElement) continue;
      if (!_annotationChecker.hasAnnotationOf(element)) continue;

      // Resolve the source file relative to lib/.
      final sourceUri = element.source.uri;
      final path = sourceUri.path.replaceFirst(
        RegExp(r'^.*?/lib/'),
        'lib/',
      );
      classNamesToFileNames[element.name] = path;
    }

    if (classNamesToFileNames.isEmpty) return;

    var content = generator.generate(classNamesToFileNames);
    for (final removal in expectedImportRemovals) {
      content = content.replaceAll('$removal\n', '');
    }

    try {
      content = DartFormatter().format(content);
    } catch (_) {
      // Leave unformatted on syntax error.
    }

    await buildStep.writeAsString(buildStep.allowedOutputs.first, content);
  }
}

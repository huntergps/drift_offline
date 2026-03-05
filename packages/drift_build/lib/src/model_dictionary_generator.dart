/// Base class for generating the model dictionary file (`*.g.dart`) that
/// aggregates all adapter mappings for a provider.
///
/// Subclasses override [requiredImports] and [generate] to emit provider-
/// specific code. [adaptersFromFiles], [dictionaryFromFiles], and
/// [modelsFromFiles] provide the raw building blocks.
abstract class ModelDictionaryGenerator {
  static const headerComment =
      '// GENERATED CODE - DO NOT MODIFY BY HAND\n// ignore_for_file: type=lint';

  const ModelDictionaryGenerator();

  /// Provider-specific import block to prepend to the generated file.
  String get requiredImports;

  /// Generate the full dictionary file from a map of
  /// `ClassName → sourceFilePath` (relative to `lib/`).
  String generate(Map<String, String> classNamesToFileNames);

  // ── Helpers for subclasses ─────────────────────────────────────────────────

  /// Import statement for each adapter part file.
  ///
  /// Converts `lib/brick/models/my_model.model.dart`
  /// → `import 'brick/models/my_model.model.g.dart';`
  String adaptersFromFiles(Map<String, String> classNamesToFileNames) {
    return classNamesToFileNames.values
        .map((path) {
          final withoutLib = path.replaceFirst(RegExp(r'^lib/'), '');
          final adapterPath =
              withoutLib.replaceFirst(RegExp(r'\.dart$'), '.g.dart');
          return "import '$adapterPath';";
        })
        .toSet() // deduplicate
        .join('\n');
  }

  /// Dictionary map entries: `ClassName: ClassNameOdooAdapter(),`
  String dictionaryFromFiles(Map<String, String> classNamesToFileNames) {
    return classNamesToFileNames.keys
        .map((name) => '$name: ${name}OdooAdapter(),')
        .join('\n  ');
  }

  /// Export statements re-exporting the model classes.
  ///
  /// Converts `lib/brick/models/my_model.model.dart`
  /// → `export 'brick/models/my_model.model.dart' show MyModel;`
  String modelsFromFiles(Map<String, String> classNamesToFileNames) {
    return classNamesToFileNames.entries
        .map((e) {
          final withoutLib = e.value.replaceFirst(RegExp(r'^lib/'), '');
          return "export '$withoutLib' show ${e.key};";
        })
        .toSet()
        .join('\n');
  }
}

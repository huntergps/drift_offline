import 'package:drift_build/generators.dart';
import 'package:drift_offline_first_with_rest/drift_offline_first_with_rest.dart';
import 'package:drift_rest/drift_rest.dart';
import 'package:source_gen/source_gen.dart';

/// Generates the `restMappings` and `restModelDictionary` constants in
/// `lib/app/rest.g.dart`.
///
/// The output looks like:
/// ```dart
/// final Map<Type, RestAdapter<RestModel>> restMappings = {
///   User: UserAdapter(),
///   Order: OrderAdapter(),
/// };
///
/// final restModelDictionary = RestModelDictionary(restMappings);
/// ```
class OfflineFirstRestModelDictionaryGenerator
    extends BaseModelDictionaryGenerator {
  const OfflineFirstRestModelDictionaryGenerator()
      : super('Rest', annotation: 'ConnectOfflineFirstWithRest');

  @override
  String get modelDictionaryDeclaration => '''
final restModelDictionary = RestModelDictionary(restMappings);
''';

  @override
  String mappingsDeclaration(Map<String, String> modelToAdapter) {
    final entries = modelToAdapter.entries
        .map((e) => '  ${e.key}: const ${e.value}(),')
        .join('\n');
    return '''
final Map<Type, RestAdapter<RestModel>> restMappings = {
$entries
};
''';
  }
}

Builder restModelDictionaryBuilder(BuilderOptions options) =>
    LibraryBuilder(
      OfflineFirstRestModelDictionaryGenerator(),
      generatedExtension: '.rest.g.dart',
    );

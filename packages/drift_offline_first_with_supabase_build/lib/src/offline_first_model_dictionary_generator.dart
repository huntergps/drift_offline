import 'package:drift_build/generators.dart';

/// Generates the `supabaseModelDictionary` and mappings file (`supabase.g.dart`).
class OfflineFirstModelDictionaryGenerator extends ModelDictionaryGenerator {
  @override
  String get requiredImports => """
// ignore: unused_import
import 'dart:convert';
import 'package:drift_supabase/drift_supabase.dart'
    show SupabaseModel, SupabaseAdapter, SupabaseModelDictionary, SupabaseOfflineQueueClient;
import 'package:drift_offline_first_with_supabase/drift_offline_first_with_supabase.dart'
    show OfflineFirstWithSupabaseRepository, OfflineFirstWithSupabaseAdapter;""";

  const OfflineFirstModelDictionaryGenerator();

  @override
  String generate(Map<String, String> classNamesToFileNames) {
    final adapters = adaptersFromFiles(classNamesToFileNames);
    final dictionary = dictionaryFromFiles(classNamesToFileNames);
    final models = modelsFromFiles(classNamesToFileNames);

    return '''
${ModelDictionaryGenerator.HEADER}
$requiredImports

$models

$adapters

/// Supabase mappings — use when initialising [SupabaseModelDictionary] /
/// [OfflineFirstWithSupabaseRepository].
final Map<Type, SupabaseAdapter<SupabaseModel>> supabaseMappings = {
  $dictionary
};
final supabaseModelDictionary = SupabaseModelDictionary(supabaseMappings);
''';
  }
}

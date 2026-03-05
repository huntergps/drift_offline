import 'package:analyzer/dart/element/element.dart';
import 'package:brick_build/generators.dart';
import 'package:drift_offline_first_with_supabase/drift_offline_first_with_supabase.dart';
import 'package:drift_supabase/drift_supabase.dart';
import 'package:drift_supabase_generators/generators.dart';
import 'package:drift_supabase_generators/supabase_model_serdes_generator.dart';

/// Generates `fromSupabase`/`toSupabase` for offline-first Supabase models.
class OfflineFirstSupabaseModelSerdesGenerator extends SupabaseModelSerdesGenerator {
  OfflineFirstSupabaseModelSerdesGenerator(
    super.element,
    super.reader, {
    required String super.repositoryName,
  });

  @override
  List<SerdesGenerator> get generators {
    final classElement = element as ClassElement;
    final fields = SupabaseFields(classElement, config);
    return [
      _OfflineFirstSupabaseDeserialize(classElement, fields,
          repositoryName: repositoryName!),
      _OfflineFirstSupabaseSerialize(classElement, fields,
          repositoryName: repositoryName!),
    ];
  }
}

class _OfflineFirstSupabaseDeserialize extends SupabaseDeserialize {
  _OfflineFirstSupabaseDeserialize(
    super.element,
    super.fields, {
    required super.repositoryName,
  });

  @override
  List<String> get instanceFieldsAndMethods {
    final tableName =
        (fields as SupabaseFields).config?.tableName;
    return [
      if (tableName != null)
        "@override\nfinal String supabaseTableName = '$tableName';",
    ];
  }
}

class _OfflineFirstSupabaseSerialize extends SupabaseSerialize {
  _OfflineFirstSupabaseSerialize(
    super.element,
    super.fields, {
    required super.repositoryName,
  });
}

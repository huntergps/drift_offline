import 'package:analyzer/dart/element/element.dart';
import 'package:brick_json_generators/json_deserialize.dart';
import 'package:drift_supabase/drift_supabase.dart';

import 'supabase_fields.dart';
import 'supabase_serdes_generator.dart';

/// Generates the `fromSupabase` factory method for a [SupabaseModel].
class SupabaseDeserialize extends SupabaseSerdesGenerator
    with JsonDeserialize<SupabaseModel, Supabase> {
  SupabaseDeserialize(
    super.element,
    super.fields, {
    required super.repositoryName,
  });

  @override
  List<String> get instanceFieldsAndMethods {
    final tableName = (fields as SupabaseFields).config?.tableName;
    return [
      if (tableName != null)
        "@override\nfinal String supabaseTableName = '$tableName';",
    ];
  }
}

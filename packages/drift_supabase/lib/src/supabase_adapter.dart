import 'package:drift_supabase/src/runtime_supabase_column_definition.dart';
import 'package:drift_supabase/src/supabase_model.dart';

/// Generated adapter interface for a [SupabaseModel].
///
/// Each model annotated with `@ConnectOfflineFirstWithSupabase` gets a generated
/// concrete subclass with `fromSupabase` / `toSupabase` implementations and
/// column metadata.
abstract class SupabaseAdapter<TModel extends SupabaseModel> {
  /// The Supabase table name (e.g. `'users'`).
  String get supabaseTableName;

  /// Maps Dart field names to their Supabase column definitions.
  Map<String, RuntimeSupabaseColumnDefinition> get fieldsToSupabaseColumns;

  /// Field names whose values identify rows uniquely (used for upsert/delete).
  Set<String> get uniqueFields;

  /// Passed to Supabase `upsert(defaultToNull:)`.
  bool get defaultToNull;

  /// Passed to Supabase `upsert(ignoreDuplicates:)`.
  bool get ignoreDuplicates;

  /// Passed to Supabase `upsert(onConflict:)`. Null means not specified.
  String? get onConflict => null;

  const SupabaseAdapter();

  /// Deserialize a Supabase JSON record into [TModel].
  Future<TModel> fromSupabase(
    Map<String, dynamic> data, {
    required covariant Object provider,
    covariant Object? repository,
  });

  /// Serialize [TModel] into a Supabase-compatible JSON map.
  Future<Map<String, dynamic>> toSupabase(
    TModel instance, {
    required covariant Object provider,
    covariant Object? repository,
  });
}

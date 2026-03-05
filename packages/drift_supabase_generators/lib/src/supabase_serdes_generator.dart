import 'package:brick_json_generators/json_serdes_generator.dart';
import 'package:drift_supabase/drift_supabase.dart';

import 'supabase_fields.dart';

/// Abstract base for [SupabaseDeserialize] and [SupabaseSerialize].
abstract class SupabaseSerdesGenerator extends JsonSerdesGenerator<SupabaseModel, Supabase> {
  SupabaseSerdesGenerator(
    super.element,
    SupabaseFields super.fields, {
    required super.repositoryName,
  }) : super(providerName: 'Supabase');
}

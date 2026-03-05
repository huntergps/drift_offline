import 'package:drift_supabase/src/supabase_adapter.dart';
import 'package:drift_supabase/src/supabase_model.dart';

/// Registry mapping Dart model [Type]s to their [SupabaseAdapter]s.
///
/// Generated as `supabaseMappings` and `supabaseModelDictionary` in `supabase.g.dart`.
class SupabaseModelDictionary {
  final Map<Type, SupabaseAdapter<SupabaseModel>> adapterFor;

  const SupabaseModelDictionary(this.adapterFor);
}

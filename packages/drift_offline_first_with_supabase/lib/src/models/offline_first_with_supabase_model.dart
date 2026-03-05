import 'package:drift_offline_first/drift_offline_first.dart';
import 'package:drift_supabase/drift_supabase.dart';

/// Base class for models that are stored locally in Drift and synced to Supabase.
///
/// Models annotated with `@ConnectOfflineFirstWithSupabase` must extend this class.
abstract class OfflineFirstWithSupabaseModel extends OfflineFirstModel
    implements SupabaseModel {
  const OfflineFirstWithSupabaseModel();
}

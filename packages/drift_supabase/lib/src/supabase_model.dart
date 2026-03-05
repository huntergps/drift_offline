/// Base class for all Supabase-backed models.
///
/// Models annotated with `@ConnectOfflineFirstWithSupabase` must extend
/// either this class or [OfflineFirstWithSupabaseModel] (which extends this).
abstract class SupabaseModel {
  const SupabaseModel();
}

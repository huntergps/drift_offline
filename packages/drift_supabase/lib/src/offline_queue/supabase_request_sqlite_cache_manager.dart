import 'package:drift_offline_first/drift_offline_first.dart';
import 'package:sqflite_common/sqlite_api.dart';

/// Supabase-flavored alias for [HttpRequestSqliteCacheManager].
///
/// Kept for API compatibility. Prefer [HttpRequestSqliteCacheManager] directly.
class SupabaseRequestSqliteCacheManager extends HttpRequestSqliteCacheManager {
  SupabaseRequestSqliteCacheManager(
    super.databasePath, {
    required DatabaseFactory openDatabase,
    super.serialProcessing,
    super.loggerName,
  }) : super(databaseFactory: openDatabase);
}

import 'package:drift_offline_first/drift_offline_first.dart';
import 'package:http/http.dart' as http;

/// Supabase-specific offline queue client.
///
/// Extends [HttpOfflineQueueClient] with Supabase's default [ignorePaths]:
/// `/auth/v1` (auth endpoints) and `/storage/v1` (file storage) are always
/// forwarded live — they must not be queued because their tokens expire quickly.
///
/// Usage is identical to [HttpOfflineQueueClient]; just pass a
/// [HttpRequestSqliteCacheManager] and an inner [http.Client].
class SupabaseOfflineQueueClient extends HttpOfflineQueueClient {
  /// Paths that bypass the offline queue by default for Supabase.
  static const defaultIgnorePaths = {'/auth/v1', '/storage/v1'};

  SupabaseOfflineQueueClient(
    http.Client inner,
    HttpRequestSqliteCacheManager requestManager, {
    Set<String> additionalIgnorePaths = const {},
    List<int>? reattemptForStatusCodes,
    void Function(http.Request, int)? onReattempt,
    void Function(http.Request, Object)? onRequestException,
    String? loggerName,
  }) : super(
          inner,
          requestManager,
          ignorePaths: {...defaultIgnorePaths, ...additionalIgnorePaths},
          reattemptForStatusCodes: reattemptForStatusCodes,
          onReattempt: onReattempt,
          onRequestException: onRequestException,
          loggerName: loggerName ?? 'SupabaseOfflineQueueClient',
        );
}

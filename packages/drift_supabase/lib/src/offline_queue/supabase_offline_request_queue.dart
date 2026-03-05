import 'package:drift_offline_first/drift_offline_first.dart';

import 'supabase_offline_queue_client.dart';

/// Supabase-flavored alias for [HttpOfflineRequestQueue].
///
/// Kept for API compatibility. Prefer [HttpOfflineRequestQueue] directly.
class SupabaseOfflineRequestQueue extends HttpOfflineRequestQueue {
  SupabaseOfflineRequestQueue({
    required SupabaseOfflineQueueClient client,
    Duration interval = const Duration(seconds: 5),
    String? loggerName,
  }) : super(client: client, interval: interval, loggerName: loggerName);
}

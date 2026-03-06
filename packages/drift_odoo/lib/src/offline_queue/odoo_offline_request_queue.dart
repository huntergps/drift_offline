import 'dart:async';
import 'dart:convert';

import 'package:drift_odoo/src/offline_queue/odoo_offline_queue_client.dart';
import 'package:drift_odoo/src/offline_queue/odoo_request_sqlite_cache_manager.dart';
import 'package:logging/logging.dart';

/// Periodically drains the offline queue by retransmitting pending Odoo requests.
///
/// Start with [start] after calling [OdooOfflineFirstWithOdooRepository.initialize].
/// Stop with [stop] when the repository is disposed.
class OdooOfflineRequestQueue {
  final OdooOfflineQueueClient client;

  /// How often the queue is processed. Defaults to 5 seconds.
  final Duration processingInterval;

  bool get isRunning => _timer?.isActive ?? false;

  Timer? _timer;
  bool _processingInBackground = false;

  final Logger _logger;

  OdooOfflineRequestQueue({
    required this.client,
    Duration? processingInterval,
  })  : processingInterval = processingInterval ?? client.requestManager.processingInterval,
        _logger = Logger('OdooOfflineRequestQueue');

  /// Start the queue processor. Stops any existing timer first.
  void start() {
    stop();
    _processingInBackground = false;
    _logger.finer('Queue started');
    _timer = Timer.periodic(processingInterval, _process);
  }

  /// Stop the queue processor.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _processingInBackground = false;
    _logger.finer('Queue stopped');
  }

  Future<void> _process(Timer timer) async {
    if (_processingInBackground) return;
    _processingInBackground = true;

    try {
      final job = await client.requestManager.prepareNextRequestToProcess();
      if (job != null) {
        await _transmit(job);
      }
    } finally {
      _processingInBackground = false;
    }
  }

  Future<void> _transmit(Map<String, dynamic> job) async {
    final rowId = job[kColId] as int;
    final model = job[kColModel] as String;
    final method = job[kColMethod] as String;
    final ids = (jsonDecode(job[kColIds] as String) as List).cast<int>();
    final kwargs = Map<String, dynamic>.from(
      jsonDecode(job[kColPayload] as String) as Map,
    );

    _logger.info('Processing queued: $method $model ids=$ids');

    // Calling client.call() re-routes through OdooOfflineQueueClient, which:
    //   1. Calls insertOrUpdate() — finds the existing row by (model+method+ids+payload)
    //      and increments its attempt counter. Returns the same rowId.
    //   2. Calls the live HTTP endpoint.
    //   3a. On success  → calls delete(rowId), removing the job from the queue.
    //   3b. On SocketException → calls unlock(rowId), then returns null (no throw).
    //   3c. On other errors → calls unlock(rowId), then rethrows.
    //
    // The catch block here handles case 3c only (unlock was already called by
    // client.call(), so a second unlock is benign).
    try {
      await client.call(model, method, ids: ids, kwargs: kwargs);
    } catch (e) {
      _logger.warning('Queue transmit failed: $method $model: $e');
      await client.requestManager.unlock(rowId);
    }
  }
}

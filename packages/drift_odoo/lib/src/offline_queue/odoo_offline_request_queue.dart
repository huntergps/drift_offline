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

    try {
      await client.call(model, method, ids: ids, kwargs: kwargs);
      // Success — client.call already removes from queue on success
    } catch (e) {
      _logger.warning('Queue transmit failed: $method $model: $e');
      await client.requestManager.unlock(rowId);
    }
  }
}

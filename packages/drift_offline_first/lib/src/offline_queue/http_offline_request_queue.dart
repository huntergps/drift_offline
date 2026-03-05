import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import 'http_offline_queue_client.dart';
import 'http_request_sqlite_cache_manager.dart';

/// Periodically replays queued HTTP requests stored by [HttpOfflineQueueClient].
///
/// Call [start] after [HttpRequestSqliteCacheManager.migrate] completes.
/// Call [stop] when the repository is disposed.
///
/// Replay is performed through the **inner** HTTP client directly, bypassing
/// the wrapping queue logic to prevent re-queuing already-queued requests.
class HttpOfflineRequestQueue {
  final HttpOfflineQueueClient client;
  final Duration interval;

  Timer? _timer;
  bool _processing = false;

  final Logger _logger;

  HttpOfflineRequestQueue({
    required this.client,
    this.interval = const Duration(seconds: 5),
    String? loggerName,
  }) : _logger = Logger(loggerName ?? 'HttpOfflineRequestQueue');

  /// Begin replaying queued requests on [interval].
  void start() {
    _timer ??= Timer.periodic(interval, (_) => _process());
    _logger.fine('start: queue processor running every ${interval.inSeconds}s');
  }

  /// Stop the periodic processor.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _logger.fine('stop: queue processor stopped');
  }

  Future<void> _process() async {
    if (_processing) return;
    _processing = true;
    try {
      final row = await client.requestManager.prepareNextRequestToProcess();
      if (row == null) return;

      final id = row[HTTP_JOBS_PRIMARY_KEY_COLUMN] as int;
      _logger.finest(
          '_process: replaying id=$id ${row[HTTP_JOBS_METHOD_COLUMN]} ${row[HTTP_JOBS_URL_COLUMN]}');

      try {
        final request = _rowToRequest(row);
        // Use innerClient directly to bypass the queue wrapper.
        final streamed = await client.innerClient.send(request);
        final response = await http.Response.fromStream(streamed);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          await client.requestManager.delete(id);
          _logger.fine('_process: success id=$id, removed');
        } else if (client.reattemptForStatusCodes.contains(response.statusCode)) {
          _logger.warning(
              '_process: id=$id status=${response.statusCode}, keeping for reattempt');
          await client.requestManager.unlock(id);
        } else {
          // Non-retryable error — remove to unblock the queue.
          _logger.warning(
              '_process: id=$id non-retryable status=${response.statusCode}, discarding');
          await client.requestManager.delete(id);
        }
      } catch (e) {
        _logger.warning('_process: id=$id error during replay: $e');
        await client.requestManager.unlock(id);
      }
    } finally {
      _processing = false;
    }
  }

  static http.Request _rowToRequest(Map<String, dynamic> row) {
    final request = http.Request(
      row[HTTP_JOBS_METHOD_COLUMN] as String,
      Uri.parse(row[HTTP_JOBS_URL_COLUMN] as String),
    );

    final encodingName = row[HTTP_JOBS_ENCODING_COLUMN] as String?;
    if (encodingName != null) {
      final enc = Encoding.getByName(encodingName);
      if (enc != null) request.encoding = enc;
    }

    request.headers.addAll(HttpRequestSqliteCacheManager.headersFromRow(row));

    final body = row[HTTP_JOBS_BODY_COLUMN] as String?;
    if (body != null) request.body = body;

    return request;
  }
}

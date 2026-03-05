import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import 'http_request_sqlite_cache_manager.dart';

/// HTTP methods that mutate server state and must be queued when offline.
const _kWriteMethods = {'POST', 'PUT', 'PATCH', 'DELETE'};

/// An [http.BaseClient] decorator that queues write requests when offline.
///
/// Write requests (POST/PUT/PATCH/DELETE) that fail with a [SocketException]
/// are stored in SQLite by [requestManager] and replayed by
/// [HttpOfflineRequestQueue] when connectivity is restored.
///
/// Read requests (GET/HEAD) are always forwarded directly.
///
/// **Bypass rules:**
/// - Paths starting with any entry in [ignorePaths] are forwarded immediately.
/// - Requests carrying the [policyHeader] with value `requireRemote` are
///   forwarded immediately (error propagates to caller).
///
/// Usage:
/// ```dart
/// final manager = HttpRequestSqliteCacheManager(
///   'offline_queue.sqlite',
///   databaseFactory: databaseFactory,
/// );
/// await manager.migrate();
/// final client = HttpOfflineQueueClient(http.Client(), manager);
/// ```
class HttpOfflineQueueClient extends http.BaseClient {
  /// Header used to signal that this request must not be queued.
  /// Set by the repository when the policy is [OfflineFirstUpsertPolicy.requireRemote].
  static const policyHeader = 'X-Drift-OfflineFirstPolicy';

  final http.Client _inner;

  /// Direct access to the inner client for queue replay (bypasses queue logic).
  http.Client get innerClient => _inner;

  /// Manages the SQLite-backed request queue.
  final HttpRequestSqliteCacheManager requestManager;

  /// URL path prefixes that bypass the queue entirely.
  /// Useful for auth and storage endpoints that should always be live.
  final Set<String> ignorePaths;

  /// HTTP response status codes that keep the request in the queue for
  /// re-attempt instead of removing it as successfully sent.
  final List<int> reattemptForStatusCodes;

  /// Called when the server returns a status code in [reattemptForStatusCodes].
  final void Function(http.Request request, int statusCode)? onReattempt;

  /// Called when the request throws an exception (including [SocketException]).
  final void Function(http.Request request, Object error)? onRequestException;

  final Logger _logger;

  HttpOfflineQueueClient(
    this._inner,
    this.requestManager, {
    this.ignorePaths = const {},
    List<int>? reattemptForStatusCodes,
    this.onReattempt,
    this.onRequestException,
    String? loggerName,
  })  : reattemptForStatusCodes = reattemptForStatusCodes ?? [404, 501, 502, 503, 504],
        _logger =
            Logger(loggerName ?? 'HttpOfflineQueueClient#${requestManager.databaseName}');

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // 1. Ignore-path bypass.
    if (ignorePaths.any((p) => request.url.path.startsWith(p))) {
      return _inner.send(request);
    }

    // 2. Only handle concrete http.Request (not multipart etc.).
    if (request is! http.Request) return _inner.send(request);

    // 3. requireRemote policy: forward immediately, don't queue.
    final policy = request.headers.remove(policyHeader);
    if (policy == 'requireRemote') return _inner.send(request);

    // 4. Read requests bypass the queue.
    if (!_kWriteMethods.contains(request.method.toUpperCase())) {
      return _inner.send(request);
    }

    // 5. Store the request before attempting.
    final Encoding? encoding =
        request.encoding.name.isNotEmpty ? request.encoding : null;
    final id = await requestManager.insertOrUpdate(
      method: request.method,
      url: request.url.toString(),
      headers: Map<String, String>.from(request.headers),
      body: request.body,
      encoding: encoding?.name,
    );

    _logger.finest('send: queued id=$id ${request.method} ${request.url}');

    try {
      final resp = await _inner.send(request);

      if (!reattemptForStatusCodes.contains(resp.statusCode)) {
        // Successfully sent — remove from queue.
        await requestManager.delete(id);
        _logger.finest('send: success id=$id, removed from queue');
      } else {
        _logger.warning('send: id=$id status=${resp.statusCode}, will reattempt');
        onReattempt?.call(request, resp.statusCode);
        await requestManager.unlock(id);
      }

      return resp;
    } catch (e) {
      // Offline (SocketException) or other transient error.
      onRequestException?.call(request, e);
      _logger.warning('send: id=$id exception, staying in queue: $e');
      await requestManager.unlock(id);

      return http.StreamedResponse(
        Stream.fromFuture(Future.value('offline'.codeUnits)),
        501,
        request: request,
        reasonPhrase: 'Queued offline',
      );
    }
  }

  /// Detects "Tunnel not found" proxy errors — same heuristic as Brick.
  static bool isATunnelNotFoundResponse(http.Response response) {
    return response.statusCode == 404 &&
        response.body.startsWith('Tunnel') &&
        response.body.endsWith('not found');
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

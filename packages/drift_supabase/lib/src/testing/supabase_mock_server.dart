import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Lightweight HTTP + WebSocket mock server for testing [SupabaseProvider]
/// without a real Supabase backend.
///
/// Supports:
/// - HTTP stubs via [stub]
/// - WebSocket realtime simulation via [broadcastRealtimeEvent]
///
/// Start the server with [serve], register stubs via [stub], and shut it
/// down with [close].
///
/// ```dart
/// late SupabaseMockServer server;
///
/// setUp(() async {
///   server = SupabaseMockServer();
///   await server.serve();
///
///   server.stub(
///     method: 'GET',
///     pathPattern: '/rest/v1/users',
///     response: SupabaseMockResponse(
///       body: [{'id': 1, 'name': 'Alice'}],
///     ),
///   );
/// });
///
/// tearDown(() => server.close());
/// ```
///
/// To simulate realtime events:
/// ```dart
/// server.broadcastRealtimeEvent(
///   table: 'users',
///   eventType: 'INSERT',
///   record: {'id': 1, 'name': 'Alice'},
/// );
/// ```
class SupabaseMockServer {
  HttpServer? _server;
  final List<_MockRoute> _routes = [];
  final List<WebSocket> _wsClients = [];

  /// The base URL of this server (e.g. `http://localhost:54321`).
  String get url {
    if (_server == null) throw StateError('Server not started. Call serve() first.');
    return 'http://localhost:${_server!.port}';
  }

  /// Start the mock server on a random available port.
  Future<void> serve() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _handleRequests();
  }

  /// Register a stub for the given HTTP [method] and path [pathPattern].
  ///
  /// [pathPattern] is matched against the request path using [String.contains].
  /// The first matching stub wins.
  void stub({
    required String method,
    required String pathPattern,
    required SupabaseMockResponse response,
  }) {
    _routes.add(_MockRoute(
      method: method.toUpperCase(),
      pathPattern: pathPattern,
      response: response,
    ));
  }

  /// Remove all registered stubs.
  void clearStubs() => _routes.clear();

  /// Stop the server and close all WebSocket connections.
  Future<void> close() async {
    for (final ws in _wsClients) {
      await ws.close();
    }
    _wsClients.clear();
    await _server?.close(force: true);
    _server = null;
    _routes.clear();
  }

  /// Broadcast a Supabase realtime event to all connected WebSocket clients.
  ///
  /// [table] is the PostgreSQL table name.
  /// [eventType] is 'INSERT', 'UPDATE', or 'DELETE'.
  /// [record] is the new/current record data.
  /// [oldRecord] is the previous record data (for UPDATE/DELETE).
  /// [schema] defaults to 'public'.
  void broadcastRealtimeEvent({
    required String table,
    required String eventType,
    required Map<String, dynamic> record,
    Map<String, dynamic>? oldRecord,
    String schema = 'public',
  }) {
    final event = {
      'type': 'broadcast',
      'event': eventType,
      'payload': {
        'type': 'postgres_changes',
        'schema': schema,
        'table': table,
        'eventType': eventType,
        'new': record,
        'old': oldRecord ?? {},
      },
    };
    final encoded = jsonEncode(event);
    for (final ws in List<WebSocket>.from(_wsClients)) {
      try {
        ws.add(encoded);
      } catch (_) {
        _wsClients.remove(ws);
      }
    }
  }

  void _handleRequests() {
    _server!.listen((HttpRequest request) async {
      // WebSocket upgrade
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        final ws = await WebSocketTransformer.upgrade(request);
        _wsClients.add(ws);
        ws.done.then((_) => _wsClients.remove(ws));
        // Send connection acknowledgment (Supabase realtime protocol)
        ws.add(jsonEncode({'type': 'system', 'status': 'ok', 'message': 'connected'}));
        ws.listen(
          (data) {
            // Handle subscription messages and acknowledge them
            try {
              final msg = jsonDecode(data as String) as Map<String, dynamic>;
              if (msg['type'] == 'SUBSCRIBE') {
                ws.add(jsonEncode({
                  'type': 'SUBSCRIBED',
                  'ref': msg['ref'],
                }));
              } else if (msg['type'] == 'phx_join') {
                ws.add(jsonEncode({
                  'event': 'phx_reply',
                  'ref': msg['ref'],
                  'topic': msg['topic'],
                  'payload': {'status': 'ok', 'response': {}},
                }));
              }
            } catch (_) {}
          },
          onDone: () => _wsClients.remove(ws),
        );
        return;
      }

      // Regular HTTP handling
      final method = request.method.toUpperCase();
      final path = request.uri.path;

      final route = _routes.firstWhere(
        (r) => r.method == method && path.contains(r.pathPattern),
        orElse: () => _MockRoute(
          method: method,
          pathPattern: path,
          response: SupabaseMockResponse(
              statusCode: 404, body: {'error': 'not stubbed: $method $path'}),
        ),
      );

      final res = request.response;
      res.statusCode = route.response.statusCode;
      res.headers.contentType = ContentType.json;
      if (route.response.headers != null) {
        route.response.headers!.forEach(res.headers.set);
      }
      res.write(jsonEncode(route.response.body));
      await res.close();
    });
  }
}

/// Response definition for [SupabaseMockServer.stub].
class SupabaseMockResponse {
  /// HTTP status code. Defaults to 200.
  final int statusCode;

  /// Response body. Can be a [List], [Map], or any JSON-serializable value.
  final Object? body;

  /// Additional headers to include in the response.
  final Map<String, String>? headers;

  const SupabaseMockResponse({
    this.statusCode = 200,
    this.body,
    this.headers,
  });
}

class _MockRoute {
  final String method;
  final String pathPattern;
  final SupabaseMockResponse response;

  const _MockRoute({
    required this.method,
    required this.pathPattern,
    required this.response,
  });
}

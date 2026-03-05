import 'dart:convert';

import 'package:drift_offline_first/drift_offline_first.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import 'rest_adapter.dart';
import 'rest_exception.dart';
import 'rest_model.dart';
import 'rest_model_dictionary.dart';
import 'rest_request.dart';
import 'rest_request_transformer.dart';

/// HTTP provider that performs CRUD operations against a REST API.
///
/// Wrap the underlying [http.Client] with [HttpOfflineQueueClient] from
/// `drift_offline_first` to get transparent offline queuing.
///
/// ```dart
/// final provider = RestProvider(
///   'https://api.example.com',
///   modelDictionary: restModelDictionary,
///   client: HttpOfflineQueueClient(http.Client(), RequestSqliteCacheManager('rest_queue.db')),
/// );
/// ```
class RestProvider {
  static final _logger = Logger('RestProvider');

  /// Base URL for all requests (no trailing slash).
  final String baseEndpoint;

  /// The model dictionary mapping [Type]s to [RestAdapter]s.
  final RestModelDictionary modelDictionary;

  /// HTTP headers merged with per-request headers.
  final Map<String, String> defaultHeaders;

  final http.Client _client;

  RestProvider(
    this.baseEndpoint, {
    required this.modelDictionary,
    http.Client? client,
    this.defaultHeaders = const {},
  }) : _client = client ?? http.Client();

  // ---------------------------------------------------------------------------
  // GET
  // ---------------------------------------------------------------------------

  /// Fetch one or more [TModel] instances.
  ///
  /// [query] is forwarded to [RestRequestTransformer.get] so the transformer
  /// can build dynamic URLs (e.g. `query?.providerArgs['id']`).
  Future<List<TModel>> get<TModel extends RestModel>({
    Query? query,
  }) async {
    final adapter = _adapterFor<TModel>();
    final request = _requestFor(adapter, 'get', query: query, instance: null);
    if (request == null) return [];

    final uri = _uri(request.url ?? '');
    _logger.fine('GET $uri');

    final response = await _client.get(uri, headers: _headers(request));
    _assertSuccessful(response);

    final body = json.decode(response.body);
    final data = request.topLevelKey != null ? body[request.topLevelKey] : body;

    if (data is List) {
      return Future.wait(
        data.cast<Map<String, dynamic>>().map(
              (d) => adapter.fromRest(d, provider: this),
            ),
      );
    } else if (data is Map<String, dynamic>) {
      return [await adapter.fromRest(data, provider: this)];
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // UPSERT
  // ---------------------------------------------------------------------------

  /// Create or update [instance] on the server.
  ///
  /// Returns the server-reflected model (parsed from the response body).
  Future<TModel?> upsert<TModel extends RestModel>(TModel instance) async {
    final adapter = _adapterFor<TModel>();
    final request = _requestFor(adapter, 'upsert', query: null, instance: instance);
    if (request == null) return null;

    final method = request.method?.toUpperCase() ?? 'POST';
    final uri = _uri(request.url ?? '');
    _logger.fine('$method $uri');

    final serialized = await adapter.toRest(instance, provider: this);
    final payload = _wrapPayload(serialized, request);

    final response = await _send(method, uri, _headers(request), payload);
    _assertSuccessful(response);

    if (response.body.isEmpty) return instance;

    final body = json.decode(response.body);
    final data = request.topLevelKey != null ? body[request.topLevelKey] : body;

    if (data is Map<String, dynamic>) {
      return adapter.fromRest(data, provider: this);
    }
    return instance;
  }

  // ---------------------------------------------------------------------------
  // DELETE
  // ---------------------------------------------------------------------------

  /// Delete [instance] from the server.
  Future<void> delete<TModel extends RestModel>(TModel instance) async {
    final adapter = _adapterFor<TModel>();
    final request = _requestFor(adapter, 'delete', query: null, instance: instance);
    if (request == null) return;

    final uri = _uri(request.url ?? '');
    _logger.fine('DELETE $uri');

    final response = await _client.delete(uri, headers: _headers(request));
    _assertSuccessful(response);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  RestAdapter<TModel> _adapterFor<TModel extends RestModel>() {
    final adapter = modelDictionary.adapterFor[TModel];
    if (adapter == null) {
      throw ArgumentError('No RestAdapter registered for $TModel');
    }
    return adapter as RestAdapter<TModel>;
  }

  /// Returns the [RestRequest] for [operation] ('get', 'upsert', 'delete') by
  /// calling the adapter's [restRequest] factory if one exists.
  RestRequest? _requestFor(
    RestAdapter adapter,
    String operation, {
    required Query? query,
    required RestModel? instance,
  }) {
    final factory = adapter.restRequest;
    if (factory == null) return null;

    final transformer = factory(query, instance);
    switch (operation) {
      case 'get':
        return transformer.get;
      case 'upsert':
        return transformer.upsert;
      case 'delete':
        return transformer.delete;
      default:
        return null;
    }
  }

  Uri _uri(String path) => Uri.parse('$baseEndpoint$path');

  Map<String, String> _headers(RestRequest request) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...defaultHeaders,
        ...?request.headers,
      };

  /// Wraps [data] under [request.topLevelKey] and merges
  /// [request.supplementalTopLevelData] at the top level.
  Map<String, dynamic> _wrapPayload(
    Map<String, dynamic> data,
    RestRequest request,
  ) {
    final top = <String, dynamic>{};
    if (request.topLevelKey != null) {
      top[request.topLevelKey!] = data;
    } else {
      top.addAll(data);
    }
    if (request.supplementalTopLevelData != null) {
      top.addAll(request.supplementalTopLevelData!);
    }
    return top;
  }

  Future<http.Response> _send(
    String method,
    Uri uri,
    Map<String, String> headers,
    Map<String, dynamic> body,
  ) {
    final encoded = json.encode(body);
    switch (method) {
      case 'POST':
        return _client.post(uri, headers: headers, body: encoded);
      case 'PUT':
        return _client.put(uri, headers: headers, body: encoded);
      case 'PATCH':
        return _client.patch(uri, headers: headers, body: encoded);
      case 'DELETE':
        return _client.delete(uri, headers: headers, body: encoded);
      default:
        return _client.post(uri, headers: headers, body: encoded);
    }
  }

  void _assertSuccessful(http.Response response) {
    if (response.statusCode < 200 || response.statusCode > 299) {
      throw RestException(response);
    }
  }
}

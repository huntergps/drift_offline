import 'dart:convert';

import 'package:drift_odoo/src/odoo_exception.dart';
import 'package:drift_odoo_core/drift_odoo_core.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

/// Low-level HTTP client for the Odoo JSON-2 API.
///
/// Endpoint pattern: `POST /json/2/<model>/<method>`
/// Authentication: `Authorization: Bearer <api_key>`
///
/// Example:
/// ```dart
/// final client = OdooClient(
///   baseUrl: 'https://mycompany.odoo.com',
///   apiKey: 'my_api_key',
/// );
/// final partners = await client.searchRead('res.partner', fields: ['name', 'email']);
/// ```
class OdooClient {
  /// The base URL of the Odoo instance (e.g. `'https://mycompany.odoo.com'`).
  final String baseUrl;

  /// Bearer token API key from Odoo Preferences → Account Security → New API Key.
  final String apiKey;

  /// Required when multiple databases share the same domain.
  final String? database;

  /// The underlying HTTP client.
  http.Client httpClient;

  final Logger _logger;

  OdooClient({
    required this.baseUrl,
    required this.apiKey,
    this.database,
    http.Client? httpClient,
  })  : httpClient = httpClient ?? http.Client(),
        _logger = Logger('OdooClient');

  // ---------------------------------------------------------------------------
  // Public API methods
  // ---------------------------------------------------------------------------

  /// `POST /json/2/<model>/search_read`
  ///
  /// Returns a list of records matching [domain].
  /// Note: Odoo returns `false` (not `null`) for empty fields.
  Future<List<Map<String, dynamic>>> searchRead(
    String model, {
    OdooDomain domain = const [],
    List<String>? fields,
    int? offset,
    int? limit,
    String? order,
    String load = '',
  }) async {
    final kwargs = <String, dynamic>{
      'domain': domain,
      if (fields != null) 'fields': fields,
      if (offset != null) 'offset': offset,
      if (limit != null) 'limit': limit,
      if (order != null) 'order': order,
      if (load.isNotEmpty) 'load': load,
    };
    final result = await _call(model, 'search_read', kwargs: kwargs);
    return (result as List).cast<Map<String, dynamic>>();
  }

  /// `POST /json/2/<model>/create`
  ///
  /// Creates one or more records. Returns the list of created IDs.
  Future<List<int>> create(
    String model,
    List<Map<String, dynamic>> valsList,
  ) async {
    final result = await _call(model, 'create', kwargs: {'vals_list': valsList});
    if (result is int) return [result];
    return (result as List).cast<int>();
  }

  /// `POST /json/2/<model>/write`
  ///
  /// Updates [ids] with [vals]. Returns `true` on success.
  Future<bool> write(
    String model,
    List<int> ids,
    Map<String, dynamic> vals,
  ) async {
    final result = await _call(model, 'write', ids: ids, kwargs: {'vals': vals});
    return result as bool;
  }

  /// `POST /json/2/<model>/unlink`
  ///
  /// Deletes records identified by [ids]. Returns `true` on success.
  Future<bool> unlink(String model, List<int> ids) async {
    final result = await _call(model, 'unlink', ids: ids);
    return result as bool;
  }

  /// `POST /json/2/<model>/fields_get`
  ///
  /// Returns field definitions for [model].
  Future<Map<String, dynamic>> fieldsGet(
    String model, {
    List<String>? allfields,
    List<String>? attributes,
  }) async {
    final kwargs = <String, dynamic>{
      if (allfields != null) 'allfields': allfields,
      if (attributes != null) 'attributes': attributes,
    };
    final result = await _call(model, 'fields_get', kwargs: kwargs);
    return result as Map<String, dynamic>;
  }

  /// `POST /json/2/<model>/search`
  ///
  /// Returns IDs of records matching [domain].
  Future<List<int>> search(
    String model, {
    OdooDomain domain = const [],
    int? offset,
    int? limit,
    String? order,
  }) async {
    final kwargs = <String, dynamic>{
      'domain': domain,
      if (offset != null) 'offset': offset,
      if (limit != null) 'limit': limit,
      if (order != null) 'order': order,
    };
    final result = await _call(model, 'search', kwargs: kwargs);
    return (result as List).cast<int>();
  }

  /// Generic method call: `POST /json/2/<model>/<method>`
  ///
  /// Use this for custom Odoo methods not covered above.
  /// [ids] are browse()'d on the server side to create a recordset.
  Future<dynamic> call(
    String model,
    String method, {
    List<int> ids = const [],
    Map<String, dynamic> kwargs = const {},
  }) {
    return _call(model, method, ids: ids, kwargs: kwargs);
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  Future<dynamic> _call(
    String model,
    String method, {
    List<int> ids = const [],
    Map<String, dynamic> kwargs = const {},
  }) async {
    final url = Uri.parse('$baseUrl/json/2/$model/$method');
    final body = <String, dynamic>{
      if (ids.isNotEmpty) 'ids': ids,
      ...kwargs,
    };

    _logger.fine('POST $url');
    _logger.finest('body: ${jsonEncode(body)}');

    final response = await httpClient.post(
      url,
      headers: _headers(),
      body: jsonEncode(body),
    );

    _logger.finest('response ${response.statusCode}: ${response.body}');

    if (_isSuccess(response.statusCode)) {
      return jsonDecode(response.body);
    }

    throw OdooException.fromResponse(response);
  }

  Map<String, String> _headers() {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
      if (database != null) 'X-Odoo-Database': database!,
    };
  }

  static bool _isSuccess(int statusCode) => statusCode >= 200 && statusCode < 300;
}

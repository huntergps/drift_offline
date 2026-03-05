/// Configuration for a single REST operation (get, upsert, or delete).
///
/// Used as the return type of [RestRequestTransformer]'s `get`, `upsert`,
/// and `delete` getters.
///
/// ```dart
/// class UserTransformer extends RestRequestTransformer {
///   @override
///   RestRequest get get => RestRequest(url: '/users');
///
///   @override
///   RestRequest get upsert {
///     final id = instance?.id;
///     return id != null
///         ? RestRequest(url: '/users/$id', method: 'PUT')
///         : RestRequest(url: '/users', method: 'POST');
///   }
///
///   @override
///   RestRequest get delete => RestRequest(url: '/users/${instance!.id}');
///
///   const UserTransformer(super.params, super.instance);
/// }
/// ```
class RestRequest {
  /// HTTP method override. When `null`, the provider infers it from the
  /// operation type: GET → `'GET'`, upsert → `'POST'`, delete → `'DELETE'`.
  final String? method;

  /// Path appended to `RestProvider.baseEndpoint`. Must start with `/`.
  ///
  /// ```dart
  /// RestRequest(url: '/users')       // → GET https://api.example.com/users
  /// RestRequest(url: '/users/${id}') // → GET https://api.example.com/users/42
  /// ```
  final String? url;

  /// Extra HTTP headers merged with [RestProvider.defaultHeaders].
  final Map<String, String>? headers;

  /// When set, the request body is wrapped under this key and the response
  /// is unwrapped from it.
  ///
  /// ```dart
  /// // Payload sent: {"user": {"name": "Tom"}}
  /// // Response expected: {"user": {"id": 1, "name": "Tom"}}
  /// RestRequest(url: '/users', topLevelKey: 'user')
  /// ```
  final String? topLevelKey;

  /// Extra data merged at the top level of the request body alongside
  /// [topLevelKey]. Rarely needed — prefer managing data at the model level.
  final Map<String, dynamic>? supplementalTopLevelData;

  const RestRequest({
    this.method,
    this.url,
    this.headers,
    this.topLevelKey,
    this.supplementalTopLevelData,
  });

  RestRequest copyWith({
    String? method,
    String? url,
    Map<String, String>? headers,
    String? topLevelKey,
    Map<String, dynamic>? supplementalTopLevelData,
  }) =>
      RestRequest(
        method: method ?? this.method,
        url: url ?? this.url,
        headers: headers ?? this.headers,
        topLevelKey: topLevelKey ?? this.topLevelKey,
        supplementalTopLevelData: supplementalTopLevelData ?? this.supplementalTopLevelData,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RestRequest &&
          method == other.method &&
          url == other.url &&
          headers == other.headers &&
          topLevelKey == other.topLevelKey &&
          supplementalTopLevelData == other.supplementalTopLevelData;

  @override
  int get hashCode =>
      method.hashCode ^
      url.hashCode ^
      headers.hashCode ^
      topLevelKey.hashCode ^
      supplementalTopLevelData.hashCode;
}

import 'package:drift_offline_first/drift_offline_first.dart';

import 'rest_model.dart';
import 'rest_request.dart';

/// Specifies the [RestRequest] configuration for each CRUD operation of a model.
///
/// Subclass this for every model that uses REST, providing URLs and HTTP method
/// overrides per operation. The generator emits a `restRequest` getter on the
/// adapter that wires the transformer constructor.
///
/// ```dart
/// class UserTransformer extends RestRequestTransformer {
///   // GET /users  or  GET /users/:id
///   @override
///   RestRequest get get {
///     final id = query?.providerArgs['id'];
///     return RestRequest(url: id != null ? '/users/$id' : '/users');
///   }
///
///   // POST /users  or  PUT /users/:id
///   @override
///   RestRequest get upsert {
///     final id = (instance as User?)?.serverId;
///     return id != null
///         ? RestRequest(url: '/users/$id', method: 'PUT')
///         : RestRequest(url: '/users');
///   }
///
///   // DELETE /users/:id
///   @override
///   RestRequest get delete => RestRequest(url: '/users/${(instance as User).serverId}');
///
///   const UserTransformer(super.query, super.instance);
/// }
/// ```
///
/// Pass the constructor tear-off on the annotation:
/// ```dart
/// @ConnectOfflineFirstWithRest(
///   restConfig: RestSerializable(requestTransformer: UserTransformer.new),
/// )
/// class User extends OfflineFirstWithRestModel { ... }
/// ```
abstract class RestRequestTransformer {
  /// The query passed from the repository.
  /// Use query.providerArgs, query.where, etc. to build dynamic URLs.
  final Query? query;

  /// The model instance being operated on. Non-null for upsert and delete.
  final RestModel? instance;

  /// Request configuration for GET operations.
  RestRequest? get get => null;

  /// Request configuration for upsert (create/update) operations.
  RestRequest? get upsert => null;

  /// Request configuration for delete operations.
  RestRequest? get delete => null;

  const RestRequestTransformer(this.query, this.instance);
}

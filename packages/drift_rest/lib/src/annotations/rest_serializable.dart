import 'package:brick_core/field_rename.dart';

import '../rest_model.dart';
import '../rest_request_transformer.dart';

/// Class-level annotation that configures REST serialization for a model.
///
/// ```dart
/// @ConnectOfflineFirstWithRest(
///   restConfig: RestSerializable(
///     requestTransformer: UserTransformer.new,
///   ),
/// )
/// class User extends OfflineFirstWithRestModel { ... }
///
/// class UserTransformer extends RestRequestTransformer {
///   final get = RestRequest(url: '/users');
///   final upsert = RestRequest(url: '/users', method: 'POST');
///   final delete = RestRequest(url: '/users');
///   const UserTransformer(super.params, super.instance);
/// }
/// ```
class RestSerializable {
  /// Naming strategy for fields not annotated with `@Rest(name:)`.
  /// Defaults to [FieldRename.snake].
  final FieldRename fieldRename;

  /// When `true` (default), null fields are handled gracefully from the
  /// REST response. Setting to `false` reduces generated code but may throw
  /// on null values at runtime.
  final bool nullable;

  /// The [RestRequestTransformer] constructor to use for this model.
  /// Provides per-operation URL, HTTP method, headers, and top-level key.
  ///
  /// Pass the constructor tear-off: `requestTransformer: MyTransformer.new`.
  final RestRequestTransformer Function(Map<String, dynamic>? params, RestModel? instance)?
      requestTransformer;

  const RestSerializable({
    FieldRename? fieldRename,
    bool? nullable,
    this.requestTransformer,
  })  : fieldRename = fieldRename ?? FieldRename.snake,
        nullable = nullable ?? false;

  static const defaults = RestSerializable();
}

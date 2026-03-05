import 'package:drift_offline_first/drift_offline_first.dart';

import 'rest_model.dart';
import 'rest_request_transformer.dart';

/// Generated adapter interface for a [RestModel].
///
/// Each model annotated with `@ConnectOfflineFirstWithRest` gets a generated
/// concrete subclass with `fromRest` / `toRest` and the `restRequest` transformer.
abstract class RestAdapter<TModel extends RestModel> {
  /// Returns the [RestRequestTransformer] for the given [query] and [instance].
  ///
  /// Generated from the `requestTransformer` field of `@RestSerializable`.
  /// Returns `null` if no transformer was specified.
  RestRequestTransformer Function(Query? query, TModel? instance)?
      get restRequest => null;

  const RestAdapter();

  /// Deserialize a REST JSON record into [TModel].
  Future<TModel> fromRest(
    Map<String, dynamic> data, {
    required covariant Object provider,
    covariant Object? repository,
  });

  /// Serialize [TModel] into a REST-compatible JSON map.
  Future<Map<String, dynamic>> toRest(
    TModel instance, {
    required covariant Object provider,
    covariant Object? repository,
  });
}

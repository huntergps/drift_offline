import 'package:drift_rest/drift_rest.dart';

/// Annotate a model class to generate a REST adapter and wire it into
/// the offline-first pipeline.
///
/// ```dart
/// @ConnectOfflineFirstWithRest(
///   restConfig: RestSerializable(
///     requestTransformer: UserTransformer.new,
///   ),
/// )
/// class User extends OfflineFirstWithRestModel { ... }
/// ```
class ConnectOfflineFirstWithRest {
  /// REST-specific serialization config (field rename, transformer, etc.).
  final RestSerializable restConfig;

  const ConnectOfflineFirstWithRest({
    this.restConfig = const RestSerializable(),
  });
}

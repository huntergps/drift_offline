import 'rest_adapter.dart';
import 'rest_model.dart';

/// Registry mapping Dart model [Type]s to their [RestAdapter]s.
///
/// Generated as `restMappings` and `restModelDictionary` in `rest.g.dart`.
class RestModelDictionary {
  final Map<Type, RestAdapter<RestModel>> adapterFor;

  const RestModelDictionary(this.adapterFor);
}

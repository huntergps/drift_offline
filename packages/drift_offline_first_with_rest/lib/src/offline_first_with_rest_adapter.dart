import 'package:drift_offline_first/drift_offline_first.dart';
import 'package:drift_rest/drift_rest.dart';

import 'models/offline_first_with_rest_model.dart';

/// Generated adapter base for REST-backed offline-first models.
///
/// The code generator emits a concrete subclass for each
/// `@ConnectOfflineFirstWithRest`-annotated class, implementing [fromRest],
/// [toRest], and optionally [restRequest].
abstract class OfflineFirstWithRestAdapter<
        TModel extends OfflineFirstWithRestModel>
    extends OfflineFirstAdapter<TModel> implements RestAdapter<TModel> {
  const OfflineFirstWithRestAdapter();
}

import 'package:drift_offline_first/drift_offline_first.dart';
import 'package:drift_rest/drift_rest.dart';

/// Base class for models that are persisted locally via Drift and synchronized
/// with a REST API.
///
/// Extend this class (instead of [OfflineFirstModel] directly) when using
/// `@ConnectOfflineFirstWithRest`.
abstract class OfflineFirstWithRestModel extends OfflineFirstModel
    implements RestModel {
  const OfflineFirstWithRestModel();
}

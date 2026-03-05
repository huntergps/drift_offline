/// Base class for all REST-backed models.
///
/// Models annotated with `@ConnectOfflineFirstWithRest` must extend
/// [OfflineFirstWithRestModel] (which extends this).
abstract class RestModel {
  const RestModel();
}

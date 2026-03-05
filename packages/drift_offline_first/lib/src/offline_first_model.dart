/// Base class for all models in the offline-first system.
///
/// Provider-agnostic — does not reference Odoo or Supabase.
/// Subclasses (e.g. [OfflineFirstWithOdooModel]) add remote-specific fields.
abstract class OfflineFirstModel {
  const OfflineFirstModel();

  /// The remote provider's unique identifier for this record.
  ///
  /// Used by [DestructiveLocalSyncFromRemoteMixin] to diff local vs remote sets.
  /// Returns `null` by default; override in provider-specific subclasses.
  Object? get primaryKey => null;
}

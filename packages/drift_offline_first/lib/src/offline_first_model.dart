/// Base class for all models in the offline-first system.
///
/// Provider-agnostic — does not reference Odoo or Supabase.
/// Subclasses (e.g. [OfflineFirstWithOdooModel]) add remote-specific fields.
abstract class OfflineFirstModel {
  const OfflineFirstModel();
}

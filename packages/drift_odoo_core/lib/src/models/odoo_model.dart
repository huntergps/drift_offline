/// Base class for all models managed by an [OdooProvider].
///
/// Every Odoo record has an integer `id` field. This is stored as [odooId].
/// A `null` [odooId] means the record has not yet been saved to Odoo.
abstract class OdooModel {
  /// The Odoo database ID (`id` field). Null for records not yet synced.
  int? odooId;

  OdooModel({this.odooId});
}

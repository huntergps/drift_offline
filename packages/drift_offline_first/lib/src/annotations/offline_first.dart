/// Field-level annotation for fine-grained control over offline-first
/// association resolution.
///
/// Similar to Brick's `@OfflineFirst`, this annotation lets you override
/// how the code generator builds the `getAssociation` query for a related
/// model field, instead of relying on the default provider-specific lookup.
///
/// ## Example
///
/// Without `@OfflineFirst`, a `Partner?` field annotated `@Odoo()` relies on
/// the Odoo-specific logic: for Many2one fields Odoo returns `[id, name]`, so
/// the generator uses `data['partner_id'][0]` as the odooId.
///
/// With `@OfflineFirst` you can make the lookup more explicit:
///
/// ```dart
/// @OfflineFirst(where: {'odooId': "data['partner_id']"})
/// @Odoo(name: 'partner_id', ignoreTo: true)
/// Partner? partner;
/// ```
///
/// This generates:
/// ```dart
/// partner: data['partner_id'] == false || data['partner_id'] == null
///   ? null
///   : await repository?.getAssociation<Partner>(
///       Query(where: [Where('odooId').isExactly(data['partner_id'])]),
///     ).then((r) => r?.firstOrNull),
/// ```
///
/// The `where` map can have multiple entries for composite keys.
class OfflineFirst {
  /// A map of `{ dartFieldName: dartExpression }` pairs for the association
  /// query `where` clause.
  ///
  /// Values are raw Dart expressions inserted verbatim into generated code.
  /// They may reference:
  /// - `data` — the raw deserialized map from the remote provider.
  /// - `instance` — the current model instance (only in `toRemote` context).
  ///
  /// Example:
  /// ```dart
  /// @OfflineFirst(where: {'odooId': "data['partner_id']"})
  /// ```
  final Map<String, String>? where;

  /// When `true` (default), the `where` override applies during remote
  /// deserialization (e.g. `fromOdoo`).
  ///
  /// Set to `false` to apply the override only during local (SQLite)
  /// deserialization.
  final bool applyToRemoteDeserialization;

  const OfflineFirst({
    this.where,
    this.applyToRemoteDeserialization = true,
  });
}

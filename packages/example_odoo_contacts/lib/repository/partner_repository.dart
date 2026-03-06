import 'package:drift/drift.dart';
import 'package:drift_odoo/drift_odoo.dart';
import 'package:drift_odoo_core/drift_odoo_core.dart';
import 'package:drift_offline_first/drift_offline_first.dart';
import 'package:drift_offline_first_with_odoo/drift_offline_first_with_odoo.dart';

import '../db/app_database.dart';
import '../models/partner.dart';
import '../models/partner_adapter.dart';

// ---------------------------------------------------------------------------
// Model dictionary — normally auto-generated in odoo.g.dart
// ---------------------------------------------------------------------------

/// Registry of all model adapters.
///
/// In a code-generated project this is generated as `odooModelDictionary`
/// inside `odoo.g.dart`.
const _modelDictionary = OdooModelDictionary({
  Partner: PartnerAdapter(),
});

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

/// Concrete offline-first repository for [Partner].
///
/// Demonstrates both improvements over the base class:
///
/// 1. **[watchLocal] with Drift's `.watch()`** — subscriptions emit
///    automatically whenever the `partners` table changes, without any
///    manual call to [notifySubscriptionsWithLocalData].
///
/// 2. **[QueryDriftTransformer]** — translates drift_offline [Query] objects
///    (Where / OrderBy / LimitBy) into Drift SQL expressions automatically,
///    so [getLocal] and [watchLocal] respect query constraints natively.
class PartnerRepository
    extends OfflineFirstWithOdooRepository<OfflineFirstWithOdooModel> {
  final AppDatabase _db;

  /// Maps Dart field names → Drift columns for automatic query translation.
  ///
  /// Cast to `GeneratedColumn<Object>` to satisfy the transformer's generic
  /// map type while preserving Drift's runtime type for dynamic dispatch.
  late final QueryDriftTransformer _transformer = QueryDriftTransformer({
    'odooId': _db.partners.odooId as GeneratedColumn<Object>,
    'name': _db.partners.name as GeneratedColumn<Object>,
    'email': _db.partners.email as GeneratedColumn<Object>,
    'phone': _db.partners.phone as GeneratedColumn<Object>,
    'isCompany': _db.partners.isCompany as GeneratedColumn<Object>,
  });

  PartnerRepository({
    required AppDatabase db,
    required super.remoteProvider,
    required super.syncManager,
  })  : _db = db,
        super(loggerName: 'PartnerRepository');

  @override
  OdooModelDictionary get modelDictionary => _modelDictionary;

  // ── Local storage (Drift) ─────────────────────────────────────────────────

  /// Reads from the local `partners` table, applying [Query] constraints
  /// automatically via [QueryDriftTransformer].
  @override
  Future<List<T>> getLocal<T extends OfflineFirstWithOdooModel>({
    Query? query,
  }) async {
    if (T == Partner) {
      final stmt = _db.select(_db.partners);
      _transformer.applyToSelect(stmt, query);
      return (await stmt.get()).map(_rowToPartner).toList().cast<T>();
    }
    throw UnsupportedError('No local handler for $T');
  }

  @override
  Future<bool> existsLocal<T extends OfflineFirstWithOdooModel>({
    Query? query,
  }) async {
    if (T == Partner) {
      final stmt = _db.select(_db.partners);
      _transformer.applyToSelect(stmt, query);
      return (await stmt.get()).isNotEmpty;
    }
    return false;
  }

  @override
  Future<int?> upsertLocal<T extends OfflineFirstWithOdooModel>(
    T instance,
  ) async {
    if (instance is Partner) {
      return _db
          .into(_db.partners)
          .insertOnConflictUpdate(PartnersCompanion(
            odooId: Value(instance.odooId),
            name: Value(instance.name),
            email: Value(instance.email),
            phone: Value(instance.phone),
            isCompany: Value(instance.isCompany),
          ));
    }
    throw UnsupportedError('No local handler for ${instance.runtimeType}');
  }

  @override
  Future<void> deleteLocal<T extends OfflineFirstWithOdooModel>(
    T instance,
  ) async {
    if (instance is Partner && instance.odooId != null) {
      await (_db.delete(_db.partners)
            ..where((t) => t.odooId.equals(instance.odooId!)))
          .go();
    }
  }

  // ── Reactive subscriptions via Drift's watch() ────────────────────────────

  /// Returns a Drift `.watch()` stream for [T].
  ///
  /// Drift automatically emits a new list whenever the `partners` table
  /// changes — no manual [notifySubscriptionsWithLocalData] needed.
  /// [Query] constraints (Where / OrderBy / LimitBy) are applied via
  /// [QueryDriftTransformer] so each subscription only sees relevant rows.
  @override
  Stream<List<T>> watchLocal<T extends OfflineFirstWithOdooModel>({
    Query? query,
  }) {
    if (T == Partner) {
      return _transformer
          .applyToWatch(_db.select(_db.partners), query)
          .map((rows) => rows.map(_rowToPartner).toList().cast<T>());
    }
    // Fallback: use the base StreamController for unregistered types.
    return super.watchLocal<T>(query: query);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Partner _rowToPartner(PartnersData row) => Partner(
        odooId: row.odooId,
        name: row.name,
        email: row.email,
        phone: row.phone,
        isCompany: row.isCompany,
      );
}

import 'package:drift/drift.dart';
import 'package:drift_odoo/drift_odoo.dart';
import 'package:drift_odoo_core/drift_odoo_core.dart';
import 'package:drift_offline_first_with_odoo/drift_offline_first_with_odoo.dart';

import '../db/app_database.dart';
import '../models/partner.dart';
import '../models/partner_adapter.dart';

// ---------------------------------------------------------------------------
// Model dictionary — normally auto-generated in brick.g.dart
// ---------------------------------------------------------------------------

/// Registry of all model adapters.
///
/// In a code-generated project this constant is generated as
/// `odooModelDictionary` inside `brick.g.dart`.
const _modelDictionary = OdooModelDictionary({
  Partner: PartnerAdapter(),
});

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

/// Concrete offline-first repository for [Partner].
///
/// Subclass [OfflineFirstWithOdooRepository] and implement the four local-
/// storage methods using your Drift database.
class PartnerRepository
    extends OfflineFirstWithOdooRepository<OfflineFirstWithOdooModel> {
  final AppDatabase _db;

  PartnerRepository({
    required AppDatabase db,
    required super.remoteProvider,
    required super.syncManager,
  }) : _db = db,
       super(loggerName: 'PartnerRepository');

  @override
  OdooModelDictionary get modelDictionary => _modelDictionary;

  // ── Local storage (Drift) ─────────────────────────────────────────────────

  @override
  Future<List<T>> getLocal<T extends OfflineFirstWithOdooModel>({
    Query? query,
  }) async {
    if (T == Partner) {
      final rows = await _db.select(_db.partners).get();
      return rows.map(_rowToPartner).toList().cast<T>();
    }
    throw UnsupportedError('No local handler for $T');
  }

  @override
  Future<bool> existsLocal<T extends OfflineFirstWithOdooModel>({
    Query? query,
  }) async {
    if (T == Partner) {
      final count = await _db.select(_db.partners).get();
      return count.isNotEmpty;
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

  // ── Helpers ───────────────────────────────────────────────────────────────

  Partner _rowToPartner(PartnersData row) => Partner(
        odooId: row.odooId,
        name: row.name,
        email: row.email,
        phone: row.phone,
        isCompany: row.isCompany,
      );
}

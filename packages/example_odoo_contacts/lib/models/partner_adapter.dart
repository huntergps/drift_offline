// HAND-WRITTEN ADAPTER — illustrates what `drift_offline_first_with_odoo_build`
// generates from the @ConnectOfflineFirstWithOdoo + @Odoo annotations.
//
// In a real project this file is named `partner.adapter_build_odoo.dart` and
// is committed (or .gitignored) after running:
//   dart run build_runner build

import 'package:drift_odoo/drift_odoo.dart';
import 'package:drift_offline_first_with_odoo/drift_offline_first_with_odoo.dart';

import 'partner.dart';

/// Generated adapter for [Partner] ↔ Odoo `res.partner`.
class PartnerAdapter extends OfflineFirstWithOdooAdapter<Partner> {
  const PartnerAdapter();

  @override
  String get odooModel => 'res.partner';

  // Always includes 'id' and 'write_date' plus every non-ignored field.
  @override
  List<String> get odooFields => const [
        'id',
        'write_date',
        'name',
        'email',
        'phone',
        'is_company',
      ];

  @override
  Future<Partner> fromOdoo(
    Map<String, dynamic> data, {
    required OdooOfflineQueueClient provider,
    OfflineFirstWithOdooRepository? repository,
  }) async {
    return Partner(
      odooId: data['id'] as int?,
      // Odoo returns `false` (not null) for empty fields — coerce to null.
      name: data['name'] as String? ?? '',
      email: data['email'] == false ? null : data['email'] as String?,
      phone: data['phone'] == false ? null : data['phone'] as String?,
      isCompany: data['is_company'] as bool? ?? false,
    );
  }

  @override
  Future<Map<String, dynamic>> toOdoo(
    Partner instance, {
    required OdooOfflineQueueClient provider,
    OfflineFirstWithOdooRepository? repository,
  }) async {
    return {
      'name': instance.name,
      if (instance.email != null) 'email': instance.email,
      if (instance.phone != null) 'phone': instance.phone,
      'is_company': instance.isCompany,
    };
  }
}

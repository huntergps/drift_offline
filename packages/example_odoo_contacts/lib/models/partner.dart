import 'package:drift_odoo_core/drift_odoo_core.dart';
import 'package:drift_offline_first_with_odoo/drift_offline_first_with_odoo.dart';

// Step 1 — Annotate your model.
//
// In a real project you'd run:
//   dart run build_runner build
//
// …and the generator produces PartnerAdapter + registers it in the
// OdooModelDictionary.  For this self-contained example the adapter is
// written by hand in partner_adapter.dart so you can run `dart bin/main.dart`
// without build_runner.

@ConnectOfflineFirstWithOdoo(
  odooConfig: OdooSerializable(odooModel: 'res.partner'),
)
class Partner extends OfflineFirstWithOdooModel {
  final String name;

  @Odoo(name: 'email')
  final String? email;

  @Odoo(name: 'phone')
  final String? phone;

  /// Whether this contact is a company (vs an individual).
  @Odoo(name: 'is_company')
  final bool isCompany;

  Partner({
    required this.name,
    this.email,
    this.phone,
    this.isCompany = false,
    super.odooId,
  });

  @override
  String toString() =>
      'Partner(id=$odooId, name=$name, email=$email, isCompany=$isCompany)';
}

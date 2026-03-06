import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:drift_offline_first_with_odoo_build/drift_offline_first_with_odoo_build.dart';
import 'package:test/test.dart';

/// Source with a simple model — scalar fields only.
const _simpleModelSrc = r'''
library;

import 'package:drift_offline_first_with_odoo/drift_offline_first_with_odoo.dart';
import 'package:drift_odoo_core/drift_odoo_core.dart';

@ConnectOfflineFirstWithOdoo(odooConfig: OdooSerializable(odooModel: 'res.partner'))
class Partner extends OfflineFirstWithOdooModel {
  final String name;

  @Odoo(name: 'email')
  final String? email;

  @Odoo(name: 'is_company')
  final bool isCompany;

  @Odoo(ignore: true)
  final String localNote;

  Partner({
    required this.name,
    this.email,
    this.isCompany = false,
    this.localNote = '',
    super.odooId,
  });
}
''';

/// Source with an enum field using enumAsString.
const _enumModelSrc = r'''
library;

import 'package:drift_offline_first_with_odoo/drift_offline_first_with_odoo.dart';
import 'package:drift_odoo_core/drift_odoo_core.dart';

enum PartnerType { person, company }

@ConnectOfflineFirstWithOdoo(odooConfig: OdooSerializable(odooModel: 'res.partner'))
class Partner extends OfflineFirstWithOdooModel {
  final String name;

  @Odoo(enumAsString: true)
  final PartnerType type;

  Partner({required this.name, required this.type, super.odooId});
}
''';

/// Source with a nullable DateTime field.
const _dateModelSrc = r'''
library;

import 'package:drift_offline_first_with_odoo/drift_offline_first_with_odoo.dart';
import 'package:drift_odoo_core/drift_odoo_core.dart';

@ConnectOfflineFirstWithOdoo(odooConfig: OdooSerializable(odooModel: 'crm.lead'))
class Lead extends OfflineFirstWithOdooModel {
  final String name;

  @Odoo(name: 'date_deadline')
  final DateTime? deadline;

  Lead({required this.name, this.deadline, super.odooId});
}
''';

/// Source with a custom fromGenerator expression.
const _customGeneratorSrc = r'''
library;

import 'package:drift_offline_first_with_odoo/drift_offline_first_with_odoo.dart';
import 'package:drift_odoo_core/drift_odoo_core.dart';

@ConnectOfflineFirstWithOdoo(odooConfig: OdooSerializable(odooModel: 'res.currency'))
class Currency extends OfflineFirstWithOdooModel {
  final String name;

  @Odoo(fromGenerator: "data['symbol'] as String? ?? '?'")
  final String symbol;

  Currency({required this.name, required this.symbol, super.odooId});
}
''';

void main() {
  group('offlineFirstAdaptersBuilder', () {
    test('generates fromOdoo and toOdoo methods for scalar fields', () async {
      await testBuilder(
        offlineFirstAdaptersBuilder(BuilderOptions.empty),
        {'test_pkg|lib/partner.dart': _simpleModelSrc},
        outputs: {
          'test_pkg|lib/partner.odoo_adapter.g.dart': allOf(
            // Method signatures
            contains('fromOdoo'),
            contains('toOdoo'),
            // fromOdoo reads Odoo field names from the response map
            contains("data['name']"),
            contains("data['email']"),
            contains("data['is_company']"),
            // toOdoo writes Dart instance fields
            contains('instance.name'),
            contains('instance.isCompany'),
            // @Odoo(ignore: true) field must NOT appear
            isNot(contains('localNote')),
            // odooId is assigned via generateSuffix (cascade notation)
            contains('odooId = data['),
            // Adapter declares the odooFields getter
            contains('odooFields'),
            // Adapter records the Odoo model name
            contains("'res.partner'"),
          ),
        },
      );
    });

    test('enum field uses .byName() for string enums', () async {
      await testBuilder(
        offlineFirstAdaptersBuilder(BuilderOptions.empty),
        {'test_pkg|lib/partner.dart': _enumModelSrc},
        outputs: {
          'test_pkg|lib/partner.odoo_adapter.g.dart': allOf(
            contains('fromOdoo'),
            // Deserialization: PartnerType.values.byName(raw)
            contains('.values.byName('),
            // Serialization: instance.type.name
            contains('.name'),
          ),
        },
      );
    });

    test('nullable DateTime parses Odoo string format', () async {
      await testBuilder(
        offlineFirstAdaptersBuilder(BuilderOptions.empty),
        {'test_pkg|lib/lead.dart': _dateModelSrc},
        outputs: {
          'test_pkg|lib/lead.odoo_adapter.g.dart': allOf(
            contains('fromOdoo'),
            // Reads from the renamed Odoo field
            contains("data['date_deadline']"),
            // Guards against Odoo's false / null
            contains('== false'),
            // Parses with the space→T replacement
            contains('DateTime.parse'),
            contains("replaceFirst(' ', 'T')"),
            // Serializes back with T→space
            contains("replaceFirst('T', ' ')"),
          ),
        },
      );
    });

    test('custom fromGenerator expression is emitted verbatim', () async {
      await testBuilder(
        offlineFirstAdaptersBuilder(BuilderOptions.empty),
        {'test_pkg|lib/currency.dart': _customGeneratorSrc},
        outputs: {
          'test_pkg|lib/currency.odoo_adapter.g.dart': allOf(
            contains('fromOdoo'),
            // The custom expression must appear unchanged
            contains("data['symbol'] as String? ?? '?'"),
          ),
        },
      );
    });
  });
}

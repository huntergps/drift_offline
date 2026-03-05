import 'package:build/build.dart';
import 'package:drift_build/builders.dart';
import 'package:drift_offline_first_with_odoo/drift_offline_first_with_odoo.dart';

import 'src/offline_first_model_dictionary_generator.dart';
import 'src/offline_first_with_odoo_generator.dart';

const _generator = OfflineFirstWithOdooGenerator(
  superAdapterName: 'OfflineFirstWithOdoo',
  repositoryName: 'OfflineFirstWithOdoo',
);

/// Aggregates all model files annotated with @ConnectOfflineFirstWithOdoo
/// into a single file before the adapter/dictionary builders run.
Builder offlineFirstAggregateBuilder(BuilderOptions options) =>
    const AggregateBuilder(
      requiredImports: [
        "import 'package:drift_offline_first_with_odoo/drift_offline_first_with_odoo.dart';",
        "import 'package:drift_odoo_core/drift_odoo_core.dart';",
      ],
    );

/// Generates `*_adapter.g.dart` files with fromOdoo/toOdoo for each model.
Builder offlineFirstAdaptersBuilder(BuilderOptions options) =>
    adapterBuilder(_generator);

/// Generates `odoo.g.dart` with `odooMappings` and `odooModelDictionary`.
Builder offlineFirstModelDictionaryBuilder(BuilderOptions options) =>
    ModelDictionaryBuilder<ConnectOfflineFirstWithOdoo>(
      const OfflineFirstModelDictionaryGenerator(),
      expectedImportRemovals: [
        "import 'package:drift_offline_first_with_odoo/drift_offline_first_with_odoo.dart';",
        'import "package:drift_offline_first_with_odoo/drift_offline_first_with_odoo.dart";',
      ],
    );

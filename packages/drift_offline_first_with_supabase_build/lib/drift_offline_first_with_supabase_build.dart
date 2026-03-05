import 'package:drift_build/builders.dart';
import 'package:build/build.dart';
import 'package:drift_offline_first_with_supabase/drift_offline_first_with_supabase.dart';

import 'src/offline_first_model_dictionary_generator.dart';
import 'src/offline_first_with_supabase_generator.dart';

const _generator = OfflineFirstWithSupabaseGenerator(
  superAdapterName: 'OfflineFirstWithSupabase',
  repositoryName: 'OfflineFirstWithSupabase',
);

/// Aggregates all model files annotated with @ConnectOfflineFirstWithSupabase
/// into a single file before the adapter/dictionary builders run.
Builder offlineFirstAggregateBuilder(BuilderOptions options) =>
    const AggregateBuilder(
      requiredImports: [
        "import 'package:drift_offline_first_with_supabase/drift_offline_first_with_supabase.dart';",
        "import 'package:drift_supabase/drift_supabase.dart';",
      ],
    );

/// Generates `*_adapter.g.dart` files with fromSupabase/toSupabase for each model.
Builder offlineFirstAdaptersBuilder(BuilderOptions options) =>
    AdapterBuilder<ConnectOfflineFirstWithSupabase>(_generator);

/// Generates `supabase.g.dart` with `supabaseMappings` and `supabaseModelDictionary`.
Builder offlineFirstModelDictionaryBuilder(BuilderOptions options) =>
    ModelDictionaryBuilder<ConnectOfflineFirstWithSupabase>(
      const OfflineFirstModelDictionaryGenerator(),
      expectedImportRemovals: [
        "import 'package:drift_offline_first_with_supabase/drift_offline_first_with_supabase.dart';",
        'import "package:drift_offline_first_with_supabase/drift_offline_first_with_supabase.dart";',
      ],
    );

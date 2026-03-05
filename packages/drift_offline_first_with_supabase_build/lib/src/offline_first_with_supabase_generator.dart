import 'package:analyzer/dart/element/element.dart';
import 'package:drift_build/generators.dart';
import 'package:drift_offline_first_with_supabase/drift_offline_first_with_supabase.dart';
import 'package:source_gen/source_gen.dart';

import 'offline_first_supabase_generators.dart';

/// Top-level generator: discovers all `@ConnectOfflineFirstWithSupabase` classes
/// and delegates to [OfflineFirstSupabaseModelSerdesGenerator].
class OfflineFirstWithSupabaseGenerator
    extends AnnotationSuperGenerator<ConnectOfflineFirstWithSupabase> {
  final String repositoryName;

  @override
  final String superAdapterName;

  const OfflineFirstWithSupabaseGenerator({
    String? repositoryName,
    String? superAdapterName,
  })  : repositoryName = repositoryName ?? 'OfflineFirstWithSupabase',
        superAdapterName = superAdapterName ?? 'OfflineFirstWithSupabase';

  @override
  List<SerdesGenerator> buildGenerators(
    Element element,
    ConstantReader annotation,
  ) {
    final supabase = OfflineFirstSupabaseModelSerdesGenerator(
      element,
      annotation,
      repositoryName: repositoryName,
    );
    return supabase.generators;
  }
}

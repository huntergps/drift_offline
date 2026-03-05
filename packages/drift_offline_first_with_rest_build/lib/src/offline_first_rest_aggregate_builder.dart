import 'package:brick_build/generators.dart';
import 'package:build/build.dart';
import 'package:drift_offline_first_with_rest/drift_offline_first_with_rest.dart';
import 'package:source_gen/source_gen.dart';

import 'offline_first_with_rest_generator.dart';

/// Aggregates all `@ConnectOfflineFirstWithRest` classes across the library
/// into a single `lib/app/brick.g.dart` part file.
///
/// This file is then consumed by [restModelDictionaryBuilder].
Builder restAggregateBuilder(BuilderOptions options) => LibraryBuilder(
      AggregateRestGenerator(),
      generatedExtension: '.aggregate_rest.dart',
    );

class AggregateRestGenerator
    extends AnnotationSuperGenerator<ConnectOfflineFirstWithRest> {
  @override
  final String providerName = 'Rest';

  @override
  final String repositoryName = 'OfflineFirstWithRest';

  const AggregateRestGenerator();

  @override
  List<SerdesGenerator> buildGenerators(element, annotation) => [];
}

import 'package:drift_build/generators.dart';
import 'package:drift_offline_first_with_rest/drift_offline_first_with_rest.dart';
import 'package:source_gen/source_gen.dart';

import 'offline_first_with_rest_generator.dart';

/// [SharedPartBuilder] that emits the `.rest.dart` part file for every
/// class annotated with `@ConnectOfflineFirstWithRest`.
Builder restAdaptersBuilder(BuilderOptions options) => SharedPartBuilder(
      [OfflineFirstWithRestGenerator()],
      'rest_adapters',
      additionalOutputExtensions: ['.rest.dart'],
    );

import 'package:analyzer/dart/element/element.dart';
import 'package:brick_build/generators.dart';
import 'package:drift_offline_first_with_odoo/drift_offline_first_with_odoo.dart';

import 'offline_first_odoo_generators.dart';

/// Top-level generator: discovers all `@ConnectOfflineFirstWithOdoo` classes
/// and delegates to [OfflineFirstOdooModelSerdesGenerator].
class OfflineFirstWithOdooGenerator
    extends AnnotationSuperGenerator<ConnectOfflineFirstWithOdoo> {
  final String repositoryName;

  @override
  final String superAdapterName;

  const OfflineFirstWithOdooGenerator({
    String? repositoryName,
    String? superAdapterName,
  })  : repositoryName = repositoryName ?? 'OfflineFirstWithOdoo',
        superAdapterName = superAdapterName ?? 'OfflineFirstWithOdoo';

  @override
  List<SerdesGenerator> buildGenerators(
    Element element,
    ConstantReader annotation,
  ) {
    final odoo = OfflineFirstOdooModelSerdesGenerator(
      element,
      annotation,
      repositoryName: repositoryName,
    );
    return odoo.generators;
  }
}

import 'package:analyzer/dart/element/element.dart';
import 'package:drift_build/generators.dart';
import 'package:drift_offline_first_with_rest/drift_offline_first_with_rest.dart';
import 'package:drift_rest/drift_rest.dart';
import 'package:drift_rest_generators/generators.dart';
import 'package:source_gen/source_gen.dart';

/// Generates the concrete `RestAdapter` subclass for a single
/// `@ConnectOfflineFirstWithRest`-annotated class.
class OfflineFirstWithRestGenerator
    extends AnnotationSuperGenerator<ConnectOfflineFirstWithRest> {
  @override
  final String providerName = 'Rest';

  @override
  final String repositoryName = 'OfflineFirstWithRest';

  const OfflineFirstWithRestGenerator();

  @override
  List<SerdesGenerator> buildGenerators(
    ClassElement element,
    ConstantReader annotation,
  ) {
    final restAnnotation = annotation.read('restConfig');
    final config = RestSerializableExtended.fromAnnotation(
      restAnnotation,
      element,
    );
    final fields = RestFields(element, config);

    return [
      RestDeserialize(element, fields, config: config),
      RestSerialize(element, fields, config: config),
    ];
  }

  /// Returns the extra adapter members (e.g. `restRequest` getter).
  String adapterExtras(ClassElement element, RestSerializableExtended config) {
    if (config.requestName == null) return '';
    return '''
  @override
  ${config.requestName} Function(Map<String, dynamic>? params, ${element.name}? instance)?
      get restRequest => ${config.requestName}.new;
''';
  }
}

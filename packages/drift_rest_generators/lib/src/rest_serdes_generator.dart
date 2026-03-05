import 'package:analyzer/dart/element/element.dart';
import 'package:drift_build/generators.dart';
import 'package:drift_rest/drift_rest.dart';
import 'package:source_gen/source_gen.dart';

import 'rest_deserialize.dart';
import 'rest_fields.dart';
import 'rest_serialize.dart';
import 'rest_serializable_extended.dart';

/// Generates the `RestAdapter` subclass (both `fromRest` and `toRest`),
/// plus the `restRequest` getter when a transformer was specified.
class RestModelSerdesGenerator extends AnnotationSuperGenerator<RestSerializable> {
  @override
  final String providerName = 'Rest';

  @override
  final String repositoryName = 'OfflineFirstWithRest';

  const RestModelSerdesGenerator();

  @override
  List<SerdesGenerator> buildGenerators(
    ClassElement element,
    ConstantReader annotation,
  ) {
    final config = RestSerializableExtended.fromAnnotation(annotation, element);
    final fields = RestFields(element, config);

    return [
      RestDeserialize(element, fields, config: config),
      RestSerialize(element, fields, config: config),
    ];
  }

  /// Emits the `restRequest` getter on the adapter, wiring the transformer.
  String adapterExtras(
    ClassElement element,
    RestSerializableExtended config,
  ) {
    if (config.requestName == null) return '';

    return '''
  @override
  ${config.requestName} Function(Map<String, dynamic>? params, ${element.name}? instance)?
      get restRequest => ${config.requestName}.new;
''';
  }
}

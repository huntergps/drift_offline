import 'package:analyzer/dart/element/element.dart';
import 'package:brick_build/generators.dart';
import 'package:drift_rest/drift_rest.dart';
import 'package:source_gen/source_gen.dart';

import 'src/rest_deserialize.dart';
import 'src/rest_fields.dart';
import 'src/rest_serdes_generator.dart';
import 'src/rest_serialize.dart';
import 'src/rest_serializable_extended.dart';

/// Top-level generator that the `build_runner` builder factory hands off to.
///
/// For each class annotated with `@ConnectOfflineFirstWithRest`, this emits a
/// concrete `RestAdapter` subclass with `fromRest`, `toRest`, and optionally
/// a `restRequest` getter.
class RestModelSerdesGenerator
    extends AnnotationSuperGenerator<RestSerializable> {
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
}

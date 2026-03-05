import 'package:drift_build/generators.dart';
import 'package:brick_json_generators/brick_json_generators.dart';
import 'package:drift_rest/drift_rest.dart';

import 'rest_fields.dart';
import 'rest_serializable_extended.dart';

/// Generates the `fromRest` deserializer method body.
class RestDeserialize extends RestSerdesGenerator
    with JsonDeserialize<RestModel, Rest> {
  RestDeserialize(
    super.element,
    super.fields, {
    required super.config,
  });
}

/// Base class shared by [RestDeserialize] and [RestSerialize].
abstract class RestSerdesGenerator
    extends JsonSerdesGenerator<RestModel, Rest> {
  final RestSerializableExtended config;

  RestSerdesGenerator(
    super.element,
    RestFields super.fields, {
    required this.config,
  }) : super(
          providerName: 'Rest',
          repositoryName: 'OfflineFirstWithRest',
        );
}

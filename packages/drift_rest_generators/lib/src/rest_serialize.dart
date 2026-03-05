import 'package:brick_build/generators.dart';
import 'package:brick_json_generators/brick_json_generators.dart';
import 'package:drift_rest/drift_rest.dart';

import 'rest_deserialize.dart';
import 'rest_fields.dart';
import 'rest_serializable_extended.dart';

/// Generates the `toRest` serializer method body.
class RestSerialize extends RestSerdesGenerator
    with JsonSerialize<RestModel, Rest> {
  RestSerialize(
    super.element,
    RestFields super.fields, {
    required super.config,
  });
}

import 'package:brick_core/field_serializable.dart';

/// Annotation for configuring how a field is serialized to/from a REST API.
///
/// ```dart
/// class User extends OfflineFirstWithRestModel {
///   @Rest(name: 'first_name')
///   final String firstName;
///
///   @Rest(ignore: true)
///   final String localOnly;
///
///   @Rest(enumAsString: true)
///   final Role role;
/// }
/// ```
class Rest implements FieldSerializable {
  @override
  final String? name;

  @override
  final bool ignore;

  @override
  final bool ignoreFrom;

  @override
  final bool ignoreTo;

  /// Treat enums as their string name rather than their index.
  @override
  final bool enumAsString;

  @override
  final String? defaultValue;

  @override
  final String? fromGenerator;

  @override
  final String? toGenerator;

  const Rest({
    this.name,
    bool? ignore,
    bool? ignoreFrom,
    bool? ignoreTo,
    bool? enumAsString,
    this.defaultValue,
    this.fromGenerator,
    this.toGenerator,
  })  : ignore = ignore ?? false,
        ignoreFrom = ignoreFrom ?? false,
        ignoreTo = ignoreTo ?? false,
        enumAsString = enumAsString ?? false;

  static const defaults = Rest();
}

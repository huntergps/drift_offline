import 'package:analyzer/dart/element/element.dart';
import 'package:source_gen/source_gen.dart';

import 'serdes_generator.dart';

/// Reads a provider-specific config object from a class-level annotation and
/// produces the [SerdesGenerator]s for that class.
///
/// Example — reading `odooConfig` from `@ConnectOfflineFirstWithOdoo(odooConfig: ...)`:
/// ```dart
/// class OdooModelSerdesGenerator
///     extends ProviderSerializableGenerator<OdooSerializable> {
///   OdooModelSerdesGenerator(super.element, super.reader, {super.repositoryName})
///       : super(configKey: 'odooConfig');
/// }
/// ```
abstract class ProviderSerializableGenerator<TConfig> {
  /// The annotated class element.
  final Element element;

  /// [ConstantReader] for the class-level annotation.
  final ConstantReader reader;

  /// The key within the annotation that holds the provider config object.
  final String configKey;

  /// Optional suffix used to derive the repository type name.
  final String? repositoryName;

  const ProviderSerializableGenerator(
    this.element,
    this.reader, {
    required this.configKey,
    this.repositoryName,
  });

  /// The resolved provider config.
  TConfig get config;

  /// The [SerdesGenerator]s to run for this class.
  List<SerdesGenerator<dynamic>> get generators;

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Peek a value nested under [configKey] → [key] in the annotation.
  ///
  /// Returns `null` when the config key is absent or when [key] is not set.
  ConstantReader? withinConfigKey(String key) {
    final configReader = reader.peek(configKey);
    if (configReader == null || configReader.isNull) return null;
    return configReader.peek(key);
  }
}

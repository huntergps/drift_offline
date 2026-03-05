import 'package:analyzer/dart/element/element.dart';
import 'package:brick_json_generators/json_serialize.dart';
import 'package:drift_supabase/drift_supabase.dart';

import 'supabase_fields.dart';
import 'supabase_serdes_generator.dart';

/// Generates the `toSupabase` method and adapter metadata for a [SupabaseModel].
class SupabaseSerialize extends SupabaseSerdesGenerator
    with JsonSerialize<SupabaseModel, Supabase> {
  SupabaseSerialize(
    super.element,
    super.fields, {
    required super.repositoryName,
  });

  @override
  List<String> get instanceFieldsAndMethods {
    final config = (fields as SupabaseFields).config;
    final fieldsToColumns = <String>[];
    final uniqueFields = <String>{};

    for (final field in unignoredFields) {
      final annotation = fields.annotationForField(field);
      final checker = checkerForType(field.type);
      final columnName = providerNameForField(annotation.name, checker: checker);
      final isAssociation = checker.isSibling || (checker.isIterable && checker.isArgTypeASibling);

      var definition = '''
        '${field.name}': const RuntimeSupabaseColumnDefinition(
          association: $isAssociation,
          columnName: '$columnName',
      ''';
      if (isAssociation) definition += 'associationType: ${checker.withoutNullResultType},';
      if (isAssociation) definition += 'associationIsNullable: ${checker.isNullable},';
      if (annotation.foreignKey != null) definition += "foreignKey: '${annotation.foreignKey}',";
      if (annotation.query != null) definition += "query: '''${annotation.query}''',";
      definition += ')';
      fieldsToColumns.add(definition);

      if (annotation.unique) uniqueFields.add(field.name!);
    }

    return [
      if (config?.defaultToNull != null)
        '@override\nfinal bool defaultToNull = ${config!.defaultToNull};',
      '@override\nfinal Map<String, RuntimeSupabaseColumnDefinition> fieldsToSupabaseColumns = {${fieldsToColumns.join(',\n')}};',
      '@override\nfinal bool ignoreDuplicates = ${config?.ignoreDuplicates ?? false};',
      if (config?.onConflict != null)
        "@override\nfinal String? onConflict = '${config!.onConflict}';",
      '@override\nfinal Set<String> uniqueFields = {${uniqueFields.map((u) => "'$u'").join(',\n')}};',
    ];
  }
}

import 'package:analyzer/dart/element/element.dart';
import 'package:brick_build/generators.dart';
import 'package:brick_core/field_rename.dart';
import 'package:drift_supabase/drift_supabase.dart';

import 'src/supabase_deserialize.dart';
import 'src/supabase_fields.dart';
import 'src/supabase_serialize.dart';

/// Reads `supabaseConfig` from an annotation (e.g. `@ConnectOfflineFirstWithSupabase`)
/// and produces [SupabaseDeserialize] + [SupabaseSerialize] generators.
class SupabaseModelSerdesGenerator
    extends ProviderSerializableGenerator<SupabaseSerializable> {
  final String? repositoryName;

  SupabaseModelSerdesGenerator(
    super.element,
    super.reader, {
    this.repositoryName,
  }) : super(configKey: 'supabaseConfig');

  @override
  SupabaseSerializable get config {
    if (reader.peek(configKey) == null) return SupabaseSerializable.defaults;

    final fieldRenameIndex =
        withinConfigKey('fieldRename')?.objectValue.getField('index')?.toIntValue();
    final fieldRename =
        fieldRenameIndex != null ? FieldRename.values[fieldRenameIndex] : null;

    return SupabaseSerializable(
      fieldRename: fieldRename ?? SupabaseSerializable.defaults.fieldRename,
      tableName: withinConfigKey('tableName')?.stringValue ??
          StringHelpers.snakeCase('${element.displayName}s'),
      onConflict:
          withinConfigKey('onConflict')?.stringValue,
      ignoreDuplicates: withinConfigKey('ignoreDuplicates')?.boolValue ??
          SupabaseSerializable.defaults.ignoreDuplicates,
      defaultToNull: withinConfigKey('defaultToNull')?.boolValue ??
          SupabaseSerializable.defaults.defaultToNull,
    );
  }

  @override
  List<SerdesGenerator> get generators {
    final classElement = element as ClassElement;
    final fields = SupabaseFields(classElement, config);
    return [
      SupabaseDeserialize(classElement, fields, repositoryName: repositoryName!),
      SupabaseSerialize(classElement, fields, repositoryName: repositoryName!),
    ];
  }
}

import 'package:analyzer/dart/element/element.dart';
import 'package:drift_build/generators.dart';
import 'package:drift_supabase/drift_supabase.dart';

/// Finds `@Supabase` on a field element and returns its configuration.
class SupabaseAnnotationFinder extends AnnotationFinder<Supabase>
    with AnnotationFinderWithFieldRename<Supabase> {
  final SupabaseSerializable? config;

  SupabaseAnnotationFinder([this.config]);

  @override
  Supabase from(FieldElement element) {
    final obj = objectForField(element);

    if (obj == null) {
      return Supabase(
        name: renameField(
          element.name!,
          config?.fieldRename,
          SupabaseSerializable.defaults.fieldRename,
        ),
      );
    }

    return Supabase(
      defaultValue: obj.getField('defaultValue')!.toStringValue(),
      enumAsString:
          obj.getField('enumAsString')!.toBoolValue() ?? Supabase.defaults.enumAsString,
      foreignKey: obj.getField('foreignKey')!.toStringValue(),
      fromGenerator: obj.getField('fromGenerator')!.toStringValue(),
      ignore: obj.getField('ignore')!.toBoolValue() ?? Supabase.defaults.ignore,
      ignoreFrom:
          obj.getField('ignoreFrom')!.toBoolValue() ?? Supabase.defaults.ignoreFrom,
      ignoreTo: obj.getField('ignoreTo')!.toBoolValue() ?? Supabase.defaults.ignoreTo,
      name: obj.getField('name')?.toStringValue() ??
          renameField(
            element.name!,
            config?.fieldRename,
            SupabaseSerializable.defaults.fieldRename,
          ),
      query: obj.getField('query')?.toStringValue(),
      toGenerator: obj.getField('toGenerator')!.toStringValue(),
      unique: obj.getField('unique')!.toBoolValue() ?? Supabase.defaults.unique,
    );
  }
}

/// Collects all fields from a class element, annotating each with [Supabase].
class SupabaseFields extends FieldsForClass<Supabase> {
  @override
  final SupabaseAnnotationFinder finder;

  final SupabaseSerializable? config;

  SupabaseFields(ClassElement element, [this.config])
      : finder = SupabaseAnnotationFinder(config),
        super(element: element);
}

import 'package:brick_core/field_rename.dart';

/// Class-level annotation configuring Supabase serialization.
///
/// Example:
/// ```dart
/// @ConnectOfflineFirstWithSupabase(
///   supabaseConfig: SupabaseSerializable(
///     tableName: 'users',
///     onConflict: 'id',
///   ),
/// )
/// class User extends OfflineFirstWithSupabaseModel { ... }
/// ```
class SupabaseSerializable {
  /// Naming strategy for fields not annotated with `@Supabase(name:)`.
  /// Defaults to [FieldRename.snake].
  final FieldRename fieldRename;

  /// The Supabase table name. Defaults to snake_case class name + trailing 's'.
  /// For example, `User` → `users`.
  final String? tableName;

  /// Column(s) to use for ON CONFLICT resolution during upserts.
  /// Comma-separated Supabase column names, e.g. `'id'` or `'email,tenant_id'`.
  final String? onConflict;

  /// Forward to Supabase's `ignoreDuplicates` upsert parameter.
  final bool ignoreDuplicates;

  /// Forward to Supabase's `defaultToNull` upsert parameter.
  final bool defaultToNull;

  const SupabaseSerializable({
    this.fieldRename = FieldRename.snake,
    this.tableName,
    this.onConflict,
    this.ignoreDuplicates = false,
    this.defaultToNull = true,
  });

  static const defaults = SupabaseSerializable();
}

import 'package:drift_supabase/drift_supabase.dart';

/// Annotation that triggers code generation for a model backed by both
/// Drift (local) and Supabase (remote).
///
/// Example:
/// ```dart
/// @ConnectOfflineFirstWithSupabase(
///   supabaseConfig: SupabaseSerializable(
///     tableName: 'users',
///     onConflict: 'id',
///   ),
/// )
/// class User extends OfflineFirstWithSupabaseModel {
///   @Supabase(unique: true)
///   final String? id;
///
///   final String email;
///
///   User({this.id, required this.email});
/// }
/// ```
class ConnectOfflineFirstWithSupabase {
  /// Supabase-specific serialization settings for this model.
  final SupabaseSerializable? supabaseConfig;

  const ConnectOfflineFirstWithSupabase({this.supabaseConfig});

  static const defaults = ConnectOfflineFirstWithSupabase(
    supabaseConfig: SupabaseSerializable.defaults,
  );
}

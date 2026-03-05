import 'package:drift/drift.dart';

// ---------------------------------------------------------------------------
// Table definition
// ---------------------------------------------------------------------------

/// Local SQLite table for res.partner.
class Partners extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().nullable()();
  TextColumn get name => text()();
  TextColumn get email => text().nullable()();
  TextColumn get phone => text().nullable()();
  BoolColumn get isCompany => boolean().withDefault(const Constant(false))();
}

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------

@DriftDatabase(tables: [Partners])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;
}

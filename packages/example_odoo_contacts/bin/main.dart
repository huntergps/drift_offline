/// Offline-first Odoo contacts example.
///
/// Demonstrates:
///   1. Wiring up the OdooClient with offline-queue support.
///   2. Creating an OdooSyncManager backed by an in-memory SQLite database.
///   3. Building the PartnerRepository.
///   4. Fetching contacts with different OfflineFirstGetPolicy values.
///   5. Upserting and deleting a contact.
///
/// To run against a real Odoo server, replace the environment variables:
///   ODOO_URL, ODOO_API_KEY (and optionally ODOO_DB).
///
/// Without a real server the example demonstrates the local-only policies
/// and the structure of the repository API.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:drift_odoo/drift_odoo.dart';
import 'package:drift_offline_first/drift_offline_first.dart';
import 'package:drift_offline_first_with_odoo/drift_offline_first_with_odoo.dart';
import 'package:logging/logging.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:example_odoo_contacts/db/app_database.dart';
import 'package:example_odoo_contacts/models/partner.dart';
import 'package:example_odoo_contacts/repository/partner_repository.dart';

void main() async {
  // ── Logging ────────────────────────────────────────────────────────────────
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((r) => stderr.writeln('[${r.level}] ${r.message}'));

  // ── sqflite_common_ffi (required on desktop / CI) ─────────────────────────
  sqfliteFfiInit();

  // ── Local Drift database (in-memory for this demo) ─────────────────────────
  final db = AppDatabase(NativeDatabase.memory());

  // ── OdooClient ─────────────────────────────────────────────────────────────
  // Replace these values with real credentials to test against a live server.
  final baseUrl = Platform.environment['ODOO_URL'] ?? 'https://demo.odoo.com';
  final apiKey = Platform.environment['ODOO_API_KEY'] ?? 'demo-key';
  final database = Platform.environment['ODOO_DB'];

  final rawClient = OdooClient(
    baseUrl: baseUrl,
    apiKey: apiKey,
    database: database,
  );

  // Wrap with offline-queue support: mutations are persisted to SQLite and
  // retried when connectivity is restored.
  final queuedClient = OdooOfflineQueueClient(
    client: rawClient,
    // Use a dedicated database file for the queue in production:
    // requestManager: OdooRequestSqliteCacheManager(
    //   NativeDatabase.createInBackground(File('offline_queue.db')),
    // ),
    requestManager: OdooRequestSqliteCacheManager(NativeDatabase.memory()),
  );

  // ── SyncManager ────────────────────────────────────────────────────────────
  // Tracks last-sync timestamps to enable incremental hydration.
  // Use NativeDatabase.createInBackground(File('sync_state.db')) in production.
  final syncManager = OdooSyncManager(NativeDatabase.memory());

  // ── Repository ─────────────────────────────────────────────────────────────
  final repo = PartnerRepository(
    db: db,
    remoteProvider: queuedClient,
    syncManager: syncManager,
  );

  await repo.initialize();

  // ── Demo: local-only operations (no network needed) ──────────────────────

  print('\n--- upsert (localOnly) ---');
  final alice = Partner(name: 'Alice', email: 'alice@example.com', odooId: 1);
  await repo.upsert(alice, policy: OfflineFirstUpsertPolicy.localOnly);

  final bob = Partner(name: 'Bob', isCompany: true, odooId: 2);
  await repo.upsert(bob, policy: OfflineFirstUpsertPolicy.localOnly);

  print('\n--- get (localOnly) ---');
  final contacts = await repo.get<Partner>(
    policy: OfflineFirstGetPolicy.localOnly,
  );
  for (final c in contacts) {
    print('  $c');
  }

  print('\n--- delete (localOnly) ---');
  await repo.delete(alice, policy: OfflineFirstDeletePolicy.localOnly);
  final afterDelete = await repo.get<Partner>(
    policy: OfflineFirstGetPolicy.localOnly,
  );
  print('Remaining after delete: ${afterDelete.length} contacts');

  // ── Demo: awaitRemoteWhenNoneExist ─────────────────────────────────────────
  // Would contact the Odoo server if no local records exist.
  // With invalid credentials it will gracefully fall back to local cache.
  print('\n--- get (awaitRemoteWhenNoneExist) ---');
  final cached = await repo.get<Partner>(
    policy: OfflineFirstGetPolicy.awaitRemoteWhenNoneExist,
  );
  print('Total contacts after optional remote hydration: ${cached.length}');

  // ── Cleanup ────────────────────────────────────────────────────────────────
  await repo.dispose();
  await syncManager.close();
  await db.close();

  print('\nDone.');
}

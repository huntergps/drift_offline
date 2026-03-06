# drift_offline

Librería de persistencia offline-first para Flutter/Dart que combina **Drift** (SQLite local) con backends remotos como **Odoo**, REST y Supabase.

Inspirada en [Brick](https://github.com/GetDutchie/brick), pero construida sobre Drift en lugar de sqflite, aprovechando su sistema de migraciones, queries reactivos (`watchAll`) y soporte multiplataforma (Android, iOS, macOS, Windows, Linux, Web/WASM).

---

## Paquetes

| Paquete | Descripción |
|---------|-------------|
| `drift_odoo_core` | Interfaces base: `@Odoo`, `@OdooSerializable`, `OdooModel`, `OdooAdapter`, `OdooModelDictionary`, `OdooDomain` |
| `drift_odoo` | Cliente HTTP para la API JSON-2 de Odoo, `OdooOfflineQueueClient`, cola SQLite de peticiones pendientes |
| `drift_odoo_generators` | Generadores de código `fromOdoo`/`toOdoo` (build_runner) |
| `drift_offline_first` | Repositorio base, políticas de acceso, `MemoryCacheProvider`, suscripciones reactivas |
| `drift_offline_first_with_odoo` | Repositorio final con Odoo, `OdooSyncManager` (sync incremental por `write_date`) |
| `drift_offline_first_with_odoo_build` | `build.yaml` y factories de builder para generación de código |

---

## Inicio rápido

### 1. Definir el modelo

```dart
@ConnectOfflineFirstWithOdoo(
  odooConfig: OdooSerializable(odooModel: 'res.partner'),
)
class Partner extends OfflineFirstWithOdooModel {
  final String name;

  @Odoo(name: 'email')
  final String? email;

  @Odoo(name: 'is_company')
  final bool isCompany;

  Partner({required this.name, this.email, this.isCompany = false, super.odooId});
}
```

### 2. Tabla Drift

```dart
class Partners extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().nullable()();
  TextColumn get name => text()();
  TextColumn get email => text().nullable()();
  BoolColumn get isCompany => boolean().withDefault(const Constant(false))();
}

@DriftDatabase(tables: [Partners])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);
  @override int get schemaVersion => 1;
}
```

### 3. Repositorio

```dart
class PartnerRepository extends OfflineFirstWithOdooRepository<OfflineFirstWithOdooModel> {
  final AppDatabase _db;

  PartnerRepository({required AppDatabase db, required super.remoteProvider, required super.syncManager})
      : _db = db;

  @override
  OdooModelDictionary get modelDictionary => const OdooModelDictionary({
    Partner: PartnerAdapter(),
  });

  @override
  Future<List<T>> getLocal<T extends OfflineFirstWithOdooModel>({Query? query}) async {
    if (T == Partner) {
      return (await _db.select(_db.partners).get()).map(_rowToPartner).toList().cast<T>();
    }
    throw UnsupportedError('$T');
  }

  // ... upsertLocal, existsLocal, deleteLocal
}
```

### 4. Inicializar y usar

```dart
final rawClient = OdooClient(baseUrl: 'https://mycompany.odoo.com', apiKey: 'api_key');

final queuedClient = OdooOfflineQueueClient(
  inner: rawClient,
  requestManager: OdooRequestSqliteCacheManager(
    'offline_queue.db',
    databaseFactory: databaseFactory,
  ),
);

final syncManager = OdooSyncManager(
  NativeDatabase.createInBackground(File('sync_state.db')),
);

final repo = PartnerRepository(
  db: AppDatabase(NativeDatabase.createInBackground(File('app.db'))),
  remoteProvider: queuedClient,
  syncManager: syncManager,
);

await repo.initialize();

// Leer — solo local (no toca la red)
final partners = await repo.get<Partner>(policy: OfflineFirstGetPolicy.localOnly);

// Leer — espera red solo si no hay datos locales
final partners = await repo.get<Partner>(policy: OfflineFirstGetPolicy.awaitRemoteWhenNoneExist);

// Leer — siempre espera la red
final partners = await repo.get<Partner>(policy: OfflineFirstGetPolicy.awaitRemote);

// Guardar — optimista: guarda local de inmediato, sincroniza en background
await repo.upsert(partner, policy: OfflineFirstUpsertPolicy.optimisticLocal);

// Guardar — requiere confirmación del servidor
await repo.upsert(partner, policy: OfflineFirstUpsertPolicy.requireRemote);

// Borrar
await repo.delete(partner, policy: OfflineFirstDeletePolicy.optimisticLocal);
```

---

## Políticas

### `OfflineFirstGetPolicy`

| Política | Comportamiento |
|----------|---------------|
| `localOnly` | Solo lee local. Nunca contacta el servidor. |
| `awaitRemoteWhenNoneExist` | Lee local si hay datos; si no, espera la red. **(default)** |
| `awaitRemote` | Siempre espera la respuesta del servidor. |
| `alwaysHydrate` | Devuelve local inmediatamente; refresca desde red en background. |

### `OfflineFirstUpsertPolicy`

| Política | Comportamiento |
|----------|---------------|
| `optimisticLocal` | Guarda local de inmediato; sincroniza al servidor en background. **(default)** |
| `requireRemote` | Solo guarda local si el servidor responde exitosamente. |
| `localOnly` | Solo guarda local. No toca la red. |

### `OfflineFirstDeletePolicy`

| Política | Comportamiento |
|----------|---------------|
| `optimisticLocal` | Borra local de inmediato; envía al servidor en background. **(default)** |
| `requireRemote` | Solo borra local si el servidor confirma. |
| `localOnly` | Solo borra local. |

---

## Sync incremental

El `OdooSyncManager` persiste el timestamp del último sync por modelo. En cada `hydrateRemote` se añade automáticamente un filtro `write_date > <last_sync>`, evitando re-descargar todos los registros.

```dart
// Forzar re-sync completo de un modelo
await syncManager.reset('res.partner');

// Forzar re-sync completo de todos los modelos
await syncManager.resetAll();
```

---

## Cola offline

`OdooOfflineQueueClient` intercepta todas las mutaciones (create, write, unlink, métodos personalizados) y las persiste en SQLite. Cuando la conectividad se restaura, `OdooOfflineRequestQueue` las reintenta automáticamente.

Los métodos de solo lectura (`search_read`, `search`, `read`, `fields_get`, etc.) nunca se encolan — se ejecutan directamente o fallan.

---

## API JSON-2 de Odoo

- Endpoint: `POST /json/2/<model>/<method>`
- Auth: `Authorization: Bearer <api_key>`
- Todos los métodos son POST. La distinción push/pull es por nombre de método.
- Odoo devuelve `false` (no `null`) para campos vacíos — el deserializador lo maneja.
- Los campos Many2one devuelven `[id, display_name]` — se extrae el primer elemento.

---

## Dominios Odoo

```dart
// Campo simple
OdooDomainBuilder.field('active', OdooOperator.eq, true)
// → [['active', '=', true]]

// AND
OdooDomainBuilder.and([
  OdooDomainBuilder.field('is_company', OdooOperator.eq, true),
  OdooDomainBuilder.field('active', OdooOperator.eq, true),
])
// → ['&', ['is_company', '=', true], ['active', '=', true]]

// OR
OdooDomainBuilder.or([
  OdooDomainBuilder.field('name', OdooOperator.ilike, 'Alice'),
  OdooDomainBuilder.field('name', OdooOperator.ilike, 'Bob'),
])
// → ['|', ['name', 'ilike', 'Alice'], ['name', 'ilike', 'Bob']]

// Sync incremental
OdooDomainBuilder.writtenAfter(lastSyncAt)
// → [['write_date', '>', '2026-01-01 00:00:00']]

// Incluir archivados
OdooDomainBuilder.includeArchived()
// → [['active', 'in', [true, false]]]
```

---

## Ejemplo completo

Ver [`packages/example_odoo_contacts/`](packages/example_odoo_contacts/) para un ejemplo funcional con `res.partner` que incluye:
- Definición del modelo con `@ConnectOfflineFirstWithOdoo`
- Base de datos Drift con tabla `Partners`
- Repositorio concreto implementando los métodos locales
- Demostración de todas las políticas offline-first

```bash
cd packages/example_odoo_contacts
dart run bin/main.dart
```

---

## Tests

```bash
# Un paquete específico
cd packages/drift_odoo && dart test

# Todos los paquetes (requiere melos)
melos run test
```

---

## Setup

```bash
dart pub global activate melos
dart pub get
melos bootstrap
```

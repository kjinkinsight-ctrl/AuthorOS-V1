# ADR-0004: Embedded Database

## Status

Accepted for M1 implementation, subject to packaged-platform validation

## Date

August 17, 2026

## Decision

AuthorOS 2.0 will use **Drift over SQLite** as its embedded creative database.

The production package stack will be promoted from the current development spike only after a packaged Windows application and an Android build pass the integration gate below. Repository interfaces remain storage-agnostic so this decision can be revisited if that gate fails.

## Context

The connected domain requires:

- atomic writes across records, links, indexes, and manuscript metadata
- stable-ID lookup
- efficient incoming/outgoing backlink queries
- joins and bounded graph traversal
- schema migrations with testable version history
- full-text search
- deterministic archive export
- Windows and Android support first
- a credible macOS/iOS path
- isolated in-memory tests
- durable local operation without a network

The proof of concept compared the current maintained stacks:

- Drift `2.34.3` with SQLite through `sqlite3 3.5.1`
- Isar Community `3.3.2`

The original `isar 3.1.0+1` package was not selected as the Isar candidate because its current pub.dev activity and companion-package adoption are substantially lower than the maintained community fork.

## Benchmark workload

The repeatable tool is `tool/storage_benchmark.dart`.

Each candidate stored and queried the same deterministic workload:

- 2,500 records
- 15,000 typed links
- 1,000 indexed canonical-ID lookups
- 1,000 bidirectional backlink queries
- one atomic record-plus-link update
- identical stable IDs, JSON payloads, and link distribution
- deterministic random seed `20260817`

Durability settings were intentionally conservative:

- SQLite: WAL journal mode and `synchronous = FULL`
- Isar: `relaxedDurability = false`

Both candidates returned identical lookup and backlink checksums in every accepted run.

## Windows spike results

Three consecutive `dart run` samples on August 17, 2026 produced these ranges:

| Measurement | Drift/SQLite engine | Isar Community |
|---|---:|---:|
| Batch insert | 124–131 ms | 174–196 ms |
| 1,000 ID lookups | 9–10 ms | 13–15 ms |
| 1,000 bidirectional backlink queries | 24–27 ms | 957–1053 ms |
| Atomic record/link update | 726–1026 µs | 4424–4784 µs |
| Database size including indexes | 3,039,232 bytes | 5,152,768 bytes |

These are development-machine microbenchmarks, not universal performance claims. The backlink result is especially relevant because incoming/outgoing link resolution is a high-frequency Connection Engine operation. The SQL query expresses `source_id = ? OR target_id = ?` directly over two indexes. Isar's generated filter API can express the same result, but this graph-oriented query shape was substantially slower in the measured stack.

The benchmark uses SQLite directly to isolate the database engine. Drift's generated mapping and reactive layers will add some overhead and must be measured in the M1 repository vertical slice.

## Qualitative evaluation

| Criterion | Drift/SQLite | Isar Community |
|---|---|---|
| Transactions | Built in; natural multi-table unit of work | Built in |
| Relational links/backlinks | Native foreign keys, joins, `OR`, recursive CTE options | Object collections, links, and generated filters |
| Schema migrations | Explicit schema versions and migration tooling | Schema evolution supported, but object-schema changes are less aligned with portable SQL fixtures |
| Full-text search | SQLite FTS5 with explicit indexes and query behavior | Word/token indexes available; less flexible for mixed manuscript/record search |
| Query inspection | Standard SQL, `EXPLAIN QUERY PLAN`, broad tooling | Isar inspector and generated queries |
| Archive extraction | Ordered SQL queries map cleanly to normalized portable JSON | Requires collection-specific extraction |
| Test isolation | In-memory SQLite through Drift/native database | Temporary Isar instances and native core setup |
| Platform support | Android, iOS, macOS, Windows, Linux, web options | Flutter/mobile/desktop support through native core packages |
| Ecosystem maturity | High current adoption; first-party Drift/SQLite package family | Maintained community fork, smaller ecosystem |
| Domain fit | Strong for records, typed edges, scopes, revisions, and search | Strong for object persistence; weaker measured graph-query fit |

## Tooling findings

- Both dependency stacks resolved under the current project SDK constraints.
- Isar code generation completed successfully.
- Drift and sqlite3 build hooks completed successfully through `dart run`.
- Isar's command-line benchmark required `Isar.initializeIsarCore(download: true)`; packaged Flutter applications use the native library package instead.
- A standalone `dart compile exe` benchmark did not bundle sqlite3's native asset in this toolchain and could not resolve `sqlite3_initialize`. This does not represent normal Flutter packaging, but it reinforces the need for packaged Windows validation.
- The normal `dart run` benchmark loaded both native engines and exited cleanly after database closure.

## Consequences

### Positive

- The connected graph maps naturally to normalized records and links tables.
- Referential constraints can reject invalid links at the storage boundary.
- Atomic multi-entity migration and import operations are straightforward.
- FTS5 can index record text and manuscript search with controlled tokenization.
- SQL query plans and database files are inspectable with mature tools.
- Archive export can use stable ordered queries independent of UI models.
- Entity-level sync can reuse revision and tombstone tables without serializing entire objects.

### Costs

- Drift introduces code generation and generated schema files.
- Custom record fields need a deliberate relational/JSON design rather than arbitrary object nesting.
- Large manuscript text and editor snapshots require careful table and transaction boundaries.
- SQL migrations must be maintained and tested for every released schema version.
- SQLite writes must run off the UI-critical path where needed.

### Risks

- Raw SQLite benchmark performance may overstate final Drift repository performance.
- FTS5 availability and tokenizer behavior must be validated in packaged builds.
- Native asset packaging must be proven on every supported platform.
- Poor table design could turn flexible custom fields into opaque JSON that defeats indexing.

## Production integration gate

Before Drift moves from spike dependencies into the production runtime, M1 must prove:

1. packaged Windows debug and release builds open, migrate, query, close, and reopen the database
2. Android debug and release builds perform the same lifecycle on a physical device or emulator
3. WAL recovery survives a forced process termination during a write
4. foreign-key enforcement is enabled for every connection
5. FTS5 creates and queries the agreed record/manuscript indexes
6. migration from schema version 1 to 2 preserves fixture IDs and unknown extension JSON
7. in-memory repository tests run without platform channels
8. database and WAL files are included consistently in backup snapshots
9. a 750,000-word, 2,500-record, 15,000-link fixture meets the M0 performance targets
10. the application can export and restore the database through the portable archive rather than copying a live database file blindly

If packaged Android or Windows support fails this gate, reopen this ADR before implementing feature repositories.

### Gate evidence, August 17, 2026

| Gate | Result | Evidence |
|---|---|---|
| Windows debug package | Passed | `flutter build windows --debug --target tool/packaged_storage_probe.dart`; packaged executable exited successfully |
| Windows release package | Passed | `flutter build windows --release --target tool/packaged_storage_probe.dart`; packaged executable exited successfully twice, proving close/reopen |
| Production opener | Passed on Windows | Probe used `AuthorOsDatabase.defaults()` and `drift_flutter`, not the in-memory test executor |
| Foreign keys | Passed on Windows and VM | Probe required `PRAGMA foreign_keys = 1`; focused test rejects dangling links |
| FTS5 | Passed on Windows and VM | Probe searched a newly written record; migration test backfills a version 1 record and finds it after version 2 reopen |
| Version 1 to 2 migration | Passed on VM real file | IDs, link, node, and unknown extension JSON survived close, migration, and reopen |
| Transaction rollback | Passed on VM | Forced transaction failure leaves the entity table empty |
| Android release package | Blocked by environment | `flutter build apk --release --target tool/packaged_storage_probe.dart` failed before compilation because no Android SDK / `ANDROID_HOME` is configured |
| Android runtime | Not run | Requires SDK plus emulator or physical device |
| WAL crash recovery | Passed on Windows VM test | Child process begins an uncommitted `BEGIN IMMEDIATE` write, signals readiness, is force-killed, and the reopened database excludes the row and accepts a subsequent valid snapshot |
| Portable archive restore | Not run | Archive implementation follows ADR-0005 |

The packaged probe is isolated in `tool/packaged_storage_probe.dart`; it does not alter normal application startup. It writes a record, manuscript node, and link through the Drift repository, verifies extension JSON, backlinks, FTS5, and foreign-key activation, closes the database, and exits nonzero on any failed assertion.

The WAL harness is isolated in `tool/wal_crash_writer.dart`. The test starts it with the Flutter-bundled Dart SDK, waits until the uncommitted row and readiness marker exist, terminates the full process tree, then reopens through Drift. Explicit connection settings are `journal_mode = WAL`, `synchronous = FULL`, and `foreign_keys = ON`.

## Implementation constraints

- UI code depends on repositories, never Drift tables or generated row classes.
- Domain IDs remain strings and are never replaced by database row IDs.
- Foreign keys model integrity, but domain services still enforce scope and link-type rules.
- Custom field values use controlled typed tables or indexed projections plus extension JSON; do not place the entire domain in one unqueryable JSON column.
- Manuscript bodies are isolated from frequently updated graph metadata.
- All migrations have fixture-based upgrade and rollback/failure tests.
- Database writes that alter records and links use one transaction.

## Rejected alternatives

### SharedPreferences

Rejected for the creative corpus because it lacks transactions, indexes, relational integrity, scalable querying, and safe multi-entity migration.

### Isar Community

Not selected because the measured record/link workload was larger and slower, especially for bidirectional backlinks, and AuthorOS relies heavily on relational graph and search queries. Isar remains technically viable if Drift fails packaged-platform validation.

### Original Isar package

Rejected in favor of evaluating its maintained community fork.

### Remote database as local authority

Rejected because it violates the local-first product boundary.

### Flat JSON project files as live storage

Rejected because rewriting large project graphs increases corruption risk and makes indexed search, transactions, and entity-level sync difficult. JSON remains part of the portable archive format.

## Validation and review

The measured benchmark is repeatable with:

```powershell
dart run build_runner build
dart run tool/storage_benchmark.dart
```

Run the benchmark multiple times and compare checksums before timings. Android and packaged Windows results must be appended to this ADR when the M1 vertical slice exists.

## Related documents

- [ADR-0003: Connected Creative Domain Model](ADR-0003-connected-domain-model.md)
- [AuthorOS 2.0 Master Feature and Architecture Plan](../authoros-2-master-plan.md)
- [Persisted Data Inventory](../persisted-data-inventory.md)
# AuthorOS — Archive Completeness

Closing R-2 and R-22

Status: **Implemented.** The `.authoros` archive carries prose and writing sessions
Format: `archiveVersion: 1`, unchanged — the two new entries are additive and optional

---

## 0. Why now, and what was actually wrong

Two things fell out of an `.authoros` file:

| Risk | Defect |
|---|---|
| **R-2** | Scene prose lives in the Manuscript Studio's own store, not the database. The archive preserved scene *identity* and never the writing, so a restore returned a fully-connected graph of **empty scenes** |
| **R-22** | `writing_session_rows` is the twelfth table, but the archive still wrote the same ten entries. A round trip lost every daily total, streak and longitudinal metric |

**Both were latent, not live.** `AuthorOsArchiveService` has **no production callers** — it
is referenced only by tests. Nothing in the app exports or imports an archive today, so no
author could reach either defect. Authors *can* export a manuscript as PDF
(`ManuscriptExportDialog`, wired into Manuscript Studio), so prose was never trapped.

That is precisely the argument for fixing it now rather than later: **the format has not
shipped.** Repairing it costs one change. Repairing it after backup/restore is wired, and
authors hold `.authoros` files with no prose in them, is a format migration and a support
burden forever.

---

## 1. What changed

| File | Change |
|---|---|
| `lib/core/connected_domain.dart` | `ConnectedDomainSnapshot` gains `writingSessions` |
| `lib/persistence/authoros_database.dart` | `snapshot()` reads sessions; `replaceSnapshot()` clears them; `_insertSnapshot` writes them |
| `lib/archive/authoros_archive.dart` | Two new entries, an `AuthorOsArchiveContents` result type, `importArchive` |

### 1.1 Sessions travel in the snapshot

Sessions sit beside `versions` and `auditEvents`, which are also **not graph data**. The
architecture is explicit that this is consistent rather than a contradiction:

> Correctly *outside* the graph per I-16, but backup is a separate concern from graph
> membership, and this is a real data-loss path.

Invariant I-16 is untouched and its guardrail still passes: `writing_session_rows` has no
foreign key into `connected_entities`, no registered record type, and no connection type
takes a session as an endpoint. Being *archived* is not being a *node*.

### 1.2 Prose travels beside the snapshot, untyped

Prose is not in the database, so it cannot arrive through `ConnectedDomainSnapshot`. It is
passed to `exportSnapshot` as already-serialised `ManuscriptProjectSummary` JSON and comes
back on `AuthorOsArchiveContents.manuscripts`.

Keeping it as raw maps is deliberate. `ManuscriptProjectSummary` lives in
`lib/manuscript_store.dart`, which imports `shared_preferences`; importing it into
`lib/archive/` would drag the store's dependencies into a pure serialisation layer. The
archive's job is bytes ↔ JSON, and the caller owns the model.

**This is not decision D-1.** Prose is not moved into the database and scenes do not become
records. The manuscript store remains the source of truth; the archive merely copies what it
holds.

### 1.3 Both entries are optional, in both directions

- **On export**, an entry is written only when there is something to write. An archive of a
  project with no sessions and no prose is byte-identical to one produced before this
  change, so the stable-fingerprint guarantee is unaffected.
- **On import**, both are absent-tolerant, so every archive written before this change still
  loads.

`_jsonLines` sorts on an `id`, and `ManuscriptProjectSummary.toJson()` has none, so one is
synthesised from `projectId` — mirroring what the branch overlays already do.

### 1.4 Restore replaces session history

`replaceSnapshot` now clears `writing_session_rows` along with everything else. A restore is
a whole-snapshot replace; leaving history behind would leave totals and streaks describing a
manuscript that no longer exists. Restoring a pre-change archive therefore clears session
history, because such an archive genuinely records none.

---

## 2. API

```dart
Uint8List exportSnapshot(
  ConnectedDomainSnapshot snapshot, {
  …,
  Iterable<Map<String, Object?>> manuscripts = const [],
});

AuthorOsArchiveContents importArchive(Uint8List bytes);

/// Unchanged, and still the graph half only.
ConnectedDomainSnapshot importSnapshot(Uint8List bytes);
```

`importSnapshot` is kept as a delegating wrapper so the eleven test files that already use
it, and `importAndCommit`, needed no change.

---

## 3. Verification

`test/authoros_archive_completeness_test.dart` proves behaviour, not shape:

- sessions round-trip through the archive, and through the repository that feeds it;
- scene prose round-trips, and is **byte-exact** — newlines, indentation, em dashes and
  quotes included, because "present" is not the same as "unchanged";
- an archive with neither entry still imports;
- `importSnapshot` still returns the graph;
- integrity still rejects a tampered archive containing the new entries.

---

## 4. Still open

The archive remains **unwired**. Nothing exports or imports one. This change makes the
format correct so that whoever builds backup and restore inherits a lossless format rather
than a migration; it does not itself give authors a backup.

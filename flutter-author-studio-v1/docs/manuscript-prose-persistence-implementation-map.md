# Manuscript Prose Persistence Implementation Map

## Scope

This is the storage foundation of Manuscript Studio: where a scene's words
live, how a save reaches them, and what happens when the author wants an
earlier draft back.

It delivers:

- a prose document model that can carry structure and inline marks, and that
  projects losslessly back to plain text
- one database row per scene for the current prose, replacing the
  whole-manuscript `SharedPreferences` blob as the home of body text
- saves proportional to the edit rather than to the manuscript
- a bounded per-scene history of earlier drafts, and a restore path for them
- prose in the shared search index and in the portable project archive
- a one-time, backed-up migration for every manuscript written before the split

It does not deliver a formatting toolbar, block styling in the editor, parts,
multiple manuscripts per project, or any change to word goals, sprints or
focus mode. Those are separate work; see **Deliberately not done** below.

## The problem

`ManuscriptStore` kept the entire manuscript — structure *and* every word of
prose — in one `SharedPreferences` entry, `author_studio.manuscript_studio.{projectId}`.
The editor's autosave fires 700ms after a keystroke and calls `saveStudio`, so
recording a three-letter edit re-serialised and rewrote every chapter and every
scene in the project. Three consequences followed from the single cause:

1. **Scale.** Save cost grew with the manuscript, not with the edit. A
   120,000-word novel rewrote 120,000 words to record one.
2. **Formatting.** A scene's prose was a bare `String`. There was nowhere to
   put a mark, so there could be no rich editor.
3. **Recovery.** Nothing kept what a scene used to say. The editor's undo
   stack died with the widget, and the History pane's own restore dialog had to
   warn that "drafted prose is not rolled back".

The master plan already required the fix (§6.5): *"Scene text is stored
separately from graph indexes so large-document editing does not rewrite the
full project graph."*

## Architecture

```text
ManuscriptScene.content : String        <- unchanged above this line
        |
ManuscriptStore
        |-- structure  -> SharedPreferences  author_studio.manuscript_studio.{projectId}
        |-- prose      -> scene_prose_rows            (one row per scene)
        \-- history    -> scene_prose_snapshot_rows   (bounded, per scene)
```

The split is invisible to callers. `loadStudio` still returns a whole
manuscript with its prose in place; `saveStudio` still takes one. Nothing above
`ManuscriptStore` knows a second store exists.

### Domain

`lib/core/prose_document.dart` is plain Dart — no Flutter, no drift.

- `ProseDocument` is an ordered list of `ProseBlock`s; each block holds
  `ProseSpan`s carrying a set of `ProseMark`s.
- `ProseDocument.fromPlainText` maps one line to one paragraph, so
  `fromPlainText(x).plainText == x` for **every** input. Blank lines, trailing
  newlines and runs of whitespace all survive. This is what makes the migration
  incapable of losing a character.
- `ProseDocument.countWords` is the one word-count implementation in the tree.
  `ManuscriptScene.wordCount` delegates to it, so scenes, stored prose,
  snapshots, writing sessions, streaks, goals and progress bars cannot disagree.
- `toJson` writes unformatted prose as `{"schema":1,"text":"..."}` and only
  falls back to a block list once a document actually carries formatting.
  Every scene written before this model has the compact shape, so the
  migration does not inflate a manuscript on disk.
- Unknown block kinds and marks decode to their nearest known equivalent
  rather than throwing: an older build opening a newer build's document loses
  styling it cannot draw, never the sentence.

`lib/core/scene_prose.dart` holds the stored shapes — `SceneProse`,
`SceneProseSnapshot`, `SceneProseSnapshotReason` — and
`SceneProseSnapshotPolicy`, the single place the "is this worth keeping?"
question is answered.

### Persistence

Schema version 10 adds two tables, created as SQL in
`AuthorOsDatabase._createSceneProseTables` rather than as drift table classes.
That follows the precedent of the FTS index in the same file, and it is
deliberate: prose is not graph data. It has no entity row, no typed links and
no branch overlay, and a generated dataclass would invite exactly the joins the
separation exists to prevent.

```text
scene_prose_rows            scene_id (pk), project_id, chapter_id, revision,
                            document_json, plain_text, word_count,
                            is_formatted, updated_at, last_snapshot_at
scene_prose_snapshot_rows   id (pk), scene_id, project_id, revision,
                            document_json, word_count, reason, captured_at
```

Instants are stored as milliseconds since the epoch, in UTC. Drift's
`DateTimeColumn` stores whole seconds, which is coarser than an autosave
interval and would make two saves in the same second indistinguishable in the
history.

`last_snapshot_at` lives on the current row so a save needs one read of the
project's prose, not one aggregate query per scene.

The repository methods are on `DriftConnectedDomainRepository`:
`sceneProseDigestsForProject`, `sceneProseForProject`, `sceneProseById`,
`putSceneProse`, `removeSceneProse`,
`removeSceneProseForProject`, `appendSceneProseSnapshots`,
`sceneProseSnapshots`, `sceneProseSnapshotById`. All of them no-op below schema
10, the same way the search-index helpers no-op below schema 2.

### Saving

`ManuscriptStore._saveProse` reads one `SceneProseDigest` per scene — scene id,
chapter, plain text, counts, timestamps, and whether the document carries
formatting — and deliberately *not* `document_json`. Decoding every scene's
document on every autosave tick would put the whole-manuscript cost straight
back, in CPU instead of in bytes written. A string comparison against
`ManuscriptScene.content` settles the unchanged scenes; only the scene the
author is typing in has its stored document read.

`is_formatted` is what keeps that cheap comparison exact rather than merely
usually right. Once a document carries marks, its plain text no longer
identifies it — toggling a word to italic and back would read as "nothing
changed" — so a formatted digest declines to match on text and the document is
read instead.

Only the scenes whose text changed are written — during ordinary writing, one.
A save that changed no prose writes nothing at all: a rename, a reorder or an
autosave tick after an idle pause never touches the prose tables.

Scenes that leave the manuscript have their prose and their history retired,
mirroring the rule the manuscript-node projection already followed. A new scene
with no words is given no row, so creating scenes does not fill the table with
blanks.

### History

`SceneProseSnapshotPolicy` decides whether the prose about to be replaced is
copied into history first. Three thresholds, and nothing else in the tree may
hard-code one:

| Threshold | Default | What it is for |
|---|---|---|
| `minimumInterval` | 5 minutes | Stops an author's typing — a save roughly twice a second — from becoming thousands of history entries. |
| `significantWordDelta` | 25 words | The safety net. Preserves the scene when the author selects it and types over it, whatever the interval says. |
| `retainedPerScene` | 25 | Bounds the history. Pruning happens on write, so it cannot grow without something having just added to it. |

A restore passes `forceProseSnapshotFor`, which snapshots unconditionally:
replacing prose with an older version is the edit an author is most likely to
want to take back, and that must not depend on when the routine policy last
fired.

### Migration

`ManuscriptStore._ensureProseMigrated` runs before the first read **and** the
first write of a project, because either can be the first thing that happens to
it. A save that overwrote the blob with its prose-free form before the prose
had been read out of it would destroy the manuscript.

It writes the pre-migration blob verbatim to
`author_studio.manuscript_prose_backup.{projectId}` *before* the prose rows,
so an interruption leaves the blob intact and the migration simply runs again.
That key doubles as the marker that the move has happened; an empty value means
there was nothing to migrate and stops every later save from re-checking. Each
scene's imported state is recorded as one `imported` snapshot — the only
version of the prose that predates the database.

A malformed blob is not marked migrated: whatever repairs it deserves to have
its prose moved too.

### Search

Scene prose was never searchable, because it was never in the database.
`_putManuscriptNode` now indexes a scene as its metadata plus its prose, and
`putSceneProse` re-indexes the scene it just wrote. An existing search for a
POV or a status keeps matching; a sentence the author wrote now matches too.

### Archive

`ConnectedDomainSnapshot` gains `sceneProse`, and the archive gains
`content/scene-prose.jsonl` under the manifest's existing `scene-content` role.
It is optional on read, so an archive written before the split still restores.
Snapshot history is deliberately excluded: it is local recovery scratch, and
carrying twenty-five copies of every scene would multiply the archive size for
no gain to the author restoring it.

`replaceSnapshot` clears the prose tables. Prose carries no entity row, so the
existing deletes did not reach it, and the replaced project's words would
otherwise have attached themselves to whichever new scene reused an id.

## Ownership

Manuscript Studio owns chapters, scenes and prose. Nothing else writes
`scene_prose_rows`. Chapters and scenes remain single-sourced in
`manuscript_node_rows`; prose adds no second copy of either, no second graph,
and no second search index.

## Behaviour changes worth knowing

- `ManuscriptStore.saveStudio`'s `persistLegacyText` now defaults to **false**.
  Refreshing the flattened `author_studio.manuscript.{projectId}` mirror means
  writing the whole manuscript as one string, which is the cost this work
  exists to remove. The mirror was a pre-2.0 migration fallback; per-scene rows
  with their own history are a better one. `ManuscriptStore.load` reads prose
  from the database, so nothing that consulted the mirror loses anything.
- Search results now include scenes matched on their prose.
- Selecting a chapter or the manuscript root in the navigator draws its
  selection highlight, which a missing `Material` ancestor had been swallowing.

## Verification

```bash
cd flutter-author-studio-v1
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
bash ../scripts/provision-drift-web-assets.sh
flutter build web --release --no-web-resources-cdn
```

New tests:

- `test/prose_document_test.dart` — plain-text round trips over the awkward
  inputs (blank lines, trailing newlines, tabs, unicode), word counts checked
  against the scene count they replaced, compact vs block encoding, forward
  compatibility.
- `test/scene_prose_test.dart` — the snapshot policy's four decisions, record
  round trips, id collisions.
- `test/manuscript_prose_persistence_test.dart` — prose absent from the blob,
  present in the rows and on reload; per-scene saves; orphan retirement;
  migration on read, on write, once only, and with a malformed blob; history
  bounds; restore through `ManuscriptService`; branch/Canon refusal; prose in
  search.
- `test/manuscript_workspace_test.dart` — restoring an earlier draft through
  the History pane; chapters are offered no prose history.
- `test/authoros_archive_test.dart` — prose survives an archive round trip, and
  an archive without it still loads.

`test/story_graph_architecture_test.dart` records the two new tables in its
audited-table list, which is what makes adding a table a visible act.

## Deliberately not done

- **A formatting toolbar.** The document model can carry bold, italic,
  underline, strikethrough, headings, block quotes and scene breaks; the editor
  still edits plain text and round-trips through the model. Wiring selection-based
  mark toggling into a Flutter editing surface is the next piece of work, and it
  is now purely a UI problem — the storage is ready for it.
- **Parts, and more than one manuscript per project.** The hierarchy stays
  Chapter → Scene.
- **Word goals, sprints, focus mode.** Untouched.
- **Snapshot history in the archive.** Current prose only.

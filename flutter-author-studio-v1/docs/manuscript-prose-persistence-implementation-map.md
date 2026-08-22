# Manuscript Prose Persistence Implementation Map

## Scope

Where a scene's *current* prose lives, and how it gets there.

This is a reconciliation. Two pieces of work solved adjacent halves of the same
problem at the same time, and this merges them into one architecture rather
than letting both ship:

| Work | Question it answered | Answer |
|---|---|---|
| Author Performance System (merged) | how do we recover previous versions of prose? | `scene_revision_rows` |
| Prose persistence (this) | where should the current prose live? | `scene_prose_rows` |

Those are not competing concepts, and together they are a cleaner architecture
than either alone:

```text
Scene
  |
  +-- scene_prose_rows        current canonical prose
  |        |
  |        | revision capture
  |        v
  +-- scene_revision_rows     bounded history
           |
           | restore, writing back through scene_prose_rows
           v
       current prose again
```

**One current-prose store. One revision-history store.** The discarded
alternative was a second history (`scene_prose_snapshot_rows`) that arrived
with the prose-storage work; it is deliberately absent, and three tests keep it
absent.

## The problem the storage move solves

`ManuscriptStore` kept the entire manuscript — structure *and* every word of
prose — in one `SharedPreferences` entry, `author_studio.manuscript_studio.{projectId}`.
The editor's autosave fires 700ms after a keystroke and calls `saveStudio`, so
recording a three-letter edit re-serialised and rewrote every chapter and every
scene in the project.

Revision history alone does not fix that: it answers "what did this scene used
to say", not "what does it cost to save it". The move also unlocks two things
history cannot — prose in the shared search index, and prose in a project
archive — because both need the words to be in the database at all.

The master plan required it (§6.5): *"Scene text is stored separately from
graph indexes so large-document editing does not rewrite the full project
graph."*

## Architecture

```text
ManuscriptScene.content : String        <- unchanged above this line
        |
ManuscriptStore
        |-- structure -> SharedPreferences  author_studio.manuscript_studio.{projectId}
        \-- prose     -> scene_prose_rows   (one row per scene)

SceneRevisionService  -- reads scenes from the hydrated manuscript,
                         writes history to scene_revision_rows
```

The split is invisible to callers. `loadStudio` and `peekStudio` still return a
whole manuscript with its prose in place; `saveStudio` still takes one. Nothing
above `ManuscriptStore` knows a second store exists — which is why the revision
service needed **no logic change**: it reads `ManuscriptScene.content` from the
manuscript it is handed, and that content now comes from the prose table.

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
  revisions, writing sessions, streaks, goals and velocity cannot disagree.
- `toJson` writes unformatted prose as `{"schema":1,"text":"..."}` and only
  falls back to a block list once a document carries formatting, so today's
  scenes do not inflate on disk.
- Unknown block kinds and marks decode to their nearest known equivalent: an
  older build loses styling it cannot draw, never the sentence.

`lib/core/scene_prose.dart` holds `SceneProse` and `SceneProseDigest`. It has
**no history type**, by design, and a test asserts it never grows one.

### Persistence

Schema version **13** adds one table, created as SQL in
`AuthorOsDatabase._createSceneProseTable` rather than as a drift table class —
following the FTS index in the same file. Prose is not graph data: no entity
row, no typed links, no branch overlay, and a generated dataclass would invite
the joins the separation prevents. It also keeps the change out of the
ten-thousand-line generated file, where a schema addition is unreviewable.

```text
scene_prose_rows   scene_id (pk), project_id, chapter_id, revision,
                   document_json, plain_text, word_count, is_formatted,
                   updated_at
```

**Version 13, not 10.** Versions 10, 11 and 12 are already spent on writing
goals, the series and project roster, and scene revisions. A migration version
is consumed the moment a build ships it, because drift records the applied
version in the user's own database file — reusing one would leave anyone who
had run the earlier build skipping the step entirely and opening an app whose
tables do not exist. `test/manuscript_prose_persistence_test.dart` upgrades
from schemas 1, 2, 8, 9, 10, 11 and 12 and asserts the new table *and* every
earlier one arrive.

Instants are stored as milliseconds since the epoch, in UTC. Drift's
`DateTimeColumn` stores whole seconds, which is coarser than an autosave.

### Saving

`ManuscriptStore._saveProse` reads one `SceneProseDigest` per scene — scene id,
chapter, plain text, counts, timestamps, and whether the document carries
formatting — and deliberately *not* `document_json`. Decoding every scene's
document on every autosave tick would put the whole-manuscript cost straight
back, in CPU instead of in bytes written. A string comparison against
`ManuscriptScene.content` settles the unchanged scenes; only the scene the
author is typing in has its stored document read.

`is_formatted` keeps that cheap comparison exact rather than merely usually
right. Once a document carries marks, its plain text no longer identifies it —
toggling a word to italic and back would read as "nothing changed" — so a
formatted digest declines to match on text and the document is read instead.

Scenes that leave the manuscript have their prose retired. Their **revisions
are kept**: deleting a scene captures a `deletion` revision precisely so its
words outlive it.

`saveStudio` captures no history, and an architecture test asserts
`manuscript_store.dart` never so much as names the revision type. `loadStudio`
saves when it seeds a manuscript nobody has opened, so a capture inside the
save would write history during a read — risk R-21.

### Migration

`_ensureProseMigrated` runs before the first read **and** the first write of a
project, because either can come first: a save that overwrote the blob with its
prose-free form before the prose had been read out of it would destroy the
manuscript.

It writes the pre-migration blob verbatim to
`author_studio.manuscript_prose_backup.{projectId}` *before* the prose rows, so
an interruption leaves the blob intact and the migration simply runs again.
That key doubles as the marker that the move has happened; an empty value means
there was nothing to migrate. A malformed blob is not marked migrated.

`peekStudio` hydrates but deliberately never migrates: it is on the sync path
and must not write. A project whose prose has not moved yet still reads
correctly there, because the blob it reads is the one that still holds the
prose.

### Search

Scene prose was never searchable, because it was never in the database.
`_putManuscriptNode` now indexes a scene as its metadata plus its prose, and
`putSceneProse` re-indexes the scene it just wrote. An existing search for a
POV or a status keeps matching; a sentence the author wrote now matches too.

### Archive

`ConnectedDomainSnapshot` gains `sceneProse`, and the archive gains
`content/scene-prose.jsonl` under the manifest's existing `scene-content` role.
It sits beside the entries added by the archive-completeness work:

| Entry | Holds | Source |
|---|---|---|
| `content/scene-prose.jsonl` | the words | `snapshot.sceneProse` |
| `data/manuscripts.jsonl` | the shape — chapter/scene tree, ordering, POV, relationships, current position | raw `ManuscriptProjectSummary.toJson()` maps |

The two do not overlap: the store writes its blob with `includeProse: false`,
so exactly one copy of the prose is in the file — the one the database is
restored from — and a test holds the format to that.

Revision history is deliberately **not** archived. Revisions are device-local
by design, and carrying every retained copy of every scene would multiply an
archive by its retention depth for no gain to the author restoring it.

## What was preserved from the performance work

Audited before touching shared files, and unchanged by this:

- manuscript prose sync, the conflict-copy rule, and the sync shadow
- writing goals, series analytics, the project roster
- tombstones and the remote-change / session safeguards
- `SceneRevisionService` — every trigger (`boundary`, `remoteApply`, `restore`,
  `deletion`), its retention policy, and its rule that revisions are never
  captured on the 700ms autosave

The only behavioural change to that work is what it reads: scenes now arrive
carrying prose from `scene_prose_rows` instead of from the blob.

## Behaviour changes worth knowing

- `saveStudio`'s `persistLegacyText` now defaults to **false**. Refreshing the
  flattened `author_studio.manuscript.{projectId}` mirror means writing the
  whole manuscript as one string, which is the cost this removes. Nothing reads
  that key except `load`'s corruption fallback, and per-scene rows plus
  revisions are a better fallback than the mirror ever was.
- Search results now include scenes matched on their prose.

## Verification

```bash
cd flutter-author-studio-v1
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
bash ../scripts/provision-drift-web-assets.sh
flutter build web --release --no-web-resources-cdn
```

`test/manuscript_prose_persistence_test.dart` covers the matrix this
reconciliation was required to prove: fresh database; upgrade from schemas 1,
2, 8, 9, 10, 11 and 12; blob → `scene_prose_rows` with the backup kept; a save
landing before any load; idempotency; revision capture reading canonical prose;
restore writing back through it; deletion keeping history while dropping prose;
remote apply capturing what it replaces; search; and three tests asserting one
current-prose store and one revision store.

Alongside it: `test/prose_document_test.dart`, `test/scene_prose_test.dart`,
`test/authoros_archive_completeness_test.dart`, and the audited-table list in
`test/story_graph_architecture_test.dart`.

## Deliberately not done

- **A second revision system.** `scene_prose_snapshot_rows` was dropped.
- **A formatting toolbar.** The model carries marks; the editor still edits
  plain text and round-trips through the document. That is now purely a UI
  problem.
- **Parts, or more than one manuscript per project.** The hierarchy stays
  Chapter → Scene.
- **Revisions in the archive**, or in sync. Both are deliberate.

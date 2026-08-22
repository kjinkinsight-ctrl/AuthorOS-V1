# Manuscript Formatting UI Implementation Map

## Scope

The writing surface can now format prose: bold, italic, underline and
strikethrough, applied by toolbar or keyboard, stored in `scene_prose_rows`,
and reopened as they were left.

This builds on the prose persistence layer rather than modifying it. No schema
change, no new table, no migration: `scene_prose_rows` was designed with a
`document_json` column and an `is_formatted` flag for exactly this, and both
were already exercised by the storage tests before anything could produce a
mark.

## The problem

`ProseDocument` could carry marks and `scene_prose_rows` could store them, but
nothing could *make* one. The editor was a `TextField` over a plain `String`,
so the model's blocks-spans-marks structure existed with only one shape ever
written to it.

The gap is not conceptual, it is mechanical. A Flutter text field edits one
flat string and reports one flat selection; a document is a tree. Something has
to hold the correspondence between them, and keep holding it while the author
types.

## Architecture

```text
ProseDocument            blocks -> spans -> marks        (storage shape)
      ^  |
      |  v   ProseMarkup.fromDocument / .toDocument
ProseMarkup              text + ranges + blockKinds      (flat shape)
      ^  |
      |  v   withText / toggle
ProseEditingController   a TextEditingController that paints marks
      ^  |
      |  v
ProseFormattingToolbar   one button per mark
ProseFormattingShortcuts Ctrl+B / Ctrl+I / Ctrl+U / Ctrl+Shift+X
```

### `lib/core/prose_markup.dart` — the flat view

Plain Dart, no Flutter. A document's `plainText` plus two side tables anchored
to offsets in it: `ranges` (where the marks are) and `blockKinds` (what each
line is, one entry per line).

`blockKinds` is carried even though nothing can change one yet. A document
arriving with a heading — from an archive, or a later build — would otherwise
be flattened to paragraphs the first time an author typed in it, which is a
data loss nobody would see until they looked.

Three invariants, each with tests:

- **Round trip.** `fromDocument(document).toDocument() == document` for every
  document, and the same the other way. A mark that spans a newline is split at
  it, because the newline between two blocks belongs to neither block's text —
  without that split the second half is silently dropped on the way to a
  document.
- **Normalisation.** Ranges are sorted, clipped, non-empty, and merged when
  adjacent with equal marks. Toggling bold across a paragraph otherwise leaves
  one range per character: correct, and unusable to read or store.
- **`isPlain`.** True only when there are no marks and every block is a
  paragraph. This drives `scene_prose_rows.is_formatted`, which is what lets an
  unchanged save still be settled by string comparison alone.

`withText` re-anchors marks after an edit. A text field hands back a whole new
string rather than an edit, so the edit is recovered from the common prefix and
suffix. The interesting case is what happens at a run's edges, and it is a
deliberate asymmetry:

| Edit | Behaviour | Why |
|---|---|---|
| insert inside a run | run extends | typing in the middle of a bold word stays bold |
| insert at a run's **trailing** edge | run extends | carrying on past a bold word keeps typing bold, as every editor does |
| insert at a run's **leading** edge | run is pushed | so a bold word can still be prefixed with plain text |
| delete across a run | run is clipped | |

### `lib/prose_editor.dart` — the surface

`ProseEditingController extends TextEditingController`. The field keeps
everything it already did — selection, undo, IME, platform text handling — and
gains two things: `buildTextSpan` paints the marks, and `set value` re-anchors
them on every change.

- `markup` is assigned when the author moves scene. Assigning `text` alone
  would leave the previous scene's marks anchored over the new scene's words,
  so `_syncEditorWithSelection` goes through `markup` and a test holds it there.
- `activeMarks` drives the toolbar and follows the caret: moving into a bold
  word lights the bold button with nothing having to tell it.
- **Pending marks.** Pressing bold with nothing selected arms it for the next
  character typed, and the button looks pressed meanwhile. Without this,
  choosing bold and typing produces plain text and the button looks broken.
  Moving the caret abandons the choice — bold chosen over there is not still
  chosen over here.

`ProseFormattingToolbar` rebuilds from the controller rather than holding state
of its own. It is deliberately compact: it sits directly above the writing
surface, where every pixel it takes is one the author does not get to write in,
and in focus mode the field is sized to the window — a chunky toolbar does not
just look wrong there, it pushes the editor off the bottom.

`enabled: false` while the manuscript is Canon and a branch is active, so the
toolbar is visibly unavailable rather than silently inert.

### How a mark reaches the database

The constraint that shaped this: `ManuscriptScene.content` is a `String`, and
sync payloads, scene revisions, export, continuity and every word count read
it. Turning it into a document would have touched all of them.

So marks travel *beside* it. `ManuscriptScene` gains
`ProseDocument? document` — null when the scene is plain, which is almost
always — while `content` stays the plain projection and stays authoritative.
Nothing else had to learn about marks.

Two guards keep the pair honest:

- **`copyWith(content:)` without a document drops the formatting, deliberately.**
  Every caller that sets prose from somewhere plain — a restored revision, an
  arriving sync payload, a legacy migration — is handing over text that
  genuinely has no marks, and keeping the old scene's marks anchored over new
  words would be worse than losing them. Only the editor passes both, because
  only the editor knows both.
- **`_saveProse` distrusts a document whose plain text has drifted** from the
  scene's `content`, and falls back to the text. `content` is what every other
  system reads, so it wins.

One subtlety worth naming, because getting it wrong would have lost data
silently: `_saveProse`'s fast path settles unchanged scenes by comparing plain
text. A formatting-only edit changes no characters, so that comparison would
have said "nothing changed" and swallowed it. The fast path now also requires
that the scene carries no document.

## What this deliberately does not do

- **Block formatting.** Headings, block quotes and scene breaks are stored,
  round-tripped and preserved through edits, but nothing can *apply* one and
  the editor paints them as paragraphs. Block-level UI is per-line rather than
  per-selection and is its own piece of work.
- **Paste with formatting.** Pasted text arrives plain.
- **Marks in sync or revisions.** Both carry plain text, as they did. A
  revision restores words, not formatting — which is honest, since a revision
  is a copy of what the scene said.
- **Marks in export.** PDF export renders `content`.

## Verification

```bash
cd flutter-author-studio-v1
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
flutter build web --release --no-web-resources-cdn
```

`test/prose_markup_test.dart` — round trips including marks across line breaks
and block kinds surviving an edit; toggling, including the half-marked
selection and the split-a-run case; every re-anchoring rule in the table above.

`test/prose_editor_test.dart` — the controller's marks surviving typing,
pending marks, caret-following button state, scene switching; the toolbar
offering every mark the document can store, reflecting selection state, and
being disabled on Canon; and two Studio tests that press the toolbar and assert
the mark reaches `scene_prose_rows` with `is_formatted` set, then that a
formatted scene reopens formatted.

/// The flat view of a [ProseDocument], for editing.
///
/// A document is a tree: blocks holding spans holding marks. A Flutter text
/// field is not — it edits one flat string and reports one flat selection. This
/// library is the conversion between the two, and it is the only place that
/// conversion happens.
///
/// The flat form is the document's [ProseDocument.plainText] plus two side
/// tables anchored to offsets in it:
///
/// * [ranges] — where the inline marks are.
/// * [blockKinds] — what each line is, one entry per line.
///
/// Both are carried even though only marks have a UI yet. A document that
/// arrives with headings — from an archive, or from a later build — would
/// otherwise be flattened to paragraphs the first time an author typed in it,
/// which is a data loss nobody would see until they looked.
///
/// Nothing here imports Flutter. Rendering marks is the controller's job;
/// deciding what a mark *is* is this file's.
library;

import 'prose_document.dart';

/// A run of text carrying marks, as offsets into [ProseMarkup.text].
class MarkedRange {
  const MarkedRange({
    required this.start,
    required this.end,
    required this.marks,
  });

  /// Inclusive.
  final int start;

  /// Exclusive.
  final int end;

  final Set<ProseMark> marks;

  bool get isEmpty => end <= start || marks.isEmpty;

  int get length => end - start;

  bool contains(int offset) => offset >= start && offset < end;

  MarkedRange copyWith({int? start, int? end, Set<ProseMark>? marks}) =>
      MarkedRange(
        start: start ?? this.start,
        end: end ?? this.end,
        marks: marks ?? this.marks,
      );

  @override
  bool operator ==(Object other) =>
      other is MarkedRange &&
      other.start == start &&
      other.end == end &&
      other.marks.length == marks.length &&
      other.marks.containsAll(marks);

  @override
  int get hashCode => Object.hash(start, end, Object.hashAllUnordered(marks));

  @override
  String toString() => 'MarkedRange($start..$end, ${marks.map((m) => m.name)})';
}

/// One scene's prose, flattened for a text field.
class ProseMarkup {
  ProseMarkup({
    required this.text,
    List<MarkedRange> ranges = const [],
    List<ProseBlockKind> blockKinds = const [],
  })  : ranges = _normalize(ranges, text),
        blockKinds = _fitKinds(blockKinds, _lineCount(text));

  /// The document's plain text: block texts joined by newlines.
  final String text;

  /// Sorted, non-overlapping, non-empty, and clipped to [text].
  final List<MarkedRange> ranges;

  /// Exactly one entry per line of [text].
  final List<ProseBlockKind> blockKinds;

  static ProseMarkup get empty => ProseMarkup(text: '');

  /// Whether anything here is invisible to the plain text.
  ///
  /// Drives `scene_prose_rows.is_formatted`, which is what lets an unchanged
  /// save be settled by string comparison alone.
  bool get isPlain =>
      ranges.isEmpty &&
      blockKinds.every((kind) => kind == ProseBlockKind.paragraph);

  factory ProseMarkup.fromDocument(ProseDocument document) {
    final buffer = StringBuffer();
    final ranges = <MarkedRange>[];
    final kinds = <ProseBlockKind>[];
    var offset = 0;

    for (var index = 0; index < document.blocks.length; index++) {
      if (index > 0) {
        buffer.write('\n');
        offset += 1;
      }
      final block = document.blocks[index];
      kinds.add(block.kind);
      for (final span in block.spans) {
        if (span.text.isEmpty) continue;
        buffer.write(span.text);
        if (span.marks.isNotEmpty) {
          ranges.add(
            MarkedRange(
              start: offset,
              end: offset + span.text.length,
              marks: span.marks,
            ),
          );
        }
        offset += span.text.length;
      }
    }

    return ProseMarkup(
      text: buffer.toString(),
      ranges: ranges,
      blockKinds: kinds,
    );
  }

  /// Rebuilds the document this flattened.
  ///
  /// The inverse of [ProseMarkup.fromDocument] for every input, which is what
  /// makes it safe for the editor to hold the flat form and convert back on
  /// every save.
  ProseDocument toDocument() {
    final blocks = <ProseBlock>[];
    var lineStart = 0;
    final lines = text.split('\n');

    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final lineEnd = lineStart + line.length;
      blocks.add(
        ProseBlock(
          kind: index < blockKinds.length
              ? blockKinds[index]
              : ProseBlockKind.paragraph,
          spans: _spansFor(lineStart, lineEnd),
        ),
      );
      lineStart = lineEnd + 1;
    }

    return ProseDocument(blocks);
  }

  List<ProseSpan> _spansFor(int lineStart, int lineEnd) {
    if (lineEnd <= lineStart) return const [];
    final spans = <ProseSpan>[];
    var cursor = lineStart;

    for (final range in ranges) {
      if (range.end <= lineStart) continue;
      if (range.start >= lineEnd) break;
      final from = range.start < lineStart ? lineStart : range.start;
      final to = range.end > lineEnd ? lineEnd : range.end;
      if (from > cursor) {
        spans.add(ProseSpan(text.substring(cursor, from)));
      }
      spans.add(ProseSpan(text.substring(from, to), marks: range.marks));
      cursor = to;
    }

    if (cursor < lineEnd) {
      spans.add(ProseSpan(text.substring(cursor, lineEnd)));
    }
    return spans;
  }

  /// The marks carried by every character in `[start, end)`.
  ///
  /// Every character, not any: a toolbar button is lit only when the whole
  /// selection already has the mark, so pressing it reads as "remove" rather
  /// than as a no-op on the half that lacks it. For an empty selection this is
  /// the marks at the character before the caret, which is what decides the
  /// formatting of what gets typed next.
  Set<ProseMark> marksIn(int start, int end) {
    if (text.isEmpty) return const {};
    if (end <= start) {
      final probe = start - 1;
      if (probe < 0) return const {};
      return _marksAt(probe);
    }
    Set<ProseMark>? common;
    for (var offset = start; offset < end && offset < text.length; offset++) {
      final here = _marksAt(offset);
      if (here.isEmpty) return const {};
      common = common == null ? here : common.intersection(here);
      if (common.isEmpty) return const {};
    }
    return common ?? const {};
  }

  Set<ProseMark> _marksAt(int offset) {
    for (final range in ranges) {
      if (range.contains(offset)) return range.marks;
      if (range.start > offset) break;
    }
    return const {};
  }

  /// Adds [mark] across `[start, end)`, or removes it when every character in
  /// that span already has it.
  ///
  /// One method rather than separate add and remove, because the toolbar has
  /// one button per mark and its meaning is decided by what the selection
  /// already carries.
  ProseMarkup toggle(ProseMark mark, int start, int end) {
    if (end <= start) return this;
    final from = start.clamp(0, text.length);
    final to = end.clamp(0, text.length);
    if (to <= from) return this;

    final removing = marksIn(from, to).contains(mark);
    final rebuilt = <MarkedRange>[];

    for (var offset = from; offset < to; offset++) {
      final marks = {..._marksAt(offset)};
      if (removing) {
        marks.remove(mark);
      } else {
        marks.add(mark);
      }
      if (marks.isNotEmpty) {
        rebuilt.add(MarkedRange(start: offset, end: offset + 1, marks: marks));
      }
    }

    final untouched = [
      for (final range in ranges)
        ..._split(range, from, to),
    ];

    return ProseMarkup(
      text: text,
      ranges: [...untouched, ...rebuilt],
      blockKinds: blockKinds,
    );
  }

  /// The parts of [range] outside `[from, to)`.
  static List<MarkedRange> _split(MarkedRange range, int from, int to) {
    final parts = <MarkedRange>[];
    if (range.start < from) {
      parts.add(range.copyWith(end: range.end < from ? range.end : from));
    }
    if (range.end > to) {
      parts.add(range.copyWith(start: range.start > to ? range.start : to));
    }
    return [for (final part in parts) if (!part.isEmpty) part];
  }

  /// Re-anchors the marks onto [next] after the author edited the text.
  ///
  /// A text field hands back a whole new string, not an edit, so the edit is
  /// recovered by finding the common prefix and suffix. Everything between
  /// them is what changed.
  ///
  /// Insertions inside a marked run extend it, and insertions at its trailing
  /// edge extend it too — typing at the end of a bold word keeps typing bold,
  /// which is what every editor does and what an author expects. Typing at the
  /// *leading* edge does not, so a bold word can be prefixed with plain text.
  ProseMarkup withText(String next, {Set<ProseMark> applyMarks = const {}}) {
    if (next == text) return this;
    if (ranges.isEmpty && isPlain && applyMarks.isEmpty) {
      return ProseMarkup(text: next, blockKinds: const []);
    }

    var prefix = 0;
    final shortest = text.length < next.length ? text.length : next.length;
    while (prefix < shortest && text[prefix] == next[prefix]) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < shortest - prefix &&
        text[text.length - 1 - suffix] == next[next.length - 1 - suffix]) {
      suffix++;
    }

    final removedFrom = prefix;
    final removedTo = text.length - suffix;
    final insertedLength = next.length - suffix - prefix;
    final delta = insertedLength - (removedTo - removedFrom);
    final isInsertion = removedTo == removedFrom;

    // A pure insertion and a replacement move an edge differently, and the
    // difference is what an author feels. Typing at offset p pushes a run that
    // *starts* at p (so a bold word can be prefixed with plain text) and
    // extends one that *ends* at p (so carrying on past a bold word keeps
    // typing bold). A deletion has no such choice to make: both edges collapse
    // to where the deleted span began.
    int moveInsertion(int offset) =>
        offset < removedFrom ? offset : offset + insertedLength;

    int moveReplacement(int offset) {
      if (offset <= removedFrom) return offset;
      if (offset >= removedTo) return offset + delta;
      return removedFrom;
    }

    final move = isInsertion ? moveInsertion : moveReplacement;

    final moved = <MarkedRange>[];
    for (final range in ranges) {
      final start = move(range.start);
      final end = move(range.end);
      if (end > start) {
        moved.add(MarkedRange(start: start, end: end, marks: range.marks));
      }
    }

    // Marks the author asked for while the caret was empty land on whatever
    // they then typed. Without this, choosing bold and typing produces plain
    // text and the button looks broken.
    if (applyMarks.isNotEmpty && isInsertion && insertedLength > 0) {
      moved.add(
        MarkedRange(
          start: removedFrom,
          end: removedFrom + insertedLength,
          marks: applyMarks,
        ),
      );
    }

    return ProseMarkup(
      text: next,
      ranges: moved,
      blockKinds: _reanchorKinds(next),
    );
  }

  List<ProseBlockKind> _reanchorKinds(String next) {
    final before = _lineCount(text);
    final after = _lineCount(next);
    if (after == before) return blockKinds;
    if (after < before) return blockKinds.take(after).toList();
    return [
      ...blockKinds,
      for (var index = before; index < after; index++) ProseBlockKind.paragraph,
    ];
  }

  static int _lineCount(String text) => text.split('\n').length;

  static List<ProseBlockKind> _fitKinds(
    List<ProseBlockKind> kinds,
    int lines,
  ) {
    if (kinds.length == lines) return List.unmodifiable(kinds);
    return List.unmodifiable([
      for (var index = 0; index < lines; index++)
        index < kinds.length ? kinds[index] : ProseBlockKind.paragraph,
    ]);
  }

  /// Sorts, clips, drops empties and merges neighbours carrying equal marks.
  ///
  /// Without the merge, toggling bold over a paragraph would leave one range
  /// per character: correct, and unusable to read or store.
  static List<MarkedRange> _normalize(List<MarkedRange> input, String text) {
    final length = text.length;
    final clipped = <MarkedRange>[];
    for (final range in input) {
      final start = range.start.clamp(0, length);
      final end = range.end.clamp(0, length);
      if (end <= start || range.marks.isEmpty) continue;
      // A mark belongs to characters inside a line. The newline between two
      // blocks is in no block's text, so a run that spans one is split here
      // rather than silently losing its second half on the way to a document.
      var from = start;
      for (var offset = start; offset < end; offset++) {
        if (text[offset] != '\n') continue;
        if (offset > from) {
          clipped.add(
            MarkedRange(start: from, end: offset, marks: {...range.marks}),
          );
        }
        from = offset + 1;
      }
      if (end > from) {
        clipped.add(MarkedRange(start: from, end: end, marks: {...range.marks}));
      }
    }
    clipped.sort((left, right) => left.start.compareTo(right.start));

    final merged = <MarkedRange>[];
    for (final range in clipped) {
      if (merged.isEmpty) {
        merged.add(range);
        continue;
      }
      final previous = merged.last;
      final sameMarks = previous.marks.length == range.marks.length &&
          previous.marks.containsAll(range.marks);
      if (sameMarks && range.start <= previous.end) {
        merged[merged.length - 1] = previous.copyWith(
          end: range.end > previous.end ? range.end : previous.end,
        );
      } else {
        merged.add(range);
      }
    }
    return List.unmodifiable(merged);
  }

  @override
  bool operator ==(Object other) =>
      other is ProseMarkup &&
      other.text == text &&
      _listEquals(other.ranges, ranges) &&
      _listEquals(other.blockKinds, blockKinds);

  @override
  int get hashCode =>
      Object.hash(text, Object.hashAll(ranges), Object.hashAll(blockKinds));
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}

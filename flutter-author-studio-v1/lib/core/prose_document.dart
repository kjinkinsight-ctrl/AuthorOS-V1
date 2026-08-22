/// Manuscript prose — the document model.
///
/// Until now a scene's prose was a bare `String`, and the whole manuscript —
/// every chapter, every scene, every word of it — was re-serialised into a
/// single `SharedPreferences` entry on every autosave tick. That made three
/// things impossible at once: formatting (a `String` has nowhere to put a
/// mark), scale (a 120,000-word manuscript rewrote 120,000 words to record a
/// three-letter edit), and recovery (nothing kept what the prose used to say).
///
/// This library is the first of those three: a document that can carry
/// structure and inline marks, and that still projects back to exactly the
/// plain text it came from. Two rules govern it:
///
/// * It is presentation-independent. Nothing here imports Flutter, and nothing
///   here decides how a mark is drawn.
/// * It is losslessly plain-text-compatible. [ProseDocument.fromPlainText]
///   followed by [ProseDocument.plainText] returns the original string for
///   every input, so migrating today's prose cannot lose a character, and any
///   code that still wants a `String` keeps working.
///
/// The word-count algorithm lives here and nowhere else. It is the same
/// whitespace split `ManuscriptScene.wordCount` has always used, so counts
/// stay identical across the migration and every statistic built on them —
/// writing sessions, streaks, goals, progress bars — keeps its meaning.
library;

/// An inline mark applied to a run of text.
///
/// Deliberately small. These four are what a manuscript needs; a mark that
/// carries data (a comment, a link, a citation) is a different shape and does
/// not belong in this enum.
enum ProseMark { bold, italic, underline, strikethrough }

/// Resolves persisted mark ids without throwing on values a newer build wrote.
extension ProseMarkX on ProseMark {
  String get id => name;

  /// The mark named [id], or `null` when nothing matches.
  ///
  /// Returning `null` rather than throwing is what lets an older build open a
  /// document a newer one saved: it drops the mark it cannot draw and keeps
  /// the words, which is always the better of the two failures.
  static ProseMark? fromId(String? id) {
    for (final mark in ProseMark.values) {
      if (mark.name == id) return mark;
    }
    return null;
  }
}

/// The kind of a block-level unit of prose.
enum ProseBlockKind {
  paragraph,
  heading1,
  heading2,
  heading3,
  blockQuote,

  /// The typographic break between two scenes inside one chapter.
  sceneBreak,
}

/// Resolves persisted block ids, defaulting to a paragraph.
extension ProseBlockKindX on ProseBlockKind {
  String get id => name;

  static ProseBlockKind fromId(String? id) {
    for (final kind in ProseBlockKind.values) {
      if (kind.name == id) return kind;
    }
    return ProseBlockKind.paragraph;
  }
}

/// A run of text sharing one set of marks.
class ProseSpan {
  const ProseSpan(this.text, {this.marks = const <ProseMark>{}});

  final String text;
  final Set<ProseMark> marks;

  bool get isPlain => marks.isEmpty;

  ProseSpan copyWith({String? text, Set<ProseMark>? marks}) =>
      ProseSpan(text ?? this.text, marks: marks ?? this.marks);

  Map<String, Object?> toJson() => {
        'text': text,
        if (marks.isNotEmpty)
          'marks': [
            for (final mark in ProseMark.values)
              if (marks.contains(mark)) mark.id,
          ],
      };

  factory ProseSpan.fromJson(Map<String, dynamic> json) => ProseSpan(
        (json['text'] as String?) ?? '',
        marks: _decodeMarks(json['marks'] as List?),
      );

  static Set<ProseMark> _decodeMarks(List<Object?>? raw) {
    if (raw == null || raw.isEmpty) return const <ProseMark>{};
    final marks = <ProseMark>{};
    for (final value in raw) {
      final mark = ProseMarkX.fromId(value?.toString());
      if (mark != null) marks.add(mark);
    }
    return marks;
  }

  @override
  bool operator ==(Object other) =>
      other is ProseSpan &&
      other.text == text &&
      other.marks.length == marks.length &&
      other.marks.containsAll(marks);

  @override
  int get hashCode => Object.hash(
        text,
        Object.hashAllUnordered(marks),
      );
}

/// One block-level unit of prose: a paragraph, a heading, a scene break.
class ProseBlock {
  const ProseBlock({
    this.kind = ProseBlockKind.paragraph,
    this.spans = const <ProseSpan>[],
  });

  /// A plain, unmarked paragraph holding [text].
  factory ProseBlock.paragraph(String text) => ProseBlock(
        spans: text.isEmpty ? const [] : [ProseSpan(text)],
      );

  final ProseBlockKind kind;
  final List<ProseSpan> spans;

  /// The block's text with every mark removed.
  String get text => spans.map((span) => span.text).join();

  bool get isEmpty => text.isEmpty;

  /// Whether this block is an unmarked paragraph — the shape every scene
  /// written before the document model has, and the shape the compact
  /// encoding in [ProseDocument.toJson] is allowed to collapse.
  bool get isPlainParagraph =>
      kind == ProseBlockKind.paragraph &&
      spans.every((span) => span.isPlain);

  ProseBlock copyWith({ProseBlockKind? kind, List<ProseSpan>? spans}) =>
      ProseBlock(kind: kind ?? this.kind, spans: spans ?? this.spans);

  Map<String, Object?> toJson() => {
        'kind': kind.id,
        'spans': [for (final span in spans) span.toJson()],
      };

  factory ProseBlock.fromJson(Map<String, dynamic> json) => ProseBlock(
        kind: ProseBlockKindX.fromId(json['kind'] as String?),
        spans: [
          for (final raw in (json['spans'] as List? ?? const []))
            ProseSpan.fromJson(Map<String, dynamic>.from(raw as Map)),
        ],
      );

  @override
  bool operator ==(Object other) =>
      other is ProseBlock &&
      other.kind == kind &&
      _listEquals(other.spans, spans);

  @override
  int get hashCode => Object.hash(kind, Object.hashAll(spans));
}

/// The prose of one scene.
///
/// A document is an ordered list of blocks. Its [plainText] is the blocks'
/// text joined by newlines, which is the inverse of [ProseDocument.fromPlainText]
/// for every possible input — see the library comment for why that matters.
class ProseDocument {
  const ProseDocument(this.blocks);

  /// The empty document: one empty paragraph, so an empty scene and a scene
  /// holding `''` are the same document rather than two different ones.
  static const ProseDocument empty = ProseDocument([ProseBlock()]);

  /// The current on-disk shape of [toJson].
  ///
  /// Persisted with every document so a later shape can be recognised and
  /// converted rather than guessed at.
  static const int schemaVersion = 1;

  final List<ProseBlock> blocks;

  /// Builds a document from [text], one paragraph per line.
  ///
  /// Line-per-paragraph — rather than the more usual blank-line-separated
  /// paragraphs — is what makes the round-trip exact: blank lines survive as
  /// empty paragraphs instead of being collapsed away.
  factory ProseDocument.fromPlainText(String text) => ProseDocument([
        for (final line in text.split('\n')) ProseBlock.paragraph(line),
      ]);

  /// The document's text with every mark and block distinction removed.
  String get plainText => blocks.map((block) => block.text).join('\n');

  bool get isEmpty => plainText.isEmpty;

  /// Whether every block is an unmarked paragraph.
  bool get isPlainText => blocks.every((block) => block.isPlainParagraph);

  /// The manuscript's canonical word count.
  ///
  /// The one implementation of this algorithm. `ManuscriptScene.wordCount`
  /// delegates here so a scene's count cannot drift from its document's.
  int get wordCount => countWords(plainText);

  /// Counts the words in [text].
  static int countWords(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }

  /// The persisted shape.
  ///
  /// A document that carries no formatting is written as its plain text
  /// instead of a block list. Every scene written before this model is exactly
  /// that shape, so the migration does not inflate a manuscript on disk, and a
  /// scene only starts paying for the block encoding once it holds something
  /// the block encoding is needed for.
  Map<String, Object?> toJson() => isPlainText
      ? {'schema': schemaVersion, 'text': plainText}
      : {
          'schema': schemaVersion,
          'blocks': [for (final block in blocks) block.toJson()],
        };

  factory ProseDocument.fromJson(Map<String, dynamic> json) {
    final blocks = json['blocks'] as List?;
    if (blocks == null) {
      return ProseDocument.fromPlainText((json['text'] as String?) ?? '');
    }
    if (blocks.isEmpty) return ProseDocument.empty;
    return ProseDocument([
      for (final raw in blocks)
        ProseBlock.fromJson(Map<String, dynamic>.from(raw as Map)),
    ]);
  }

  @override
  bool operator ==(Object other) =>
      other is ProseDocument && _listEquals(other.blocks, blocks);

  @override
  int get hashCode => Object.hashAll(blocks);
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}

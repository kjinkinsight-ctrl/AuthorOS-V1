/// Book Studio Phase 6 — inline emphasis.
///
/// Emphasis reaches a book two ways, and this library is the second of them.
///
/// The first is a real mark: Manuscript Studio's toolbar writes
/// [ProseMark.italic] into the scene's [ProseDocument], and
/// `BookParagraph.marked` carries it through to every exporter untouched. Where
/// the author used it, it decides, and nothing here runs.
///
/// The second is what this parses. A scene's `content` is a plain string —
/// a deliberate storage decision made long before Book Studio, and what makes a
/// scene diffable, searchable and recoverable, and lets every proof finding
/// point at a character offset. Prose typed into that string before the toolbar
/// existed, or into any field that has no toolbar, still needs a way to say
/// "this part is emphasised". The author writes `_like this_`, the marker
/// travels with the prose, and every format resolves it into whatever emphasis
/// means there.
///
/// **One parser, four consumers.** The layout engine, the EPUB, the DOCX and
/// the text exporter all call this. That is the same reasoning
/// `chapterNumberLabel` records in `book_format.dart`: four implementations of
/// what emphasis means is how a paragraph comes to read one way in the PDF and
/// another in the Word file.
///
/// **It is off by default and errs towards leaving prose alone.** Turning a
/// convention on reinterprets writing that already exists, and an underscore is
/// a character authors legitimately use — file names, snake_case, a character
/// who types that way. Every rule below exists to make a false positive
/// unlikely, because a false positive silently rewrites somebody's page.
library;

import '../core/prose_document.dart';
import 'book_format.dart';

export '../core/prose_document.dart' show ProseMark, ProseSpan;

/// The one set of marks a book can set today.
///
/// Only italic. The bundled faces are roman and italic per family, and neither
/// the PDF renderer nor the line breaker has anywhere to put an underline or a
/// strikethrough. A mark this build cannot set is reported by preflight rather
/// than dropped in silence — see `UnsettableMarkCheck`.
const Set<ProseMark> italicOnly = {ProseMark.italic};

/// Emphasis, in the one sense a book can set.
///
/// The book layer speaks of italic where the manuscript speaks of marks, and
/// this is the whole of the translation. [ProseSpan] itself comes from
/// `core/prose_document.dart` — the manuscript's own type, which is plain Dart
/// and so is safe for the layout engine to import. Sharing it is what lets a
/// mark the author applied in the editor reach the PDF unchanged, rather than
/// being round-tripped through a text convention on the way.
extension BookProseSpan on ProseSpan {
  bool get italic => marks.contains(ProseMark.italic);

  /// The marks this build cannot set, which is every mark but italic.
  Set<ProseMark> get unsettableMarks =>
      marks.where((mark) => mark != ProseMark.italic).toSet();
}

/// Splits [paragraph] on the author's convention.
///
/// Returns a single unstyled span when the convention is off, when the
/// paragraph carries no emphasis, or when what looked like a marker turns out
/// not to be one. The concatenated [ProseSpan.text] of the result is always the
/// paragraph with its markers removed and nothing else changed.
List<ProseSpan> parseProse(String paragraph, BookInlineMarkup markup) {
  if (markup == BookInlineMarkup.none || paragraph.isEmpty) {
    return [ProseSpan(paragraph)];
  }
  return _parseUnderscore(paragraph);
}

/// [paragraph] with the markers taken out and nothing else changed.
String stripProse(String paragraph, BookInlineMarkup markup) {
  if (markup == BookInlineMarkup.none) return paragraph;
  final buffer = StringBuffer();
  for (final span in parseProse(paragraph, markup)) {
    buffer.write(span.text);
  }
  return buffer.toString();
}

/// Whether [paragraph] carries any emphasis at all.
bool hasEmphasis(String paragraph, BookInlineMarkup markup) =>
    parseProse(paragraph, markup).any((span) => span.italic);

/// Whether [paragraph] opens emphasis it never closes.
///
/// Reported by the proofing stage rather than guessed at. A dropped closing
/// marker is the one failure that actually matters: the author meant a phrase
/// and the parser, refusing to run off the end of the paragraph, gives them
/// none at all.
bool hasUnclosedEmphasis(String paragraph, BookInlineMarkup markup) {
  if (markup == BookInlineMarkup.none) return false;
  return _findOpener(paragraph, from: 0, requireClose: false) >= 0 &&
      !hasEmphasis(paragraph, markup);
}

// --- the underscore convention ---------------------------------------------

const _underscore = 0x5F; // _

/// True when [code] is a space, tab or any other Unicode separator.
bool _isSpace(int code) =>
    code == 0x20 || code == 0x09 || code == 0x0A || code == 0x0D ||
    code == 0xA0 || code == 0x2007 || code == 0x202F;

/// True where a closing marker is allowed to sit: the end of the paragraph,
/// whitespace, or punctuation that naturally follows a phrase.
///
/// Punctuation is included because `_the Kestrel_,` and `_why?_` are how
/// emphasis actually ends in prose. Requiring whitespace after the marker would
/// fail on the majority of real sentences.
bool _closerFollows(String text, int index) {
  if (index >= text.length) return true;
  final code = text.codeUnitAt(index);
  if (_isSpace(code)) return true;
  return const {
    0x2E, 0x2C, 0x3B, 0x3A, 0x21, 0x3F, // . , ; : ! ?
    0x29, 0x5D, 0x7D, // ) ] }
    0x22, 0x27, // " '
    0x201C, 0x201D, 0x2018, 0x2019, // curly quotes
    0x2014, 0x2013, // em and en dash
    0x2026, // ellipsis
  }.contains(code);
}

/// True where an opening marker is allowed to sit: the start of the paragraph,
/// after whitespace, or after punctuation that naturally precedes a phrase.
bool _openerPrecedes(String text, int index) {
  if (index == 0) return true;
  final code = text.codeUnitAt(index - 1);
  if (_isSpace(code)) return true;
  return const {
    0x28, 0x5B, 0x7B, // ( [ {
    0x22, 0x27, // " '
    0x201C, 0x2018, // opening curly quotes
    0x2014, 0x2013, // em and en dash
  }.contains(code);
}

/// The index of the next character that could open emphasis, or -1.
///
/// When [requireClose] is false this answers "is there a plausible opener at
/// all", which is what the unclosed-emphasis check needs.
int _findOpener(String text, {required int from, bool requireClose = true}) {
  for (var i = from; i < text.length; i++) {
    if (text.codeUnitAt(i) != _underscore) continue;

    // `__` is a literal underscore, escaping itself, so neither half opens.
    if (i + 1 < text.length && text.codeUnitAt(i + 1) == _underscore) {
      i++;
      continue;
    }
    if (!_openerPrecedes(text, i)) continue;
    // An opener has to be followed by something to emphasise.
    if (i + 1 >= text.length || _isSpace(text.codeUnitAt(i + 1))) continue;

    if (!requireClose) return i;
    if (_findCloser(text, from: i + 1) > 0) return i;
  }
  return -1;
}

/// The index of the marker that closes emphasis opened before [from], or -1.
int _findCloser(String text, {required int from}) {
  for (var i = from; i < text.length; i++) {
    if (text.codeUnitAt(i) != _underscore) continue;

    if (i + 1 < text.length && text.codeUnitAt(i + 1) == _underscore) {
      i++;
      continue;
    }
    // A closer has to have something before it, and has to end a phrase.
    if (_isSpace(text.codeUnitAt(i - 1))) continue;
    if (!_closerFollows(text, i + 1)) continue;
    return i;
  }
  return -1;
}

List<ProseSpan> _parseUnderscore(String paragraph) {
  final spans = <ProseSpan>[];
  final plain = StringBuffer();
  var index = 0;

  void flushPlain() {
    if (plain.isEmpty) return;
    spans.add(ProseSpan(plain.toString()));
    plain.clear();
  }

  while (index < paragraph.length) {
    final open = _findOpener(paragraph, from: index);
    if (open < 0) break;

    final close = _findCloser(paragraph, from: open + 1);
    if (close < 0) break;

    plain.write(_unescape(paragraph.substring(index, open)));
    flushPlain();
    spans.add(ProseSpan(
      _unescape(paragraph.substring(open + 1, close)),
      marks: italicOnly,
    ));
    index = close + 1;
  }

  plain.write(_unescape(paragraph.substring(index)));
  flushPlain();

  // An empty paragraph still has to be one span, so a caller can always write
  // `spans.first` without checking.
  return spans.isEmpty ? [const ProseSpan('')] : spans;
}

/// `__` becomes a single literal underscore once the markers are resolved.
String _unescape(String text) =>
    text.contains('__') ? text.replaceAll('__', '_') : text;

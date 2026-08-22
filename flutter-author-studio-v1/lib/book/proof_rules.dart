/// Book Studio Phase 3 — the rules.
///
/// A registry rather than a switch, so a rule is data: it can be listed,
/// described, switched off, and added to without touching the engine.
///
/// Each rule is a pure function over text and structure. Where a rule offers a
/// replacement it is because the correct answer is unambiguous; where it does
/// not, that is deliberate. An unbalanced quotation mark needs a person, and a
/// tool that guesses at prose is worse than one that points and stays quiet.
library;

import '../manuscript_store.dart';
import 'book_document.dart';
import 'book_layout.dart';
import 'proofing.dart';

/// Every text rule, in the order the studio lists them.
class BuiltInProofRules {
  const BuiltInProofRules._();

  static const List<ProofRule> all = [
    // Editing: the mechanics of the text.
    ManualIndentRule(),
    DoubleSpaceRule(),
    TrailingWhitespaceRule(),
    SpaceBeforePunctuationRule(),
    StraightQuotesRule(),
    StraightApostrophesRule(),
    RepeatedWordRule(),
    MixedDashesRule(),
    EllipsisStyleRule(),
    // Proofing: what only the whole book can see.
    SceneBreakConsistencyRule(),
    EmptyNodeRule(),
    ChapterTitleConsistencyRule(),
    UnbalancedQuotesRule(),
    UnbalancedBracketsRule(),
    FrontMatterCompleteRule(),
    SpellingRule(),
  ];

  static const List<LayoutProofRule> layout = [
    RiverRule(),
    WidowOrphanRule(),
    ShortChapterEndRule(),
    BlankPageRule(),
    SignatureRule(),
  ];

  static ProofRule? byId(String id) {
    for (final rule in all) {
      if (rule.id == id) return rule;
    }
    return null;
  }

  /// The ids a new project runs.
  static Set<String> get defaultEnabled => {
        for (final rule in all)
          if (rule.defaultEnabled) rule.id,
        for (final rule in layout)
          if (rule.defaultEnabled) rule.id,
      };
}

// --- editing -------------------------------------------------------------

/// Indentation typed by hand.
///
/// The highest-value rule in the set, and the clearest link between writing and
/// formatting: the layout engine applies `firstLineIndentPt` itself, so a
/// paragraph that also starts with a tab or a run of spaces is indented twice.
/// It looks fine in a plain editor and wrong in the finished book.
class ManualIndentRule extends ProofRule {
  const ManualIndentRule();

  @override
  String get id => 'manualIndent';
  @override
  String get label => 'Indentation typed by hand';
  @override
  String get description =>
      'Tabs or spaces at the start of a paragraph. The book applies its own '
      'first-line indent, so these are indented twice.';
  @override
  ProofStage get stage => ProofStage.editing;

  @override
  Iterable<ProofFinding> run(ProofContext context) sync* {
    for (final entry in context.scenes) {
      final content = entry.scene.content;
      var offset = 0;
      for (final line in content.split('\n')) {
        final match = RegExp(r'^[ \t]+').firstMatch(line);
        if (match != null && line.trim().isNotEmpty) {
          yield ProofFinding(
            ruleId: id,
            stage: stage,
            severity: ProofSeverity.warning,
            title: 'Indent typed by hand',
            message: 'The book adds its own first-line indent, so this '
                'paragraph would be indented twice.',
            sceneId: entry.scene.id,
            chapterId: entry.chapter.id,
            where: context.describe(entry.chapter, entry.scene),
            start: offset,
            end: offset + match.end,
            found: line.substring(0, match.end),
            replacement: '',
          );
        }
        offset += line.length + 1;
      }
    }
  }
}

/// More than one space between words.
class DoubleSpaceRule extends ProofRule {
  const DoubleSpaceRule();

  @override
  String get id => 'doubleSpace';
  @override
  String get label => 'Double spaces';
  @override
  String get description =>
      'Two or more spaces between words. Typesetting handles the spacing.';
  @override
  ProofStage get stage => ProofStage.editing;

  @override
  Iterable<ProofFinding> run(ProofContext context) sync* {
    for (final entry in context.scenes) {
      final content = entry.scene.content;
      for (final match in RegExp(r'(?<=\S) {2,}(?=\S)').allMatches(content)) {
        yield ProofFinding(
          ruleId: id,
          stage: stage,
          severity: ProofSeverity.notice,
          title: 'Double space',
          message: 'Collapsed to a single space.',
          sceneId: entry.scene.id,
          chapterId: entry.chapter.id,
          where: context.describe(entry.chapter, entry.scene),
          start: match.start,
          end: match.end,
          found: match.group(0)!,
          replacement: ' ',
        );
      }
    }
  }
}

/// Spaces or tabs left at the end of a line.
class TrailingWhitespaceRule extends ProofRule {
  const TrailingWhitespaceRule();

  @override
  String get id => 'trailingWhitespace';
  @override
  String get label => 'Trailing whitespace';
  @override
  String get description => 'Spaces or tabs left at the end of a line.';
  @override
  ProofStage get stage => ProofStage.editing;

  @override
  Iterable<ProofFinding> run(ProofContext context) sync* {
    for (final entry in context.scenes) {
      final content = entry.scene.content;
      var offset = 0;
      for (final line in content.split('\n')) {
        final match = RegExp(r'[ \t]+$').firstMatch(line);
        if (match != null && line.trim().isNotEmpty) {
          yield ProofFinding(
            ruleId: id,
            stage: stage,
            severity: ProofSeverity.notice,
            title: 'Trailing whitespace',
            message: 'Removed from the end of the line.',
            sceneId: entry.scene.id,
            chapterId: entry.chapter.id,
            where: context.describe(entry.chapter, entry.scene),
            start: offset + match.start,
            end: offset + match.end,
            found: match.group(0)!,
            replacement: '',
          );
        }
        offset += line.length + 1;
      }
    }
  }
}

/// A space before a comma or a full stop.
class SpaceBeforePunctuationRule extends ProofRule {
  const SpaceBeforePunctuationRule();

  @override
  String get id => 'spaceBeforePunctuation';
  @override
  String get label => 'Space before punctuation';
  @override
  String get description =>
      'A space sitting in front of a comma, full stop or similar.';
  @override
  ProofStage get stage => ProofStage.editing;

  @override
  Iterable<ProofFinding> run(ProofContext context) sync* {
    for (final entry in context.scenes) {
      final content = entry.scene.content;
      for (final match
          in RegExp(r'(?<=\S)[ \t]+(?=[,.;:!?])').allMatches(content)) {
        yield ProofFinding(
          ruleId: id,
          stage: stage,
          severity: ProofSeverity.warning,
          title: 'Space before punctuation',
          message: 'The space in front of the punctuation is removed.',
          sceneId: entry.scene.id,
          chapterId: entry.chapter.id,
          where: context.describe(entry.chapter, entry.scene),
          start: match.start,
          end: match.end,
          found: match.group(0)!,
          replacement: '',
        );
      }
    }
  }
}

/// Typewriter double quotes.
///
/// The direction is decided by what comes before the mark: a quote opens at the
/// start of a line, after whitespace, or after an opening bracket or a dash,
/// and closes otherwise. That is the whole rule, and it is right far more often
/// than it is wrong because prose alternates.
class StraightQuotesRule extends ProofRule {
  const StraightQuotesRule();

  @override
  String get id => 'straightQuotes';
  @override
  String get label => 'Straight quotation marks';
  @override
  String get description =>
      'Typewriter quotes ("), replaced with the curly marks a book is set in.';
  @override
  ProofStage get stage => ProofStage.editing;

  @override
  Iterable<ProofFinding> run(ProofContext context) sync* {
    for (final entry in context.scenes) {
      final content = entry.scene.content;
      for (var i = 0; i < content.length; i++) {
        if (content[i] != '"') continue;
        final before = i == 0 ? '' : content[i - 1];
        final opens = before.isEmpty ||
            RegExp(r'[\s(\[\{—–‘“]').hasMatch(before);
        yield ProofFinding(
          ruleId: id,
          stage: stage,
          severity: ProofSeverity.warning,
          title: opens ? 'Straight opening quote' : 'Straight closing quote',
          message: 'Replaced with ${opens ? 'an opening' : 'a closing'} '
              'quotation mark.',
          sceneId: entry.scene.id,
          chapterId: entry.chapter.id,
          where: context.describe(entry.chapter, entry.scene),
          start: i,
          end: i + 1,
          found: '"',
          replacement: opens ? '“' : '”',
        );
      }
    }
  }
}

/// Typewriter apostrophes.
///
/// Only the unambiguous cases are offered a replacement: an apostrophe between
/// two letters is a contraction, and a leading apostrophe on a known elision or
/// a decade is the same right-hand mark. A single quote opening reported speech
/// is left alone with a notice, because guessing there mangles prose, and
/// mangled prose is worse than an unfixed one.
class StraightApostrophesRule extends ProofRule {
  const StraightApostrophesRule();

  static const _elisions = {
    'tis', 'twas', 'em', 'til', 'round', 'cause', 'bout', 'n', 'nother',
  };

  @override
  String get id => 'straightApostrophes';
  @override
  String get label => 'Straight apostrophes';
  @override
  String get description =>
      "Typewriter apostrophes ('), replaced with the typographic mark where "
      'the meaning is certain.';
  @override
  ProofStage get stage => ProofStage.editing;

  @override
  Iterable<ProofFinding> run(ProofContext context) sync* {
    final letter = RegExp(r'[A-Za-z]');
    for (final entry in context.scenes) {
      final content = entry.scene.content;
      for (var i = 0; i < content.length; i++) {
        if (content[i] != "'") continue;
        final before = i == 0 ? '' : content[i - 1];
        final after = i + 1 >= content.length ? '' : content[i + 1];

        final isContraction =
            letter.hasMatch(before) && letter.hasMatch(after);
        // Only a plural possessive is unambiguous here. "boys'" ends in an s
        // and can be nothing else; "go'" is far more likely to be closing a
        // single-quoted phrase, and rewriting it would change the punctuation
        // the author meant.
        final pluralPossessive = (before == 's' || before == 'S') &&
            !letter.hasMatch(after);
        final elision = _isElision(content, i);

        if (isContraction || pluralPossessive || elision) {
          yield ProofFinding(
            ruleId: id,
            stage: stage,
            severity: ProofSeverity.notice,
            title: 'Straight apostrophe',
            message: 'Replaced with a typographic apostrophe.',
            sceneId: entry.scene.id,
            chapterId: entry.chapter.id,
            where: context.describe(entry.chapter, entry.scene),
            start: i,
            end: i + 1,
            found: "'",
            replacement: '’',
          );
        } else {
          yield ProofFinding(
            ruleId: id,
            stage: stage,
            severity: ProofSeverity.notice,
            title: 'Single quote left alone',
            message: 'This could open quoted speech or close a quotation, and '
                'guessing would risk changing what you wrote. Set it by hand.',
            sceneId: entry.scene.id,
            chapterId: entry.chapter.id,
            where: context.describe(entry.chapter, entry.scene),
            start: i,
            end: i + 1,
            found: "'",
          );
        }
      }
    }
  }

  /// `'tis`, `'em`, `'90s` and the like: the mark leans the same way as a
  /// contraction even though it starts the word.
  bool _isElision(String content, int index) {
    final after = content.substring(index + 1);
    if (RegExp(r'^\d0s\b').hasMatch(after)) return true;
    final word = RegExp(r'^[A-Za-z]+').firstMatch(after)?.group(0);
    if (word == null) return false;
    final before = index == 0 ? '' : content[index - 1];
    if (RegExp(r'[A-Za-z]').hasMatch(before)) return false;
    return _elisions.contains(word.toLowerCase());
  }
}

/// The same word twice in a row.
class RepeatedWordRule extends ProofRule {
  const RepeatedWordRule();

  /// Doubling that is ordinary English rather than a slip.
  static const _allowed = {
    'had had', 'that that', 'is is', 'no no', 'so so', 'very very',
    'ha ha', 'bye bye', 'night night',
  };

  @override
  String get id => 'repeatedWord';
  @override
  String get label => 'Repeated words';
  @override
  String get description =>
      'The same word twice in a row — usually a slip left behind by an edit.';
  @override
  ProofStage get stage => ProofStage.editing;

  @override
  Iterable<ProofFinding> run(ProofContext context) sync* {
    final pattern = RegExp(r'\b([A-Za-z]+)([ \t]+)(\1)\b', caseSensitive: false);
    for (final entry in context.scenes) {
      final content = entry.scene.content;
      for (final match in pattern.allMatches(content)) {
        final phrase = '${match.group(1)!} ${match.group(3)!}'.toLowerCase();
        if (_allowed.contains(phrase)) continue;
        yield ProofFinding(
          ruleId: id,
          stage: stage,
          severity: ProofSeverity.warning,
          title: 'Repeated word',
          message: '"${match.group(1)}" appears twice in a row.',
          sceneId: entry.scene.id,
          chapterId: entry.chapter.id,
          where: context.describe(entry.chapter, entry.scene),
          start: match.start,
          end: match.end,
          found: match.group(0)!,
          replacement: match.group(1)!,
        );
      }
    }
  }
}

/// Several kinds of dash used for the same job.
///
/// Whole-book, because consistency is the point: one book, one dash. The form
/// the author used most often wins, so the fix follows their habit rather than
/// a house style they never asked for.
class MixedDashesRule extends ProofRule {
  const MixedDashesRule();

  @override
  String get id => 'mixedDashes';
  @override
  String get label => 'Mixed dashes';
  @override
  String get description =>
      'Double hyphens, en dashes and em dashes used interchangeably. The form '
      'you use most often becomes the book\'s.';
  @override
  ProofStage get stage => ProofStage.proofing;

  @override
  Iterable<ProofFinding> run(ProofContext context) sync* {
    final forms = <String, RegExp>{
      '--': RegExp(r'(?<![-])--(?![-])'),
      '–': RegExp(r'(?<=\S)–(?=\S)'),
      '—': RegExp('—'),
    };

    final counts = <String, int>{for (final key in forms.keys) key: 0};
    for (final entry in context.scenes) {
      for (final form in forms.entries) {
        counts[form.key] =
            counts[form.key]! + form.value.allMatches(entry.scene.content).length;
      }
    }

    final used = counts.entries.where((e) => e.value > 0).toList();
    if (used.length < 2) return;
    used.sort((a, b) => b.value.compareTo(a.value));
    final winner = used.first.key;

    for (final entry in context.scenes) {
      for (final form in forms.entries) {
        if (form.key == winner) continue;
        for (final match in form.value.allMatches(entry.scene.content)) {
          yield ProofFinding(
            ruleId: id,
            stage: stage,
            severity: ProofSeverity.notice,
            title: 'Inconsistent dash',
            message: 'This book mostly uses "$winner".',
            sceneId: entry.scene.id,
            chapterId: entry.chapter.id,
            where: context.describe(entry.chapter, entry.scene),
            start: match.start,
            end: match.end,
            found: match.group(0)!,
            replacement: winner,
          );
        }
      }
    }
  }
}

/// Three dots and the ellipsis character, mixed.
class EllipsisStyleRule extends ProofRule {
  const EllipsisStyleRule();

  @override
  String get id => 'ellipsisStyle';
  @override
  String get label => 'Mixed ellipses';
  @override
  String get description =>
      'Three full stops and the ellipsis character used interchangeably.';
  @override
  ProofStage get stage => ProofStage.proofing;

  @override
  Iterable<ProofFinding> run(ProofContext context) sync* {
    final dots = RegExp(r'\.{3,}');
    final glyph = RegExp('…');

    var dotCount = 0;
    var glyphCount = 0;
    for (final entry in context.scenes) {
      dotCount += dots.allMatches(entry.scene.content).length;
      glyphCount += glyph.allMatches(entry.scene.content).length;
    }
    if (dotCount == 0 || glyphCount == 0) return;

    final preferGlyph = glyphCount >= dotCount;
    final pattern = preferGlyph ? dots : glyph;
    final replacement = preferGlyph ? '…' : '...';

    for (final entry in context.scenes) {
      for (final match in pattern.allMatches(entry.scene.content)) {
        yield ProofFinding(
          ruleId: id,
          stage: stage,
          severity: ProofSeverity.notice,
          title: 'Inconsistent ellipsis',
          message: 'This book mostly uses '
              '"${preferGlyph ? '…' : '...'}".',
          sceneId: entry.scene.id,
          chapterId: entry.chapter.id,
          where: context.describe(entry.chapter, entry.scene),
          start: match.start,
          end: match.end,
          found: match.group(0)!,
          replacement: replacement,
        );
      }
    }
  }
}

// --- proofing ------------------------------------------------------------

/// Scene-break markers that disagree with each other.
///
/// Only a whole book can see this, which makes it a genuine speciality of this
/// stage: each chapter looks internally consistent while the book is not.
class SceneBreakConsistencyRule extends ProofRule {
  const SceneBreakConsistencyRule();

  @override
  String get id => 'inconsistentSceneBreak';
  @override
  String get label => 'Inconsistent scene breaks';
  @override
  String get description =>
      'More than one kind of scene-break marker typed into the manuscript.';
  @override
  ProofStage get stage => ProofStage.proofing;

  @override
  Iterable<ProofFinding> run(ProofContext context) sync* {
    final seen = <String, ({String sceneId, String chapterId, String where})>{};

    for (final entry in context.scenes) {
      for (final line in entry.scene.content.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        if (!BookDocumentBuilder.isSceneBreakMarker(trimmed)) continue;
        seen.putIfAbsent(
          trimmed,
          () => (
            sceneId: entry.scene.id,
            chapterId: entry.chapter.id,
            where: context.describe(entry.chapter, entry.scene),
          ),
        );
      }
    }

    if (seen.length < 2) return;
    final forms = seen.keys.toList()..sort();
    for (final form in forms) {
      final at = seen[form]!;
      yield ProofFinding(
        ruleId: id,
        stage: stage,
        severity: ProofSeverity.warning,
        title: 'Scene break written as "$form"',
        message: 'This book uses ${forms.length} different scene-break '
            'markers: ${forms.join(', ')}. The book draws its own breaks from '
            'the Design stage, so pick one here and the rest will follow.',
        sceneId: at.sceneId,
        chapterId: at.chapterId,
        where: at.where,
      );
    }
  }
}

/// Chapters and scenes with nothing in them.
class EmptyNodeRule extends ProofRule {
  const EmptyNodeRule();

  @override
  String get id => 'emptyNode';
  @override
  String get label => 'Empty chapters and scenes';
  @override
  String get description =>
      'A chapter or scene with no prose. It would print as a heading and '
      'nothing else.';
  @override
  ProofStage get stage => ProofStage.proofing;

  @override
  Iterable<ProofFinding> run(ProofContext context) sync* {
    final chapters = [...context.manuscript.chapters]
      ..sort((a, b) => a.order.compareTo(b.order));

    for (final chapter in chapters) {
      final hasProse =
          chapter.scenes.any((scene) => scene.content.trim().isNotEmpty);
      if (!hasProse) {
        yield ProofFinding(
          ruleId: id,
          stage: stage,
          severity: ProofSeverity.critical,
          title: 'Empty chapter',
          message: '"${chapter.title}" has no prose, so it would print as an '
              'opener followed by nothing.',
          chapterId: chapter.id,
          where: chapter.title,
        );
        continue;
      }
      for (final scene in chapter.scenes) {
        if (scene.content.trim().isNotEmpty) continue;
        yield ProofFinding(
          ruleId: id,
          stage: stage,
          severity: ProofSeverity.warning,
          title: 'Empty scene',
          message: 'This scene has no prose and will not appear in the book.',
          sceneId: scene.id,
          chapterId: chapter.id,
          where: context.describe(chapter, scene),
        );
      }
    }
  }
}

/// Chapters left on their default name while the rest carry real titles.
///
/// Absence is not the problem — a book of numbered chapters is a fine choice.
/// Inconsistency is, because it reads as an oversight in the contents.
class ChapterTitleConsistencyRule extends ProofRule {
  const ChapterTitleConsistencyRule();

  static final _default = RegExp(
    r'^(chapter|untitled)(\s+(chapter|\d+|[ivxlcdm]+))?$',
    caseSensitive: false,
  );

  @override
  String get id => 'chapterTitles';
  @override
  String get label => 'Chapter titles';
  @override
  String get description =>
      'Some chapters titled and others left on their default name.';
  @override
  ProofStage get stage => ProofStage.proofing;

  @override
  Iterable<ProofFinding> run(ProofContext context) sync* {
    final chapters = [...context.manuscript.chapters]
      ..sort((a, b) => a.order.compareTo(b.order));
    if (chapters.length < 2) return;

    bool isDefault(ManuscriptChapter chapter) {
      final title = chapter.title.trim();
      return title.isEmpty || _default.hasMatch(title);
    }

    final untitled = chapters.where(isDefault).toList();
    if (untitled.isEmpty || untitled.length == chapters.length) return;

    for (final chapter in untitled) {
      yield ProofFinding(
        ruleId: id,
        stage: stage,
        severity: ProofSeverity.notice,
        title: 'Chapter left untitled',
        message: '${chapters.length - untitled.length} of '
            '${chapters.length} chapters have titles; this one does not, so '
            'the contents will look uneven.',
        chapterId: chapter.id,
        where: chapter.title.trim().isEmpty ? 'Untitled chapter' : chapter.title,
      );
    }
  }
}

/// A paragraph whose quotation marks do not pair up.
///
/// Dialogue that runs over several paragraphs opens each one and closes only
/// the last, which is correct and would otherwise be reported every time — so a
/// paragraph is only flagged when the next one does not continue the speech.
class UnbalancedQuotesRule extends ProofRule {
  const UnbalancedQuotesRule();

  @override
  String get id => 'unbalancedQuotes';
  @override
  String get label => 'Unpaired quotation marks';
  @override
  String get description =>
      'A paragraph with an odd number of quotation marks, where the speech '
      'does not continue into the next paragraph.';
  @override
  ProofStage get stage => ProofStage.proofing;

  @override
  Iterable<ProofFinding> run(ProofContext context) sync* {
    for (final entry in context.scenes) {
      final content = entry.scene.content;
      final lines = content.split('\n');
      var offset = 0;

      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final start = offset;
        offset += line.length + 1;
        if (line.trim().isEmpty) continue;

        final marks = RegExp('["“”]').allMatches(line).length;
        if (marks.isEven) continue;

        // Speech carried into the next paragraph is the correct form.
        final next = lines.skip(i + 1).firstWhere(
              (candidate) => candidate.trim().isNotEmpty,
              orElse: () => '',
            );
        if (RegExp('^["“]').hasMatch(next.trim())) continue;

        yield ProofFinding(
          ruleId: id,
          stage: stage,
          severity: ProofSeverity.warning,
          title: 'Unpaired quotation mark',
          message: 'This paragraph has an odd number of quotation marks and '
              'the speech does not carry into the next one.',
          sceneId: entry.scene.id,
          chapterId: entry.chapter.id,
          where: context.describe(entry.chapter, entry.scene),
          start: start,
          end: start + line.length,
          found: line,
        );
      }
    }
  }
}

/// Brackets that do not close.
class UnbalancedBracketsRule extends ProofRule {
  const UnbalancedBracketsRule();

  @override
  String get id => 'unbalancedBrackets';
  @override
  String get label => 'Unclosed brackets';
  @override
  String get description => 'A paragraph with a bracket that never closes.';
  @override
  ProofStage get stage => ProofStage.proofing;

  @override
  Iterable<ProofFinding> run(ProofContext context) sync* {
    const pairs = {'(': ')', '[': ']'};
    for (final entry in context.scenes) {
      var offset = 0;
      for (final line in entry.scene.content.split('\n')) {
        final start = offset;
        offset += line.length + 1;
        if (line.trim().isEmpty) continue;

        for (final pair in pairs.entries) {
          final opens = pair.key.allMatches(line).length;
          final closes = pair.value.allMatches(line).length;
          if (opens == closes) continue;
          yield ProofFinding(
            ruleId: id,
            stage: stage,
            severity: ProofSeverity.notice,
            title: 'Unclosed ${pair.key}${pair.value}',
            message: 'This paragraph has $opens "${pair.key}" and $closes '
                '"${pair.value}".',
            sceneId: entry.scene.id,
            chapterId: entry.chapter.id,
            where: context.describe(entry.chapter, entry.scene),
            start: start,
            end: start + line.length,
            found: line,
          );
        }
      }
    }
  }
}

/// A copyright page switched on without the details it needs.
class FrontMatterCompleteRule extends ProofRule {
  const FrontMatterCompleteRule();

  @override
  String get id => 'frontMatterIncomplete';
  @override
  String get label => 'Incomplete front matter';
  @override
  String get description =>
      'A generated page switched on without the details that fill it.';
  @override
  ProofStage get stage => ProofStage.proofing;

  @override
  Iterable<ProofFinding> run(ProofContext context) sync* {
    final book = context.book;

    final copyright = book.frontMatter
        .where((section) =>
            section.kind == BookSectionKind.copyright && section.included)
        .isNotEmpty;
    if (copyright) {
      final missing = <String>[
        if (book.copyrightYear.trim().isEmpty) 'the year',
        if (book.copyrightHolder.trim().isEmpty &&
            book.authorOverride.trim().isEmpty)
          'the rights holder',
      ];
      if (missing.isNotEmpty) {
        yield ProofFinding(
          ruleId: id,
          stage: stage,
          severity: ProofSeverity.warning,
          title: 'Copyright page incomplete',
          message: 'The copyright page is switched on but ${missing.join(' and ')} '
              'is missing. Fill it in on the Structure stage.',
          where: 'Front matter',
        );
      }
    }

    for (final section in book.frontMatter.followedBy(book.backMatter)) {
      if (!section.included || section.isGenerated) continue;
      if (section.body.trim().isNotEmpty) continue;
      yield ProofFinding(
        ruleId: id,
        stage: stage,
        severity: ProofSeverity.warning,
        title: '${section.kind.label} is empty',
        message: 'It is switched on but has no text, so it is left out of the '
            'book rather than printed blank.',
        where: section.kind.isFrontMatter ? 'Front matter' : 'Back matter',
      );
    }
  }
}

/// Words the dictionary does not know.
///
/// Produces nothing at all when no dictionary has been loaded, rather than
/// pretending everything is spelled correctly.
class SpellingRule extends ProofRule {
  const SpellingRule();

  /// Strips a trailing possessive so `Kali's` is looked up as `Kali`.
  static String _withoutPossessive(String word) {
    final normalised = word.replaceAll('’', "'");
    if (normalised.endsWith("'s")) {
      return normalised.substring(0, normalised.length - 2);
    }
    if (normalised.endsWith("'")) {
      return normalised.substring(0, normalised.length - 1);
    }
    return normalised;
  }

  /// A cap per scene. A scene written in a language the dictionary does not
  /// have would otherwise produce thousands of findings and drown everything
  /// genuinely wrong.
  static const maxPerScene = 40;

  @override
  String get id => 'spelling';
  @override
  String get label => 'Spelling';
  @override
  String get description =>
      'Words no dictionary entry matches. Your own character and place names '
      'are taken from your records, so they are never flagged.';
  @override
  ProofStage get stage => ProofStage.proofing;

  @override
  Iterable<ProofFinding> run(ProofContext context) sync* {
    final dictionary = context.dictionary;
    if (dictionary == null) return;

    final known = <String>{
      for (final name in context.knownNames)
        for (final part in name.split(RegExp(r'[^A-Za-z’\x27-]+')))
          if (part.trim().length > 1) part.trim().toLowerCase(),
    };

    // Words, allowing internal apostrophes and hyphens.
    final wordPattern = RegExp(r"[A-Za-z][A-Za-z’'\-]*");

    for (final entry in context.scenes) {
      final content = entry.scene.content;
      var found = 0;
      final reported = <String>{};

      for (final match in wordPattern.allMatches(content)) {
        if (found >= maxPerScene) break;
        final word = match.group(0)!;
        if (word.length < 3) continue;
        // A possessive of a name is still that name, and the author should not
        // have to add both forms.
        final lower = _withoutPossessive(word.toLowerCase());
        if (lower.length < 3) continue;
        if (known.contains(lower)) continue;
        if (dictionary.contains(word)) continue;
        // One finding per distinct word per scene: an author does not need the
        // same misspelling pointed at forty times.
        if (!reported.add(lower)) continue;

        found += 1;
        yield ProofFinding(
          ruleId: id,
          stage: stage,
          severity: ProofSeverity.notice,
          title: 'Not in the dictionary',
          message: '"$word" was not recognised. If it is yours, add it to the '
              'book\'s own word list.',
          sceneId: entry.scene.id,
          chapterId: entry.chapter.id,
          where: context.describe(entry.chapter, entry.scene),
          start: match.start,
          end: match.end,
          found: word,
        );
      }
    }
  }
}

// --- layout ---------------------------------------------------------------

/// Justified lines stretched far enough to open a river of white space.
class RiverRule extends LayoutProofRule {
  const RiverRule();

  @override
  String get id => 'river';
  @override
  String get label => 'Rivers';
  @override
  String get description =>
      'Justified lines stretched so far that the gaps line up down the page.';

  @override
  Iterable<ProofFinding> run(PaginatedBook book) sync* {
    final count = book.stats.riverCount;
    if (count == 0) return;
    yield ProofFinding(
      ruleId: id,
      stage: ProofStage.layout,
      severity: ProofSeverity.notice,
      title: '$count stretched line${count == 1 ? '' : 's'}',
      message: 'Some justified lines are spaced wide enough to be visible. '
          'A slightly wider measure, a smaller type size, or ragged-right '
          'setting will close them.',
      where: 'Layout',
    );
  }
}

/// A paragraph line stranded on its own at a page boundary.
///
/// The engine avoids these while it lays the book out, so a finding here means
/// the break rules were loosened enough to let one through.
class WidowOrphanRule extends LayoutProofRule {
  const WidowOrphanRule();

  @override
  String get id => 'widowOrphan';
  @override
  String get label => 'Widows and orphans';
  @override
  String get description =>
      'A single line of a paragraph left alone at the top or bottom of a page.';

  @override
  Iterable<ProofFinding> run(PaginatedBook book) sync* {
    final lines = <String, Map<int, int>>{};
    for (final page in book.pages) {
      for (final element in page.elements) {
        if (element is! LayoutTextLine) continue;
        if (element.paragraphId.isEmpty) continue;
        final byPage = lines.putIfAbsent(element.paragraphId, () => {});
        byPage[page.index] = (byPage[page.index] ?? 0) + 1;
      }
    }

    for (final entry in lines.entries) {
      if (entry.value.length < 2) continue;
      final pages = entry.value.keys.toList()..sort();
      for (final page in pages) {
        if (entry.value[page]! > 1) continue;
        final isLast = page == pages.last;
        yield ProofFinding(
          ruleId: id,
          stage: ProofStage.layout,
          severity: ProofSeverity.warning,
          title: isLast ? 'Widow' : 'Orphan',
          message: 'A paragraph leaves one line alone on page ${page + 1}. '
              'Raise the break rules in the Design stage to close it.',
          where: 'Page ${page + 1}',
        );
      }
    }
  }
}

/// A chapter that spills a line or two onto a final, near-empty page.
class ShortChapterEndRule extends LayoutProofRule {
  const ShortChapterEndRule();

  @override
  String get id => 'shortChapterEnd';
  @override
  String get label => 'Short chapter endings';
  @override
  String get description =>
      'A chapter whose last page carries only a line or two.';

  @override
  Iterable<ProofFinding> run(PaginatedBook book) sync* {
    for (var i = 0; i < book.pages.length; i++) {
      final page = book.pages[i];
      if (page.role != BookPageRole.body) continue;
      final next = i + 1 < book.pages.length ? book.pages[i + 1] : null;
      final endsChapter = next == null ||
          next.role == BookPageRole.chapterOpener ||
          next.role == BookPageRole.partTitle ||
          next.isBlank;
      if (!endsChapter) continue;

      final lines =
          page.elements.whereType<LayoutTextLine>().length;
      if (lines == 0 || lines > 2) continue;
      yield ProofFinding(
        ruleId: id,
        stage: ProofStage.layout,
        severity: ProofSeverity.notice,
        title: 'Chapter ends on a near-empty page',
        message: 'Page ${page.index + 1} carries $lines line'
            '${lines == 1 ? '' : 's'} before the chapter ends.',
        where: 'Page ${page.index + 1}',
      );
    }
  }
}

/// How many pages the book spends on nothing.
class BlankPageRule extends LayoutProofRule {
  const BlankPageRule();

  @override
  String get id => 'blankPages';
  @override
  String get label => 'Blank pages';
  @override
  String get description =>
      'Pages left blank so chapters open on the right-hand side.';

  @override
  Iterable<ProofFinding> run(PaginatedBook book) sync* {
    final blanks = book.stats.blankPageCount;
    if (blanks == 0) return;
    yield ProofFinding(
      ruleId: id,
      stage: ProofStage.layout,
      severity: ProofSeverity.notice,
      title: '$blanks blank page${blanks == 1 ? '' : 's'}',
      message: 'These exist so chapters open on a right-hand page, which is '
          'how a printed book reads. Print-on-demand charges for them, so if '
          'that matters, let chapters start on any new page instead.',
      where: 'Layout',
    );
  }
}

/// Printers bind in gatherings, so the page count matters.
class SignatureRule extends LayoutProofRule {
  const SignatureRule();

  @override
  String get id => 'signature';
  @override
  String get label => 'Page count';
  @override
  String get description =>
      'Printers fold paper in fours, so a page count that is not a multiple of '
      'four leaves blank leaves at the back.';

  @override
  Iterable<ProofFinding> run(PaginatedBook book) sync* {
    if (book.format.reflowable) return;
    final remainder = book.pageCount % 4;
    if (remainder == 0) return;
    yield ProofFinding(
      ruleId: id,
      stage: ProofStage.layout,
      severity: ProofSeverity.notice,
      title: '${book.pageCount} pages is not a multiple of four',
      message: 'A printer folds paper in fours, so ${4 - remainder} blank '
          'leaf${4 - remainder == 1 ? '' : 'ves'} will be added at the back. '
          'Back matter is a good way to use them.',
      where: 'Layout',
    );
  }
}

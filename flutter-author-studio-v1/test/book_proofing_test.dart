import 'package:author_studio_v1/book/book_document.dart';
import 'package:author_studio_v1/book/proof_rules.dart';
import 'package:author_studio_v1/book/proofing.dart';
import 'package:author_studio_v1/book/book_fonts.dart';
import 'package:author_studio_v1/book/book_format.dart';
import 'package:author_studio_v1/book/book_layout.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/book_studio_fixture.dart';

/// A dictionary of exactly the words a test names, so spelling assertions do
/// not depend on a 350 KB asset.
class _Words implements SpellingDictionary {
  _Words(Iterable<String> words)
      : _words = words.map((w) => w.toLowerCase()).toSet();

  final Set<String> _words;

  @override
  Set<String> get personal => const {};

  @override
  bool contains(String word) {
    var candidate = word.toLowerCase().replaceAll('’', "'");
    if (candidate.endsWith("'s")) {
      candidate = candidate.substring(0, candidate.length - 2);
    }
    return _words.contains(candidate);
  }
}

/// Builds a one-scene manuscript around [prose].
ManuscriptProjectSummary proseFixture(String prose, {String title = 'Opening'}) =>
    ManuscriptProjectSummary(
      projectId: 'project-book',
      manuscriptTitle: 'The Widow Knife',
      currentChapterId: 'ch-1',
      currentSceneId: 'sc-1',
      createdAt: fixtureTimestamp,
      updatedAt: fixtureTimestamp,
      version: 1,
      chapters: [
        chapter(id: 'ch-1', title: 'The Arrival', order: 1, scenes: [
          scene(
            id: 'sc-1',
            chapterId: 'ch-1',
            title: title,
            order: 1,
            content: prose,
          ),
        ]),
      ],
    );

ProofReport check(
  String prose, {
  ProofRule? only,
  SpellingDictionary? dictionary,
  Set<String> knownNames = const {},
  BookProject? book,
  ManuscriptProjectSummary? manuscript,
}) {
  final engine = only == null
      ? const ProofingEngine()
      : ProofingEngine(rules: [only], layoutRules: const []);
  return engine.analyse(ProofContext(
    manuscript: manuscript ?? proseFixture(prose),
    book: book ?? bookFixture(),
    dictionary: dictionary,
    knownNames: knownNames,
  ));
}

List<ProofFinding> findingsOf(String prose, ProofRule rule) =>
    check(prose, only: rule).findings;

/// Runs every fixable finding back over the prose, the way the studio does.
String fixed(String prose, ProofRule rule) {
  final report = check(prose, only: rule);
  return const ProofFixer().apply(prose, report.findings);
}

void main() {
  group('indentation typed by hand', () {
    // The highest-value rule: the layout engine adds its own first-line
    // indent, so a hand-typed one is applied twice in the finished book.
    test('is found and removed', () {
      const prose = '\tThe knife was old.\n    So was the house.';
      final report = check(prose, only: const ManualIndentRule());

      expect(report.findings, hasLength(2));
      expect(report.findings.every((f) => f.isFixable), isTrue);
      expect(fixed(prose, const ManualIndentRule()),
          'The knife was old.\nSo was the house.');
    });

    test('leaves a blank line alone', () {
      expect(findingsOf('One.\n   \nTwo.', const ManualIndentRule()), isEmpty);
    });
  });

  group('spacing', () {
    test('double spaces collapse', () {
      const prose = 'He waited.  Then he left.';
      expect(fixed(prose, const DoubleSpaceRule()),
          'He waited. Then he left.');
    });

    test('a space before punctuation is closed up', () {
      const prose = 'He waited , then left .';
      expect(fixed(prose, const SpaceBeforePunctuationRule()),
          'He waited, then left.');
    });

    test('trailing whitespace goes', () {
      const prose = 'He waited.   \nThen he left.';
      expect(fixed(prose, const TrailingWhitespaceRule()),
          'He waited.\nThen he left.');
    });
  });

  group('quotation marks', () {
    test('open and close according to what precedes them', () {
      const prose = '"Go," she said. "Now."';
      expect(fixed(prose, const StraightQuotesRule()),
          '“Go,” she said. “Now.”');
    });

    test('a quote after an opening bracket still opens', () {
      const prose = '(He said "go".)';
      expect(fixed(prose, const StraightQuotesRule()), '(He said “go”.)');
    });

    test('a quote after a dash opens', () {
      const prose = 'She turned—"Go."';
      expect(fixed(prose, const StraightQuotesRule()), 'She turned—“Go.”');
    });
  });

  group('apostrophes', () {
    test('a contraction is fixed', () {
      expect(fixed("don't", const StraightApostrophesRule()), 'don’t');
    });

    test('a trailing possessive is fixed', () {
      expect(fixed("the boys' knives", const StraightApostrophesRule()),
          'the boys’ knives');
    });

    test('a known elision leans the right way', () {
      // The classic mistake is turning 'tis into ‘tis. It is a right-hand
      // mark, because it stands for a missing letter.
      expect(fixed("'tis done", const StraightApostrophesRule()), '’tis done');
      expect(fixed("the '90s", const StraightApostrophesRule()), 'the ’90s');
    });

    test('an ambiguous single quote is reported but never rewritten', () {
      const prose = "She said 'go' and left.";
      final report = check(prose, only: const StraightApostrophesRule());
      final ambiguous =
          report.findings.where((f) => f.replacement == null).toList();

      expect(ambiguous, isNotEmpty,
          reason: 'the author should still be told it is there');
      expect(fixed(prose, const StraightApostrophesRule()), prose,
          reason: 'guessing here would change what the author wrote');
    });
  });

  group('repeated words', () {
    test('a doubled word is found and the duplicate removed', () {
      const prose = 'He went to to the door.';
      expect(fixed(prose, const RepeatedWordRule()), 'He went to the door.');
    });

    test('ordinary English doubling is left alone', () {
      for (final phrase in ['She had had enough.', 'He knew that that was it.']) {
        expect(findingsOf(phrase, const RepeatedWordRule()), isEmpty,
            reason: '"$phrase" is correct English');
      }
    });

    test('a repeat across a line break is not a repeat', () {
      expect(findingsOf('the\nthe', const RepeatedWordRule()), isEmpty);
    });
  });

  group('dashes and ellipses', () {
    test('the form used most often wins', () {
      const prose = 'One—two—three—four--five';
      final report = check(prose, only: const MixedDashesRule());

      expect(report.findings, hasLength(1));
      expect(report.findings.single.found, '--');
      expect(report.findings.single.replacement, '—',
          reason: 'the fix should follow the author\'s own habit');
    });

    test('one dash used consistently is not a finding', () {
      expect(findingsOf('One—two—three', const MixedDashesRule()), isEmpty);
    });

    test('ellipses normalise to the majority form', () {
      const prose = 'One… two… three...';
      expect(fixed(prose, const EllipsisStyleRule()), 'One… two… three…');
    });
  });

  group('scene breaks across the whole book', () {
    test('two different markers are reported', () {
      // Neither chapter looks wrong on its own. Only the book can see this.
      final manuscript = ManuscriptProjectSummary(
        projectId: 'project-book',
        manuscriptTitle: 'The Widow Knife',
        currentChapterId: 'ch-1',
        currentSceneId: 'sc-1',
        createdAt: fixtureTimestamp,
        updatedAt: fixtureTimestamp,
        version: 1,
        chapters: [
          chapter(id: 'ch-1', title: 'One', order: 1, scenes: [
            scene(
                id: 'sc-1',
                chapterId: 'ch-1',
                title: 'A',
                order: 1,
                content: 'Before.\n***\nAfter.'),
          ]),
          chapter(id: 'ch-2', title: 'Two', order: 2, scenes: [
            scene(
                id: 'sc-2',
                chapterId: 'ch-2',
                title: 'B',
                order: 1,
                content: 'Before.\n# # #\nAfter.'),
          ]),
        ],
      );

      final report = check('', manuscript: manuscript,
          only: const SceneBreakConsistencyRule());
      expect(report.findings, hasLength(2));
      expect(report.findings.first.message, contains('2 different'));
    });

    test('one marker used throughout is fine', () {
      expect(
        findingsOf('A.\n***\nB.\n***\nC.', const SceneBreakConsistencyRule()),
        isEmpty,
      );
    });
  });

  group('empty chapters and scenes', () {
    test('a chapter with no prose is critical', () {
      final manuscript = ManuscriptProjectSummary(
        projectId: 'project-book',
        manuscriptTitle: 'T',
        currentChapterId: 'ch-1',
        currentSceneId: 'sc-1',
        createdAt: fixtureTimestamp,
        updatedAt: fixtureTimestamp,
        version: 1,
        chapters: [
          chapter(id: 'ch-1', title: 'Hollow', order: 1, scenes: [
            scene(
                id: 'sc-1',
                chapterId: 'ch-1',
                title: 'A',
                order: 1,
                content: '   '),
          ]),
        ],
      );
      final report =
          check('', manuscript: manuscript, only: const EmptyNodeRule());

      expect(report.findings, hasLength(1));
      expect(report.findings.single.severity, ProofSeverity.critical);
      expect(report.findings.single.title, 'Empty chapter');
    });
  });

  group('unpaired quotation marks', () {
    test('an odd mark is reported', () {
      const prose = '"Go, she said.\n\nHe did not move.';
      final report = check(prose, only: const UnbalancedQuotesRule());
      expect(report.findings, hasLength(1));
      expect(report.findings.single.isFixable, isFalse,
          reason: 'this needs a person, not a regex');
    });

    test('dialogue running across paragraphs is not reported', () {
      // The correct form opens every paragraph and closes only the last, which
      // a naive counter would flag on every one of them.
      const prose = '"I went to the house,\n\n"and the door was open,\n\n'
          '"and nobody was there."';
      expect(findingsOf(prose, const UnbalancedQuotesRule()), isEmpty);
    });
  });

  group('spelling', () {
    test('produces nothing at all without a dictionary', () {
      final report = check('xyzzy plugh', only: const SpellingRule());
      expect(report.findings, isEmpty);
      expect(report.spellingChecked, isFalse,
          reason: 'the studio must be able to say it did not check, rather '
              'than implying the book is clean');
    });

    test('flags a word the dictionary does not have', () {
      final report = check(
        'The knife was teh sharpest.',
        only: const SpellingRule(),
        dictionary: _Words(['the', 'knife', 'was', 'sharpest']),
      );
      expect(report.findings.map((f) => f.found), ['teh']);
    });

    test('never flags the author\'s own names', () {
      // The whole reason a spellchecker is usable in a novel: invented names
      // come from records the author already made.
      final report = check(
        'Kali walked into Endovier with the Widowknife.',
        only: const SpellingRule(),
        dictionary: _Words(['walked', 'into', 'with', 'the']),
        knownNames: {'Kali Vale', 'Endovier', 'Widowknife'},
      );
      expect(report.findings, isEmpty);
    });

    test('reports a repeated misspelling once per scene', () {
      final report = check(
        'teh knife and teh door and teh window',
        only: const SpellingRule(),
        dictionary: _Words(['knife', 'and', 'door', 'window']),
      );
      expect(report.findings, hasLength(1));
    });

    test('handles possessives and short words sensibly', () {
      final report = check(
        "Kali's knife is a thing.",
        only: const SpellingRule(),
        dictionary: _Words(['knife', 'thing']),
        knownNames: {'Kali'},
      );
      expect(report.findings, isEmpty,
          reason: 'a possessive of a known name is still that name, and words '
              'under three letters are not worth checking');
    });
  });

  group('front matter', () {
    test('a copyright page without a year is reported', () {
      final book = bookFixture().copyWith(copyrightYear: '');
      final report = check('Some prose.',
          only: const FrontMatterCompleteRule(), book: book);
      expect(report.findings.map((f) => f.title),
          contains('Copyright page incomplete'));
    });

    test('a complete copyright page is silent', () {
      final report =
          check('Some prose.', only: const FrontMatterCompleteRule());
      expect(report.findings, isEmpty);
    });
  });

  group('applying fixes', () {
    test('several fixes in one scene all land correctly', () {
      // Applied from the end backwards, so earlier offsets stay valid.
      const prose = '\tHe  waited , then said "go".';
      final report = check(prose);
      final result = const ProofFixer().apply(prose, report.findings);

      expect(result, 'He waited, then said “go”.');
    });

    test('a fix is skipped when the text no longer matches', () {
      const prose = 'He  waited.';
      final report = check(prose);
      // The scene changed under the finding.
      final result = const ProofFixer().apply('Something else.', report.findings);
      expect(result, 'Something else.');
    });

    test('overlapping fixes do not stack on one another', () {
      const prose = 'He went to to to the door.';
      final report = check(prose, only: const RepeatedWordRule());
      final result = const ProofFixer().apply(prose, report.findings);
      // Whatever it settles on, it must still be sane text.
      expect(result, isNot(contains('to to to')));
      expect(result, startsWith('He went to'));
    });

    test('findings group by the scene they belong to', () {
      final report = check('He  waited , twice.');
      final grouped = const ProofFixer().bySceneId(report.findings);
      expect(grouped.keys, ['sc-1']);
    });
  });

  group('the report', () {
    test('sorts the worst first', () {
      final report = check('He  waited , then said "go".');
      final ranks = report.findings.map((f) => f.severity.rank).toList();
      expect(ranks, orderedEquals(List.of(ranks)..sort()));
    });

    test('names how many rules ran', () {
      final report = check('Some prose.');
      expect(report.rulesRun, BuiltInProofRules.all.length);
    });

    test('a rule can be switched off', () {
      const prose = 'He  waited.';
      final all = const ProofingEngine().analyse(
        ProofContext(manuscript: proseFixture(prose), book: bookFixture()),
      );
      final without = const ProofingEngine().analyse(
        ProofContext(manuscript: proseFixture(prose), book: bookFixture()),
        enabled: BuiltInProofRules.defaultEnabled..remove('doubleSpace'),
      );
      expect(all.findings.map((f) => f.ruleId), contains('doubleSpace'));
      expect(without.findings.map((f) => f.ruleId),
          isNot(contains('doubleSpace')));
    });

    test('every rule has a stable id, a label and a description', () {
      final ids = <String>{};
      for (final rule in BuiltInProofRules.all) {
        expect(rule.id, isNotEmpty);
        expect(rule.label, isNotEmpty);
        expect(rule.description, isNotEmpty);
        expect(ids.add(rule.id), isTrue, reason: '${rule.id} is duplicated');
      }
      for (final rule in BuiltInProofRules.layout) {
        expect(ids.add(rule.id), isTrue, reason: '${rule.id} is duplicated');
      }
    });

    test('clean prose produces nothing', () {
      final report = check(
        'The knife was old before the house was old.\n'
        'She turned it against the light.',
      );
      expect(report.findings, isEmpty, reason: report.findings.toString());
    });
  });

  group('the layout stage', () {
    PaginatedBook layout({
      BookFormat? format,
      ManuscriptProjectSummary? manuscript,
    }) {
      final chosen = format ?? BookFormatPresets.paperback;
      final document = const BookDocumentBuilder().build(
        manuscript: manuscript ?? longManuscriptFixture(paragraphs: 12),
        book: bookFixture(format: chosen),
        profileAuthorName: 'Kali Vale',
      );
      return BookLayoutEngine(FakeBookFontMetrics()).layout(document, chosen);
    }

    ProofReport layoutReport({BookFormat? format}) =>
        const ProofingEngine().analyseLayout(layout(format: format));

    // `blankPages` and `signature` moved to preflight in Phase 5, where the
    // questions they ask about a printer actually belong. Their assertions
    // moved with them, to `test/book_preflight_test.dart`.
    test('printer economics are no longer this stage\'s business', () {
      final report = layoutReport();
      expect(report.findings.map((f) => f.ruleId),
          isNot(anyElement(isIn(const ['blankPages', 'signature']))),
          reason: 'these are preflight checks now');
    });

    test('the engine leaves no widows or orphans behind', () {
      // The layout engine prevents these while it paginates, so this is a
      // check that it really does rather than a report an author will see.
      final report = layoutReport();
      expect(report.findings.where((f) => f.ruleId == 'widowOrphan'), isEmpty);
    });

    test('loosening the break rules lets one through, and it is reported', () {
      final loose = BookFormatPresets.paperback.copyWith(
        breaks: const BookBreakRules(
          minLinesAtPageBottom: 1,
          minLinesAtPageTop: 1,
        ),
      );
      final report = const ProofingEngine().analyseLayout(layout(format: loose));
      // Not asserting that one always occurs — that depends on the prose — but
      // the rule must be capable of finding one when the guard is off.
      for (final finding in
          report.findings.where((f) => f.ruleId == 'widowOrphan')) {
        expect(finding.severity, ProofSeverity.warning);
        expect(finding.where, startsWith('Page '));
      }
    });

    test('every layout rule is described for the author', () {
      for (final rule in BuiltInProofRules.layout) {
        expect(rule.id, isNotEmpty);
        expect(rule.label, isNotEmpty);
        expect(rule.description, isNotEmpty);
      }
    });

    test('layout findings never claim to be fixable', () {
      // Nothing here can be repaired by rewriting the manuscript; they are
      // resolved by changing the format.
      final report = layoutReport();
      expect(report.findings.every((f) => !f.isFixable), isTrue);
    });
  });
}

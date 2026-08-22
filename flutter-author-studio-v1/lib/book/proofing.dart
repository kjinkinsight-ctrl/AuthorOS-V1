/// Book Studio Phase 3 — the Editing and Proofing stages.
///
/// Every rule here is a pure function over text and structure. That is not a
/// limitation being worked around: AuthorOS is deliberately AI-free, and making
/// the checks deterministic is what turns that from a promise into a property
/// of the design. There is nowhere in this file for a model call to hide, and a
/// finding can always be explained by pointing at the rule that produced it.
///
/// **This is a separate engine from `ContinuityAnalyzer`, on purpose.**
/// `lib/continuity.dart` owns a *story* vocabulary — unknown character, unknown
/// location, impossible travel — and `_recommendationFor` switches over it
/// exhaustively in a file that `world_continuity.dart` and
/// `codex_continuity.dart` both consume. Adding "straight quotes" there would
/// force a recommendation string into that switch for a warning neither of
/// those studios can ever produce. The resolutions differ too:
/// `ContinuityActionKind` describes graph repairs — create a record, add a link
/// — while a proof finding is resolved by editing text at a character offset.
/// The two are displayed together in the studio; they are not merged.
///
/// Findings carry offsets into the *manuscript's own* prose rather than into a
/// laid-out book, because a fix has to be applied to the source the author
/// wrote.
library;

import '../manuscript_store.dart';
import 'book_document.dart';
import 'book_layout.dart';
import 'proof_rules.dart';

/// Which stage of the pipeline a rule belongs to.
enum ProofStage {
  /// Mechanics of the text itself, checkable one scene at a time.
  editing,

  /// Consistency across the whole book — the checks only a book can make.
  proofing,

  /// Only answerable once the book has been laid out.
  layout,
}

extension ProofStageX on ProofStage {
  String get label => switch (this) {
        ProofStage.editing => 'Editing',
        ProofStage.proofing => 'Proofing',
        ProofStage.layout => 'Layout',
      };

  String get summary => switch (this) {
        ProofStage.editing =>
          'The mechanics of the text. Everything here has one right answer, so '
              'it can be fixed for you.',
        ProofStage.proofing =>
          'What only the whole book can see: spelling, consistency between '
              'chapters, and the checks that need a finished layout.',
        ProofStage.layout =>
          'Answerable only once the book has been laid out.',
      };
}

/// How much a finding matters.
enum ProofSeverity {
  /// Worth knowing, not worth blocking on.
  notice,

  /// Will read as a mistake.
  warning,

  /// Will produce a visibly broken book.
  critical,
}

extension ProofSeverityX on ProofSeverity {
  String get label => switch (this) {
        ProofSeverity.notice => 'Notice',
        ProofSeverity.warning => 'Warning',
        ProofSeverity.critical => 'Needs attention',
      };

  int get rank => switch (this) {
        ProofSeverity.critical => 0,
        ProofSeverity.warning => 1,
        ProofSeverity.notice => 2,
      };
}

/// One thing a rule noticed.
class ProofFinding {
  const ProofFinding({
    required this.ruleId,
    required this.stage,
    required this.severity,
    required this.title,
    required this.message,
    this.sceneId = '',
    this.chapterId = '',
    this.where = '',
    this.start = -1,
    this.end = -1,
    this.found = '',
    this.replacement,
  });

  final String ruleId;
  final ProofStage stage;
  final ProofSeverity severity;

  /// A short name for the problem.
  final String title;

  /// What to do about it, in the author's terms.
  final String message;

  /// The scene whose prose this points at, when it points at prose.
  final String sceneId;
  final String chapterId;

  /// Where the author will find it, for display.
  final String where;

  /// Character offsets into that scene's content. Both are -1 for a finding
  /// that is not about a span of text.
  final int start;
  final int end;

  final String found;

  /// The text that should replace [found].
  ///
  /// Null means the rule found something worth a look but will not presume to
  /// rewrite it — an unbalanced quotation mark needs a person, not a regex.
  final String? replacement;

  /// True when the studio can apply this without asking anything further.
  bool get isFixable =>
      replacement != null && start >= 0 && end > start && sceneId.isNotEmpty;

  @override
  String toString() => '[$ruleId] $title ($where)';
}

/// Everything a rule is allowed to look at.
class ProofContext {
  const ProofContext({
    required this.manuscript,
    required this.book,
    this.dictionary,
    this.knownNames = const {},
  });

  /// The manuscript as written, with its offsets intact.
  final ManuscriptProjectSummary manuscript;

  /// The book's settings, for checks about front matter.
  final BookProject book;

  /// Looks a word up. Null when the dictionary has not been loaded, in which
  /// case spelling rules produce nothing rather than guessing.
  final SpellingDictionary? dictionary;

  /// Every record title and alias in the project.
  ///
  /// A novel is full of invented words, and flagging an author's own character
  /// and place names is what makes a spellchecker useless to them. These come
  /// from the records they already created, so nothing has to be trained.
  final Set<String> knownNames;

  /// Every scene in reading order, paired with its chapter.
  Iterable<({ManuscriptChapter chapter, ManuscriptScene scene})> get scenes
      sync* {
    final chapters = [...manuscript.chapters]
      ..sort((a, b) => a.order.compareTo(b.order));
    for (final chapter in chapters) {
      final ordered = [...chapter.scenes]
        ..sort((a, b) => a.order.compareTo(b.order));
      for (final scene in ordered) {
        yield (chapter: chapter, scene: scene);
      }
    }
  }

  /// How a finding names its location.
  String describe(ManuscriptChapter chapter, ManuscriptScene scene) {
    final chapterName =
        chapter.title.trim().isEmpty ? 'Untitled chapter' : chapter.title.trim();
    final sceneName =
        scene.title.trim().isEmpty ? 'Untitled scene' : scene.title.trim();
    return '$chapterName · $sceneName';
  }
}

/// What a dictionary has to be able to answer.
///
/// An interface rather than a class so a test can supply a handful of words
/// without loading a 350 KB asset.
abstract class SpellingDictionary {
  /// True when [word] is spelled correctly. Case and possessives are the
  /// implementation's problem, not the caller's.
  bool contains(String word);

  /// Words the author added themselves.
  Set<String> get personal;
}

/// One check.
abstract class ProofRule {
  const ProofRule();

  /// Stable across releases: it is stored when an author switches a rule off.
  String get id;

  String get label;
  String get description;
  ProofStage get stage;

  /// Whether a new project has this rule switched on.
  bool get defaultEnabled => true;

  Iterable<ProofFinding> run(ProofContext context);
}

/// A rule that reads the laid-out book rather than the manuscript.
abstract class LayoutProofRule {
  const LayoutProofRule();

  String get id;
  String get label;
  String get description;
  bool get defaultEnabled => true;

  Iterable<ProofFinding> run(PaginatedBook book);
}

/// What a pass over the book found.
class ProofReport {
  const ProofReport({
    required this.findings,
    this.elapsed = Duration.zero,
    this.rulesRun = 0,
    this.spellingChecked = false,
  });

  static const empty = ProofReport(findings: []);

  final List<ProofFinding> findings;
  final Duration elapsed;
  final int rulesRun;

  /// False when the dictionary was not available, so the absence of spelling
  /// findings means nothing.
  final bool spellingChecked;

  bool get isClean => findings.isEmpty;

  List<ProofFinding> forStage(ProofStage stage) =>
      findings.where((finding) => finding.stage == stage).toList();

  List<ProofFinding> get fixable =>
      findings.where((finding) => finding.isFixable).toList();

  int countOf(ProofSeverity severity) =>
      findings.where((finding) => finding.severity == severity).length;

  /// Findings grouped by the rule that produced them, worst first.
  Map<String, List<ProofFinding>> get byRule {
    final grouped = <String, List<ProofFinding>>{};
    for (final finding in findings) {
      (grouped[finding.ruleId] ??= []).add(finding);
    }
    return grouped;
  }
}

/// Runs the rules.
class ProofingEngine {
  const ProofingEngine({
    this.rules = BuiltInProofRules.all,
    this.layoutRules = BuiltInProofRules.layout,
  });

  final List<ProofRule> rules;
  final List<LayoutProofRule> layoutRules;

  /// Runs every enabled text rule over the manuscript.
  ///
  /// [enabled] names the rules to run; when null every rule with
  /// [ProofRule.defaultEnabled] runs.
  ProofReport analyse(ProofContext context, {Set<String>? enabled}) {
    final stopwatch = Stopwatch()..start();
    final findings = <ProofFinding>[];
    var ran = 0;

    for (final rule in rules) {
      final on = enabled?.contains(rule.id) ?? rule.defaultEnabled;
      if (!on) continue;
      ran += 1;
      findings.addAll(rule.run(context));
    }

    _sort(findings);
    return ProofReport(
      findings: List.unmodifiable(findings),
      elapsed: stopwatch.elapsed,
      rulesRun: ran,
      spellingChecked: context.dictionary != null,
    );
  }

  /// Runs the checks that only a laid-out book can answer.
  ProofReport analyseLayout(PaginatedBook book, {Set<String>? enabled}) {
    final stopwatch = Stopwatch()..start();
    final findings = <ProofFinding>[];
    var ran = 0;

    for (final rule in layoutRules) {
      final on = enabled?.contains(rule.id) ?? rule.defaultEnabled;
      if (!on) continue;
      ran += 1;
      findings.addAll(rule.run(book));
    }

    _sort(findings);
    return ProofReport(
      findings: List.unmodifiable(findings),
      elapsed: stopwatch.elapsed,
      rulesRun: ran,
    );
  }

  static void _sort(List<ProofFinding> findings) {
    findings.sort((a, b) {
      final bySeverity = a.severity.rank.compareTo(b.severity.rank);
      if (bySeverity != 0) return bySeverity;
      final byRule = a.ruleId.compareTo(b.ruleId);
      if (byRule != 0) return byRule;
      return a.start.compareTo(b.start);
    });
  }
}

/// Applies fixes to a scene's prose.
class ProofFixer {
  const ProofFixer();

  /// Returns [content] with every fixable finding in [findings] applied.
  ///
  /// Applied in **descending offset order** so that earlier offsets stay valid
  /// as later ones are rewritten. Overlapping findings are dropped rather than
  /// applied on top of one another, because the second would be operating on
  /// text the first has already changed.
  String apply(String content, Iterable<ProofFinding> findings) {
    final applicable = findings
        .where((finding) => finding.isFixable)
        .where((finding) => finding.end <= content.length)
        .where((finding) =>
            content.substring(finding.start, finding.end) == finding.found)
        .toList()
      ..sort((a, b) => b.start.compareTo(a.start));

    var result = content;
    var lastStart = content.length + 1;
    for (final finding in applicable) {
      if (finding.end > lastStart) continue; // overlaps one already applied
      result = result.replaceRange(
        finding.start,
        finding.end,
        finding.replacement!,
      );
      lastStart = finding.start;
    }
    return result;
  }

  /// Groups fixable findings by the scene they belong to.
  Map<String, List<ProofFinding>> bySceneId(Iterable<ProofFinding> findings) {
    final grouped = <String, List<ProofFinding>>{};
    for (final finding in findings.where((f) => f.isFixable)) {
      (grouped[finding.sceneId] ??= []).add(finding);
    }
    return grouped;
  }
}

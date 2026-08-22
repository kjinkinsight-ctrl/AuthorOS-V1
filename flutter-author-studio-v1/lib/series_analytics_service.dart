/// Series Analytics — the derivation layer.
///
/// Answers one question: how far through each book of a series is the author,
/// and how far through the series as a whole. Like [AnalyticsService] it owns
/// no storage and invents no number — the books come from the project roster,
/// and each book's words come from the manuscript that book already has.
///
/// Two rules govern this file:
///
/// * **It never writes.** Books are read through [ManuscriptStore.peekStudio],
///   never `loadStudio`, because `loadStudio` seeds and persists a starter
///   manuscript when it finds none. Surveying a five-book series through it
///   would create four manuscripts the author never asked for. A dashboard
///   must be able to look without touching.
/// * **It owns no second definition of a number.** A book's word count is the
///   Manuscript Studio's `wordCount`; a book's target is the project's own
///   `wordGoal`, the same figure `AnalyticsSummary.targetWordCount` reads.
///
/// This is a separate model from [AnalyticsSummary], not a duplicate of it:
/// that summary describes one project in depth, this describes several books
/// shallowly, and neither can be derived from the other.
library;

import 'core/project_roster_entry.dart';
import 'core/writing_series.dart';
import 'manuscript_store.dart';
import 'persistence/authoros_database.dart';
import 'project_roster_store.dart';

/// One book's progress toward its own target.
class SeriesBookProgress {
  const SeriesBookProgress({
    required this.projectId,
    required this.title,
    required this.position,
    required this.wordCount,
    required this.targetWords,
    required this.hasManuscript,
  });

  final String projectId;
  final String title;

  /// Zero-based position in the series; [bookNumber] is what a reader sees.
  final int position;

  /// Words written so far. `0` for a book never opened — a true statement
  /// about an unwritten book, not a failure and not a guess.
  final int wordCount;

  /// The book's target, from the project's own goal. `0` means none is set.
  final int targetWords;

  /// Whether a manuscript exists for this book at all. Distinct from
  /// `wordCount == 0`: a manuscript opened but not yet written in has one.
  final bool hasManuscript;

  /// Human-facing book number: position 0 is "Book 1".
  int get bookNumber => position + 1;

  bool get hasTarget => targetWords > 0;

  /// Whether the author has written anything in this book yet.
  bool get isStarted => wordCount > 0;

  /// Progress in `0.0..1.0`, or `null` without a target. Consumers must not
  /// render a percentage when this is null — the same rule
  /// `AnalyticsSummary.progressTowardTarget` follows.
  double? get progress =>
      hasTarget ? (wordCount / targetWords).clamp(0.0, 1.0) : null;

  /// Progress in `0..100`, or `null` without a target.
  double? get percent {
    final value = progress;
    return value == null ? null : value * 100;
  }

  /// Words left before this book reaches its target, or `null` without one.
  /// Never negative: overshooting leaves zero remaining.
  int? get wordsRemaining =>
      hasTarget ? (targetWords - wordCount).clamp(0, targetWords) : null;

  /// Whether the book has reached its target. False without a target: a book
  /// with nothing to reach cannot have reached it.
  bool get isComplete => hasTarget && wordCount >= targetWords;
}

/// A whole series, book by book.
class SeriesAnalytics {
  const SeriesAnalytics({required this.series, required this.books});

  final WritingSeries series;

  /// The books in the author's own order, gaps included: a book that has never
  /// been opened still appears, at 0 words. A series shows what it contains.
  final List<SeriesBookProgress> books;

  int get bookCount => books.length;

  bool get hasBooks => books.isNotEmpty;

  /// Words written across every book.
  int get totalWords =>
      books.fold<int>(0, (sum, book) => sum + book.wordCount);

  /// Targets summed across the books that have one. Books without a target
  /// contribute nothing rather than a zero that would drag the series
  /// percentage down.
  int get totalTargetWords => books
      .where((book) => book.hasTarget)
      .fold<int>(0, (sum, book) => sum + book.targetWords);

  /// Whether any book has a target at all.
  bool get hasTargets => totalTargetWords > 0;

  /// Books carrying a target, and books carrying none.
  int get targetedBookCount => books.where((book) => book.hasTarget).length;

  int get untargetedBookCount => bookCount - targetedBookCount;

  /// Whether the series bar is measuring only part of the series.
  ///
  /// True when some books have a target and some do not, which means the
  /// percentage below answers "how far through the books that have a goal" —
  /// a narrower question than it looks. Consumers must say so rather than let
  /// the bar imply it covers everything.
  bool get hasPartialTargets => targetedBookCount > 0 && untargetedBookCount > 0;

  int get completedBookCount => books.where((book) => book.isComplete).length;

  int get startedBookCount => books.where((book) => book.isStarted).length;

  /// Words written across the books that carry a target.
  ///
  /// Paired with [totalTargetWords] so the series percentage compares like
  /// with like: counting words from an untargeted book against a total that
  /// excludes its target would report progress above 100%.
  int get targetedWords => books
      .where((book) => book.hasTarget)
      .fold<int>(0, (sum, book) => sum + book.wordCount);

  /// The series' overall progress in `0.0..1.0`, or `null` when no book has a
  /// target.
  double? get seriesProgress => hasTargets
      ? (targetedWords / totalTargetWords).clamp(0.0, 1.0)
      : null;

  /// The series' overall progress in `0..100`, or `null` without targets.
  double? get seriesPercent {
    final value = seriesProgress;
    return value == null ? null : value * 100;
  }

  /// Words left across the whole series, or `null` without targets.
  int? get wordsRemaining => hasTargets
      ? (totalTargetWords - targetedWords).clamp(0, totalTargetWords)
      : null;
}

/// Derives [SeriesAnalytics] from the project roster and stored manuscripts.
///
/// Mirrors [AnalyticsService]'s shape: the repository defaults to the app-wide
/// [authorOsRepository], and the manuscript is read through the Manuscript
/// Studio's own store so every screen reports the same word count.
class SeriesAnalyticsService {
  const SeriesAnalyticsService({
    DriftConnectedDomainRepository? repository,
    this.manuscriptStore = const ManuscriptStore(),
    ProjectRosterStore? rosterStore,
  })  : _repository = repository,
        _rosterStore = rosterStore;

  final DriftConnectedDomainRepository? _repository;
  final ProjectRosterStore? _rosterStore;

  /// Reused rather than re-implemented: word counts are the Manuscript
  /// Studio's to define.
  final ManuscriptStore manuscriptStore;

  DriftConnectedDomainRepository get repository =>
      _repository ?? authorOsRepository;

  ProjectRosterStore get rosterStore =>
      _rosterStore ?? ProjectRosterStore(repository: repository);

  /// The series [projectId] belongs to, or `null` when it stands alone.
  ///
  /// `null` is the ordinary answer for a standalone novel, not an error, and
  /// consumers must render it as "not part of a series".
  Future<SeriesAnalytics?> forProject(String projectId) async {
    final series = await rosterStore.seriesForProject(projectId);
    if (series == null) return null;
    return forSeries(series);
  }

  /// Every book of [series], in the author's order.
  Future<SeriesAnalytics> forSeries(WritingSeries series) async {
    final books = await rosterStore.books(series.id);
    final progress = <SeriesBookProgress>[];
    for (var index = 0; index < books.length; index++) {
      progress.add(await _bookProgress(books[index], index));
    }
    return SeriesAnalytics(
      series: series,
      books: List.unmodifiable(progress),
    );
  }

  /// One book's progress.
  ///
  /// [position] comes from the book's place in the ordered list rather than
  /// its stored `seriesPosition`, so the numbering a reader sees is always
  /// 1, 2, 3 even if stored positions ever developed a gap.
  Future<SeriesBookProgress> _bookProgress(
    ProjectRosterEntry entry,
    int position,
  ) async {
    // peekStudio, never loadStudio: reading a series must not create the
    // manuscripts it is only trying to measure.
    final manuscript = await manuscriptStore.peekStudio(entry.projectId);
    return SeriesBookProgress(
      projectId: entry.projectId,
      title: entry.title,
      position: position,
      wordCount: manuscript?.wordCount ?? 0,
      targetWords: entry.targetWords,
      hasManuscript: manuscript != null,
    );
  }
}

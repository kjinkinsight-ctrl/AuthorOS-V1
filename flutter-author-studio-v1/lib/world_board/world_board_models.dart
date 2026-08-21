/// World Board Phase 1 — the aggregation vocabulary.
///
/// Plain Dart. These models describe what the board *shows*; they own no
/// storage and define no records. Every value in a [WorldBoardSnapshot] is
/// derived from records the existing Studios already persist, so the board
/// stays a presentation layer over AuthorOS rather than a second source of
/// truth.
library;

/// The categories the board surfaces, in reading order.
///
/// These are view sections, not record types. Each one maps onto data an
/// existing service already owns; none of them implies a new domain.
enum WorldBoardSection {
  projects,
  manuscript,
  characters,
  worlds,
  timelines,
  plot,
}

/// Where a section can send the author.
///
/// The board never names the shell's section enum directly — routing belongs
/// to the shell. It maps these destinations onto its own navigation, the same
/// way the Character and Story Codex workspaces already do.
enum WorldBoardDestination {
  projects,
  manuscript,
  characters,
  world,
  timeline,
  plot,
}

extension WorldBoardSectionData on WorldBoardSection {
  String get label => switch (this) {
        WorldBoardSection.projects => 'Projects',
        WorldBoardSection.manuscript => 'Manuscript',
        WorldBoardSection.characters => 'Characters',
        WorldBoardSection.worlds => 'Worlds',
        WorldBoardSection.timelines => 'Timelines',
        WorldBoardSection.plot => 'Plot',
      };

  WorldBoardDestination get destination => switch (this) {
        WorldBoardSection.projects => WorldBoardDestination.projects,
        WorldBoardSection.manuscript => WorldBoardDestination.manuscript,
        WorldBoardSection.characters => WorldBoardDestination.characters,
        WorldBoardSection.worlds => WorldBoardDestination.world,
        WorldBoardSection.timelines => WorldBoardDestination.timeline,
        WorldBoardSection.plot => WorldBoardDestination.plot,
      };

  /// Headline shown when the section holds nothing yet.
  String get emptyTitle => switch (this) {
        WorldBoardSection.projects => 'No project yet',
        WorldBoardSection.manuscript => 'No manuscript yet',
        WorldBoardSection.characters => 'No characters yet',
        WorldBoardSection.worlds => 'No world yet',
        WorldBoardSection.timelines => 'No timeline yet',
        WorldBoardSection.plot => 'No plot records yet',
      };

  /// The one line that tells the author where to go next.
  String get emptyBody => switch (this) {
        WorldBoardSection.projects =>
          'Create a project to open your AuthorOS world.',
        WorldBoardSection.manuscript => 'Start drafting in Manuscript Studio.',
        WorldBoardSection.characters => 'Build your cast in Characters Studio.',
        WorldBoardSection.worlds =>
          'Your world-building workspace will live here.',
        WorldBoardSection.timelines =>
          'Start organising your story chronology.',
        WorldBoardSection.plot => 'Build your story structure in Plot Studio.',
      };

  /// Label for the action that leaves the board for the owning Studio.
  String get openLabel => switch (this) {
        WorldBoardSection.projects => 'Open Projects',
        WorldBoardSection.manuscript => 'Open Manuscript',
        WorldBoardSection.characters => 'Open Characters Studio',
        WorldBoardSection.worlds => 'Open World Studio',
        WorldBoardSection.timelines => 'Open Timeline Studio',
        WorldBoardSection.plot => 'Open Plot Studio',
      };
}

/// One tile in the ecosystem grid.
///
/// [count] measures how much the section holds, and zero always means the
/// section is genuinely empty. For the record-backed sections that is a record
/// tally; for the manuscript it is the words and chapters that make a draft
/// exist at all. [value] is what the tile actually shows — for the manuscript,
/// a word count, because words are what the author is tracking.
class WorldBoardMetric {
  const WorldBoardMetric({
    required this.section,
    required this.count,
    required this.value,
    this.caption = '',
  });

  final WorldBoardSection section;

  /// How much this section holds. Zero means the empty state is the truth.
  final int count;

  /// The headline as rendered, already formatted.
  final String value;

  /// Supporting detail, or empty when the section has nothing to add.
  final String caption;

  bool get isEmpty => count == 0;

  @override
  String toString() =>
      'WorldBoardMetric(${section.name}, count: $count, value: $value)';
}

/// A project's branch of the ecosystem tree: PROJECT to section to records.
///
/// Phase 1 stops at one level of leaves. That is enough to make the
/// relationships legible without building an interactive graph, which belongs
/// to World Board Phase 2.
class WorldBoardBranch {
  const WorldBoardBranch({
    required this.section,
    required this.count,
    this.leaves = const [],
  });

  final WorldBoardSection section;

  /// Total records on this branch, which may exceed [leaves].
  final int count;

  /// A sample of real record titles, most recent first. Never invented.
  final List<String> leaves;

  bool get isEmpty => count == 0;

  /// Records the branch holds beyond the sampled [leaves].
  int get hiddenCount {
    final hidden = count - leaves.length;
    return hidden < 0 ? 0 : hidden;
  }
}

/// One entry in the recent-activity feed, taken from the shared audit history.
class WorldBoardActivity {
  const WorldBoardActivity({
    required this.id,
    required this.summary,
    required this.changeLabel,
    required this.occurredAt,
  });

  final String id;

  /// The audit summary as the owning service wrote it.
  final String summary;

  /// Human-readable change type, e.g. `Updated`.
  final String changeLabel;

  final DateTime occurredAt;
}

/// The active project's context: identity, progress, and what hangs off it.
class WorldBoardProjectContext {
  const WorldBoardProjectContext({
    required this.projectId,
    required this.title,
    required this.genre,
    required this.projectType,
    required this.wordCount,
    required this.wordGoal,
    required this.chapterCount,
    required this.sceneCount,
  });

  final String projectId;
  final String title;
  final String genre;
  final String projectType;
  final int wordCount;
  final int wordGoal;
  final int chapterCount;
  final int sceneCount;

  /// Draft completion against the project's own word goal, `0.0..1.0`.
  ///
  /// A project without a goal reports no progress rather than a false 100%.
  double get progress {
    if (wordGoal <= 0) return 0;
    final ratio = wordCount / wordGoal;
    return ratio < 0 ? 0 : (ratio > 1 ? 1 : ratio);
  }

  int get progressPercent => (progress * 100).round();

  int get wordsRemaining {
    final remaining = wordGoal - wordCount;
    return remaining < 0 ? 0 : remaining;
  }

  bool get hasManuscript => wordCount > 0 || chapterCount > 0;
}

/// Everything the board renders in one pass.
class WorldBoardSnapshot {
  const WorldBoardSnapshot({
    required this.project,
    required this.metrics,
    required this.branches,
    required this.activity,
  });

  final WorldBoardProjectContext project;

  /// One metric per [WorldBoardSection], in enum order.
  final Map<WorldBoardSection, WorldBoardMetric> metrics;

  /// The project's branches, excluding the project section itself.
  final List<WorldBoardBranch> branches;

  /// Most recent first, already trimmed to what the panel shows.
  final List<WorldBoardActivity> activity;

  WorldBoardMetric metric(WorldBoardSection section) {
    final found = metrics[section];
    if (found == null) {
      throw StateError('World Board metric ${section.name} was not resolved.');
    }
    return found;
  }

  /// True when the project has nothing but itself — every branch is empty.
  bool get isNewWorld =>
      branches.every((branch) => branch.isEmpty) && !project.hasManuscript;
}

/// `18420` becomes `18,420`, so six-figure word counts stay readable.
String formatWorldBoardCount(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var index = 0; index < digits.length; index += 1) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return buffer.toString();
}

/// "Just now", "3h ago", "2d ago" — the timestamp on an activity row.
String formatWorldBoardMoment(DateTime moment, {DateTime? now}) {
  final reference = (now ?? DateTime.now()).toUtc();
  final elapsed = reference.difference(moment.toUtc());
  if (elapsed.isNegative || elapsed.inMinutes < 1) return 'Just now';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes}m ago';
  if (elapsed.inDays < 1) return '${elapsed.inHours}h ago';
  if (elapsed.inDays < 7) return '${elapsed.inDays}d ago';
  return '${(elapsed.inDays / 7).floor()}w ago';
}

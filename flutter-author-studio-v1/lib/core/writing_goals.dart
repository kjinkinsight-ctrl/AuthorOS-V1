/// Writing goals — the domain layer.
///
/// A [WritingGoals] is the author's own pace for one project: how many words
/// they mean to write in a day, a week, and a month. It is deliberately the
/// opposite kind of value from a [WritingSession]:
///
/// * A session is a *fact*. It records what happened and is never rewritten.
/// * A goal is an *intention*. It is current, editable, and overwritten every
///   time the author changes their mind.
///
/// That difference is why goals live in their own file rather than beside the
/// session model, and why the storage layer upserts them instead of appending.
///
/// Two rules govern this file:
///
/// * It is presentation-independent. Nothing here imports Flutter, and nothing
///   here formats a value for a screen.
/// * It owns no progress arithmetic. How far through a goal the author is
///   depends on words written, which is the analytics layer's question to
///   answer; this file only carries the targets.
library;

/// The author's daily, weekly, and monthly word targets for one project.
///
/// A target of `0` means "no goal for this period" — a distinct state from a
/// small goal, and one consumers must render as absent rather than as 0%.
/// This mirrors the rule `AnalyticsSummary.hasWritingTarget` already follows
/// for the manuscript target.
class WritingGoals {
  const WritingGoals({
    required this.projectId,
    required this.dailyWords,
    required this.weeklyWords,
    required this.monthlyWords,
    this.updatedAt,
  });

  /// The targets a project starts with, and the only place they are written
  /// down. Everything that needs a default — the storage layer, the restore
  /// button, the tests — reads them from here, so there is exactly one answer
  /// to "what is a default goal?".
  static const seedDefaults = WritingGoals(
    projectId: '',
    dailyWords: 2000,
    weeklyWords: 10000,
    monthlyWords: 40000,
  );

  /// An upper bound that keeps a slip — a pasted word count, a stray zero —
  /// from becoming a goal no author could write against.
  static const maximumWords = 1000000;

  /// The seeded targets, bound to one project.
  factory WritingGoals.defaultsFor(String projectId) =>
      seedDefaults.copyWith(projectId: projectId);

  final String projectId;

  /// Words the author means to write in a local calendar day. `0` means no
  /// daily goal.
  final int dailyWords;

  /// Words per local week (Monday-based, matching `WritingCalendar`).
  final int weeklyWords;

  /// Words per local calendar month.
  final int monthlyWords;

  /// When the author last changed these targets, or `null` when they have
  /// never been edited and these are still the seeded defaults.
  final DateTime? updatedAt;

  bool get hasDailyGoal => dailyWords > 0;
  bool get hasWeeklyGoal => weeklyWords > 0;
  bool get hasMonthlyGoal => monthlyWords > 0;

  /// Whether the author has moved off the seeded targets.
  bool get isCustomized =>
      dailyWords != seedDefaults.dailyWords ||
      weeklyWords != seedDefaults.weeklyWords ||
      monthlyWords != seedDefaults.monthlyWords;

  /// The same goals with every target inside the range storage accepts:
  /// negatives floored at zero, everything capped at [maximumWords].
  ///
  /// Applied on the way in to storage, so a value the author can never reach
  /// — or a negative one, which would invert every progress bar — is never
  /// written in the first place.
  WritingGoals normalized() => WritingGoals(
        projectId: projectId,
        dailyWords: _clamp(dailyWords),
        weeklyWords: _clamp(weeklyWords),
        monthlyWords: _clamp(monthlyWords),
        updatedAt: updatedAt,
      );

  static int _clamp(int words) {
    if (words < 0) return 0;
    if (words > maximumWords) return maximumWords;
    return words;
  }

  WritingGoals copyWith({
    String? projectId,
    int? dailyWords,
    int? weeklyWords,
    int? monthlyWords,
    DateTime? updatedAt,
  }) =>
      WritingGoals(
        projectId: projectId ?? this.projectId,
        dailyWords: dailyWords ?? this.dailyWords,
        weeklyWords: weeklyWords ?? this.weeklyWords,
        monthlyWords: monthlyWords ?? this.monthlyWords,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// Timestamps serialize as UTC ISO-8601, matching every other AuthorOS
  /// record, and are converted back to local time on the way in.
  Map<String, Object?> toJson() => {
        'projectId': projectId,
        'dailyWords': dailyWords,
        'weeklyWords': weeklyWords,
        'monthlyWords': monthlyWords,
        'updatedAt': updatedAt?.toUtc().toIso8601String(),
      };

  factory WritingGoals.fromJson(Map<String, dynamic> json) {
    final updatedAt = json['updatedAt'] as String?;
    return WritingGoals(
      projectId: (json['projectId'] as String?) ?? '',
      dailyWords: (json['dailyWords'] as int?) ?? seedDefaults.dailyWords,
      weeklyWords: (json['weeklyWords'] as int?) ?? seedDefaults.weeklyWords,
      monthlyWords: (json['monthlyWords'] as int?) ?? seedDefaults.monthlyWords,
      updatedAt:
          updatedAt == null ? null : DateTime.parse(updatedAt).toLocal(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WritingGoals &&
          other.projectId == projectId &&
          other.dailyWords == dailyWords &&
          other.weeklyWords == weeklyWords &&
          other.monthlyWords == monthlyWords &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      Object.hash(projectId, dailyWords, weeklyWords, monthlyWords, updatedAt);

  @override
  String toString() => 'WritingGoals($projectId, daily $dailyWords, '
      'weekly $weeklyWords, monthly $monthlyWords)';
}

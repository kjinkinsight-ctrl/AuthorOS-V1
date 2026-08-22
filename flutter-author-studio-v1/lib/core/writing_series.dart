/// Series — the domain layer.
///
/// A [WritingSeries] is a named sequence of books. It is deliberately a thin
/// thing: a name, and the target a book inherits when it joins. Everything
/// else a series appears to have — its books, their order, their word counts —
/// belongs to the projects themselves, because a book is a project and a
/// project already knows its own title and target.
///
/// That restraint is the point. AuthorOS forbids graph links across projects,
/// so a series cannot be an edge between books; and a `targetWords` column
/// here would be a second definition of a number `StarterProject.wordGoal`
/// already owns. What is left is the small amount a series genuinely adds:
/// what it is called, and what a new book in it should aim for.
///
/// Presentation-independent: nothing here imports Flutter, and nothing here
/// formats a value for a screen.
library;

/// A named series of books.
class WritingSeries {
  const WritingSeries({
    required this.id,
    required this.name,
    required this.defaultTargetWords,
    this.createdAt,
    this.updatedAt,
  });

  /// The target a book inherits when it joins a series that names none.
  ///
  /// Deliberately the same figure a standalone project starts with, so joining
  /// a series never silently changes what a book was already aiming for.
  static const defaultTargetWordsSeed = 80000;

  /// An upper bound that keeps a slip — a pasted word count, a stray zero —
  /// from becoming a target no author could write to.
  static const maximumTargetWords = 1000000;

  final String id;
  final String name;

  /// Words a book joining this series inherits as its own target. `0` means
  /// the series names no default and a joining book keeps the target it has.
  final int defaultTargetWords;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasDefaultTarget => defaultTargetWords > 0;

  /// The same series with a usable name and target: the name trimmed, the
  /// target floored at zero and capped at [maximumTargetWords].
  ///
  /// Applied on the way in to storage, so an unusable value is never written.
  WritingSeries normalized() => WritingSeries(
        id: id.trim(),
        name: name.trim(),
        defaultTargetWords: _clamp(defaultTargetWords),
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  static int _clamp(int words) {
    if (words < 0) return 0;
    if (words > maximumTargetWords) return maximumTargetWords;
    return words;
  }

  WritingSeries copyWith({
    String? id,
    String? name,
    int? defaultTargetWords,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      WritingSeries(
        id: id ?? this.id,
        name: name ?? this.name,
        defaultTargetWords: defaultTargetWords ?? this.defaultTargetWords,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// Timestamps serialize as UTC ISO-8601, matching every other AuthorOS
  /// record, and are converted back to local time on the way in.
  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'defaultTargetWords': defaultTargetWords,
        'createdAt': createdAt?.toUtc().toIso8601String(),
        'updatedAt': updatedAt?.toUtc().toIso8601String(),
      };

  factory WritingSeries.fromJson(Map<String, dynamic> json) {
    DateTime? at(Object? value) =>
        value is String ? DateTime.parse(value).toLocal() : null;
    return WritingSeries(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Untitled Series',
      defaultTargetWords:
          (json['defaultTargetWords'] as int?) ?? defaultTargetWordsSeed,
      createdAt: at(json['createdAt']),
      updatedAt: at(json['updatedAt']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WritingSeries &&
          other.id == id &&
          other.name == name &&
          other.defaultTargetWords == defaultTargetWords &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      Object.hash(id, name, defaultTargetWords, createdAt, updatedAt);

  @override
  String toString() =>
      'WritingSeries($id, $name, target $defaultTargetWords)';
}

/// Identity for series, mirroring `WritingSessionId` so ids stay recognisable
/// across the codebase: a prefix, the creation instant in microseconds, and a
/// monotonic counter so two series created in the same microsecond collide.
class WritingSeriesId {
  WritingSeriesId._();

  static int _sequence = 0;

  static String create([DateTime? at]) =>
      'series_${(at ?? DateTime.now()).microsecondsSinceEpoch}'
      '_${_sequence++}';
}

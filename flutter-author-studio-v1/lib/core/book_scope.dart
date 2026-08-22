import 'connected_domain.dart';

/// How a record's book membership is read.
///
/// Every read of book membership in the app goes through this file. That is
/// deliberate: if a future multi-project library ever makes each book its own
/// project (master plan M4), the definition of "which book is this in" changes
/// in one place instead of at every call site.
///
/// The rules, stated once:
///
/// * **B-1.** A record's book membership is [AuthorRecord.bookId]. `null` means
///   *series canon* — visible from every book. A book id means the record
///   belongs to exactly that book. It is never derived, never inferred from
///   links, and changes only through an audited author action
///   (`RecordService.changeBookAssignment`).
/// * **B-2.** A `book` record's own `bookId` is its own id, so
///   `UniversalSearchService.searchByBook` returns the book alongside
///   everything scoped to it, and `bookId == null` unambiguously means "not
///   book-specific" rather than "unassigned".
/// * **B-3.** [RecordScopeType.book] is reserved, not used. `RecordScope`
///   requires a `seriesId` for book scope and there is no series *scope* inside
///   a single project, so book-specific records stay project-scoped and carry
///   their book in the column the database, its index and the search index
///   already read.
class BookScope {
  const BookScope._();

  /// The record type that represents a book.
  static const bookTypeId = 'book';

  /// The record type that represents a series.
  static const seriesTypeId = 'series';

  /// The record type that represents one entity's state inside one book.
  static const entityStateTypeId = 'entity-state';

  /// The connection that records an appearance in a book, chapter or scene.
  static const appearsInTypeId = 'appearsIn';

  /// The connection that places a book in its series.
  static const bookInSeriesTypeId = 'bookInSeries';

  /// The connection that places an entity state in its book.
  static const stateInBookTypeId = 'stateInBook';

  /// The connection that ties an entity state to the entity it varies.
  static const documentsTypeId = 'documents';

  /// The manuscript node key carrying a chapter's book, mirroring the
  /// `chapterId` a scene node already carries.
  static const chapterBookKey = 'bookId';

  /// The prefix an `entity-state` record uses for the entity field values it
  /// overrides.
  ///
  /// Namespaced the way `_codex.` and `_world.` already are, so an override of
  /// `summary` can never be mistaken for the state record's own summary. It
  /// also means the overlay can carry a field belonging to any entity type
  /// without the `entity-state` definition having to declare it.
  static const stateFieldPrefix = '_state.';

  /// The overridden entity fields carried by an `entity-state` record.
  static Map<String, Object?> overridesOf(AuthorRecord state) => {
        for (final entry in state.fields.entries)
          if (entry.key.startsWith(stateFieldPrefix))
            entry.key.substring(stateFieldPrefix.length): entry.value,
      };

  /// The entity fields an `entity-state` record drops for its book.
  static Set<String> removalsOf(AuthorRecord state) {
    final value = state.fields['removedFieldIds'];
    if (value is! List) return const {};
    return {
      for (final item in value)
        if (item.toString().trim().isNotEmpty) item.toString().trim(),
    };
  }

  /// The entity an `entity-state` record varies.
  static String? canonicalIdOf(AuthorRecord state) =>
      _string(state.fields['canonicalRecordId']);

  /// Series canon merged with one book's overlay.
  ///
  /// Derived on every read and never written back: merging it into canon would
  /// destroy the distinction between what is true everywhere and what is only
  /// true in one book. With no state record the result is canon itself, so a
  /// project that never overrides anything pays nothing for this.
  static EffectiveEntityFields effectiveFields(
    AuthorRecord canon, {
    String? bookId,
    AuthorRecord? state,
  }) {
    if (state == null) {
      return EffectiveEntityFields(
        recordId: canon.id,
        bookId: bookId,
        fields: Map<String, Object?>.unmodifiable(canon.fields),
        overriddenFieldIds: const {},
        removedFieldIds: const {},
      );
    }
    final overrides = overridesOf(state);
    final removals = removalsOf(state);
    final merged = <String, Object?>{
      for (final entry in canon.fields.entries)
        if (!removals.contains(entry.key)) entry.key: entry.value,
      ...overrides,
    };
    return EffectiveEntityFields(
      recordId: canon.id,
      bookId: bookId,
      fields: Map<String, Object?>.unmodifiable(merged),
      overriddenFieldIds: overrides.keys.toSet(),
      removedFieldIds: removals,
      stateRecordId: state.id,
    );
  }

  /// Whether [record] is series canon — true for anything not tied to one book.
  static bool isSeriesCanon(AuthorRecord record) => bookIdOf(record) == null;

  /// The book [record] belongs to, or null for series canon.
  ///
  /// A `book` record answers with its own id (B-2), even if the column was
  /// never populated, so callers never have to special-case books.
  static String? bookIdOf(AuthorRecord record) {
    if (record.typeId == bookTypeId) return record.id;
    final value = record.bookId?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  /// Whether [record] should be visible while reading [bookId].
  ///
  /// Series canon is visible from every book. A book-specific record is visible
  /// only from its own book. With no book selected, everything is visible.
  static bool visibleInBook(AuthorRecord record, String? bookId) {
    if (bookId == null || bookId.trim().isEmpty) return true;
    final owner = bookIdOf(record);
    return owner == null || owner == bookId;
  }

  /// The book a manuscript node belongs to.
  ///
  /// A chapter node carries its book directly. A scene node carries its
  /// chapter, so its book is its chapter's — resolved through [nodesById] so a
  /// scene never has to duplicate the value.
  static String? bookOfNode(
    ManuscriptNodeReference node,
    Map<String, ManuscriptNodeReference> nodesById,
  ) {
    final direct = _string(node.extensionData[chapterBookKey]);
    if (direct != null) return direct;
    final chapterId = _string(node.extensionData['chapterId']);
    if (chapterId == null) return null;
    final chapter = nodesById[chapterId];
    if (chapter == null) return null;
    return _string(chapter.extensionData[chapterBookKey]);
  }

  /// Sorts books by their `order` field, falling back to title.
  static int compareBooks(AuthorRecord a, AuthorRecord b) {
    final byOrder = _order(a).compareTo(_order(b));
    return byOrder != 0 ? byOrder : a.title.compareTo(b.title);
  }

  static num _order(AuthorRecord record) {
    final value = record.fields['order'];
    return value is num ? value : 0;
  }

  static String? _string(Object? value) {
    final normalized = value is String ? value.trim() : '';
    return normalized.isEmpty ? null : normalized;
  }
}

/// One entity's fields as they stand inside one book.
///
/// Series canon merged with the book's [AuthorRecord]-typed `entity-state`
/// overlay. This is a **derived** view object: it is computed on read, it is
/// never persisted, and merging it back into canon would destroy the
/// distinction between what is true everywhere and what is true in one book.
class EffectiveEntityFields {
  const EffectiveEntityFields({
    required this.recordId,
    required this.bookId,
    required this.fields,
    required this.overriddenFieldIds,
    required this.removedFieldIds,
    this.stateRecordId,
  });

  final String recordId;
  final String? bookId;

  /// Canon, with the book's overrides applied and its removals dropped.
  final Map<String, Object?> fields;

  /// Field ids this book gives a different value to.
  final Set<String> overriddenFieldIds;

  /// Field ids this book drops entirely.
  final Set<String> removedFieldIds;

  /// The `entity-state` record supplying the overlay, if there is one.
  final String? stateRecordId;

  bool get isCanon => overriddenFieldIds.isEmpty && removedFieldIds.isEmpty;
}

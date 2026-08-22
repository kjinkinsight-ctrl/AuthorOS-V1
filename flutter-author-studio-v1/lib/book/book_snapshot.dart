/// Book Studio Phase 5 — frozen manuscript snapshots.
///
/// The master plan states that *"Book Studio consumes a manuscript snapshot and
/// does not mutate the source manuscript while laying out a book"* (§11.10), and
/// M7's exit gate asks that *"exports are reproducible from a frozen manuscript
/// snapshot"*. The second half of that sentence was true from Phase 1 — nothing
/// here writes prose. The first half was not: the studio read whatever the
/// manuscript said at that instant, and an export could not be reproduced once
/// the author wrote another paragraph.
///
/// This is the freezing. Every export records the manuscript it was built from,
/// so an author can see what each file actually contains and produce that exact
/// file again months later.
///
/// **Where the bytes live, and why not with the other book settings.** The rest
/// of the book's configuration is a shared-preferences blob, which on the web is
/// `localStorage` — roughly five megabytes for the whole origin, shared with the
/// author's own prose. A snapshot of a full novel is a couple of hundred
/// kilobytes and there are several of them. That is precisely the ceiling cover
/// art was moved off in Phase 2, and snapshots go the same way, into
/// `book_asset_rows`.
///
/// **Why no new table.** `book_asset_rows` already exists, is already declared
/// in `test/story_graph_architecture_test.dart`'s audited set with its
/// rationale, and already has a `role` discriminator in its primary key. A
/// snapshot is an authored asset by exactly the same argument a cover is: it is
/// never a `RecordLink` endpoint and participates in nothing. Adding a second
/// table to say the same thing would be a second persistence system for no gain.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' as drift;

import '../manuscript_store.dart';
import '../persistence/authoros_database.dart';

/// A manuscript, frozen.
class BookSnapshot {
  const BookSnapshot({
    required this.hash,
    required this.manuscript,
    required this.capturedAt,
  });

  /// Content address: the same manuscript always produces the same hash.
  ///
  /// This is what makes exporting one book to five formats store one snapshot
  /// rather than five.
  final String hash;

  final ManuscriptProjectSummary manuscript;
  final DateTime capturedAt;

  /// The hash a given manuscript will be stored under.
  ///
  /// Sixteen hex characters of SHA-256. Long enough that a collision between
  /// two drafts of one novel is not a thing that happens, short enough to read
  /// in a row of export history.
  static String hashOf(ManuscriptProjectSummary manuscript) =>
      sha256.convert(utf8.encode(jsonEncode(manuscript.toJson())))
          .toString()
          .substring(0, 16);

  static String roleFor(String hash) => 'snapshot:$hash';

  static const rolePrefix = 'snapshot:';
}

/// Reads and writes snapshots.
class BookSnapshotStore {
  const BookSnapshotStore({this.database});

  final AuthorOsDatabase? database;

  /// How many distinct manuscripts are kept per project.
  ///
  /// Content-addressing means this is five distinct *drafts*, not five exports:
  /// exporting one book to PDF, EPUB, DOCX and TXT keeps one. Five is enough to
  /// reproduce recent work and few enough that a shared device does not fill up
  /// with drafts nobody will ask for again.
  static const retained = 5;

  AuthorOsDatabase get _database => database ?? authorOsDatabase;

  /// Stores [manuscript] if it is not already stored, and returns its hash.
  ///
  /// Writing the same manuscript twice is a no-op beyond refreshing its
  /// timestamp, which is what keeps eviction honest: a snapshot re-used by a
  /// later export is not the oldest any more.
  Future<String> capture(
    String projectId,
    ManuscriptProjectSummary manuscript, {
    DateTime? timestamp,
  }) async {
    final hash = BookSnapshot.hashOf(manuscript);
    final bytes = Uint8List.fromList(
      const GZipEncoder().encodeBytes(
        utf8.encode(jsonEncode(manuscript.toJson())),
      ),
    );

    await _database.into(_database.bookAssetRows).insertOnConflictUpdate(
          BookAssetRowsCompanion.insert(
            projectId: projectId,
            role: BookSnapshot.roleFor(hash),
            mediaType: 'application/json',
            bytes: bytes,
            updatedAt: timestamp ?? DateTime.now().toUtc(),
            extensionJson: '{}',
          ),
        );
    return hash;
  }

  /// The manuscript stored under [hash], or null if it has been evicted.
  Future<BookSnapshot?> load(String projectId, String hash) async {
    final query = _database.select(_database.bookAssetRows)
      ..where((row) =>
          row.projectId.equals(projectId) &
          row.role.equals(BookSnapshot.roleFor(hash)));
    final row = await query.getSingleOrNull();
    if (row == null) return null;

    try {
      final inflated = const GZipDecoder().decodeBytes(row.bytes);
      final decoded = jsonDecode(utf8.decode(inflated)) as Map<String, dynamic>;
      return BookSnapshot(
        hash: hash,
        manuscript: ManuscriptProjectSummary.fromJson(decoded),
        capturedAt: row.updatedAt,
      );
    } catch (_) {
      // A snapshot that will not decode is worse than useless — it would fail
      // in the middle of an export. Treated as absent, like an evicted one.
      return null;
    }
  }

  /// Every snapshot hash held for this project, newest first.
  Future<List<String>> hashes(String projectId) async {
    final query = _database.select(_database.bookAssetRows)
      ..where((row) =>
          row.projectId.equals(projectId) &
          row.role.like('${BookSnapshot.rolePrefix}%'))
      ..orderBy([
        (row) => drift.OrderingTerm(
            expression: row.updatedAt, mode: drift.OrderingMode.desc),
      ]);
    final rows = await query.get();
    return [
      for (final row in rows)
        row.role.substring(BookSnapshot.rolePrefix.length),
    ];
  }

  /// Drops snapshots nothing refers to, and anything past [retained].
  ///
  /// [live] is the set of hashes the export history still names. A snapshot no
  /// history entry mentions is unreachable — nothing can ever ask for it again
  /// — so it goes regardless of age.
  Future<int> prune(String projectId, Set<String> live) async {
    final held = await hashes(projectId);
    final keep = <String>{};
    for (final hash in held) {
      if (keep.length >= retained) break;
      if (live.contains(hash)) keep.add(hash);
    }

    final doomed = held.where((hash) => !keep.contains(hash)).toList();
    for (final hash in doomed) {
      await (_database.delete(_database.bookAssetRows)
            ..where((row) =>
                row.projectId.equals(projectId) &
                row.role.equals(BookSnapshot.roleFor(hash))))
          .go();
    }
    return doomed.length;
  }

  /// Removes every snapshot for a project. Leaves the cover alone.
  Future<void> clear(String projectId) async {
    await (_database.delete(_database.bookAssetRows)
          ..where((row) =>
              row.projectId.equals(projectId) &
              row.role.like('${BookSnapshot.rolePrefix}%')))
        .go();
  }
}

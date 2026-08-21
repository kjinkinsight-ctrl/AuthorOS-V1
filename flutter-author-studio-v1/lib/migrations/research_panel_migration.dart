import 'dart:convert';

import '../core/connected_domain.dart';
import '../core/research_record_types.dart';
import '../persistence/authoros_database.dart';
import '../research_service.dart';
import 'research_panel_store.dart';

/// Why a single legacy reference did not become a record.
enum ResearchPanelSkipReason {
  /// Already migrated — a record with the derived id exists.
  alreadyMigrated,

  /// The reference carried no usable title, so there is nothing to name a
  /// record after. The legacy blob still holds it.
  emptyTitle,

  /// Creating the record failed. The legacy blob still holds it.
  failed,
}

/// One legacy reference that was not turned into a record, and why.
class ResearchPanelSkip {
  const ResearchPanelSkip({
    required this.recordId,
    required this.title,
    required this.tab,
    required this.reason,
    this.detail = '',
  });

  final String recordId;
  final String title;
  final ResearchTab tab;
  final ResearchPanelSkipReason reason;
  final String detail;

  @override
  String toString() => '${tab.name}/$recordId: ${reason.name}'
      '${detail.isEmpty ? '' : ' ($detail)'}';
}

/// What one run of the migration did.
class ResearchPanelMigrationReport {
  const ResearchPanelMigrationReport({
    required this.ran,
    required this.created,
    required this.skipped,
    required this.legacyDataRetained,
  });

  /// A no-op run: nothing in the legacy store, or already migrated.
  const ResearchPanelMigrationReport.noop()
      : ran = false,
        created = const [],
        skipped = const [],
        legacyDataRetained = true;

  /// Whether this call did any work. False when the marker was already
  /// present or the legacy store was empty.
  final bool ran;

  final List<AuthorRecord> created;
  final List<ResearchPanelSkip> skipped;

  /// Always true. The legacy preference key is never deleted or rewritten by
  /// this migration — it is the only copy of data no backup subsystem covers.
  final bool legacyDataRetained;

  bool get isEmpty => created.isEmpty && skipped.isEmpty;
}

/// Lifts the legacy Manuscript research side panel into Universal Records.
///
/// The panel stored `{title, detail, tag}` triples under
/// `author_studio.research_panel.{projectId}`, outside the canonical graph and
/// — critically — outside the archive, sync, and backup subsystems. This moves
/// that data into `research-entry` records so it lives with everything else,
/// and is covered by everything else.
///
/// Three properties matter more than anything here:
///
/// * **Nothing is destroyed.** The legacy key is never deleted or rewritten.
///   A separate marker key records that the migration ran.
/// * **It is idempotent.** Record ids are derived from the source content, so
///   running twice creates nothing twice — with or without the marker.
/// * **It degrades per-item.** One bad reference is skipped and reported; it
///   never aborts the run and never costs the author the rest of their data.
class ResearchPanelMigrationService {
  const ResearchPanelMigrationService({
    required this.projectId,
    required this.repository,
  });

  final String projectId;
  final DriftConnectedDomainRepository repository;

  ResearchService get research =>
      ResearchService(projectId: projectId, repository: repository);

  ProjectResearchStore get store => ProjectResearchStore(projectId: projectId);

  /// The extension key each migrated record carries, naming where it came
  /// from. Enough to find every migrated record, and to trace one back.
  static const provenanceField = 'migratedFrom';

  /// Runs the migration if it has not run already.
  ///
  /// Safe to call on every app open: it short-circuits on the marker, and the
  /// derived ids make even a marker-less re-run a no-op.
  Future<ResearchPanelMigrationReport> migrate({DateTime? timestamp}) async {
    if (await store.readMarker() != null) {
      return const ResearchPanelMigrationReport.noop();
    }
    return migrateNow(timestamp: timestamp);
  }

  /// Runs the migration regardless of the marker.
  ///
  /// Still idempotent — existing records are reported as
  /// [ResearchPanelSkipReason.alreadyMigrated] rather than duplicated.
  Future<ResearchPanelMigrationReport> migrateNow({DateTime? timestamp}) async {
    final legacy = await store.load();
    if (legacy.values.every((entries) => entries.isEmpty)) {
      return const ResearchPanelMigrationReport.noop();
    }

    final now = (timestamp ?? DateTime.now()).toUtc();
    final created = <AuthorRecord>[];
    final skipped = <ResearchPanelSkip>[];

    // Tab order is fixed so ids and ordering stay stable between runs.
    for (final tab in ResearchTab.values) {
      final entries = legacy[tab] ?? const <ResearchReference>[];
      for (var index = 0; index < entries.length; index++) {
        final reference = entries[index];
        final title = reference.title.trim();
        final recordId = recordIdFor(tab: tab, title: title);

        if (title.isEmpty) {
          skipped.add(ResearchPanelSkip(
            recordId: recordId,
            title: reference.title,
            tab: tab,
            reason: ResearchPanelSkipReason.emptyTitle,
            detail: 'Left in the legacy store; nothing to name a record after.',
          ));
          continue;
        }

        if (await repository.recordById(recordId) != null) {
          skipped.add(ResearchPanelSkip(
            recordId: recordId,
            title: title,
            tab: tab,
            reason: ResearchPanelSkipReason.alreadyMigrated,
          ));
          continue;
        }

        try {
          created.add(
            await _createRecord(
              reference: reference,
              tab: tab,
              index: index,
              recordId: recordId,
              title: title,
              timestamp: now,
            ),
          );
        } catch (error) {
          // A single unconvertible reference must not cost the author the
          // rest of the migration. The legacy blob still holds this one.
          skipped.add(ResearchPanelSkip(
            recordId: recordId,
            title: title,
            tab: tab,
            reason: ResearchPanelSkipReason.failed,
            detail: '$error',
          ));
        }
      }
    }

    await store.writeMarker(ResearchPanelMigrationMarker(
      migratedAt: now,
      createdRecordIds: created.map((record) => record.id).toList(),
      skipped: skipped.map((skip) => skip.toString()).toList(),
    ));

    return ResearchPanelMigrationReport(
      ran: true,
      created: created,
      skipped: skipped,
      legacyDataRetained: true,
    );
  }

  Future<AuthorRecord> _createRecord({
    required ResearchReference reference,
    required ResearchTab tab,
    required int index,
    required String recordId,
    required String title,
    required DateTime timestamp,
  }) {
    final tag = reference.tag.trim();
    final matchedCategory = matchCategory(tag);
    return research.createResearch(
      ResearchDraft(
        id: recordId,
        title: title,
        kind: kindFor(tab),
        category: matchedCategory ?? ResearchRecordTypes.defaultCategory,
        status: ResearchRecordTypes.defaultStatus,
        summary: reference.detail.trim(),
        // A tag that became the category would be redundant as a tag too; one
        // that did not is kept so the author's own labelling survives.
        tags: [
          if (matchedCategory == null && tag.isNotEmpty) tag,
        ],
        // Provenance back to the exact legacy slot, stamped at creation so
        // the record needs one revision rather than two.
        extensionData: {
          provenanceField: {
            'store': ProjectResearchStore.keyPrefix,
            'projectId': projectId,
            'tab': tab.name,
            'index': index,
            'tag': reference.tag,
          },
        },
      ),
      timestamp: timestamp,
    );
  }

  /// The record id a given legacy reference maps to.
  ///
  /// Derived from project, tab, and title rather than list position, so the
  /// same reference maps to the same record however the list is reordered —
  /// which is what makes a re-run a no-op instead of a duplicate.
  String recordIdFor({required ResearchTab tab, required String title}) {
    final seed = '$projectId|${tab.name}|${title.trim().toLowerCase()}';
    return 'research-panel-${_stableHash(seed)}';
  }

  /// Which shelf a legacy tab becomes.
  ///
  /// The panel called every entry a "pinned reference", so the Research tab
  /// maps to Reference. Notes and Timeline entries were free text about the
  /// story rather than external sources, so both become Notes — Timeline
  /// entries in particular were prose about chronology, not timeline records,
  /// and inventing `timeline-*` records from them would be a guess.
  static String kindFor(ResearchTab tab) => switch (tab) {
        ResearchTab.research => 'Reference',
        ResearchTab.notes => 'Note',
        ResearchTab.timeline => 'Note',
      };

  /// The canonical category a legacy `tag` names, or null if it names none.
  ///
  /// The panel's tag was free text, but in practice it held either the tab
  /// name or a subject word. Where that word is one of the canonical
  /// categories — `World`, `Character`, and so on — the migration keeps the
  /// author's classification instead of flattening everything to `Other`.
  static String? matchCategory(String tag) {
    final normalized = tag.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final category in ResearchRecordTypes.categories) {
      if (category.toLowerCase() == normalized) return category;
    }
    return null;
  }
}

/// A deterministic digest of [value], written out rather than taken from a
/// hash library so record ids are byte-stable across Dart versions and
/// platforms — `Object.hash` is not specified to be.
///
/// **Must stay JavaScript-safe.** AuthorOS ships to web, where `int` is a
/// double: any literal or intermediate above 2^53 is a compile error or a
/// silent precision loss. A 64-bit FNV-1a fails to compile for exactly that
/// reason. These two modular polynomial hashes keep every intermediate under
/// 2^38, and combining them gives a digest wide enough that a collision — two
/// distinct references collapsing onto one record — is not a practical risk
/// at per-project research volumes.
String _stableHash(String value) {
  var low = 0;
  var high = 0;
  for (final byte in utf8.encode(value)) {
    low = (low * 31 + byte) % 0x7FFFFFFF;
    high = (high * 131 + byte) % 0x7FFFFFF7;
  }
  return '${low.toRadixString(16).padLeft(8, '0')}'
      '${high.toRadixString(16).padLeft(8, '0')}';
}

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/connected_domain.dart';
import '../core/record_service.dart';
import '../core/story_codex_domain.dart';
import '../persistence/authoros_database.dart';
import 'legacy_research_store.dart';

/// Moves the Manuscript Studio research side panel's SharedPreferences data
/// into canonical `research-entry` records.
///
/// The migration is:
///
/// * **project-scoped** — it runs when a project is opened, never at app
///   startup, and never touches another project's research;
/// * **deterministic** — a legacy entry always resolves to the same record id,
///   so a second run creates nothing new;
/// * **resumable** — every entry is migrated independently and the completion
///   marker is only written once all of them succeeded;
/// * **non-destructive** — the legacy SharedPreferences payload is left in
///   place as a safety net.
///
/// Nothing here is a second research system: records are written through
/// [RecordService], read through [DriftConnectedDomainRepository], indexed by
/// the existing FTS index, and counted by the existing analytics query.

/// The canonical record type migrated research becomes.
const researchRecordTypeId = 'research-entry';

/// Bumped only when a future milestone needs to re-run the migration.
const researchMigrationVersion = 1;

/// Namespace for the migration provenance stored on each migrated record.
const researchMigrationExtensionKey = 'researchMigration';

/// The title used when a legacy entry carries no usable one.
///
/// Matches [ResearchReference.fromJson]'s own fallback rather than inventing a
/// new one, so an entry with a null title and an entry with an empty title end
/// up reading the same.
const researchMigrationFallbackTitle = 'Untitled reference';

/// One legacy entry that could not be migrated.
class ResearchMigrationFailure {
  const ResearchMigrationFailure({
    required this.legacyKey,
    required this.title,
    required this.error,
  });

  final String legacyKey;
  final String title;
  final String error;

  @override
  String toString() => 'ResearchMigrationFailure($legacyKey: $error)';
}

/// What one migration run did.
class ResearchMigrationOutcome {
  const ResearchMigrationOutcome({
    required this.projectId,
    required this.legacyEntryCount,
    required this.migratedRecordIds,
    required this.skippedRecordIds,
    required this.failures,
    required this.completed,
    required this.alreadyComplete,
  });

  /// A run that did nothing because the marker said the project was done.
  factory ResearchMigrationOutcome.alreadyMigrated(String projectId) =>
      ResearchMigrationOutcome(
        projectId: projectId,
        legacyEntryCount: 0,
        migratedRecordIds: const [],
        skippedRecordIds: const [],
        failures: const [],
        completed: true,
        alreadyComplete: true,
      );

  /// A run that found no legacy research at all.
  factory ResearchMigrationOutcome.nothingToMigrate(String projectId) =>
      ResearchMigrationOutcome(
        projectId: projectId,
        legacyEntryCount: 0,
        migratedRecordIds: const [],
        skippedRecordIds: const [],
        failures: const [],
        completed: true,
        alreadyComplete: false,
      );

  final String projectId;

  /// How many legacy entries the store held.
  final int legacyEntryCount;

  /// Records created by this run.
  final List<String> migratedRecordIds;

  /// Records that already existed, so this run left them alone.
  final List<String> skippedRecordIds;

  /// Entries this run could not migrate. Non-empty means [completed] is false.
  final List<ResearchMigrationFailure> failures;

  /// True when every legacy entry now has a canonical record.
  final bool completed;

  /// True when the marker already recorded a completed migration.
  final bool alreadyComplete;

  int get migratedCount => migratedRecordIds.length;
  int get skippedCount => skippedRecordIds.length;
  int get failureCount => failures.length;

  /// True when this run created or confirmed at least one record.
  bool get hasCanonicalRecords =>
      migratedRecordIds.isNotEmpty || skippedRecordIds.isNotEmpty;

  @override
  String toString() => 'ResearchMigrationOutcome($projectId, '
      'legacy: $legacyEntryCount, migrated: $migratedCount, '
      'skipped: $skippedCount, failed: $failureCount, '
      'completed: $completed)';
}

/// Reads and writes the per-project migration marker.
///
/// Uses the application's existing SharedPreferences namespace rather than a
/// second database: the marker records that a legacy store was drained, which
/// is state about the legacy store, not about the record system.
class ResearchMigrationState {
  const ResearchMigrationState({required this.projectId});

  final String projectId;

  static const keyPrefix = 'author_studio.research_migration.';

  String get storageKey => '$keyPrefix$projectId';

  /// The migration version this project has completed, or `0` for none.
  Future<int> completedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(storageKey) ?? 0;
  }

  Future<bool> isComplete() async =>
      await completedVersion() >= researchMigrationVersion;

  Future<void> markComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(storageKey, researchMigrationVersion);
  }
}

/// Migrates one project's legacy research panel into canonical records.
class LegacyResearchMigrationService {
  const LegacyResearchMigrationService({
    required this.projectId,
    required this.repository,
    this.legacyStore,
  });

  final String projectId;
  final DriftConnectedDomainRepository repository;

  /// Overridable for tests; defaults to this project's legacy store.
  final ProjectResearchStore? legacyStore;

  ProjectResearchStore get _legacy =>
      legacyStore ?? ProjectResearchStore(projectId: projectId);

  ResearchMigrationState get state =>
      ResearchMigrationState(projectId: projectId);

  RecordService get records =>
      RecordService(projectId: projectId, repository: repository);

  /// Runs the migration for this project.
  ///
  /// Reads the marker and the legacy store before touching the database, so a
  /// project with nothing to migrate costs two preference reads and no query.
  Future<ResearchMigrationOutcome> migrate({DateTime? timestamp}) async {
    if (await state.isComplete()) {
      return ResearchMigrationOutcome.alreadyMigrated(projectId);
    }

    final legacy = await _legacy.load();
    final entries = <_LegacyResearchEntry>[];
    // Iterate the tabs in declaration order, not map order, so the occurrence
    // counter that disambiguates identical entries is stable across runs.
    final seen = <String, int>{};
    for (final tab in ResearchTab.values) {
      for (final reference in legacy[tab] ?? const <ResearchReference>[]) {
        final digest = _contentDigest(reference);
        final occurrence = seen.update(
          '${tab.name}|$digest',
          (value) => value + 1,
          ifAbsent: () => 0,
        );
        entries.add(_LegacyResearchEntry(
          reference: reference,
          tab: tab,
          legacyKey: legacyResearchKey(
            projectId: projectId,
            tab: tab,
            contentDigest: digest,
            occurrence: occurrence,
          ),
        ));
      }
    }

    if (entries.isEmpty) {
      // Nothing to migrate is a completed migration: the marker stops the
      // store from being re-read every time the project is opened.
      await state.markComplete();
      return ResearchMigrationOutcome.nothingToMigrate(projectId);
    }

    final now = (timestamp ?? DateTime.now()).toUtc();
    final migrated = <String>[];
    final skipped = <String>[];
    final failures = <ResearchMigrationFailure>[];

    for (final entry in entries) {
      final recordId = researchRecordIdFor(entry.legacyKey);
      try {
        // Identity check first: an existing record — whether created by an
        // earlier run or edited by the author since — is never overwritten.
        if (await repository.recordById(recordId) != null) {
          skipped.add(recordId);
          continue;
        }
        await records.createRecord(
          _recordFor(entry, recordId: recordId, timestamp: now),
        );
        migrated.add(recordId);
      } catch (error) {
        failures.add(ResearchMigrationFailure(
          legacyKey: entry.legacyKey,
          title: entry.reference.title,
          error: error.toString(),
        ));
      }
    }

    final completed = failures.isEmpty;
    if (completed) {
      // Only a clean pass marks the project done. A partial run leaves the
      // marker unset, so the next open resumes and skips what already landed.
      await state.markComplete();
    }

    return ResearchMigrationOutcome(
      projectId: projectId,
      legacyEntryCount: entries.length,
      migratedRecordIds: List.unmodifiable(migrated),
      skippedRecordIds: List.unmodifiable(skipped),
      failures: List.unmodifiable(failures),
      completed: completed,
      alreadyComplete: false,
    );
  }

  /// The canonical records this project has from the legacy panel.
  Future<List<AuthorRecord>> migratedRecords() async {
    final records = await repository.recordsByTypeAndScope(
      typeId: researchRecordTypeId,
      scopeId: projectId,
    );
    return records.where(isMigratedResearchRecord).toList();
  }

  AuthorRecord _recordFor(
    _LegacyResearchEntry entry, {
    required String recordId,
    required DateTime timestamp,
  }) {
    final reference = entry.reference;
    final title = reference.title.trim().isEmpty
        ? researchMigrationFallbackTitle
        : reference.title.trim();
    final detail = reference.detail;
    final tag = reference.tag.trim();
    return AuthorRecord(
      id: recordId,
      typeId: researchRecordTypeId,
      scopeType: RecordScopeType.project,
      scopeId: projectId,
      projectId: projectId,
      title: title,
      templateId: researchRecordTypeId,
      templateVersion: 1,
      fields: {
        // `name` is the template's title-backed field.
        'name': title,
        // The legacy "Details" box is the entry's body text. Written to the
        // template's own `summary` field and to the Codex summary the record
        // surfaces read, exactly as `StoryCodexService` writes new entries.
        if (detail.isNotEmpty) 'summary': detail,
        if (detail.isNotEmpty) CodexFields.summary: detail,
        CodexFields.templateId: researchRecordTypeId,
        CodexFields.projectId: projectId,
      },
      // An empty legacy tag stays empty: no phantom tag is invented.
      tags: tag.isEmpty ? const [] : [tag],
      createdAt: timestamp,
      updatedAt: timestamp,
      extensionData: {
        'storyCodex': true,
        researchMigrationExtensionKey: {
          'version': researchMigrationVersion,
          'source': ProjectResearchStore.keyPrefix,
          'legacyKey': entry.legacyKey,
          // The legacy panel's tab has no field in the canonical research
          // schema. It is kept verbatim here rather than dropped.
          'legacyTab': entry.tab.name,
          'legacyTag': reference.tag,
        },
      },
    );
  }
}

class _LegacyResearchEntry {
  const _LegacyResearchEntry({
    required this.reference,
    required this.tab,
    required this.legacyKey,
  });

  final ResearchReference reference;
  final ResearchTab tab;
  final String legacyKey;
}

/// True when [record] came from the legacy research panel.
bool isMigratedResearchRecord(AuthorRecord record) =>
    record.extensionData[researchMigrationExtensionKey] is Map;

/// The legacy key [record] was migrated from, or `null` if it was not.
String? migratedResearchLegacyKey(AuthorRecord record) {
  final provenance = record.extensionData[researchMigrationExtensionKey];
  if (provenance is! Map) return null;
  final key = provenance['legacyKey'];
  return key is String && key.isNotEmpty ? key : null;
}

/// The legacy panel tab [record] was migrated from, or `null`.
String? migratedResearchLegacyTab(AuthorRecord record) {
  final provenance = record.extensionData[researchMigrationExtensionKey];
  if (provenance is! Map) return null;
  final tab = provenance['legacyTab'];
  return tab is String && tab.isNotEmpty ? tab : null;
}

/// A legacy entry's stable identity.
///
/// Deliberately not title-based: two research entries may legitimately share a
/// title, and a positional index would shift whenever an earlier entry is
/// removed. The identity is instead the project, the tab, a digest of the full
/// `{title, detail, tag}` content, and an occurrence counter that separates
/// entries whose content is byte-identical.
String legacyResearchKey({
  required String projectId,
  required ResearchTab tab,
  required String contentDigest,
  required int occurrence,
}) =>
    'research|$projectId|${tab.name}|$contentDigest|$occurrence';

/// The canonical record id a legacy key always resolves to.
String researchRecordIdFor(String legacyKey) =>
    'research-legacy-${_digest(legacyKey).substring(0, 32)}';

String _contentDigest(ResearchReference reference) => _digest(
      jsonEncode([reference.title, reference.detail, reference.tag]),
    ).substring(0, 32);

String _digest(String value) => sha256.convert(utf8.encode(value)).toString();

/// Runs the migration for [projectId], in the shape the shell calls it.
typedef ResearchMigrationRunner = Future<ResearchMigrationOutcome> Function(
  String projectId,
);

/// The shell's default runner: the app-wide repository, and never a throw.
///
/// Opening a project must not fail because migration did. A run that throws
/// leaves the marker unset, so the next open retries.
Future<ResearchMigrationOutcome> runLegacyResearchMigration(
  String projectId,
) async {
  try {
    return await LegacyResearchMigrationService(
      projectId: projectId,
      repository: authorOsRepository,
    ).migrate();
  } catch (error) {
    return ResearchMigrationOutcome(
      projectId: projectId,
      legacyEntryCount: 0,
      migratedRecordIds: const [],
      skippedRecordIds: const [],
      failures: [
        ResearchMigrationFailure(
          legacyKey: '',
          title: '',
          error: error.toString(),
        ),
      ],
      completed: false,
      alreadyComplete: false,
    );
  }
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// The legacy Manuscript Studio research side panel's storage.
///
/// This is a **read path for migration**, not a place to put new research.
/// Research is a Universal Record now: `ResearchService` owns it and the
/// Research Studio is where authors create it. Nothing in the app writes
/// through [ProjectResearchStore.save] any more — the panel that used to is
/// read-only over canonical records, and [save] survives only so migration
/// tests and fixtures can stage legacy data.
///
/// The store is kept rather than deleted because author data can exist in it,
/// and — unlike everything in the canonical graph — its key was never covered
/// by the archive, sync, or backup subsystems. Deleting it would destroy the
/// only copy. [ResearchPanelMigrationService] lifts it into records and marks
/// it migrated; the original key is left untouched for a support window.
///
/// Moved here verbatim from `main.dart`, where it lived before Research
/// Studio existed.
enum ResearchTab { research, notes, timeline }

class ResearchReference {
  const ResearchReference({
    required this.title,
    required this.detail,
    required this.tag,
  });

  final String title;
  final String detail;
  final String tag;

  Map<String, String> toJson() => {
        'title': title,
        'detail': detail,
        'tag': tag,
      };

  factory ResearchReference.fromJson(Map<String, dynamic> json) =>
      ResearchReference(
        title: json['title'] as String? ?? 'Untitled reference',
        detail: json['detail'] as String? ?? '',
        tag: json['tag'] as String? ?? 'Research',
      );
}

class ProjectResearchStore {
  const ProjectResearchStore({required this.projectId});

  final String projectId;

  /// The preference namespace the panel has always used.
  static const keyPrefix = 'author_studio.research_panel.';

  String get _key => '$keyPrefix$projectId';

  /// Where the migration records that it has already run for this project.
  ///
  /// Deliberately a separate key: the legacy blob itself is never rewritten,
  /// so a migration bug can never corrupt the only copy of the author's data.
  String get migrationMarkerKey => '$_key.migrated';

  Future<Map<ResearchTab, List<ResearchReference>>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_key);
    if (encoded == null || encoded.isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      final result = <ResearchTab, List<ResearchReference>>{};
      for (final entry in decoded.entries) {
        final tab = ResearchTab.values.firstWhere(
          (value) => value.name == entry.key,
          orElse: () => ResearchTab.research,
        );
        final items = (entry.value as List)
            .map((value) => ResearchReference.fromJson(
                Map<String, dynamic>.from(value as Map)))
            .toList();
        // Accumulate rather than assign. Any key this build does not
        // recognise folds onto `research`, so a blob written by an older
        // build — one that had a tab this one dropped — would otherwise see
        // whichever key decoded last silently erase the other's entries.
        (result[tab] ??= <ResearchReference>[]).addAll(items);
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  /// Writes the legacy blob.
  ///
  /// Production code no longer calls this. It remains so migration tests and
  /// legacy fixtures can stage data in the shape real authors have on disk.
  Future<void> save(
      Map<ResearchTab, List<ResearchReference>> references) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = <String, List<Map<String, String>>>{};
    for (final entry in references.entries) {
      payload[entry.key.name] =
          entry.value.map((reference) => reference.toJson()).toList();
    }
    await prefs.setString(_key, jsonEncode(payload));
  }

  /// Whether the raw legacy blob still holds anything, migrated or not.
  ///
  /// Reads the key directly so it stays true even after migration — the point
  /// is that the original data is still on disk.
  Future<bool> hasLegacyData() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_key);
    return encoded != null && encoded.isNotEmpty;
  }

  Future<ResearchPanelMigrationMarker?> readMarker() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(migrationMarkerKey);
    if (encoded == null || encoded.isEmpty) return null;
    try {
      return ResearchPanelMigrationMarker.fromJson(
        Map<String, dynamic>.from(jsonDecode(encoded) as Map),
      );
    } catch (_) {
      // An unreadable marker is treated as absent. Re-running the migration
      // is safe: record ids are derived from the source, so nothing doubles.
      return null;
    }
  }

  Future<void> writeMarker(ResearchPanelMigrationMarker marker) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(migrationMarkerKey, jsonEncode(marker.toJson()));
  }
}

/// The receipt written once a project's panel data has been lifted into
/// records. It names what was created so the move stays auditable.
class ResearchPanelMigrationMarker {
  const ResearchPanelMigrationMarker({
    required this.migratedAt,
    required this.createdRecordIds,
    this.skipped = const [],
    this.version = 1,
  });

  final DateTime migratedAt;
  final List<String> createdRecordIds;
  final List<String> skipped;
  final int version;

  Map<String, Object?> toJson() => {
        'version': version,
        'migratedAt': migratedAt.toUtc().toIso8601String(),
        'createdRecordIds': createdRecordIds,
        'skipped': skipped,
      };

  factory ResearchPanelMigrationMarker.fromJson(Map<String, dynamic> json) =>
      ResearchPanelMigrationMarker(
        version: json['version'] as int? ?? 1,
        migratedAt:
            DateTime.tryParse(json['migratedAt'] as String? ?? '')?.toUtc() ??
                DateTime.utc(1970),
        createdRecordIds: (json['createdRecordIds'] as List? ?? const [])
            .map((value) => value.toString())
            .toList(),
        skipped: (json['skipped'] as List? ?? const [])
            .map((value) => value.toString())
            .toList(),
      );
}

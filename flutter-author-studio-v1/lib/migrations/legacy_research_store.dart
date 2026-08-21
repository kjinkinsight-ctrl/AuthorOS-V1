import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// The Manuscript Studio research side-panel's three tabs.
///
/// Moved here from the app shell so the migration can read legacy research
/// without depending on `main.dart`. The persisted representation — the
/// SharedPreferences key, the JSON shape, and the tab names inside it — is
/// unchanged, so existing installs keep reading and writing the same data.
enum ResearchTab { research, notes, timeline }

/// One legacy research entry: `{title, detail, tag}`.
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

/// The legacy per-project research panel store, backed by SharedPreferences.
///
/// This is the pre-record-system source of truth that
/// [LegacyResearchMigrationService] reads. It is retained deliberately: the
/// migration is non-destructive, so the legacy payload stays on disk as a
/// safety net until a later cleanup milestone removes it.
class ProjectResearchStore {
  const ProjectResearchStore({required this.projectId});

  final String projectId;

  /// The key prefix every project's research panel is stored under.
  static const keyPrefix = 'author_studio.research_panel.';

  String get _key => '$keyPrefix$projectId';

  /// The SharedPreferences key this project's research panel is stored under.
  String get storageKey => _key;

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
        result[tab] = items;
      }
      return result;
    } catch (_) {
      return {};
    }
  }

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
}

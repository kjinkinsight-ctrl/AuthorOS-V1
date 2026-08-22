import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_updater.dart';
import 'command_console.dart';
import 'core/search_models.dart' show SearchNavigationTarget;
import 'local_image.dart';
import 'persistence/authoros_database.dart';
import 'manuscript_store.dart';
import 'onboarding.dart';
import 'supabase_service.dart';
import 'sync/sync_appliers.dart';
import 'theme/flutter/authoros_theme.dart';
import 'theme/theme_definition.dart';
import 'theme/theme_persistence.dart';
import 'theme/theme_registry.dart';
import 'theme/theme_tokens.dart';

export 'character_studio.dart';
export 'story_codex.dart';
export 'story_codex_workspace.dart';

enum StoryCodexType {
  character,
  place,
  faction,
  object,
  lore,
}

extension StoryCodexTypeX on StoryCodexType {
  String get label => switch (this) {
        StoryCodexType.character => 'Character',
        StoryCodexType.place => 'Place',
        StoryCodexType.faction => 'Faction',
        StoryCodexType.object => 'Object',
        StoryCodexType.lore => 'Lore',
      };
}

class StoryCodexReferenceIndex {
  const StoryCodexReferenceIndex();

  static List<String> _namesFor(
    Iterable<StoryCodexEntry> entries,
    StoryCodexType type,
  ) {
    final names = <String>[];
    for (final entry in entries) {
      if (entry.type != type) {
        continue;
      }
      names.add(entry.title);
      names.addAll(entry.aliases);
    }
    return names
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  static List<String> characterNames(Iterable<StoryCodexEntry> entries) =>
      _namesFor(entries, StoryCodexType.character);

  static List<String> locationNames(Iterable<StoryCodexEntry> entries) =>
      _namesFor(entries, StoryCodexType.place);

  static List<String> worldNames(Iterable<StoryCodexEntry> entries) {
    final names = <String>[];
    names.addAll(_namesFor(entries, StoryCodexType.place));
    names.addAll(_namesFor(entries, StoryCodexType.faction));
    names.addAll(_namesFor(entries, StoryCodexType.lore));
    names.addAll(_namesFor(entries, StoryCodexType.object));
    return names.toSet().toList()..sort();
  }
}

class StoryCodexEntry {
  const StoryCodexEntry({
    required this.id,
    required this.title,
    required this.type,
    this.aliases = const [],
    this.summary = '',
    this.tags = const [],
    this.relationships = const {},
    this.mentions = const [],
    this.status = 'Active',
  });

  final String id;
  final String title;
  final StoryCodexType type;
  final List<String> aliases;
  final String summary;
  final List<String> tags;
  final Map<String, String> relationships;
  final List<String> mentions;
  final String status;

  bool get isArchived => status == 'Archived';

  StoryCodexEntry copyWith({
    String? id,
    String? title,
    StoryCodexType? type,
    List<String>? aliases,
    String? summary,
    List<String>? tags,
    Map<String, String>? relationships,
    List<String>? mentions,
    String? status,
  }) =>
      StoryCodexEntry(
        id: id ?? this.id,
        title: title ?? this.title,
        type: type ?? this.type,
        aliases: aliases ?? this.aliases,
        summary: summary ?? this.summary,
        tags: tags ?? this.tags,
        relationships: relationships ?? this.relationships,
        mentions: mentions ?? this.mentions,
        status: status ?? this.status,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type.name,
        'aliases': aliases,
        'summary': summary,
        'tags': tags,
        'relationships': relationships,
        'mentions': mentions,
        'status': status,
      };

  factory StoryCodexEntry.fromJson(Map<String, dynamic> json) {
    final rawType = json['type'] as String? ?? StoryCodexType.character.name;
    return StoryCodexEntry(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled',
      type: StoryCodexType.values.firstWhere(
        (type) => type.name == rawType,
        orElse: () => StoryCodexType.character,
      ),
      aliases: _stringList(json['aliases']),
      summary: json['summary'] as String? ?? '',
      tags: _stringList(json['tags']),
      relationships: _stringMap(json['relationships']),
      mentions: _stringList(json['mentions']),
      status: (json['status'] as String?) ?? 'Active',
    );
  }

  Map<String, String> visibleRelationships(Iterable<StoryCodexEntry> all) {
    final activeNames = <String>{
      for (final entry in all.where((item) => !item.isArchived)) ...[
        entry.title,
        ...entry.aliases
      ],
    }
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet();

    return {
      for (final entry in relationships.entries)
        if (entry.value.trim().isNotEmpty &&
            activeNames.contains(entry.value.trim().toLowerCase()))
          entry.key: entry.value,
    };
  }

  List<String> visibleMentions(Iterable<StoryCodexEntry> all) {
    final archivedIds = all
        .where((item) => item.isArchived)
        .map((item) => item.id.trim().toLowerCase())
        .toSet();
    return mentions
        .where((mention) => !archivedIds.contains(mention.trim().toLowerCase()))
        .toList();
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) {
      return const [];
    }
    return raw.map((item) => item.toString()).toList();
  }

  static Map<String, String> _stringMap(dynamic raw) {
    if (raw is! Map) {
      return const {};
    }
    return raw.map((key, value) => MapEntry(key.toString(), value.toString()));
  }
}

class StudioRecord {
  const StudioRecord({
    required this.id,
    required this.title,
    required this.category,
    required this.details,
    this.status = 'Active',
  });

  final String id;
  final String title;
  final String category;
  final String details;
  final String status;

  bool get isArchived => status == 'Archived';

  StudioRecord copyWith({
    String? id,
    String? title,
    String? category,
    String? details,
    String? status,
  }) =>
      StudioRecord(
        id: id ?? this.id,
        title: title ?? this.title,
        category: category ?? this.category,
        details: details ?? this.details,
        status: status ?? this.status,
      );

  Map<String, Object> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'details': details,
        'status': status,
      };

  factory StudioRecord.fromJson(Map<String, dynamic> json) => StudioRecord(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? 'Untitled',
        category: json['category'] as String? ?? 'General',
        details: json['details'] as String? ?? '',
        status: (json['status'] as String?) ?? 'Active',
      );
}

class StoryCodexStore {
  const StoryCodexStore({this.projectId = ''});

  final String projectId;

  String get key => projectId.isEmpty
      ? 'author_studio.story_codex'
      : 'author_studio.story_codex.$projectId';

  static const List<StoryCodexEntry> defaultEntries = [
    StoryCodexEntry(
      id: 'codex-mara-voss',
      title: 'Mara Voss',
      type: StoryCodexType.character,
      aliases: ['Mara', 'The River Witch'],
      summary:
          'A cartographer whose memory returns in fragments when the river rises.',
      tags: ['protagonist', 'magic', 'memory'],
      relationships: {'mentor': 'Edrin Vale', 'rival': 'Joss Quill'},
      mentions: ['scene-1', 'scene-7', 'chapter-3'],
    ),
    StoryCodexEntry(
      id: 'codex-ashfall-harbor',
      title: 'Ashfall Harbor',
      type: StoryCodexType.place,
      aliases: ['Harbor', 'The Ash Reaches'],
      summary:
          'The storm-worn port city built around a salt shrine and a flooded gate.',
      tags: ['city', 'coast', 'trade'],
      relationships: {'capital': 'Northreach'},
      mentions: ['scene-2', 'timeline-event-1'],
    ),
    StoryCodexEntry(
      id: 'codex-iron-reliquary',
      title: 'The Iron Reliquary',
      type: StoryCodexType.object,
      summary:
          'A sealed vault beneath the harbor that holds the cityâ€™s oldest map keys.',
      tags: ['artifact', 'mystery'],
      relationships: {'owner': 'House Voss'},
      mentions: ['scene-5'],
    ),
    StoryCodexEntry(
      id: 'codex-veil-hollow',
      title: 'The Veil Hollow',
      type: StoryCodexType.lore,
      summary:
          'An abandoned burial road said to whisper the names of those who will soon die.',
      tags: ['myth', 'danger'],
      relationships: {'linked_location': 'Ashfall Harbor'},
      mentions: ['scene-4'],
    ),
  ];

  Future<List<StoryCodexEntry>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(key);
    if (encoded == null) {
      return projectId.isEmpty ? defaultEntries : const [];
    }
    final parsed = jsonDecode(encoded);
    if (parsed is! List) {
      return projectId.isEmpty ? defaultEntries : const [];
    }
    return parsed
        .map((value) =>
            StoryCodexEntry.fromJson(Map<String, dynamic>.from(value as Map)))
        .toList();
  }

  Future<void> save(List<StoryCodexEntry> entries) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      key,
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
  }
}

class StudioRecordStore {
  const StudioRecordStore(this.collection);

  final String collection;

  String get _key => 'author_studio.collection.$collection';

  Future<List<StudioRecord>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_key);
    if (encoded == null) {
      return [];
    }
    return (jsonDecode(encoded) as List)
        .map((value) =>
            StudioRecord.fromJson(Map<String, dynamic>.from(value as Map)))
        .toList();
  }

  Future<void> save(List<StudioRecord> records) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key,
      jsonEncode(records.map((record) => record.toJson()).toList()),
    );
  }
}

/// The Command Console, as a full page.
///
/// This section used to be a substring search over a handful of
/// `SharedPreferences` stores: it never reached the record graph, never used
/// the shared full-text index, and a result could not be opened. It is now the
/// same console the palette shows, so the page and the shortcut answer the
/// same questions the same way.
class SearchStudioView extends StatefulWidget {
  const SearchStudioView({
    super.key,
    required this.project,
    this.onNavigate,
    this.repository,
  });

  final StarterProject project;

  /// Where a tapped result should take the author. The shell supplies this;
  /// without it a result is still listed, just not navigable.
  final ValueChanged<SearchNavigationTarget>? onNavigate;

  final DriftConnectedDomainRepository? repository;

  @override
  State<SearchStudioView> createState() => _SearchStudioViewState();
}

class _SearchStudioViewState extends State<SearchStudioView> {
  @override
  Widget build(BuildContext context) {
    return _StudioPage(
      title: 'Command Console',
      subtitle: 'Ask anything about this project — characters, plots, scenes, '
          'timeline, research and how they connect.',
      child: CommandConsole(
        projectId: widget.project.id,
        repository: widget.repository,
        onNavigate: widget.onNavigate ?? (_) {},
      ),
    );
  }
}


class StatisticsStudioView extends StatefulWidget {
  const StatisticsStudioView({super.key, required this.project});

  final StarterProject project;

  @override
  State<StatisticsStudioView> createState() => _StatisticsStudioViewState();
}

class _StatisticsStudioViewState extends State<StatisticsStudioView> {
  int words = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    const store = ManuscriptStore();
    final migratedChapters =
        await store.loadLegacyChapterSeeds(widget.project.id);
    final chapterSeeds = migratedChapters.isNotEmpty
        ? migratedChapters
        : widget.project.chapters
            .map(
              (chapter) => ManuscriptChapterSeed(
                title: chapter.title,
                prompt: chapter.prompt,
                status: chapter.status,
                scenes: chapter.scenes,
                linkedChapterIds: chapter.linkedChapterIds,
              ),
            )
            .toList();
    final manuscript = await store.loadStudio(
      widget.project.id,
      manuscriptTitle: widget.project.title,
      defaultChapters: chapterSeeds,
      firstSceneTitle: widget.project.firstSceneTitle,
    );
    if (mounted) {
      setState(() {
        words = manuscript.wordCount;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.project.wordGoal == 0
        ? 0.0
        : (words / widget.project.wordGoal).clamp(0.0, 1.0);
    final remaining =
        (widget.project.wordGoal - words).clamp(0, widget.project.wordGoal);
    final screenWidth = MediaQuery.of(context).size.width;
    final cardCount = screenWidth < 700
        ? 2
        : screenWidth < 1100
            ? 3
            : 4;

    return _StudioPage(
      title: 'Statistics Studio',
      subtitle:
          'Review manuscript, story, timeline, and notes analytics from canonical data.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatTile(label: 'Words', value: '$words'),
                _StatTile(label: 'Goal', value: '${widget.project.wordGoal}'),
                _StatTile(
                    label: 'Progress', value: '${(progress * 100).round()}%'),
                _StatTile(label: 'Remaining', value: '$remaining'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Writing goal progress',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Read-only calculations',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 12,
                  borderRadius: BorderRadius.circular(999),
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${widget.project.chapters.length} planned chapters | ${widget.project.characterSheets.length} starter characters',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: cardCount,
            shrinkWrap: true,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.5,
            children: [
              _MiniMetricCard(label: 'Total Words', value: '$words'),
              _MiniMetricCard(
                  label: 'Planned Chapters',
                  value: '${widget.project.chapters.length}'),
              _MiniMetricCard(
                  label: 'Starter Characters',
                  value: '${widget.project.characterSheets.length}'),
              _MiniMetricCard(
                  label: 'Story Goals', value: '${widget.project.wordGoal}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniMetricCard extends StatelessWidget {
  const _MiniMetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class ChapterStudioView extends StatefulWidget {
  const ChapterStudioView({super.key, required this.project});

  final StarterProject project;

  @override
  State<ChapterStudioView> createState() => _ChapterStudioViewState();
}

class _ChapterStudioViewState extends State<ChapterStudioView> {
  List<StarterChapter> chapters = [];
  int? selectedIndex;

  String get _key => 'author_studio.chapters.${widget.project.id}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    final values = preferences.getStringList(_key);

    final loaded = values == null || values.isEmpty
        ? List<StarterChapter>.from(widget.project.chapters)
        : values
            .map((value) {
              try {
                final decoded = jsonDecode(value) as Map<String, dynamic>;
                return StarterChapter.fromJson(decoded);
              } catch (_) {
                return null;
              }
            })
            .whereType<StarterChapter>()
            .toList();

    if (mounted) {
      setState(() {
        chapters = loaded.isEmpty
            ? List<StarterChapter>.from(widget.project.chapters)
            : loaded;
        if (chapters.isNotEmpty) {
          selectedIndex ??= 0;
        } else {
          selectedIndex = null;
        }
      });
      if (loaded.isNotEmpty) {
        await _persist();
      }
    }
  }

  Future<void> _persist() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _key,
      chapters.map((chapter) => jsonEncode(chapter.toJson())).toList(),
    );
  }

  Future<void> _saveChap(
    String title,
    String prompt, [
    StarterChapter? existing,
  ]) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      return;
    }

    final chapter = StarterChapter(
      title: trimmedTitle,
      prompt: prompt.trim(),
      status: existing?.status ?? 'Active',
      scenes: existing?.scenes ?? const [],
      linkedChapterIds: existing?.linkedChapterIds ?? const [],
    );

    setState(() {
      if (existing == null) {
        chapters.add(chapter);
        selectedIndex = chapters.length - 1;
      } else {
        final index = chapters.indexOf(existing);
        if (index >= 0) {
          chapters[index] = chapter;
          selectedIndex = index;
        }
      }
    });

    await _persist();
  }

  Future<void> _toggleArchive(int index) async {
    if (index < 0 || index >= chapters.length) {
      return;
    }

    final nextStatus = chapters[index].isArchived ? 'Active' : 'Archived';
    setState(() {
      chapters[index] = chapters[index].copyWith(status: nextStatus);
    });
    await _persist();
  }

  Future<void> _addSceneToChapter(int chapterIndex, String name) async {
    if (chapterIndex < 0 || chapterIndex >= chapters.length) {
      return;
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final current = chapters[chapterIndex].scenes;
    setState(() {
      chapters[chapterIndex] = chapters[chapterIndex].copyWith(
        scenes: [...current, trimmed],
      );
    });
    await _persist();
  }

  Future<void> _removeChapter(int index) async {
    if (index < 0 || index >= chapters.length) {
      return;
    }

    setState(() {
      chapters.removeAt(index);
      if (chapters.isEmpty) {
        selectedIndex = null;
      } else if (selectedIndex != null && selectedIndex! >= chapters.length) {
        selectedIndex = chapters.length - 1;
      }
    });

    await _persist();
  }

  List<StarterChapter> get activeChapters =>
      chapters.where((chapter) => !chapter.isArchived).toList();

  List<StarterChapter> get archivedChapters =>
      chapters.where((chapter) => chapter.isArchived).toList();

  Future<void> _openEditor([StarterChapter? existing]) async {
    final titleController =
        TextEditingController(text: existing?.title ?? 'New chapter');
    final promptController =
        TextEditingController(text: existing?.prompt ?? '');

    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'New chapter' : 'Edit chapter'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('chapter-title-field'),
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Chapter title'),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('chapter-prompt-field'),
                controller: promptController,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Chapter prompt',
                  hintText:
                      'What changes, turns, or stakes define this chapter?',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (accepted == true) {
      await _saveChap(titleController.text, promptController.text, existing);
    }
  }

  @override
  Widget build(BuildContext context) => _StudioPage(
        title: 'Chapters',
        subtitle: 'Track the structure, momentum, and purpose of each chapter.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Chapter'),
              ),
            ),
            const SizedBox(height: 18),
            if (chapters.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No chapters yet',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 8),
                      Text('Create the first chapter to map the story arc.'),
                    ],
                  ),
                ),
              )
            else ...[
              for (var index = 0; index < chapters.length; index++)
                if (!chapters[index].isArchived)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: selectedIndex == index
                        ? Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withValues(alpha: 0.14)
                        : null,
                    child: ListTile(
                      onTap: () => setState(() => selectedIndex = index),
                      leading: CircleAvatar(
                        child: Text('${index + 1}'),
                      ),
                      title: Text(chapters[index].title),
                      subtitle: Text(
                        chapters[index].prompt.isEmpty
                            ? 'No chapter goal yet.'
                            : chapters[index].prompt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit chapter',
                            onPressed: () => _openEditor(chapters[index]),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: chapters[index].isArchived
                                ? 'Reactivate chapter'
                                : 'Archive chapter',
                            onPressed: () => _toggleArchive(index),
                            icon: Icon(
                              chapters[index].isArchived
                                  ? Icons.unarchive_outlined
                                  : Icons.archive_outlined,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Delete chapter',
                            onPressed: () => _removeChapter(index),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  ),
              if (archivedChapters.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Archived',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                for (var index = 0; index < chapters.length; index++)
                  if (chapters[index].isArchived)
                    Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.archive_outlined),
                        ),
                        title: Text(
                          chapters[index].title,
                          style: const TextStyle(
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        subtitle: Text(
                          chapters[index].prompt.isEmpty
                              ? 'Archived chapter.'
                              : chapters[index].prompt,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Reactivate chapter',
                              onPressed: () => _toggleArchive(index),
                              icon: const Icon(Icons.unarchive_outlined),
                            ),
                            IconButton(
                              tooltip: 'Delete chapter',
                              onPressed: () => _removeChapter(index),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
            ],
            if (selectedIndex != null &&
                selectedIndex! < chapters.length &&
                !chapters[selectedIndex!].isArchived)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chapters[selectedIndex!].title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        chapters[selectedIndex!].prompt.isEmpty
                            ? 'This chapter is ready for a clear objective and turning point.'
                            : chapters[selectedIndex!].prompt,
                      ),
                      const SizedBox(height: 12),
                      if (chapters[selectedIndex!].scenes.isNotEmpty) ...[
                        const Text(
                          'Scenes',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: chapters[selectedIndex!]
                              .scenes
                              .map(
                                (scene) => Chip(label: Text(scene)),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (chapters[selectedIndex!]
                          .linkedChapterIds
                          .isNotEmpty) ...[
                        const Text(
                          'Linked chapters',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: chapters[selectedIndex!]
                              .linkedChapterIds
                              .map(
                                (id) => Chip(
                                  label: Text(
                                    id.startsWith('chapter-') ? id : id,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                labelText: 'Add scene',
                              ),
                              onSubmitted: (value) {
                                _addSceneToChapter(selectedIndex!, value);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: () =>
                                _openEditor(chapters[selectedIndex!]),
                            icon: const Icon(Icons.edit_note_rounded),
                            label: const Text('Edit chapter'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
}

class LegacyStoryCodexView extends StatefulWidget {
  const LegacyStoryCodexView({
    super.key,
    required this.projectId,
  });

  final String projectId;

  @override
  State<LegacyStoryCodexView> createState() => _LegacyStoryCodexViewState();
}

class _LegacyStoryCodexViewState extends State<LegacyStoryCodexView> {
  final TextEditingController searchController = TextEditingController();
  List<StoryCodexEntry> entries = [];
  bool loading = true;

  Future<void> _load() async {
    final loaded = await StoryCodexStore(projectId: widget.projectId).load();
    if (!mounted) {
      return;
    }
    setState(() {
      entries = loaded;
      loading = false;
    });
  }

  Future<void> _save() async {
    await StoryCodexStore(projectId: widget.projectId).save(entries);
  }

  Future<void> _toggleArchive(StoryCodexEntry entry) async {
    final index = entries.indexWhere((item) => item.id == entry.id);
    if (index < 0) {
      return;
    }
    setState(() {
      entries[index] = entries[index].copyWith(
        status: entry.status == 'Archived' ? 'Active' : 'Archived',
      );
    });
    await _save();
  }

  Future<void> _edit([StoryCodexEntry? existing]) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final summaryController =
        TextEditingController(text: existing?.summary ?? '');
    final aliasesController =
        TextEditingController(text: existing?.aliases.join(', ') ?? '');
    final tagsController =
        TextEditingController(text: existing?.tags.join(', ') ?? '');
    final mentionsController =
        TextEditingController(text: existing?.mentions.join(', ') ?? '');
    final relationshipsController = TextEditingController(
      text: existing == null
          ? ''
          : existing.relationships.entries
              .map((entry) => '${entry.key}: ${entry.value}')
              .join('\n'),
    );
    var type = existing?.type ?? StoryCodexType.character;
    var status = existing?.status ?? 'Active';

    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add entry' : 'Edit entry'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<StoryCodexType>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: StoryCodexType.values
                        .map((item) => DropdownMenuItem(
                            value: item, child: Text(item.label)))
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => type = value ?? type),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: aliasesController,
                    decoration: const InputDecoration(
                      labelText: 'Aliases / nicknames',
                      hintText: 'Mara, The River Witch',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: 'Active', child: Text('Active')),
                      DropdownMenuItem(
                          value: 'Archived', child: Text('Archived')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => status = value ?? 'Active'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: summaryController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: 'Summary'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tagsController,
                    decoration: const InputDecoration(
                      labelText: 'Tags',
                      hintText: 'magic, protagonist, secret',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: mentionsController,
                    decoration: const InputDecoration(
                      labelText: 'Mention references',
                      hintText: 'scene-1, scene-7',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: relationshipsController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Relationships',
                      hintText: 'mentor: Edrin Vale',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (titleController.text.trim().isNotEmpty) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (accepted == true) {
      final nextEntry = StoryCodexEntry(
        id: existing?.id ?? 'codex-${DateTime.now().microsecondsSinceEpoch}',
        title: titleController.text.trim(),
        type: type,
        aliases: aliasesController.text
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(),
        summary: summaryController.text.trim(),
        tags: tagsController.text
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(),
        mentions: mentionsController.text
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(),
        relationships: {
          for (final line in relationshipsController.text
              .split('\n')
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty))
            if (line.contains(':'))
              line.split(':').first.trim():
                  line.split(':').sublist(1).join(':').trim(),
        },
        status: status,
      );

      setState(() {
        final index = entries.indexWhere((item) => item.id == nextEntry.id);
        index < 0 ? entries.add(nextEntry) : entries[index] = nextEntry;
      });
      await _save();
    }

    titleController.dispose();
    summaryController.dispose();
    aliasesController.dispose();
    tagsController.dispose();
    mentionsController.dispose();
    relationshipsController.dispose();
  }

  Future<void> _delete(StoryCodexEntry entry) async {
    setState(() => entries.removeWhere((item) => item.id == entry.id));
    await _save();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = searchController.text.trim().toLowerCase();
    final activeEntries = entries.where((entry) => !entry.isArchived).toList();
    final archivedEntries = entries.where((entry) => entry.isArchived).toList();
    final filtered = query.isEmpty
        ? activeEntries
        : activeEntries.where((entry) {
            final haystack = [
              entry.title,
              entry.type.label,
              entry.summary,
              ...entry.aliases,
              ...entry.tags,
              ...entry.relationships.values,
              ...entry.mentions,
            ].join(' ').toLowerCase();
            return haystack.contains(query);
          }).toList();

    final activeWidgets = <Widget>[];
    if (filtered.isEmpty && activeEntries.isEmpty && archivedEntries.isEmpty) {
      activeWidgets.add(
        const _EmptyState(
          message:
              'No codex entries match your search. Add a new record to begin building the world.',
        ),
      );
    } else if (filtered.isEmpty) {
      activeWidgets.add(
        const _EmptyState(
          message: 'No active codex entries match your search.',
        ),
      );
    } else {
      activeWidgets.addAll(
        filtered.map(
          (entry) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(10),
                        ),
                      ),
                      child: Icon(
                        Icons.auto_stories_rounded,
                        color: Theme.of(context).colorScheme.onSurface,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry.type.label,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          tooltip: 'Edit',
                          onPressed: () => _edit(entry),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: entry.isArchived ? 'Reactivate' : 'Archive',
                          onPressed: () => _toggleArchive(entry),
                          icon: Icon(
                            entry.isArchived
                                ? Icons.unarchive_outlined
                                : Icons.archive_outlined,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          onPressed: () => _delete(entry),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ],
                ),
                if (entry.summary.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(entry.summary),
                ],
                if (entry.aliases.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final alias in entry.aliases)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            alias,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ],
                if (entry.visibleRelationships(entries).isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Relationships',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...entry.visibleRelationships(entries).entries.map(
                        (relationship) => Text(
                          '- ${relationship.key}: ${relationship.value}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                ],
                if (entry.visibleMentions(entries).isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Mentioned in',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: entry
                        .visibleMentions(entries)
                        .map(
                          (mention) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              mention,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final archivedWidgets = <Widget>[];
    if (archivedEntries.isNotEmpty) {
      archivedWidgets.add(const SizedBox(height: 16));
      archivedWidgets.add(
        Text(
          'Archived',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
        ),
      );
      archivedWidgets.add(const SizedBox(height: 8));
      archivedWidgets.addAll(
        archivedEntries.map(
          (entry) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        style: const TextStyle(
                          decoration: TextDecoration.lineThrough,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.type.label,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      tooltip: 'Reactivate',
                      onPressed: () => _toggleArchive(entry),
                      icon: const Icon(Icons.unarchive_outlined),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      onPressed: () => _delete(entry),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: _StudioPage(
        title: 'Story Codex',
        subtitle:
            'Search world and character knowledge across scenes, lore, and timeline events.',
        action: FilledButton.icon(
          onPressed: loading ? null : () => _edit(),
          icon: const Icon(Icons.add),
          label: const Text('Add entry'),
        ),
        child: loading
            ? const LinearProgressIndicator()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    key: const Key('story-codex-search-field'),
                    controller: searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Search world and character knowledge',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...activeWidgets,
                  ...archivedWidgets,
                ],
              ),
      ),
    );
  }
}

class _LegacyCharacterBoardView extends StatefulWidget {
  const _LegacyCharacterBoardView({
    required this.project,
  });

  final StarterProject project;

  @override
  State<_LegacyCharacterBoardView> createState() =>
      _LegacyCharacterBoardViewState();
}

class _LegacyCharacterBoardViewState extends State<_LegacyCharacterBoardView> {
  final Map<String, String> _statusByName = {};

  List<_CharacterCardData> get _cards {
    final cards = <_CharacterCardData>[];
    for (var index = 0;
        index < widget.project.characterSheets.length;
        index++) {
      final sheet = widget.project.characterSheets[index];
      final status = _statusByName[sheet.name] ?? 'Active';
      cards.add(
        _CharacterCardData(
          id: '${sheet.name}-$index',
          name: sheet.name,
          role: sheet.role,
          category: index == 0
              ? 'Protagonist'
              : index == 1
                  ? 'Primary Opposition'
                  : 'Key Ally',
          status: status,
        ),
      );
    }
    return cards;
  }

  List<_CharacterCardData> get _activeCards =>
      _cards.where((card) => card.status == 'Active').toList();

  List<_CharacterCardData> get _archivedCards =>
      _cards.where((card) => card.status == 'Archived').toList();

  void _toggleArchive(_CharacterCardData card) {
    setState(() {
      final nextStatus =
          _statusByName[card.name] == 'Archived' ? 'Active' : 'Archived';
      _statusByName[card.name] = nextStatus;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _StudioPage(
      title: 'Characters',
      subtitle:
          'Build the cast, pressure, and emotional stakes around every scene.',
      action: FilledButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add cast'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cast',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 14),
          if (_activeCards.isEmpty)
            const _EmptyState(
              message:
                  'No active cast members. Reactivate a card to bring it back into play.',
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _activeCards
                  .map((card) => _CharacterCard(
                        card: card,
                        onArchiveToggle: () => _toggleArchive(card),
                      ))
                  .toList(),
            ),
          if (_archivedCards.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Archived',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _archivedCards
                  .map((card) => _CharacterCard(
                        card: card,
                        isArchived: true,
                        onArchiveToggle: () => _toggleArchive(card),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _CharacterCardData {
  const _CharacterCardData({
    required this.id,
    required this.name,
    required this.role,
    required this.category,
    required this.status,
  });

  final String id;
  final String name;
  final String role;
  final String category;
  final String status;
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({
    required this.card,
    required this.onArchiveToggle,
    this.isArchived = false,
  });

  final _CharacterCardData card;
  final VoidCallback onArchiveToggle;
  final bool isArchived;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          decoration: isArchived ? TextDecoration.lineThrough : null,
        );

    return Container(
      width: 260,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isArchived
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  card.name,
                  style: titleStyle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              card.category,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            card.role,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArchived ? 'Archived' : 'Active',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
              IconButton(
                tooltip: isArchived ? 'Reactivate' : 'Archive',
                onPressed: onArchiveToggle,
                icon: Icon(
                  isArchived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class RecordStudioView extends StatefulWidget {
  const RecordStudioView({
    super.key,
    required this.collection,
    required this.title,
    required this.subtitle,
    required this.categories,
    this.seedRecords = const [],
  });

  final String collection;
  final String title;
  final String subtitle;
  final List<String> categories;
  final List<StudioRecord> seedRecords;

  @override
  State<RecordStudioView> createState() => _RecordStudioViewState();
}

class _RecordStudioViewState extends State<RecordStudioView> {
  List<StudioRecord> records = [];
  bool loading = true;

  StudioRecordStore get store => StudioRecordStore(widget.collection);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saved = await store.load();
    if (mounted) {
      setState(() {
        records = saved.isEmpty ? [...widget.seedRecords] : saved;
        loading = false;
      });
      if (saved.isEmpty && records.isNotEmpty) {
        await store.save(records);
      }
    }
  }

  Future<void> _edit([StudioRecord? existing]) async {
    final title = TextEditingController(text: existing?.title ?? '');
    final details = TextEditingController(text: existing?.details ?? '');
    var category = existing?.category ?? widget.categories.first;
    var status = existing?.status ?? 'Active';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add ${widget.title}' : 'Edit entry'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  items: widget.categories
                      .map((value) =>
                          DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: (value) => setDialogState(
                      () => category = value ?? widget.categories.first),
                  decoration: const InputDecoration(labelText: 'Type'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  items: const [
                    DropdownMenuItem(value: 'Active', child: Text('Active')),
                    DropdownMenuItem(
                        value: 'Archived', child: Text('Archived')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => status = value ?? 'Active'),
                  decoration: const InputDecoration(labelText: 'Status'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: details,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Details'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (title.text.trim().isNotEmpty) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true) {
      final record = StudioRecord(
        id: existing?.id ??
            '${widget.collection}_${DateTime.now().microsecondsSinceEpoch}',
        title: title.text.trim(),
        category: category,
        details: details.text.trim(),
        status: status,
      );
      setState(() {
        final index = records.indexWhere((item) => item.id == record.id);
        index < 0 ? records.add(record) : records[index] = record;
      });
      await store.save(records);
    }
    title.dispose();
    details.dispose();
  }

  Future<void> _delete(StudioRecord record) async {
    setState(() => records.removeWhere((item) => item.id == record.id));
    await store.save(records);
  }

  @override
  Widget build(BuildContext context) {
    final activeRecords =
        records.where((record) => !record.isArchived).toList();
    final archivedRecords =
        records.where((record) => record.isArchived).toList();

    if (loading) {
      return _StudioPage(
        title: widget.title,
        subtitle: widget.subtitle,
        action: FilledButton.icon(
          onPressed: null,
          icon: const Icon(Icons.add),
          label: const Text('Add'),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: const LinearProgressIndicator(),
        ),
      );
    }

    if (records.isEmpty) {
      return _StudioPage(
        title: widget.title,
        subtitle: widget.subtitle,
        action: FilledButton.icon(
          onPressed: () => _edit(),
          icon: const Icon(Icons.add),
          label: const Text('Add'),
        ),
        child: const _EmptyState(
          message: 'Nothing here yet. Add the first entry.',
        ),
      );
    }

    final activeList = activeRecords
        .map(
          (record) => Container(
            key: ValueKey(record.id),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
                child: Icon(
                  Icons.auto_stories_outlined,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              title: Text(record.title),
              subtitle: Text(
                '${record.category} | ${record.details}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    tooltip: 'Edit',
                    onPressed: () => _edit(record),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: record.isArchived ? 'Reactivate' : 'Archive',
                    onPressed: () async {
                      final nextStatus =
                          record.status == 'Archived' ? 'Active' : 'Archived';
                      final updated = record.copyWith(status: nextStatus);
                      setState(() {
                        final index =
                            records.indexWhere((item) => item.id == record.id);
                        if (index >= 0) {
                          records[index] = updated;
                        }
                      });
                      await store.save(records);
                    },
                    icon: Icon(
                      record.isArchived
                          ? Icons.unarchive_outlined
                          : Icons.archive_outlined,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: () => _delete(record),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          ),
        )
        .toList();

    final archivedList = archivedRecords
        .map(
          (record) => Container(
            key: ValueKey('${record.id}-archived'),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
                child: Icon(
                  Icons.archive_outlined,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              title: Text(
                record.title,
                style: const TextStyle(decoration: TextDecoration.lineThrough),
              ),
              subtitle: Text(
                '${record.category} | ${record.details}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    tooltip: 'Reactivate',
                    onPressed: () async {
                      final updated = record.copyWith(status: 'Active');
                      setState(() {
                        final index =
                            records.indexWhere((item) => item.id == record.id);
                        if (index >= 0) {
                          records[index] = updated;
                        }
                      });
                      await store.save(records);
                    },
                    icon: const Icon(Icons.unarchive_outlined),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: () => _delete(record),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          ),
        )
        .toList();

    return _StudioPage(
      title: widget.title,
      subtitle: widget.subtitle,
      action: FilledButton.icon(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...activeList,
          if (archivedList.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Archived',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white60,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const SizedBox(height: 8),
            ...archivedList,
          ],
        ],
      ),
    );
  }
}

Future<void> _defaultSettingsLogout() async {}

class SettingsStudioView extends StatefulWidget {
  const SettingsStudioView({
    super.key,
    this.selection,
    this.onSelectionChanged,
    this.themeId = 'light',
    this.accentId = 'default',
    required this.onThemeChanged,
    this.onLogout = _defaultSettingsLogout,
    this.versionChecker,
    this.currentVersion,
  });

  final ThemeSelection? selection;
  final ValueChanged<ThemeSelection>? onSelectionChanged;
  final String themeId;
  final String accentId;
  final void Function(String themeId, String accentId) onThemeChanged;
  final Future<void> Function() onLogout;
  final AppVersionChecker? versionChecker;
  final String? currentVersion;

  @override
  State<SettingsStudioView> createState() => _SettingsStudioViewState();
}

class _ThemeOption {
  const _ThemeOption({
    required this.id,
    required this.name,
    required this.description,
  });

  final String id;
  final String name;
  final String description;
}

class _SettingsStudioViewState extends State<SettingsStudioView> {
  static const _autosaveKey = 'author_studio.settings.autosave';
  static const _focusKey = 'author_studio.settings.focus_defaults';
  static const _profileNameKey = 'author_studio.profile.name';
  static const _profileBioKey = 'author_studio.profile.bio';
  static const _profileFocusKey = 'author_studio.profile.focus';
  static const _profileAvatarKey = 'author_studio.profile.avatar_path';
  static const _profileWebsiteKey = 'author_studio.profile.website';
  static const _profileXKey = 'author_studio.profile.x';
  static const _profileGoodreadsKey = 'author_studio.profile.goodreads';
  static const _profileNewsletterKey = 'author_studio.profile.newsletter';
  static const _profilePublicKey = 'author_studio.profile.public';
  static const _profileRequireReauthKey =
      'author_studio.profile.require_reauth';
  static const _profileSecureSessionsKey =
      'author_studio.profile.secure_sessions';
  static const _profileSyncAlertsKey = 'author_studio.profile.sync_alerts';
  static const _profileSectionId = 'profile';
  static const _appearanceSectionId = 'appearance';
  static const _accountSectionId = 'account';
  static const _themeOptions = <_ThemeOption>[
    _ThemeOption(
        id: 'light',
        name: 'Light',
        description: 'Bright and comfortable for daytime writing.'),
    _ThemeOption(
        id: 'dark',
        name: 'Dark',
        description: 'Low-glare and focused for evening writing.'),
  ];

  /// The built-in theme registry, consulted only to derive a mode from a bare
  /// theme id on the legacy callback path. The Theme Engine path receives a
  /// fully-formed [ThemeSelection] from the shell and never needs this.
  static final ThemeRegistry _themeRegistry = ThemeRegistry.standard();

  String selectedTheme = 'light';
  String selectedAccent = 'default';
  AuthorOsThemeMode selectedMode = AuthorOsThemeMode.light;
  ThemeAccessibility selectedAccessibility = ThemeAccessibility.none;
  bool autosave = true;
  bool focusDefaults = false;
  String writerName = 'Ari Rowan';
  String writingFocus = 'Fantasy romance and literary thrillers';
  String bio =
      'I write character-led stories with strong atmosphere, sharp stakes, and hopeful endings.';
  String avatarPath = '';
  String website = '';
  String xHandle = '';
  String goodreads = '';
  String newsletter = '';
  bool publicProfile = true;
  bool requireReauth = true;
  bool secureSessions = false;
  bool syncAlerts = true;
  bool updateAvailable = false;
  String currentAppVersion = '1.0.0+1';
  String latestAppVersion = '1.0.0+1';
  late final Map<String, bool> _expandedSections;

  late final TextEditingController _nameController;
  late final TextEditingController _focusController;
  late final TextEditingController _bioController;
  late final TextEditingController _websiteController;
  late final TextEditingController _xController;
  late final TextEditingController _goodreadsController;
  late final TextEditingController _newsletterController;

  bool get _usesThemeEngineSelection =>
      widget.selection != null && widget.onSelectionChanged != null;

  @override
  void initState() {
    super.initState();
    _syncSelectionFromWidget();
    _expandedSections = {
      _profileSectionId: false,
      _appearanceSectionId: false,
      _accountSectionId: false,
    };
    _nameController = TextEditingController(text: writerName);
    _focusController = TextEditingController(text: writingFocus);
    _bioController = TextEditingController(text: bio);
    _websiteController = TextEditingController(text: website);
    _xController = TextEditingController(text: xHandle);
    _goodreadsController = TextEditingController(text: goodreads);
    _newsletterController = TextEditingController(text: newsletter);
    _load();
    _checkForAppUpdate();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _focusController.dispose();
    _bioController.dispose();
    _websiteController.dispose();
    _xController.dispose();
    _goodreadsController.dispose();
    _newsletterController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SettingsStudioView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selection != widget.selection ||
        oldWidget.themeId != widget.themeId ||
        oldWidget.accentId != widget.accentId) {
      _syncSelectionFromWidget();
    }
  }

  void _syncSelectionFromWidget() {
    final selection = widget.selection;
    if (selection != null) {
      selectedTheme = selection.themeId;
      selectedAccent = selection.accentId;
      selectedMode = selection.mode;
      selectedAccessibility = selection.accessibility;
      return;
    }
    selectedTheme = widget.themeId;
    selectedAccent = widget.accentId;
    selectedMode = _themeRegistry.byId(widget.themeId).defaultMode;
    selectedAccessibility = ThemeAccessibility.none;
  }

  ThemeSelection _currentSelection() => widget.selection?.copyWith(
        themeId: selectedTheme,
        accentId: selectedAccent,
        mode: selectedMode,
        accessibility: selectedAccessibility,
      ) ??
      ThemeSelection(
        themeId: selectedTheme,
        mode: selectedMode,
        accentId: selectedAccent,
        accessibility: selectedAccessibility,
      );

  void _applySelection(ThemeSelection selection) {
    setState(() {
      selectedTheme = selection.themeId;
      selectedAccent = selection.accentId;
      selectedMode = selection.mode;
      selectedAccessibility = selection.accessibility;
    });
    widget.onSelectionChanged?.call(selection);
    if (!_usesThemeEngineSelection) {
      widget.onThemeChanged(selection.themeId, selection.accentId);
    }
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        autosave = preferences.getBool(_autosaveKey) ?? true;
        focusDefaults = preferences.getBool(_focusKey) ?? false;
        writerName = preferences.getString(_profileNameKey) ?? writerName;
        writingFocus = preferences.getString(_profileFocusKey) ?? writingFocus;
        bio = preferences.getString(_profileBioKey) ?? bio;
        avatarPath = preferences.getString(_profileAvatarKey) ?? avatarPath;
        website = preferences.getString(_profileWebsiteKey) ?? website;
        xHandle = preferences.getString(_profileXKey) ?? xHandle;
        goodreads = preferences.getString(_profileGoodreadsKey) ?? goodreads;
        newsletter = preferences.getString(_profileNewsletterKey) ?? newsletter;
        publicProfile = preferences.getBool(_profilePublicKey) ?? publicProfile;
        requireReauth =
            preferences.getBool(_profileRequireReauthKey) ?? requireReauth;
        secureSessions =
            preferences.getBool(_profileSecureSessionsKey) ?? secureSessions;
        syncAlerts = preferences.getBool(_profileSyncAlertsKey) ?? syncAlerts;
        _nameController.text = writerName;
        _focusController.text = writingFocus;
        _bioController.text = bio;
        _websiteController.text = website;
        _xController.text = xHandle;
        _goodreadsController.text = goodreads;
        _newsletterController.text = newsletter;
      });
    }
  }

  Future<void> _checkForAppUpdate() async {
    // The version feed below advertises desktop installers. The browser build
    // is whatever kjii.info last served, so on the web there is no newer
    // download to offer and no reason to make the cross-origin request.
    if (kIsWeb && widget.versionChecker == null) {
      return;
    }
    final currentVersion = widget.currentVersion ??
        (await PackageInfo.fromPlatform())
            .version; // keep the real installed version when not overridden
    final checker = widget.versionChecker ??
        AppVersionChecker(
          latestVersionUrl:
              'https://indiauthors.com/author-studio/latest-version.json',
        );

    final result = await checker.checkForUpdate(currentVersion: currentVersion);

    if (!mounted) {
      return;
    }

    setState(() {
      currentAppVersion = result.currentVersion;
      latestAppVersion = result.latestVersion;
      updateAvailable = result.updateAvailable;
    });
  }

  Future<void> _saveProfile() async {
    final preferences = await SharedPreferences.getInstance();
    writerName = _nameController.text.trim().isEmpty
        ? 'Ari Rowan'
        : _nameController.text.trim();
    writingFocus = _focusController.text.trim().isEmpty
        ? 'Fantasy romance and literary thrillers'
        : _focusController.text.trim();
    bio = _bioController.text.trim().isEmpty
        ? 'I write character-led stories with strong atmosphere, sharp stakes, and hopeful endings.'
        : _bioController.text.trim();
    website = _websiteController.text.trim();
    xHandle = _xController.text.trim();
    goodreads = _goodreadsController.text.trim();
    newsletter = _newsletterController.text.trim();

    await preferences.setString(_profileNameKey, writerName);
    await preferences.setString(_profileFocusKey, writingFocus);
    await preferences.setString(_profileBioKey, bio);
    await preferences.setString(_profileAvatarKey, avatarPath);
    await preferences.setString(_profileWebsiteKey, website);
    await preferences.setString(_profileXKey, xHandle);
    await preferences.setString(_profileGoodreadsKey, goodreads);
    await preferences.setString(_profileNewsletterKey, newsletter);
    await preferences.setBool(_profilePublicKey, publicProfile);
    await preferences.setBool(_profileRequireReauthKey, requireReauth);
    await preferences.setBool(_profileSecureSessionsKey, secureSessions);
    await preferences.setBool(_profileSyncAlertsKey, syncAlerts);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pickAvatar() async {
    final result = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
            label: 'Images', extensions: ['jpg', 'jpeg', 'png', 'webp'])
      ],
    );
    if (result == null) {
      return;
    }

    setState(() => avatarPath = result.path);
    await _saveProfile();
  }

  Future<void> _set(String key, bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(key, value);
  }

  Future<void> _handleGoogleSignIn() async {
    final success = await AppSupabase.signInWithGoogle();
    if (!mounted) {
      return;
    }

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Google sign-in was cancelled or unavailable.')),
      );
      return;
    }

    setState(() {});

    // Drain anything saved while signed out, and pull down whatever the
    // author's other devices have. Sign-in is the moment a fresh install has
    // an empty roster and the server has a full one, so it is the one trigger
    // where the download matters most.
    await buildSyncEngine().sync();
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text(
              'Google sign-in succeeded. Your projects can sync to Supabase.')),
    );
  }

  Future<void> _handleUpdateNow() async {
    if (kIsWeb) {
      // There is no installer to run and no process to restart in a browser:
      // reloading the tab fetches whatever build the site is now serving.
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Update now'),
          content: const Text(
            'AuthorOS updates itself on the web. Reload this page to load the '
            'latest build — your work stays saved in this browser.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update now'),
        content: const Text(
          'This will restart the app so the latest build is loaded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Update now'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      final executable = Platform.resolvedExecutable;
      if (executable.isNotEmpty) {
        Process.start(executable, [], mode: ProcessStartMode.detached);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to restart the app from this session.'),
          ),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Restarting app to apply the update...'),
        ),
      );
    }

    Future.delayed(const Duration(milliseconds: 250), () {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        exit(0);
      }
      SystemNavigator.pop();
    });
  }

  Future<void> _handleSignOut() async {
    await AppSupabase.signOut();
    if (!mounted) {
      return;
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Signed out of Supabase.')),
    );
  }

  Future<void> _confirmAndLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text(
          'Are you sure you want to log out?\n\nYour projects, manuscripts, chapters, and profile data will remain saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await widget.onLogout();
  }

  void _toggleSection(String sectionId) {
    setState(() {
      _expandedSections[sectionId] = !(_expandedSections[sectionId] ?? false);
    });
  }

  Widget _buildCollapsibleSection({
    required String sectionId,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final expanded = _expandedSections[sectionId] ?? false;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Semantics(
            button: true,
            toggled: expanded,
            child: ListTile(
              onTap: () => _toggleSection(sectionId),
              leading: Icon(icon),
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              trailing: Icon(
                expanded
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.keyboard_arrow_right_rounded,
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: child,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatarPreview({bool compact = false}) {
    final avatarContent = LocalImage(
      path: avatarPath,
      width: double.infinity,
      height: double.infinity,
      fallback: Container(
        alignment: Alignment.center,
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Text(
          writerName.isNotEmpty ? writerName[0].toUpperCase() : 'A',
          style: TextStyle(
            fontSize: compact ? 26 : 36,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );

    return Container(
      width: compact ? 72 : 120,
      height: compact ? 72 : 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 22 : 30),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.55),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: avatarContent),
          Positioned(
            right: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surface
                    .withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.photo_camera_outlined, size: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePage() {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Profile',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Writer profile',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: _pickAvatar,
                      child: _buildAvatarPreview(),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Author name',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => _saveProfile(),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _focusController,
                            decoration: const InputDecoration(
                              labelText: 'Writing focus',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => _saveProfile(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.image_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                avatarPath.isEmpty
                                    ? 'No image selected yet'
                                    : 'Avatar ready for preview',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _pickAvatar,
                      icon: const Icon(Icons.upload_file_outlined),
                      label: const Text('Upload avatar'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bioController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _saveProfile(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Social links',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _websiteController,
                  decoration: const InputDecoration(
                    labelText: 'Website',
                    prefixIcon: Icon(Icons.link_outlined),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _saveProfile(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _xController,
                  decoration: const InputDecoration(
                    labelText: 'X / Twitter',
                    prefixIcon: Icon(Icons.alternate_email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _saveProfile(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _goodreadsController,
                  decoration: const InputDecoration(
                    labelText: 'Goodreads',
                    prefixIcon: Icon(Icons.book_outlined),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _saveProfile(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _newsletterController,
                  decoration: const InputDecoration(
                    labelText: 'Newsletter / Substack',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _saveProfile(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Public author preview',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildAvatarPreview(compact: true),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  writerName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  writingFocus,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        bio,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (website.isNotEmpty)
                            const Chip(label: Text('Website')),
                          if (xHandle.isNotEmpty) const Chip(label: Text('X')),
                          if (goodreads.isNotEmpty)
                            const Chip(label: Text('Goodreads')),
                          if (newsletter.isNotEmpty)
                            const Chip(label: Text('Newsletter')),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSecurityPage() {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Account Security',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _confirmAndLogout,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Log out'),
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).colorScheme.errorContainer,
                      foregroundColor:
                          Theme.of(context).colorScheme.onErrorContainer,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              const ListTile(
                leading: Icon(Icons.shield_outlined),
                title: Text('Account Security'),
                subtitle: Text(
                    'Protect your author profile, exports, and sync logs.'),
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: publicProfile,
                onChanged: (value) {
                  setState(() => publicProfile = value);
                  _saveProfile();
                },
                title: const Text('Public profile visibility'),
                subtitle: const Text(
                    'Allow your author profile to appear in shared previews.'),
                secondary: const Icon(Icons.public_outlined),
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: requireReauth,
                onChanged: (value) {
                  setState(() => requireReauth = value);
                  _saveProfile();
                },
                title: const Text('Require re-auth for sensitive actions'),
                subtitle: const Text(
                    'Protect exports, sync actions, and account changes.'),
                secondary: const Icon(Icons.security_outlined),
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: secureSessions,
                onChanged: (value) {
                  setState(() => secureSessions = value);
                  _saveProfile();
                },
                title: const Text('Secure device sessions'),
                subtitle: const Text(
                    'Keep app sessions locked when the screen is idle.'),
                secondary: const Icon(Icons.lock_clock_outlined),
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: syncAlerts,
                onChanged: (value) {
                  setState(() => syncAlerts = value);
                  _saveProfile();
                },
                title: const Text('Sync change alerts'),
                subtitle: const Text(
                    'Notify me when project changes are saved or synced.'),
                secondary: const Icon(Icons.notifications_active_outlined),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppearancePage() {
    if (_usesThemeEngineSelection) {
      final scope = StudioThemeScope.maybeOf(context);
      final theme = Theme.of(context);
      final surfaceContainer =
          scope?.color(ThemeColorRef.surfaceContainer) ??
              theme.colorScheme.surfaceContainerHighest;
      final primary = scope?.color(ThemeColorRef.primary) ?? theme.colorScheme.primary;
      final onSurface =
          scope?.color(ThemeColorRef.onSurface) ?? theme.colorScheme.onSurface;
      final onSurfaceVariant = scope?.color(ThemeColorRef.onSurfaceVariant) ??
          theme.colorScheme.onSurfaceVariant;
      final outline =
          scope?.color(ThemeColorRef.outlineVariant) ?? theme.colorScheme.outlineVariant;

      Widget modeCard(_ThemeOption option, AuthorOsThemeMode mode) {
        final isSelected = selectedMode == mode;
        final targetThemeId = switch (mode) {
          AuthorOsThemeMode.system => selectedTheme,
          AuthorOsThemeMode.light => 'light',
          AuthorOsThemeMode.dark => 'dark',
        };
        final selection = _currentSelection().copyWith(
          themeId: targetThemeId,
          mode: mode,
        );
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _applySelection(selection),
          child: Container(
            width: 170,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? primary.withValues(alpha: 0.16) : surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? primary : outline,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  option.description,
                  style: TextStyle(
                    color: onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Theme mode',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      modeCard(
                        const _ThemeOption(
                          id: 'system',
                          name: 'System',
                          description: 'Follow the host brightness when possible.',
                        ),
                        AuthorOsThemeMode.system,
                      ),
                      modeCard(
                        const _ThemeOption(
                          id: 'light',
                          name: 'Light',
                          description: 'Bright and comfortable for daytime writing.',
                        ),
                        AuthorOsThemeMode.light,
                      ),
                      modeCard(
                        const _ThemeOption(
                          id: 'dark',
                          name: 'Dark',
                          description: 'Low-glare and focused for evening writing.',
                        ),
                        AuthorOsThemeMode.dark,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Accessibility',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: selectedAccessibility.highContrast,
                    onChanged: (value) => _applySelection(
                      _currentSelection().copyWith(
                        accessibility: selectedAccessibility.copyWith(
                          highContrast: value,
                        ),
                      ),
                    ),
                    title: const Text('High contrast'),
                    subtitle: const Text(
                      'Increase foreground separation for legibility.',
                    ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: selectedAccessibility.reduceIntensity,
                    onChanged: (value) => _applySelection(
                      _currentSelection().copyWith(
                        accessibility: selectedAccessibility.copyWith(
                          reduceIntensity: value,
                        ),
                      ),
                    ),
                    title: const Text('Reduce intensity'),
                    subtitle: const Text(
                      'Soften decorative colour without changing text contrast.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  value: autosave,
                  onChanged: (value) {
                    setState(() => autosave = value);
                    _set(_autosaveKey, value);
                  },
                  title: const Text('Automatic draft saving'),
                  subtitle:
                      const Text('Keep enabled to protect manuscript changes.'),
                  secondary: const Icon(Icons.save_outlined),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: focusDefaults,
                  onChanged: (value) {
                    setState(() => focusDefaults = value);
                    _set(_focusKey, value);
                  },
                  title: const Text('Open in focus mode'),
                  subtitle:
                      const Text('Use the manuscript as the default workspace.'),
                  secondary: const Icon(Icons.center_focus_strong),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(
                AppSupabase.isSignedIn ? 'Google connected' : 'Google sign-in',
              ),
              subtitle: Text(
                AppSupabase.isSignedIn
                    ? 'Projects and drafts can sync to your Supabase account.'
                    : 'Connect your Google account to sync projects across devices.',
              ),
              trailing: AppSupabase.isSignedIn
                  ? FilledButton.tonal(
                      onPressed: _handleSignOut,
                      child: const Text('Sign out'),
                    )
                  : FilledButton.icon(
                      onPressed: _handleGoogleSignIn,
                      icon: const Icon(Icons.g_mobiledata_rounded),
                      label: const Text('Google'),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Cloud sync status'),
              subtitle: Text(AppSupabase.hasCredentials
                  ? (AppSupabase.isSignedIn
                      ? 'Supabase is configured and the user is signed in.'
                      : 'Supabase is configured but the user is not signed in yet.')
                  : 'Supabase is not configured yet. Add your URL and anon key first.'),
            ),
          ),
          if (updateAvailable) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.system_update_alt_outlined),
                title: Text('Update available: $latestAppVersion'),
                subtitle: const Text(
                  'Restart the app to apply the newest build and changes.',
                ),
                trailing: FilledButton.icon(
                  onPressed: _handleUpdateNow,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Update now'),
                ),
              ),
            ),
          ],
        ],
      );
    }

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Appearance',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _themeOptions.map((theme) {
                    final isSelected = selectedTheme == theme.id;
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        setState(() {
                          selectedTheme = theme.id;
                          selectedMode =
                              _themeRegistry.byId(theme.id).defaultMode;
                        });
                        widget.onThemeChanged(selectedTheme, selectedAccent);
                      },
                      child: Container(
                        width: 170,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              theme.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              theme.description,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                value: autosave,
                onChanged: (value) {
                  setState(() => autosave = value);
                  _set(_autosaveKey, value);
                },
                title: const Text('Automatic draft saving'),
                subtitle:
                    const Text('Keep enabled to protect manuscript changes.'),
                secondary: const Icon(Icons.save_outlined),
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: focusDefaults,
                onChanged: (value) {
                  setState(() => focusDefaults = value);
                  _set(_focusKey, value);
                },
                title: const Text('Open in focus mode'),
                subtitle:
                    const Text('Use the manuscript as the default workspace.'),
                secondary: const Icon(Icons.center_focus_strong),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(
              AppSupabase.isSignedIn ? 'Google connected' : 'Google sign-in',
            ),
            subtitle: Text(
              AppSupabase.isSignedIn
                  ? 'Projects and drafts can sync to your Supabase account.'
                  : 'Connect your Google account to sync projects across devices.',
            ),
            trailing: AppSupabase.isSignedIn
                ? FilledButton.tonal(
                    onPressed: _handleSignOut,
                    child: const Text('Sign out'),
                  )
                : FilledButton.icon(
                    onPressed: _handleGoogleSignIn,
                    icon: const Icon(Icons.g_mobiledata_rounded),
                    label: const Text('Google'),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Cloud sync status'),
            subtitle: Text(AppSupabase.hasCredentials
                ? (AppSupabase.isSignedIn
                    ? 'Supabase is configured and the user is signed in.'
                    : 'Supabase is configured but the user is not signed in yet.')
                : 'Supabase is not configured yet. Add your URL and anon key first.'),
          ),
        ),
        if (updateAvailable) ...[
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.system_update_alt_outlined),
              title: Text('Update available: $latestAppVersion'),
              subtitle: const Text(
                'Restart the app to apply the newest build and changes.',
              ),
              trailing: FilledButton.icon(
                onPressed: _handleUpdateNow,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Update now'),
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => _StudioPage(
        title: 'Settings',
        subtitle: 'Control writing preferences, login, and cloud sync.',
        child: Column(
          children: [
            _buildCollapsibleSection(
              sectionId: _profileSectionId,
              title: 'Profile',
              icon: Icons.person_outline,
              child: _buildProfilePage(),
            ),
            const SizedBox(height: 12),
            _buildCollapsibleSection(
              sectionId: _appearanceSectionId,
              title: 'Appearance',
              icon: Icons.palette_outlined,
              child: _buildAppearancePage(),
            ),
            const SizedBox(height: 12),
            _buildCollapsibleSection(
              sectionId: _accountSectionId,
              title: 'Account Security',
              icon: Icons.shield_outlined,
              child: _buildAccountSecurityPage(),
            ),
          ],
        ),
      );
}

class _StudioPage extends StatelessWidget {
  const _StudioPage({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(width: 12),
                  action!,
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 180,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 42,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

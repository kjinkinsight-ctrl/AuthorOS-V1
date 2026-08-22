/// Project seed data — the domain layer.
///
/// A [StarterProject] is the shape of one book: its identity, its template
/// seeds, and its word target. It is pure data with no Flutter in it, which is
/// what lets the onboarding flow, the persistence layer, and the project
/// roster all speak about a project without any of them importing the others.
///
/// It lives here rather than beside the onboarding widgets because
/// `lib/onboarding.dart` imports Flutter, and the roster tables in
/// `lib/persistence/authoros_database.dart` must be able to store a project
/// without dragging widgets into persistence. `onboarding.dart` re-exports
/// this library, so every existing `import 'onboarding.dart'` still resolves
/// these types.
library;

import 'dart:convert';

class StarterChapter {
  const StarterChapter({
    required this.title,
    required this.prompt,
    this.status = 'Active',
    this.scenes = const [],
    this.linkedChapterIds = const [],
  });

  final String title;
  final String prompt;
  final String status;
  final List<String> scenes;
  final List<String> linkedChapterIds;

  bool get isArchived => status == 'Archived';

  StarterChapter copyWith({
    String? title,
    String? prompt,
    String? status,
    List<String>? scenes,
    List<String>? linkedChapterIds,
  }) =>
      StarterChapter(
        title: title ?? this.title,
        prompt: prompt ?? this.prompt,
        status: status ?? this.status,
        scenes: scenes ?? this.scenes,
        linkedChapterIds: linkedChapterIds ?? this.linkedChapterIds,
      );

  Map<String, Object> toJson() => {
        'title': title,
        'prompt': prompt,
        'status': status,
        'scenes': scenes,
        'linkedChapterIds': linkedChapterIds,
      };

  factory StarterChapter.fromJson(Map<String, dynamic> json) => StarterChapter(
        title: json['title'] as String? ?? 'Untitled Chapter',
        prompt: json['prompt'] as String? ?? '',
        status: (json['status'] as String?) ?? 'Active',
        scenes: (json['scenes'] as List? ?? const [])
            .map((value) => value.toString())
            .toList(),
        linkedChapterIds: (json['linkedChapterIds'] as List? ?? const [])
            .map((value) => value.toString())
            .toList(),
      );
}

class StarterCharacterSheet {
  const StarterCharacterSheet({required this.name, required this.role});

  final String name;
  final String role;

  Map<String, Object> toJson() => {'name': name, 'role': role};

  factory StarterCharacterSheet.fromJson(Map<String, dynamic> json) =>
      StarterCharacterSheet(
        name: json['name'] as String? ?? 'Unnamed Character',
        role: json['role'] as String? ?? '',
      );
}

class StarterProject {
  const StarterProject({
    required this.id,
    required this.title,
    required this.genre,
    required this.projectType,
    required this.wordGoal,
    required this.acts,
    required this.chapters,
    required this.characterSheets,
    required this.beatChecklist,
    required this.firstSceneTitle,
    this.templateName = 'Classic Novel',
  });

  final String id;
  final String title;
  final String genre;
  final String projectType;
  final int wordGoal;
  final List<String> acts;
  final List<StarterChapter> chapters;
  final List<StarterCharacterSheet> characterSheets;
  final List<String> beatChecklist;
  final String firstSceneTitle;
  final String templateName;

  Map<String, Object> toJson() => {
        'id': id,
        'title': title,
        'genre': genre,
        'projectType': projectType,
        'wordGoal': wordGoal,
        'acts': acts,
        'chapters': chapters.map((chapter) => chapter.toJson()).toList(),
        'characterSheets':
            characterSheets.map((sheet) => sheet.toJson()).toList(),
        'beatChecklist': beatChecklist,
        'firstSceneTitle': firstSceneTitle,
        'templateName': templateName,
      };

  factory StarterProject.fromJson(Map<String, dynamic> json) => StarterProject(
        id: json['id'] as String? ??
            'legacy-${base64Url.encode(utf8.encode('${json['title'] ?? 'Untitled Project'}|${json['genre'] ?? 'Fantasy'}|${json['projectType'] ?? 'Novel'}'))}',
        title: json['title'] as String? ?? 'Untitled Project',
        genre: json['genre'] as String? ?? 'Fantasy',
        projectType: json['projectType'] as String? ?? 'Novel',
        wordGoal: json['wordGoal'] as int? ?? 80000,
        acts: List<String>.from(json['acts'] as List? ?? const []),
        chapters: (json['chapters'] as List? ?? const [])
            .map((value) => StarterChapter.fromJson(
                Map<String, dynamic>.from(value as Map)))
            .toList(),
        characterSheets: (json['characterSheets'] as List? ?? const [])
            .map((value) => StarterCharacterSheet.fromJson(
                Map<String, dynamic>.from(value as Map)))
            .toList(),
        beatChecklist:
            List<String>.from(json['beatChecklist'] as List? ?? const []),
        firstSceneTitle: json['firstSceneTitle'] as String? ?? 'Opening Scene',
        templateName: json['templateName'] as String? ?? 'Classic Novel',
      );

  StarterProject copyWith({
    String? id,
    String? title,
    String? genre,
    String? projectType,
    int? wordGoal,
    List<String>? acts,
    List<StarterChapter>? chapters,
    List<StarterCharacterSheet>? characterSheets,
    List<String>? beatChecklist,
    String? firstSceneTitle,
    String? templateName,
  }) =>
      StarterProject(
        id: id ?? this.id,
        title: title ?? this.title,
        genre: genre ?? this.genre,
        projectType: projectType ?? this.projectType,
        wordGoal: wordGoal ?? this.wordGoal,
        acts: acts ?? this.acts,
        chapters: chapters ?? this.chapters,
        characterSheets: characterSheets ?? this.characterSheets,
        beatChecklist: beatChecklist ?? this.beatChecklist,
        firstSceneTitle: firstSceneTitle ?? this.firstSceneTitle,
        templateName: templateName ?? this.templateName,
      );
}

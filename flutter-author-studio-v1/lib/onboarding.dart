import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'startup_backdrop.dart';
import 'supabase_service.dart';
import 'sync/project_sync_service.dart';

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

class StoryTemplate {
  const StoryTemplate({
    required this.name,
    required this.description,
    required this.sceneSuggestions,
    required this.arcNames,
    required this.beatChecklist,
    required this.chapterBlueprint,
    required this.firstSceneTitle,
  });

  final String name;
  final String description;
  final List<String> sceneSuggestions;
  final List<String> arcNames;
  final List<String> beatChecklist;
  final List<String> chapterBlueprint;
  final String firstSceneTitle;
}

class StoryTemplateLibrary {
  const StoryTemplateLibrary._();

  static const List<StoryTemplate> templates = [
    StoryTemplate(
      name: 'Romance',
      description: 'Character chemistry, emotional stakes, and satisfying arc.',
      sceneSuggestions: [
        'The Meet-Cute',
        'First Spark',
        'Competing Feelings',
        'True Confession',
        'The Climax of Trust',
        'The Happy Ending',
      ],
      arcNames: ['Romantic Tension', 'Emotional Growth', 'Relationship Arc'],
      beatChecklist: [
        'Meet-cute',
        'Obstacles and chemistry',
        'False hope',
        'Midpoint confession',
        'Conflict escalation',
        'Trust and vulnerability',
        'The choice to stay',
        'Happy ending',
      ],
      chapterBlueprint: [
        'Chapter 1 - The Spark',
        'Chapter 2 - The Friction',
        'Chapter 3 - The Connection',
      ],
      firstSceneTitle: 'The Meet-Cute',
    ),
    StoryTemplate(
      name: 'Thriller',
      description: 'Escalating pressure, hidden motives, and hard choices.',
      sceneSuggestions: [
        'The Signal',
        'The False Lead',
        'The Chase Begins',
        'The Break',
        'The Counterplay',
        'The Final Confrontation',
      ],
      arcNames: ['Main Plot', 'Pressure Arc', 'Counter-Intelligence'],
      beatChecklist: [
        'Opening signal',
        'False lead',
        'Escalation',
        'Midpoint fracture',
        'Reveal',
        'Countermeasure',
        'Final confrontation',
        'Resolution',
      ],
      chapterBlueprint: [
        'Chapter 1 - The Signal',
        'Chapter 2 - The Pattern',
        'Chapter 3 - The Fracture',
      ],
      firstSceneTitle: 'The Signal',
    ),
    StoryTemplate(
      name: 'Fantasy',
      description: 'Worldbuilding, mythic stakes, and a growing power arc.',
      sceneSuggestions: [
        'The Call to the Realm',
        'The Hidden Rule',
        'The Trial',
        'The Cost of Power',
        'The Betrayal',
        'The Final Threshold',
      ],
      arcNames: ['World Arc', 'Power Arc', 'Mythic Thread'],
      beatChecklist: [
        'The world opens',
        'The hidden rule',
        'The first test',
        'The price of power',
        'The deeper betrayal',
        'The final threshold',
        'The altered ending',
      ],
      chapterBlueprint: [
        'Chapter 1 - The Realm Awakes',
        'Chapter 2 - The Cost of Magic',
        'Chapter 3 - The Claiming',
      ],
      firstSceneTitle: 'The Realm Awakes',
    ),
    StoryTemplate(
      name: 'Mystery',
      description: 'Clues, red herrings, and the slow reveal of truth.',
      sceneSuggestions: [
        'The Missing Link',
        'The Case Opens',
        'The False Solution',
        'The Breakthrough',
        'The Confrontation',
        'The Reveal',
      ],
      arcNames: ['Case Arc', 'Truth Arc', 'False Solution', 'Suspect Thread'],
      beatChecklist: [
        'The crime',
        'The clue trail',
        'False solution',
        'Unexpected witness',
        'The reveal',
        'Counterplay',
        'Final account',
      ],
      chapterBlueprint: [
        'Chapter 1 - The Case',
        'Chapter 2 - The Clues',
        'Chapter 3 - The Suspect',
      ],
      firstSceneTitle: 'The Case Opens',
    ),
    StoryTemplate(
      name: 'Literary Fiction',
      description: 'Atmosphere, emotional depth, and layered meaning.',
      sceneSuggestions: [
        'The Small Shift',
        'The Memory Surface',
        'The Unspoken Tension',
        'The Quiet Reckoning',
        'The Final Choice',
        'The Last Light',
      ],
      arcNames: ['Character Arc', 'Memory Thread', 'Emotional Current'],
      beatChecklist: [
        'The emotional undercurrent',
        'The memory break',
        'The quiet fracture',
        'The loss of certainty',
        'The recognition',
        'The final act of honesty',
        'The afterimage',
      ],
      chapterBlueprint: [
        'Chapter 1 - The Shift',
        'Chapter 2 - The Memory',
        'Chapter 3 - The Reckoning',
      ],
      firstSceneTitle: 'The Small Shift',
    ),
  ];

  static StoryTemplate? templateFor(String? name) {
    if (name == null || name.trim().isEmpty) {
      return null;
    }
    final normalized = name.trim();
    try {
      return templates.firstWhere(
        (template) => template.name.toLowerCase() == normalized.toLowerCase(),
      );
    } catch (_) {
      try {
        return templates.firstWhere(
          (template) =>
              template.name.toLowerCase() ==
              normalized.toLowerCase().replaceAll('_', ' '),
        );
      } catch (_) {
        return null;
      }
    }
  }
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

class NovelStarterKit {
  const NovelStarterKit._();

  static StarterProject create({
    required String title,
    required String genre,
    required String projectType,
    required int wordGoal,
    String? templateName,
  }) {
    final template = templateName == null
        ? null
        : StoryTemplateLibrary.templateFor(templateName);
    final chapterBlueprint = template?.chapterBlueprint ??
        const [
          'Chapter 1 - The Opening',
          'Chapter 2 - The First Turn',
          'Chapter 3 - The New Direction',
        ];
    final beatChecklist = template?.beatChecklist ??
        const [
          'Opening image',
          'Story question',
          'Inciting incident',
          'First threshold',
          'Midpoint reversal',
          'Lowest point',
          'Climactic choice',
          'Closing image',
        ];
    final firstSceneTitle = template == null
        ? 'Opening Scene'
        : (title.trim().isEmpty
            ? template.firstSceneTitle
            : '${title.trim()} - ${template.firstSceneTitle}');

    return StarterProject(
      id: 'project_${DateTime.now().microsecondsSinceEpoch}',
      title: title.trim().isEmpty ? 'My Novel' : title.trim(),
      genre: genre,
      projectType: projectType,
      wordGoal: wordGoal,
      acts: const [
        'Act I - Setup',
        'Act II - Confrontation',
        'Act III - Resolution',
      ],
      chapters: [
        for (var index = 0; index < chapterBlueprint.length; index++)
          StarterChapter(
            title: chapterBlueprint[index],
            prompt: index == 0
                ? 'Open with a change, decision, or image that cannot be ignored.'
                : index == 1
                    ? 'Force the protagonist to respond to the opening disruption.'
                    : 'Commit the story to its central conflict and forward motion.',
            scenes: index == 0
                ? const ['Opening image', 'Pressure point', 'Decision']
                : index == 1
                    ? const ['Complication', 'Turn', 'Escalation']
                    : const ['Confrontation', 'Choice', 'Resolution'],
            linkedChapterIds: index == 0
                ? const ['chapter-1', 'chapter-2']
                : index == 1
                    ? const ['chapter-0', 'chapter-2']
                    : const ['chapter-0', 'chapter-1'],
          ),
      ],
      characterSheets: const [
        StarterCharacterSheet(name: 'Protagonist', role: 'Goal, flaw, stakes'),
        StarterCharacterSheet(
            name: 'Primary Opposition', role: 'Pressure and conflict'),
        StarterCharacterSheet(
            name: 'Key Ally', role: 'Support and complication'),
      ],
      beatChecklist: beatChecklist,
      firstSceneTitle: firstSceneTitle,
      templateName: template?.name ?? 'Classic Novel',
    );
  }
}

class ScreenplayStarterKit {
  const ScreenplayStarterKit._();

  static StarterProject create({
    required String title,
    required String genre,
    required int wordGoal,
    String? templateName,
  }) {
    final template = templateName == null
        ? null
        : StoryTemplateLibrary.templateFor(templateName);
    final firstSceneTitle = template != null
        ? (title.trim().isEmpty
            ? template.firstSceneTitle
            : '${title.trim()} - ${template.firstSceneTitle}')
        : 'INT./EXT. OPENING LOCATION - DAY';

    return StarterProject(
      id: 'project_${DateTime.now().microsecondsSinceEpoch}',
      title: title.trim().isEmpty ? 'My Screenplay' : title.trim(),
      genre: genre,
      projectType: 'Screenplay',
      wordGoal: wordGoal,
      acts: const [
        'Act I - Setup',
        'Act II - Confrontation',
        'Act III - Resolution',
      ],
      chapters: const [
        StarterChapter(
          title: 'Sequence 1 - Opening Image',
          prompt:
              'Establish the visual world, tone, and protagonist in action.',
          scenes: ['Opening image', 'World setup', 'Character objective'],
          linkedChapterIds: ['chapter-1'],
        ),
        StarterChapter(
          title: 'Sequence 2 - Inciting Incident',
          prompt:
              'Disrupt the protagonist’s normal world with a visible event.',
          scenes: ['Incident', 'Complication', 'Call to action'],
          linkedChapterIds: ['chapter-0', 'chapter-2'],
        ),
        StarterChapter(
          title: 'Sequence 3 - First Act Turn',
          prompt: 'Force a choice that commits the protagonist to the story.',
          scenes: ['Decision point', 'Turn', 'Commitment'],
          linkedChapterIds: ['chapter-1', 'chapter-3'],
        ),
        StarterChapter(
          title: 'Sequence 4 - Midpoint',
          prompt:
              'Change the goal, stakes, or audience understanding of events.',
          scenes: ['Midpoint reveal', 'Setback', 'New question'],
          linkedChapterIds: ['chapter-2', 'chapter-4'],
        ),
        StarterChapter(
          title: 'Sequence 5 - Crisis',
          prompt:
              'Collapse the current plan and force the decisive final choice.',
          scenes: ['Pressure spike', 'False victory', 'Last gamble'],
          linkedChapterIds: ['chapter-3', 'chapter-5'],
        ),
        StarterChapter(
          title: 'Sequence 6 - Climax and Resolution',
          prompt:
              'Resolve the central dramatic question through visible action.',
          scenes: ['Final confrontation', 'Resolution', 'Afterglow'],
          linkedChapterIds: ['chapter-4'],
        ),
      ],
      characterSheets: const [
        StarterCharacterSheet(
          name: 'Protagonist',
          role: 'Objective, need, flaw, visual signature',
        ),
        StarterCharacterSheet(
          name: 'Antagonistic Force',
          role: 'Counter-objective and escalating pressure',
        ),
        StarterCharacterSheet(
          name: 'Key Supporting Role',
          role: 'Relationship arc and story function',
        ),
      ],
      beatChecklist: template?.beatChecklist ??
          const [
            'Opening image',
            'Theme stated',
            'Inciting incident',
            'Act I turning point',
            'First culmination',
            'Midpoint reversal',
            'Act II turning point',
            'Crisis choice',
            'Climax',
            'Final image',
          ],
      firstSceneTitle: firstSceneTitle,
      templateName: template?.name ?? 'Classic Screenplay',
    );
  }
}

class OnboardingResult {
  const OnboardingResult({required this.project, required this.startSprint});

  final StarterProject project;
  final bool startSprint;
}

class OnboardingStore {
  const OnboardingStore();

  static const _projectKey = 'author_studio.starter_project';
  static const _completeKey = 'author_studio.onboarding_complete';

  Future<StarterProject?> loadProject() async {
    if (AppSupabase.isSignedIn) {
      final cloudProject = await AppSupabase.loadCurrentProject();
      if (cloudProject != null) {
        return cloudProject;
      }
    }

    final preferences = await SharedPreferences.getInstance();
    final savedProject = preferences.getString(_projectKey);
    if (savedProject == null || savedProject.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(savedProject);
    if (decoded is! Map) {
      return null;
    }
    return StarterProject.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<void> saveProject(StarterProject project) async {
    if (AppSupabase.isSignedIn) {
      await AppSupabase.saveProject(project);
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_projectKey, jsonEncode(project.toJson()));
    await preferences.setBool(_completeKey, true);

    // Queued after the local write so a sync failure can never cost the
    // user their save; the queue retries on the next flush.
    await const ProjectSyncService().recordProjectSaved(project);
  }

  static Future<void> clearProjectState() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_projectKey);
    await preferences.setBool(_completeKey, false);
  }
}

/// Artwork behind the first-run wizard: the startup doorway pulled wide so
/// the welcome form sits on the dark study wall to its left.
const AssetImage onboardingDoorway = AssetImage('assets/onboarding-doorway.png');

/// Single-page workspace setup shown after the first sign-in: project details,
/// workspace shape, and the continuity-first workflow on one screen, with a
/// sidebar preview of what the workspace will contain.
class FirstRunProjectWizard extends StatefulWidget {
  const FirstRunProjectWizard({
    super.key,
    required this.onComplete,
    this.onSignIn,
  });

  final ValueChanged<OnboardingResult> onComplete;

  /// Top-right "Already have an account? Sign in" action; returns the author
  /// to profile selection.
  final VoidCallback? onSignIn;

  @override
  State<FirstRunProjectWizard> createState() => _FirstRunProjectWizardState();
}

class _FirstRunProjectWizardState extends State<FirstRunProjectWizard> {
  final titleController = TextEditingController();
  final goalController = TextEditingController(text: '80000');
  String genre = 'Fantasy';
  String projectType = 'Novel';
  String selectedTemplate = 'Classic';

  static const genres = [
    'Fantasy',
    'Romance',
    'Mystery',
    'Science Fiction',
    'Thriller',
    'Historical',
    'Literary',
    'Other',
  ];

  static const projectTypes = [
    ('Novel', Icons.menu_book_outlined),
    ('Memoir', Icons.history_edu_outlined),
    ('Short Story', Icons.chat_bubble_outline),
    ('Screenplay', Icons.theaters_outlined),
  ];

  List<String> get templateOptions => [
        'Classic',
        ...StoryTemplateLibrary.templates.map((template) => template.name),
      ];

  @override
  void dispose() {
    titleController.dispose();
    goalController.dispose();
    super.dispose();
  }

  StarterProject _buildProject() {
    final goal = int.tryParse(goalController.text) ?? 80000;
    final clampedGoal = goal.clamp(1000, 500000);

    final shouldUseTemplate =
        selectedTemplate.isNotEmpty && selectedTemplate != 'Classic';
    final resolvedTemplate = shouldUseTemplate
        ? StoryTemplateLibrary.templateFor(selectedTemplate) ??
            StoryTemplateLibrary.templateFor(genre)
        : null;
    return projectType == 'Screenplay'
        ? ScreenplayStarterKit.create(
            title: titleController.text,
            genre: genre,
            wordGoal: clampedGoal,
            templateName: resolvedTemplate?.name,
          )
        : NovelStarterKit.create(
            title: titleController.text,
            genre: genre,
            projectType: projectType,
            wordGoal: clampedGoal,
            templateName: resolvedTemplate?.name,
          );
  }

  void _createWorkspace() {
    widget.onComplete(
      OnboardingResult(project: _buildProject(), startSprint: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = StartupPalette.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image(
            image: onboardingDoorway,
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
            errorBuilder: (context, error, stackTrace) =>
                ColoredBox(color: palette.background),
          ),
          // Deepens the left side so the form keeps its contrast; the doorway
          // stays readable on the right.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  palette.background.withValues(alpha: 0.92),
                  palette.background.withValues(alpha: 0.5),
                  palette.background.withValues(alpha: 0.05),
                ],
                stops: const [0, 0.62, 1],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTopBar(palette),
                      const SizedBox(height: 26),
                      Text(
                        'Welcome to your writing workspace',
                        style: TextStyle(
                          fontFamily: 'Merriweather',
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: palette.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Create your project, set your foundations, and step into your story.',
                        style: TextStyle(
                          fontSize: 14,
                          color: palette.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 22),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 900;
                          final form = _buildFormPanel(palette);
                          final sidebar = _WorkspacePreviewSidebar(
                            palette: palette,
                          );
                          if (!wide) {
                            return Column(
                              children: [
                                form,
                                const SizedBox(height: 18),
                                sidebar,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: form),
                              const SizedBox(width: 20),
                              SizedBox(width: 320, child: sidebar),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(StartupPalette palette) {
    return Row(
      children: [
        Icon(Icons.auto_stories, color: palette.gold, size: 28),
        const Spacer(),
        if (widget.onSignIn != null) ...[
          Text(
            'Already have an account?',
            style: TextStyle(
              fontSize: 13,
              color: palette.onSurface.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            key: const Key('onboarding-sign-in'),
            onPressed: widget.onSignIn,
            icon: const Icon(Icons.login, size: 16),
            label: const Text('Sign in'),
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.gold,
              side: BorderSide(color: palette.gold.withValues(alpha: 0.6)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFormPanel(StartupPalette palette) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _panelDecoration(palette),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            palette: palette,
            title: '1. Project details',
            subtitle: 'Start with the basics of your story.',
          ),
          const SizedBox(height: 16),
          _FieldLabel(palette: palette, label: 'Project title'),
          TextField(
            key: const Key('project-title-field'),
            controller: titleController,
            style: TextStyle(color: palette.onSurface),
            decoration: _inputDecoration(
              palette,
              hint: 'Enter your project title',
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel(palette: palette, label: 'Genre'),
                    _buildDropdown(
                      palette: palette,
                      value: genre,
                      options: genres,
                      onChanged: (value) => setState(() {
                        genre = value ?? genre;
                        selectedTemplate = 'Classic';
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel(palette: palette, label: 'Story template'),
                    _buildDropdown(
                      palette: palette,
                      value: selectedTemplate,
                      options: templateOptions,
                      onChanged: (value) => setState(
                        () => selectedTemplate = value ?? selectedTemplate,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _FieldLabel(palette: palette, label: 'Draft word goal'),
          TextField(
            key: const Key('word-goal-field'),
            controller: goalController,
            keyboardType: TextInputType.number,
            style: TextStyle(color: palette.onSurface),
            decoration: _inputDecoration(palette, suffixText: 'words'),
          ),
          _sectionDivider(palette),
          _SectionHeader(
            palette: palette,
            title: '2. Choose your workspace setup',
            subtitle: 'Select the foundation that fits your story.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final (label, icon) in projectTypes)
                _WorkspaceTypeChip(
                  palette: palette,
                  label: label,
                  icon: icon,
                  selected: projectType == label,
                  onTap: () => setState(() => projectType = label),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _StarterKitPreview(
            palette: palette,
            projectType: projectType,
          ),
          _sectionDivider(palette),
          _SectionHeader(
            palette: palette,
            title: '3. Continuity-first workflow',
            subtitle:
                'Before you draft, Indie Author OS helps you lock the narrative foundations that keep the story coherent.',
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 640 ? 3 : 1;
              final width = columns == 1
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 24) / 3;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final step in _continuitySteps)
                    _WorkflowCard(
                      palette: palette,
                      width: width,
                      icon: step.$1,
                      title: step.$2,
                      description: step.$3,
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('create-workspace-button'),
              onPressed: _createWorkspace,
              icon: const Icon(Icons.arrow_forward, size: 20),
              label: const Text('Create workspace'),
              style: FilledButton.styleFrom(
                backgroundColor: palette.gold,
                foregroundColor: palette.background,
                padding: const EdgeInsets.symmetric(vertical: 18),
                textStyle: const TextStyle(
                  fontFamily: 'Merriweather',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              projectType == 'Screenplay'
                  ? 'Your screenplay will open in Sequence 1 at the first scene heading.'
                  : 'Your starter project will open in Chapter 1 at the Opening Scene.',
              style: TextStyle(
                fontSize: 12.5,
                color: palette.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _continuitySteps = [
    (
      Icons.groups_outlined,
      'Build the cast',
      'Define the core characters, POVs, and relationships before the first major scene.',
    ),
    (
      Icons.timeline_outlined,
      'Map the timeline',
      'Place scenes in order, track dates, and note travel, locations, and plotline movement.',
    ),
    (
      Icons.fact_check_outlined,
      'Run continuity checks',
      'Let Indie Author OS flag missing POVs, impossible travel, character overlaps, and timeline issues.',
    ),
  ];

  Widget _buildDropdown({
    required StartupPalette palette,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      dropdownColor: palette.panel,
      iconEnabledColor: palette.gold,
      // An explicit family: DropdownButton replaces the inherited text style
      // wholesale, and a family-less style loses the theme's Inter face.
      style: TextStyle(
        fontFamily: 'Inter',
        color: palette.onSurface,
        fontSize: 14,
      ),
      decoration: _inputDecoration(palette),
      items: options
          .map((option) =>
              DropdownMenuItem(value: option, child: Text(option)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _sectionDivider(StartupPalette palette) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Container(
          height: 1,
          color: palette.gold.withValues(alpha: 0.15),
        ),
      );
}

BoxDecoration _panelDecoration(StartupPalette palette) => BoxDecoration(
      color: palette.background.withValues(alpha: 0.82),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: palette.gold.withValues(alpha: 0.22)),
    );

InputDecoration _inputDecoration(
  StartupPalette palette, {
  String? hint,
  String? suffixText,
}) =>
    InputDecoration(
      hintText: hint,
      suffixText: suffixText,
      suffixStyle:
          TextStyle(color: palette.onSurface.withValues(alpha: 0.55)),
      hintStyle: TextStyle(color: palette.onSurface.withValues(alpha: 0.4)),
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      filled: true,
      fillColor: palette.panel.withValues(alpha: 0.6),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: palette.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: palette.focusRing, width: 2),
      ),
    );

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.palette,
    required this.title,
    required this.subtitle,
  });

  final StartupPalette palette;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Merriweather',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: palette.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: palette.onSurface.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.palette, required this.label});

  final StartupPalette palette;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: palette.onSurface,
        ),
      ),
    );
  }
}

class _WorkspaceTypeChip extends StatelessWidget {
  const _WorkspaceTypeChip({
    required this.palette,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final StartupPalette palette;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: selected
                ? palette.gold.withValues(alpha: 0.12)
                : palette.panel.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? palette.gold.withValues(alpha: 0.9)
                  : palette.outline,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? palette.gold
                    : palette.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? palette.gold : palette.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkflowCard extends StatelessWidget {
  const _WorkflowCard({
    required this.palette,
    required this.width,
    required this.icon,
    required this.title,
    required this.description,
  });

  final StartupPalette palette;
  final double width;
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.panel.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: palette.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: palette.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: palette.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}

class _StarterKitPreview extends StatelessWidget {
  const _StarterKitPreview({
    required this.palette,
    required this.projectType,
  });

  final StartupPalette palette;
  final String projectType;

  @override
  Widget build(BuildContext context) {
    final items = projectType == 'Screenplay'
        ? const [
            (Icons.account_tree_outlined, 'Three-act screen structure'),
            (Icons.movie_outlined, 'Six sequence placeholders'),
            (Icons.groups_outlined, 'Three character sheets'),
            (Icons.checklist_outlined, 'Ten screenplay beats'),
          ]
        : const [
            (Icons.account_tree_outlined, 'Three-act structure'),
            (Icons.menu_book_outlined, 'Three chapter placeholders'),
            (Icons.groups_outlined, 'Three character sheets'),
            (Icons.checklist_outlined, 'Eight-beat checklist'),
          ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth >= 470
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items
              .map((item) => Container(
                    width: itemWidth,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: palette.panel.withValues(alpha: 0.55),
                      border: Border.all(color: palette.outline),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(item.$1, size: 18, color: palette.gold),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.$2,
                            style: TextStyle(
                              fontSize: 13,
                              color: palette.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _WorkspacePreviewSidebar extends StatelessWidget {
  const _WorkspacePreviewSidebar({required this.palette});

  final StartupPalette palette;

  static const _entries = [
    (
      Icons.groups_outlined,
      'Build the cast',
      'Define the core characters, POVs, and relationships before the first major scene.',
      'Lead character • Primary rival • Key ally',
    ),
    (
      Icons.timeline_outlined,
      'Map the timeline',
      'Place scenes in order, track dates, and note travel, locations, and plotline movement.',
      'Act I - Setup • Act II - Confrontation • Act III - Resolution',
    ),
    (
      Icons.fact_check_outlined,
      'Run continuity checks',
      'Let Indie Author OS flag missing POVs, impossible travel, character overlaps, and timeline issues.',
      null,
    ),
    (
      Icons.edit_note_outlined,
      'Start drafting with confidence',
      'With your foundation in place, step into the writing desk and bring your story to life.',
      null,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(palette),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your workspace will include',
            style: TextStyle(
              fontFamily: 'Merriweather',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: palette.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < _entries.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Container(
                  height: 1,
                  color: palette.gold.withValues(alpha: 0.12),
                ),
              ),
            _SidebarEntry(
              palette: palette,
              icon: _entries[i].$1,
              title: _entries[i].$2,
              description: _entries[i].$3,
              meta: _entries[i].$4,
            ),
          ],
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.gold.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 15, color: palette.gold),
                    const SizedBox(width: 7),
                    Text(
                      'Tip',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: palette.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'You can change any of these settings later inside the project settings.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: palette.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarEntry extends StatelessWidget {
  const _SidebarEntry({
    required this.palette,
    required this.icon,
    required this.title,
    required this.description,
    this.meta,
  });

  final StartupPalette palette;
  final IconData icon;
  final String title;
  final String description;
  final String? meta;

  @override
  Widget build(BuildContext context) {
    final metaText = meta;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: palette.gold.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: palette.gold.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, size: 18, color: palette.gold),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: palette.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: palette.onSurface.withValues(alpha: 0.65),
                ),
              ),
              if (metaText != null) ...[
                const SizedBox(height: 6),
                Text(
                  metaText,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: palette.gold.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_service.dart';

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
  }

  static Future<void> clearProjectState() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_projectKey);
    await preferences.setBool(_completeKey, false);
  }
}

class FirstRunProjectWizard extends StatefulWidget {
  const FirstRunProjectWizard({
    super.key,
    required this.onComplete,
  });

  final ValueChanged<OnboardingResult> onComplete;

  @override
  State<FirstRunProjectWizard> createState() => _FirstRunProjectWizardState();
}

class _FirstRunProjectWizardState extends State<FirstRunProjectWizard> {
  final titleController = TextEditingController();
  final goalController = TextEditingController(text: '80000');
  final List<TextEditingController> castControllers = List.generate(
    3,
    (index) => TextEditingController(
      text: switch (index) {
        0 => 'Protagonist',
        1 => 'Primary Opposition',
        _ => 'Key Ally',
      },
    ),
  );
  final List<TextEditingController> actControllers = List.generate(
    3,
    (index) => TextEditingController(
      text: switch (index) {
        0 => 'Act I - Setup',
        1 => 'Act II - Confrontation',
        _ => 'Act III - Resolution',
      },
    ),
  );
  int step = 0;
  String genre = 'Fantasy';
  String projectType = 'Novel';
  String selectedTemplate = 'Classic';
  bool startSprint = true;

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
    'Novel',
    'Memoir',
    'Short Story',
    'Screenplay',
  ];

  List<String> get templateOptions => [
        'Classic',
        ...StoryTemplateLibrary.templates.map((template) => template.name),
      ];

  @override
  void dispose() {
    titleController.dispose();
    goalController.dispose();
    for (final controller in castControllers) {
      controller.dispose();
    }
    for (final controller in actControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  StarterProject _buildProjectForWizard() {
    final goal = int.tryParse(goalController.text) ?? 80000;
    final clampedGoal = goal.clamp(1000, 500000);

    final shouldUseTemplate =
        selectedTemplate.isNotEmpty && selectedTemplate != 'Classic';
    final resolvedTemplate = shouldUseTemplate
        ? StoryTemplateLibrary.templateFor(selectedTemplate) ??
            StoryTemplateLibrary.templateFor(genre)
        : null;
    final baseProject = projectType == 'Screenplay'
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

    final castNames = List.generate(castControllers.length, (index) {
      final value = castControllers[index].text.trim();
      return value.isEmpty
          ? switch (index) {
              0 => 'Protagonist',
              1 => 'Primary Opposition',
              _ => 'Key Ally',
            }
          : value;
    });

    final timelineNames = List.generate(actControllers.length, (index) {
      final value = actControllers[index].text.trim();
      return value.isEmpty
          ? switch (index) {
              0 => 'Act I - Setup',
              1 => 'Act II - Confrontation',
              _ => 'Act III - Resolution',
            }
          : value;
    });

    return baseProject.copyWith(
      acts: timelineNames,
      characterSheets: [
        for (var i = 0; i < castNames.length; i++)
          StarterCharacterSheet(
            name: castNames[i],
            role: switch (i) {
              0 => 'Lead goal, flaw, and arc',
              1 => 'Pressure, obstacle, and counter-goal',
              _ => 'Support, contrast, and relationship thread',
            },
          ),
      ],
    );
  }

  void finish() {
    widget.onComplete(
      OnboardingResult(
        project: _buildProjectForWizard(),
        startSprint: startSprint,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _WizardBrand(),
                  const SizedBox(height: 28),
                  Text(
                    'Start your writing workspace',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A focused setup for your project, structure, and first drafting session.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                  const SizedBox(height: 24),
                  _StepRail(currentStep: step),
                  const SizedBox(height: 18),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(child: _buildStep(context)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      if (step > 0)
                        TextButton.icon(
                          onPressed: () => setState(() => step -= 1),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Back'),
                        ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: step == 2
                            ? finish
                            : () => setState(() => step += 1),
                        icon: Icon(
                            step == 2 ? Icons.edit_note : Icons.arrow_forward),
                        label:
                            Text(step == 2 ? 'Open first scene' : 'Continue'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    if (step == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Project basics', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 18),
          TextField(
            key: const Key('project-title-field'),
            controller: titleController,
            decoration: const InputDecoration(
              labelText: 'Project title',
              hintText: 'The working title is fine',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: genre,
            decoration: const InputDecoration(
              labelText: 'Genre',
              border: OutlineInputBorder(),
            ),
            items: genres
                .map((value) =>
                    DropdownMenuItem(value: value, child: Text(value)))
                .toList(),
            onChanged: (value) {
              final nextGenre = value ?? genre;
              setState(() {
                genre = nextGenre;
                selectedTemplate = 'Classic';
              });
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: selectedTemplate,
            decoration: const InputDecoration(
              labelText: 'Story template',
              border: OutlineInputBorder(),
            ),
            items: templateOptions
                .map((template) =>
                    DropdownMenuItem(value: template, child: Text(template)))
                .toList(),
            onChanged: (value) =>
                setState(() => selectedTemplate = value ?? selectedTemplate),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('word-goal-field'),
            controller: goalController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Draft word goal',
              suffixText: 'words',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      );
    }

    if (step == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Project type', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('Choose the workspace shape for this project.'),
          const SizedBox(height: 18),
          SegmentedButton<String>(
            segments: projectTypes
                .map((value) => ButtonSegment(value: value, label: Text(value)))
                .toList(),
            selected: {projectType},
            onSelectionChanged: (selection) =>
                setState(() => projectType = selection.first),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            initialValue: selectedTemplate,
            decoration: const InputDecoration(
              labelText: 'Structure template',
              border: OutlineInputBorder(),
            ),
            items: templateOptions
                .map((template) => DropdownMenuItem(
                      value: template,
                      child: Text(template),
                    ))
                .toList(),
            onChanged: (value) =>
                setState(() => selectedTemplate = value ?? selectedTemplate),
          ),
          const SizedBox(height: 24),
          _StarterKitPreview(
              projectType: projectType, templateName: selectedTemplate),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Continuity-first workflow',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        Text(
          'Before you draft, Indie Author OS helps you lock the narrative foundations that keep the story coherent.',
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
        ),
        const SizedBox(height: 20),
        _ContinuityWorkflowStep(
          icon: Icons.groups_outlined,
          title: 'Build the cast',
          description:
              'Define the core characters, POVs, and relationships before the first major scene.',
          trailing: Column(
            children: List.generate(castControllers.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  key: Key('cast-name-$index'),
                  controller: castControllers[index],
                  decoration: InputDecoration(
                    labelText: switch (index) {
                      0 => 'Lead character',
                      1 => 'Primary rival',
                      _ => 'Key ally',
                    },
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 12),
        _ContinuityWorkflowStep(
          icon: Icons.timeline_outlined,
          title: 'Map the timeline',
          description:
              'Place scenes in order, track dates, and note travel, locations, and plotline movement.',
          trailing: Column(
            children: List.generate(actControllers.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  key: Key('act-name-$index'),
                  controller: actControllers[index],
                  decoration: InputDecoration(
                    labelText: switch (index) {
                      0 => 'Act I label',
                      1 => 'Act II label',
                      _ => 'Act III label',
                    },
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 12),
        const _ContinuityWorkflowStep(
          icon: Icons.fact_check_outlined,
          title: 'Run continuity checks',
          description:
              'Let Indie Author OS flag missing POVs, impossible travel, character overlaps, and timeline issues.',
        ),
        const SizedBox(height: 22),
        Text(
          projectType == 'Screenplay'
              ? 'Your screenplay will open in Sequence 1 at the first scene heading.'
              : 'Your starter project will open in Chapter 1 at the Opening Scene.',
        ),
        const SizedBox(height: 18),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => startSprint = !startSprint),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Start a 15-minute writing sprint',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'The timer begins when the first draft opens.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Switch(
                    key: const Key('sprint-toggle'),
                    value: startSprint,
                    onChanged: (value) => setState(() => startSprint = value),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ContinuityWorkflowStep extends StatelessWidget {
  const _ContinuityWorkflowStep({
    required this.icon,
    required this.title,
    required this.description,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1.4,
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(height: 12),
                  trailing!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WizardBrand extends StatelessWidget {
  const _WizardBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.auto_stories, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        const Text(
          'INDIE AUTHOR OS',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _StepRail extends StatelessWidget {
  const _StepRail({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    const labels = ['Project', 'Template', 'Draft'];
    return Row(
      children: List.generate(labels.length, (index) {
        final active = index <= currentStep;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index == labels.length - 1 ? 0 : 8),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  width: 3,
                  color: active
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            child: Text(
              labels[index],
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _StarterKitPreview extends StatelessWidget {
  const _StarterKitPreview({required this.projectType, this.templateName});

  final String projectType;
  final String? templateName;

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

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items
          .map((item) => Container(
                width: 250,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(item.$1, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(item.$2)),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

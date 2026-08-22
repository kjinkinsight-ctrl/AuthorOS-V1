import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'onboarding.dart';
import 'theme/flutter/authoros_theme.dart';
import 'theme/theme_tokens.dart';

enum SceneStatus { backlog, outlining, drafting, revised, finalDraft }

extension SceneStatusData on SceneStatus {
  String get label => switch (this) {
        SceneStatus.backlog => 'Backlog',
        SceneStatus.outlining => 'Outlining',
        SceneStatus.drafting => 'Drafting',
        SceneStatus.revised => 'Revised',
        SceneStatus.finalDraft => 'Final',
      };

  /// Scene workflow states resolve through the theme's categorical ramp.
  ///
  /// These are stages a scene moves through, not pass/fail signals, so they
  /// use ramp slots rather than the `success`/`warning` status roles even
  /// where a value coincides today — a scene being drafted is not a warning.
  Color colorIn(BuildContext context) {
    final ramp = AuthorOsSemanticColors.of(context);
    return switch (this) {
      SceneStatus.backlog => ramp.category(ThemeCategoryRef.category1),
      SceneStatus.outlining => ramp.category(ThemeCategoryRef.category2),
      SceneStatus.drafting => ramp.category(ThemeCategoryRef.category3),
      SceneStatus.revised => ramp.category(ThemeCategoryRef.category4),
      SceneStatus.finalDraft => ramp.category(ThemeCategoryRef.category5),
    };
  }
}

enum StructureOverlay { none, threeAct, heroesJourney }

extension StructureOverlayData on StructureOverlay {
  String get label => switch (this) {
        StructureOverlay.none => 'None',
        StructureOverlay.threeAct => 'Three-Act',
        StructureOverlay.heroesJourney => "Hero's Journey",
      };

  List<String> get stages => switch (this) {
        StructureOverlay.none => const [],
        StructureOverlay.threeAct => const [
            'Act I · Setup',
            'Act II · Confrontation',
            'Act III · Resolution',
          ],
        StructureOverlay.heroesJourney => const [
            'Ordinary World',
            'Call to Adventure',
            'Refusal of the Call',
            'Meeting the Mentor',
            'Crossing the Threshold',
            'Tests, Allies, Enemies',
            'Approach to the Inmost Cave',
            'Ordeal',
            'Reward',
            'The Road Back',
            'Resurrection',
            'Return with the Elixir',
          ],
      };
}

class PlanningScene {
  const PlanningScene({
    required this.id,
    required this.title,
    required this.status,
    required this.pov,
    required this.arc,
    required this.order,
  });

  final String id;
  final String title;
  final SceneStatus status;
  final String pov;
  final String arc;
  final int order;

  PlanningScene copyWith({SceneStatus? status}) => PlanningScene(
        id: id,
        title: title,
        status: status ?? this.status,
        pov: pov,
        arc: arc,
        order: order,
      );

  Map<String, Object> toJson() => {
        'id': id,
        'title': title,
        'status': status.name,
        'pov': pov,
        'arc': arc,
        'order': order,
      };

  factory PlanningScene.fromJson(Map<String, dynamic> json) => PlanningScene(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? 'Untitled Scene',
        status: SceneStatus.values.firstWhere(
          (status) => status.name == json['status'],
          orElse: () => SceneStatus.backlog,
        ),
        pov: json['pov'] as String? ?? 'Unassigned',
        arc: json['arc'] as String? ?? 'Main Plot',
        order: json['order'] as int? ?? 0,
      );
}

class VisualPlanningState {
  const VisualPlanningState({required this.scenes, required this.overlay});

  final List<PlanningScene> scenes;
  final StructureOverlay overlay;

  VisualPlanningState copyWith({
    List<PlanningScene>? scenes,
    StructureOverlay? overlay,
  }) =>
      VisualPlanningState(
        scenes: scenes ?? this.scenes,
        overlay: overlay ?? this.overlay,
      );
}

class VisualPlanningStore {
  const VisualPlanningStore();

  String _key(String projectId) =>
      'author_studio.project.$projectId.visual_planning';

  Future<VisualPlanningState> load(StarterProject project) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_key(project.id));
    if (encoded == null) {
      return VisualPlanningState(
        scenes: createStarterScenes(project),
        overlay: StructureOverlay.none,
      );
    }

    final json = Map<String, dynamic>.from(jsonDecode(encoded) as Map);
    return VisualPlanningState(
      scenes: (json['scenes'] as List? ?? const [])
          .map((scene) => PlanningScene.fromJson(
                Map<String, dynamic>.from(scene as Map),
              ))
          .toList(),
      overlay: StructureOverlay.values.firstWhere(
        (overlay) => overlay.name == json['overlay'],
        orElse: () => StructureOverlay.none,
      ),
    );
  }

  Future<void> save(String projectId, VisualPlanningState state) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key(projectId),
      jsonEncode({
        'scenes': state.scenes.map((scene) => scene.toJson()).toList(),
        'overlay': state.overlay.name,
      }),
    );
  }

  List<PlanningScene> createStarterScenes(StarterProject project) {
    final template = StoryTemplateLibrary.templateFor(project.templateName) ??
        StoryTemplateLibrary.templateFor(project.genre);
    final povs = project.characterSheets.isEmpty
        ? const ['Unassigned']
        : project.characterSheets.map((sheet) => sheet.name).toList();
    final sceneSuggestions = template?.sceneSuggestions ??
        const [
          'Opening Scene',
          'Rising Tension',
          'The Pivot',
          'The Pressure Mounts',
          'The Turn',
          'The Resolution',
        ];
    final arcNames = template?.arcNames ??
        const [
          'Main Plot',
          'Character Arc',
          'Relationship Arc',
        ];

    return List.generate(6, (index) {
      final chapter = project.chapters[index % project.chapters.length];
      final nextTitle = index == 0
          ? project.firstSceneTitle
          : (index < sceneSuggestions.length
              ? sceneSuggestions[index]
              : '${chapter.title} · Beat ${index + 1}');
      return PlanningScene(
        id: '${project.id}_scene_${index + 1}',
        title: nextTitle,
        status: index < 2 ? SceneStatus.outlining : SceneStatus.backlog,
        pov: povs[index % povs.length],
        arc: arcNames[index % arcNames.length],
        order: index + 1,
      );
    });
  }
}

class VisualPlanningView extends StatefulWidget {
  const VisualPlanningView({super.key, required this.project});

  final StarterProject project;

  @override
  State<VisualPlanningView> createState() => _VisualPlanningViewState();
}

class _VisualPlanningViewState extends State<VisualPlanningView> {
  static const pageSize = 20;
  VisualPlanningState? planning;
  SceneStatus? statusFilter;
  String? povFilter;
  String? arcFilter;
  final searchController = TextEditingController();
  int visibleSceneCount = pageSize;

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

  Future<void> _load() async {
    final loaded = await const VisualPlanningStore().load(widget.project);
    if (mounted) {
      setState(() => planning = loaded);
    }
  }

  Future<void> _save(VisualPlanningState updated) async {
    setState(() => planning = updated);
    await const VisualPlanningStore().save(widget.project.id, updated);
  }

  List<PlanningScene> get filteredScenes {
    final scenes = planning?.scenes ?? const [];
    final query = searchController.text.trim().toLowerCase();
    return scenes.where((scene) {
      return (statusFilter == null || scene.status == statusFilter) &&
          (povFilter == null || scene.pov == povFilter) &&
          (arcFilter == null || scene.arc == arcFilter) &&
          (query.isEmpty || scene.title.toLowerCase().contains(query));
    }).toList();
  }

  void _updateFilters(VoidCallback update) {
    setState(() {
      update();
      visibleSceneCount = pageSize;
    });
  }

  void _moveScene(PlanningScene scene, SceneStatus status) {
    final current = planning;
    if (current == null || scene.status == status) {
      return;
    }
    _save(current.copyWith(
      scenes: current.scenes
          .map((item) =>
              item.id == scene.id ? item.copyWith(status: status) : item)
          .toList(),
    ));
  }

  String _overlayStage(PlanningScene scene, VisualPlanningState current) {
    final stages = current.overlay.stages;
    if (stages.isEmpty || current.scenes.isEmpty) {
      return '';
    }
    final index = ((scene.order - 1) * stages.length ~/ current.scenes.length)
        .clamp(0, stages.length - 1);
    return stages[index];
  }

  @override
  Widget build(BuildContext context) {
    final current = planning;
    if (current == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final povs = current.scenes.map((scene) => scene.pov).toSet().toList()
      ..sort();
    final arcs = current.scenes.map((scene) => scene.arc).toSet().toList()
      ..sort();
    final visibleStatuses =
        statusFilter == null ? SceneStatus.values : [statusFilter!];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Visual Planning',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Shape scenes by workflow, story structure, point of view, and arc.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Structure overlay',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<StructureOverlay>(
                  key: const Key('structure-overlay-control'),
                  showSelectedIcon: false,
                  segments: StructureOverlay.values
                      .map((overlay) => ButtonSegment(
                            value: overlay,
                            label: Text(overlay.label),
                          ))
                      .toList(),
                  selected: {current.overlay},
                  onSelectionChanged: (selection) =>
                      _save(current.copyWith(overlay: selection.first)),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: 240,
                    child: TextField(
                      key: const Key('scene-search-field'),
                      controller: searchController,
                      onChanged: (_) => _updateFilters(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Search scenes',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  KeyedSubtree(
                    key: ValueKey('status-${statusFilter?.name ?? 'all'}'),
                    child: _PlanningFilter<SceneStatus>(
                      fieldKey: const Key('status-filter'),
                      label: 'Status',
                      value: statusFilter,
                      items: SceneStatus.values,
                      itemLabel: (status) => status.label,
                      onChanged: (value) =>
                          _updateFilters(() => statusFilter = value),
                    ),
                  ),
                  KeyedSubtree(
                    key: ValueKey('pov-${povFilter ?? 'all'}'),
                    child: _PlanningFilter<String>(
                      fieldKey: const Key('pov-filter'),
                      label: 'POV',
                      value: povFilter,
                      items: povs,
                      itemLabel: (value) => value,
                      onChanged: (value) =>
                          _updateFilters(() => povFilter = value),
                    ),
                  ),
                  KeyedSubtree(
                    key: ValueKey('arc-${arcFilter ?? 'all'}'),
                    child: _PlanningFilter<String>(
                      fieldKey: const Key('arc-filter'),
                      label: 'Arc',
                      value: arcFilter,
                      items: arcs,
                      itemLabel: (value) => value,
                      onChanged: (value) =>
                          _updateFilters(() => arcFilter = value),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _updateFilters(() {
                      statusFilter = null;
                      povFilter = null;
                      arcFilter = null;
                      searchController.clear();
                    }),
                    icon: const Icon(Icons.filter_alt_off_outlined),
                    label: const Text('Clear filters'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${filteredScenes.length} of ${current.scenes.length} scenes',
          key: const Key('scene-filter-count'),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final status in visibleStatuses) ...[
                _SceneLane(
                  status: status,
                  scenes: filteredScenes
                      .where((scene) => scene.status == status)
                      .take(visibleSceneCount)
                      .toList(),
                  overlayStage: (scene) => _overlayStage(scene, current),
                  onMove: _moveScene,
                ),
                if (status != visibleStatuses.last) const SizedBox(width: 12),
              ],
            ],
          ),
        ),
        if (filteredScenes.length > visibleSceneCount) ...[
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton.icon(
              key: const Key('load-more-scenes'),
              onPressed: () => setState(() => visibleSceneCount += pageSize),
              icon: const Icon(Icons.expand_more),
              label: Text(
                'Load ${filteredScenes.length - visibleSceneCount > pageSize ? pageSize : filteredScenes.length - visibleSceneCount} more scenes',
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PlanningFilter<T> extends StatelessWidget {
  const _PlanningFilter({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  final Key fieldKey;
  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: DropdownButtonFormField<T?>(
        key: fieldKey,
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        hint: const Text('All'),
        items: [
          DropdownMenuItem<T?>(value: null, child: const Text('All')),
          ...items.map((item) => DropdownMenuItem<T?>(
                value: item,
                child: Text(itemLabel(item), overflow: TextOverflow.ellipsis),
              )),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _SceneLane extends StatelessWidget {
  const _SceneLane({
    required this.status,
    required this.scenes,
    required this.overlayStage,
    required this.onMove,
  });

  final SceneStatus status;
  final List<PlanningScene> scenes;
  final String Function(PlanningScene) overlayStage;
  final void Function(PlanningScene, SceneStatus) onMove;

  @override
  Widget build(BuildContext context) {
    return DragTarget<PlanningScene>(
      onAcceptWithDetails: (details) => onMove(details.data, status),
      builder: (context, candidates, rejected) => Container(
        key: Key('scene-lane-${status.name}'),
        width: 250,
        constraints: const BoxConstraints(minHeight: 280),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: candidates.isEmpty
              ? Theme.of(context).colorScheme.surface
              : status.colorIn(context).withValues(alpha: 0.16),
          border: Border.all(
            color: candidates.isEmpty
                ? Theme.of(context).colorScheme.outlineVariant
                : status.colorIn(context),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  color: status.colorIn(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(status.label,
                        style: const TextStyle(fontWeight: FontWeight.w700))),
                Text(
                  '${scenes.length}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (scenes.isEmpty)
              Text(
                'No matching scenes',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              )
            else
              for (final scene in scenes) ...[
                Draggable<PlanningScene>(
                  data: scene,
                  feedback: Material(
                    color: Colors.transparent,
                    child: SizedBox(
                        width: 220,
                        child: _SceneCard(
                            scene: scene, overlay: overlayStage(scene))),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.35,
                    child:
                        _SceneCard(scene: scene, overlay: overlayStage(scene)),
                  ),
                  child: _SceneCard(scene: scene, overlay: overlayStage(scene)),
                ),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }
}

class _SceneCard extends StatelessWidget {
  const _SceneCard({required this.scene, required this.overlay});

  final PlanningScene scene;
  final String overlay;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('scene-card-${scene.id}'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (overlay.isNotEmpty) ...[
            Text(
              overlay,
              key: Key('scene-overlay-${scene.id}'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
          ],
          Text(scene.title,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'POV · ${scene.pov}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 12,
            ),
          ),
          Text(
            'Arc · ${scene.arc}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

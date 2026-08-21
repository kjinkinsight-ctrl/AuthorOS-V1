import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/version_audit.dart';
import 'manuscript_export.dart';
import 'manuscript_service.dart';
import 'manuscript_store.dart';
import 'manuscript_workspace.dart';
import 'onboarding.dart';
import 'persistence/authoros_database.dart';
import 'reading_rhythm.dart';

class ManuscriptStudioView extends StatefulWidget {
  const ManuscriptStudioView({
    super.key,
    required this.project,
    required this.startSprint,
    this.minimalMode = false,
    this.store = const ManuscriptStore(),
    this.repository,
    this.activeBranchId,
    this.onNavigate,
  });

  final StarterProject project;
  final bool startSprint;
  final bool minimalMode;
  final ManuscriptStore store;

  /// The shared connected-domain repository. Defaults to the app-wide one so
  /// the Studio reads and writes the same records as every other Studio.
  final DriftConnectedDomainRepository? repository;

  /// When set, the manuscript is Canon and read-only: a branch is active.
  final String? activeBranchId;

  /// Opens a connected record in the Studio that owns it.
  final ValueChanged<ManuscriptNavigationRequest>? onNavigate;

  @override
  State<ManuscriptStudioView> createState() => _ManuscriptStudioViewState();
}

enum ManuscriptSelectionKind {
  manuscript,
  chapter,
  scene,
}

class _ManuscriptSelection {
  const _ManuscriptSelection.manuscript()
      : kind = ManuscriptSelectionKind.manuscript,
        chapterId = '',
        sceneId = '';

  const _ManuscriptSelection.chapter(this.chapterId)
      : kind = ManuscriptSelectionKind.chapter,
        sceneId = '';

  const _ManuscriptSelection.scene(this.chapterId, this.sceneId)
      : kind = ManuscriptSelectionKind.scene;

  final ManuscriptSelectionKind kind;
  final String chapterId;
  final String sceneId;
}

class _NewSceneIntent extends Intent {
  const _NewSceneIntent();
}

class _NewChapterIntent extends Intent {
  const _NewChapterIntent();
}

class _SearchIntent extends Intent {
  const _SearchIntent();
}

class _SaveIntent extends Intent {
  const _SaveIntent();
}

class _ManuscriptStudioViewState extends State<ManuscriptStudioView>
    with WidgetsBindingObserver {
  final TextEditingController _editorController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  final TextEditingController _filterController = TextEditingController();

  final Set<String> _collapsedChapterIds = <String>{};

  /// Node ids whose next save should also write a history entry. Autosaving
  /// prose does not advance history; structural edits do.
  final Set<String> _pendingHistory = <String>{};

  ManuscriptProjectSummary? _manuscript;
  _ManuscriptSelection _selection = const _ManuscriptSelection.manuscript();
  ManuscriptFilter _filter = const ManuscriptFilter();
  List<ManuscriptSceneMatch> _filterMatches = const [];
  bool _showConnectedPane = false;

  AuditChangeType _pendingChangeType = AuditChangeType.updated;

  bool _loading = true;
  bool _saving = false;
  bool _isApplyingSelection = false;
  bool _showSearchResults = false;
  Timer? _saveTimer;
  Timer? _sprintTimer;
  int _sprintSeconds = 15 * 60;
  ReadingRhythmPreset _readingRhythm = ReadingRhythmPreset.standard;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _editorController.addListener(_onEditorChanged);
    if (widget.startSprint) {
      _sprintTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || _sprintSeconds <= 0) {
          timer.cancel();
          return;
        }
        setState(() => _sprintSeconds--);
      });
    }
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _flushSave();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    _sprintTimer?.cancel();
    final snapshot = _manuscript;
    if (snapshot != null && widget.activeBranchId == null) {
      // Save without setState to avoid lifecycle assertions during disposal.
      // A branch never writes: the manuscript is Canon and read-only.
      widget.store.saveStudio(snapshot);
    }
    _editorController.removeListener(_onEditorChanged);
    _editorController.dispose();
    _searchController.dispose();
    _filterController.dispose();
    super.dispose();
  }

  /// The connected-domain repository this Studio reads and writes.
  ///
  /// The store's own repository wins when one was supplied, so the Studio and
  /// its manuscript store never end up on two different databases.
  DriftConnectedDomainRepository get _repository =>
      widget.repository ?? widget.store.repository ?? authorOsRepository;

  ManuscriptService get _service => ManuscriptService(
        projectId: widget.project.id,
        repository: _repository,
        store: widget.store,
        activeBranchId: widget.activeBranchId,
      );

  bool get _canEdit => widget.activeBranchId == null;

  Future<void> _applyFilter(ManuscriptFilter filter) async {
    final manuscript = _manuscript;
    setState(() => _filter = filter);
    if (manuscript == null) {
      return;
    }
    final matches = filter.isEmpty
        ? const <ManuscriptSceneMatch>[]
        : await _service.filterScenes(manuscript, filter);
    if (!mounted) {
      return;
    }
    setState(() => _filterMatches = matches);
  }

  Future<void> _load() async {
    _readingRhythm = await const ReadingRhythmStore().load(widget.project.id);
    final migratedChapters =
        await widget.store.loadLegacyChapterSeeds(widget.project.id);
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

    final data = await widget.store.loadStudio(
      widget.project.id,
      manuscriptTitle: widget.project.title,
      defaultChapters: chapterSeeds,
      firstSceneTitle: widget.project.firstSceneTitle,
    );

    if (!mounted) {
      return;
    }

    final initialSelection = _resolveInitialSelection(data);
    _selection = initialSelection;
    _manuscript = data;
    _syncEditorWithSelection();

    setState(() {
      _loading = false;
    });
  }

  _ManuscriptSelection _resolveInitialSelection(ManuscriptProjectSummary data) {
    if (data.currentSceneId.trim().isNotEmpty &&
        data.sceneById(data.currentSceneId) != null) {
      final scene = data.sceneById(data.currentSceneId)!;
      return _ManuscriptSelection.scene(scene.chapterId, scene.id);
    }
    if (data.currentChapterId.trim().isNotEmpty &&
        data.chapterById(data.currentChapterId) != null) {
      return _ManuscriptSelection.chapter(data.currentChapterId);
    }
    if (data.chapters.isNotEmpty && data.chapters.first.scenes.isNotEmpty) {
      final first = data.chapters.first;
      return _ManuscriptSelection.scene(first.id, first.scenes.first.id);
    }
    if (data.chapters.isNotEmpty) {
      return _ManuscriptSelection.chapter(data.chapters.first.id);
    }
    return const _ManuscriptSelection.manuscript();
  }

  void _onEditorChanged() {
    if (_isApplyingSelection || _loading) {
      return;
    }
    final manuscript = _manuscript;
    if (manuscript == null ||
        _selection.kind != ManuscriptSelectionKind.scene) {
      return;
    }

    final chapter = manuscript.chapterById(_selection.chapterId);
    if (chapter == null) {
      return;
    }

    final sceneIndex =
        chapter.scenes.indexWhere((scene) => scene.id == _selection.sceneId);
    if (sceneIndex < 0) {
      return;
    }

    final scene = chapter.scenes[sceneIndex];
    if (scene.content == _editorController.text) {
      return;
    }

    final updatedScene = scene.copyWith(
      content: _editorController.text,
      updatedAt: DateTime.now(),
    );

    _setScene(chapter.id, sceneIndex, updatedScene);
    _scheduleSave();
  }

  void _setScene(
      String chapterId, int sceneIndex, ManuscriptScene updatedScene) {
    final manuscript = _manuscript;
    if (manuscript == null) {
      return;
    }
    final chapters = [...manuscript.chapters];
    final chapterIndex =
        chapters.indexWhere((chapter) => chapter.id == chapterId);
    if (chapterIndex < 0) {
      return;
    }
    final chapter = chapters[chapterIndex];
    final scenes = [...chapter.scenes];
    scenes[sceneIndex] = updatedScene;
    chapters[chapterIndex] = chapter.copyWith(
      scenes: scenes,
      updatedAt: DateTime.now(),
    );

    _manuscript = manuscript.copyWith(
      chapters: _normalizeChapterAndSceneOrder(chapters),
      currentChapterId: chapter.id,
      currentSceneId: updatedScene.id,
      updatedAt: DateTime.now(),
      version: 2,
    );
    if (mounted) {
      setState(() {});
    }
  }

  List<ManuscriptChapter> _normalizeChapterAndSceneOrder(
      List<ManuscriptChapter> source) {
    return [
      for (var chapterIndex = 0; chapterIndex < source.length; chapterIndex++)
        source[chapterIndex].copyWith(
          order: chapterIndex + 1,
          scenes: [
            for (var sceneIndex = 0;
                sceneIndex < source[chapterIndex].scenes.length;
                sceneIndex++)
              source[chapterIndex].scenes[sceneIndex].copyWith(
                    chapterId: source[chapterIndex].id,
                    order: sceneIndex + 1,
                  )
          ],
        )
    ];
  }

  void _syncEditorWithSelection() {
    final manuscript = _manuscript;
    if (manuscript == null) {
      return;
    }

    _isApplyingSelection = true;
    try {
      if (_selection.kind == ManuscriptSelectionKind.scene) {
        final scene = manuscript.sceneById(_selection.sceneId);
        _editorController.text = scene?.content ?? '';
      } else {
        _editorController.text = '';
      }
    } finally {
      _isApplyingSelection = false;
    }
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 700), _flushSave);
  }

  String get _sprintLabel {
    final minutes = (_sprintSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_sprintSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _buildReadingRhythmControl() {
    return SegmentedButton<ReadingRhythmPreset>(
      key: const Key('reading-rhythm-control'),
      segments: [
        for (final preset in ReadingRhythmPreset.values)
          ButtonSegment(value: preset, label: Text(preset.label)),
      ],
      selected: {_readingRhythm},
      onSelectionChanged: (selection) {
        final preset = selection.first;
        setState(() => _readingRhythm = preset);
        const ReadingRhythmStore().save(widget.project.id, preset);
      },
    );
  }

  Future<void> _flushSave({bool updateUi = true}) async {
    _saveTimer?.cancel();
    final manuscript = _manuscript;
    if (manuscript == null) {
      return;
    }
    if (!_canEdit) {
      // The manuscript is Canon and a branch is active: never write.
      return;
    }
    if (updateUi && mounted) {
      setState(() {
        _saving = true;
      });
    }
    final changed = _pendingHistory.toSet();
    _pendingHistory.clear();
    final saved = await _service.save(
      manuscript,
      changed: changed,
      changeType: _pendingChangeType,
    );
    _pendingChangeType = AuditChangeType.updated;
    // Only adopt the normalized copy when nothing was typed while the save
    // was in flight, so an in-progress keystroke is never overwritten.
    if (mounted && identical(_manuscript, manuscript)) {
      _manuscript = saved;
    }
    if (updateUi && mounted) {
      setState(() {
        _saving = false;
      });
    }
  }

  /// Marks [nodeIds] as needing a history entry on the next save.
  void _recordHistoryFor(
    Iterable<String> nodeIds, {
    AuditChangeType changeType = AuditChangeType.updated,
  }) {
    _pendingHistory.addAll(nodeIds.where((id) => id.trim().isNotEmpty));
    _pendingChangeType = changeType;
  }

  void _selectManuscript() {
    setState(() {
      _selection = const _ManuscriptSelection.manuscript();
      _showSearchResults = false;
    });
    _syncEditorWithSelection();
    _scheduleSave();
  }

  void _selectChapter(String chapterId) {
    setState(() {
      _selection = _ManuscriptSelection.chapter(chapterId);
      _showSearchResults = false;
    });
    _syncEditorWithSelection();
    _scheduleSave();
  }

  void _selectScene(String chapterId, String sceneId) {
    final manuscript = _manuscript;
    if (manuscript == null) {
      return;
    }
    setState(() {
      _selection = _ManuscriptSelection.scene(chapterId, sceneId);
      _manuscript = manuscript.copyWith(
        currentChapterId: chapterId,
        currentSceneId: sceneId,
        updatedAt: DateTime.now(),
      );
      _showSearchResults = false;
    });
    _syncEditorWithSelection();
    _scheduleSave();
  }

  Future<void> _createChapter() async {
    final title = await _promptForText(
      title: 'New chapter',
      label: 'Chapter title',
      initialValue:
          'Chapter ${((_manuscript?.chapterCount ?? 0) + 1).toString().padLeft(2, '0')}',
    );
    if (title == null) {
      return;
    }
    final manuscript = _manuscript;
    if (manuscript == null) {
      return;
    }
    final now = DateTime.now();
    final nextChapter = ManuscriptChapter(
      id: ManuscriptId.create('chapter'),
      title: title,
      order: manuscript.chapters.length + 1,
      status: ManuscriptNodeStatus.planned,
      createdAt: now,
      updatedAt: now,
    );

    final chapters = [...manuscript.chapters, nextChapter];
    final normalized = _normalizeChapterAndSceneOrder(chapters);
    setState(() {
      _manuscript = manuscript.copyWith(
        chapters: normalized,
        currentChapterId: nextChapter.id,
        currentSceneId: '',
        updatedAt: now,
      );
      _selection = _ManuscriptSelection.chapter(nextChapter.id);
      _collapsedChapterIds.remove(nextChapter.id);
    });
    _recordHistoryFor([nextChapter.id], changeType: AuditChangeType.created);
    _syncEditorWithSelection();
    _scheduleSave();
  }

  Future<void> _createScene(String chapterId) async {
    final manuscript = _manuscript;
    if (manuscript == null) {
      return;
    }
    final chapterIndex =
        manuscript.chapters.indexWhere((item) => item.id == chapterId);
    if (chapterIndex < 0) {
      return;
    }

    final title = await _promptForText(
      title: 'New scene',
      label: 'Scene title',
      initialValue:
          'Scene ${(manuscript.chapters[chapterIndex].scenes.length + 1).toString().padLeft(2, '0')}',
    );
    if (title == null) {
      return;
    }

    final chapter = manuscript.chapters[chapterIndex];
    final now = DateTime.now();
    final nextScene = ManuscriptScene(
      id: ManuscriptId.create('scene'),
      chapterId: chapter.id,
      title: title,
      order: chapter.scenes.length + 1,
      content: '',
      status: ManuscriptNodeStatus.planned,
      createdAt: now,
      updatedAt: now,
    );

    final updatedChapter = chapter.copyWith(
      scenes: [...chapter.scenes, nextScene],
      updatedAt: now,
    );

    final chapters = [...manuscript.chapters];
    chapters[chapterIndex] = updatedChapter;

    setState(() {
      _manuscript = manuscript.copyWith(
        chapters: _normalizeChapterAndSceneOrder(chapters),
        currentChapterId: chapter.id,
        currentSceneId: nextScene.id,
        updatedAt: now,
      );
      _selection = _ManuscriptSelection.scene(chapter.id, nextScene.id);
      _collapsedChapterIds.remove(chapter.id);
    });
    _recordHistoryFor([nextScene.id], changeType: AuditChangeType.created);
    _syncEditorWithSelection();
    _scheduleSave();
  }

  Future<void> _renameChapter(ManuscriptChapter chapter) async {
    final next = await _promptForText(
      title: 'Rename chapter',
      label: 'Chapter title',
      initialValue: chapter.title,
    );
    if (next == null) {
      return;
    }
    _recordHistoryFor([chapter.id], changeType: AuditChangeType.renamed);
    _updateChapter(chapter.id,
        (value) => value.copyWith(title: next, updatedAt: DateTime.now()));
  }

  Future<void> _renameScene(ManuscriptScene scene) async {
    final next = await _promptForText(
      title: 'Rename scene',
      label: 'Scene title',
      initialValue: scene.title,
    );
    if (next == null) {
      return;
    }

    _recordHistoryFor([scene.id], changeType: AuditChangeType.renamed);
    _updateSceneById(
      scene.id,
      (value) => value.copyWith(title: next, updatedAt: DateTime.now()),
    );
  }

  void _updateChapter(
      String chapterId, ManuscriptChapter Function(ManuscriptChapter) updater) {
    final manuscript = _manuscript;
    if (manuscript == null) {
      return;
    }
    final index =
        manuscript.chapters.indexWhere((chapter) => chapter.id == chapterId);
    if (index < 0) {
      return;
    }
    final chapters = [...manuscript.chapters];
    chapters[index] = updater(chapters[index]);
    setState(() {
      _manuscript = manuscript.copyWith(
        chapters: _normalizeChapterAndSceneOrder(chapters),
        updatedAt: DateTime.now(),
      );
    });
    _scheduleSave();
  }

  void _updateSceneById(
      String sceneId, ManuscriptScene Function(ManuscriptScene) updater) {
    final manuscript = _manuscript;
    if (manuscript == null) {
      return;
    }

    final chapters = [...manuscript.chapters];
    for (var chapterIndex = 0; chapterIndex < chapters.length; chapterIndex++) {
      final sceneIndex = chapters[chapterIndex]
          .scenes
          .indexWhere((scene) => scene.id == sceneId);
      if (sceneIndex < 0) {
        continue;
      }
      final scenes = [...chapters[chapterIndex].scenes];
      scenes[sceneIndex] = updater(scenes[sceneIndex]);
      chapters[chapterIndex] = chapters[chapterIndex].copyWith(
        scenes: scenes,
        updatedAt: DateTime.now(),
      );
      setState(() {
        _manuscript = manuscript.copyWith(
          chapters: _normalizeChapterAndSceneOrder(chapters),
          updatedAt: DateTime.now(),
        );
      });
      _scheduleSave();
      return;
    }
  }

  Future<void> _deleteChapter(ManuscriptChapter chapter) async {
    final manuscript = _manuscript;
    if (manuscript == null) {
      return;
    }
    final analysis = await _service.analyzeDelete(manuscript, chapter.id);
    if (!mounted) {
      return;
    }
    if (analysis != null && !analysis.canDelete) {
      await _showBlockedDelete(chapter.title, analysis.blockingReasons);
      return;
    }
    final confirmed = await _confirmDelete(
      title: 'Delete chapter?',
      message: [
        'This will delete ${chapter.title} and all scenes in it.',
        ...?analysis?.warnings,
      ].join('\n\n'),
    );
    if (!confirmed) {
      return;
    }
    await _flushSave();
    final current = _manuscript;
    if (current == null) {
      return;
    }
    try {
      final next = await _service.deleteChapter(
        current,
        chapter.id,
        confirmed: true,
      );
      if (!mounted) {
        return;
      }
      final nextSelection = next.chapters.isEmpty
          ? const _ManuscriptSelection.manuscript()
          : (next.chapters.first.scenes.isEmpty
              ? _ManuscriptSelection.chapter(next.chapters.first.id)
              : _ManuscriptSelection.scene(
                  next.chapters.first.id, next.chapters.first.scenes.first.id));
      setState(() {
        _selection = nextSelection;
        _manuscript = next.copyWith(
          currentChapterId: nextSelection.chapterId,
          currentSceneId: nextSelection.sceneId,
        );
      });
      _syncEditorWithSelection();
      _scheduleSave();
    } on Object catch (error) {
      if (mounted) {
        await _showBlockedDelete(chapter.title, [error.toString()]);
      }
    }
  }

  Future<void> _showBlockedDelete(String title, List<String> reasons) =>
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          key: const Key('manuscript-delete-blocked'),
          title: Text('$title cannot be deleted'),
          content: Text(reasons.join('\n\n')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );

  Future<void> _deleteScene(ManuscriptScene scene) async {
    final manuscript = _manuscript;
    if (manuscript == null) {
      return;
    }
    final analysis = await _service.analyzeDelete(manuscript, scene.id);
    if (!mounted) {
      return;
    }
    if (analysis != null && !analysis.canDelete) {
      await _showBlockedDelete(scene.title, analysis.blockingReasons);
      return;
    }
    final confirmed = await _confirmDelete(
      title: 'Delete scene?',
      message: [
        'This will delete ${scene.title}.',
        ...?analysis?.warnings,
      ].join('\n\n'),
    );
    if (!confirmed) {
      return;
    }
    await _flushSave();
    final current = _manuscript;
    if (current == null) {
      return;
    }
    try {
      final next = await _service.deleteScene(
        current,
        scene.id,
        confirmed: true,
      );
      if (!mounted) {
        return;
      }
      final fallback = _firstSceneSelection(next.chapters) ??
          (next.chapters.isNotEmpty
              ? _ManuscriptSelection.chapter(next.chapters.first.id)
              : const _ManuscriptSelection.manuscript());
      setState(() {
        _selection = fallback;
        _manuscript = next.copyWith(
          currentChapterId: fallback.chapterId,
          currentSceneId: fallback.sceneId,
        );
      });
      _syncEditorWithSelection();
      _scheduleSave();
    } on Object catch (error) {
      if (mounted) {
        await _showBlockedDelete(scene.title, [error.toString()]);
      }
    }
  }

  _ManuscriptSelection? _firstSceneSelection(List<ManuscriptChapter> chapters) {
    for (final chapter in chapters) {
      if (chapter.scenes.isNotEmpty) {
        return _ManuscriptSelection.scene(chapter.id, chapter.scenes.first.id);
      }
    }
    return null;
  }

  Future<void> _moveChapter(ManuscriptChapter chapter, int delta) async {
    final manuscript = _manuscript;
    if (manuscript == null) {
      return;
    }
    final chapters = [...manuscript.chapters]
      ..sort((a, b) => a.order.compareTo(b.order));
    final index = chapters.indexWhere((item) => item.id == chapter.id);
    final next = index + delta;
    if (index < 0 || next < 0 || next >= chapters.length) {
      return;
    }
    final item = chapters.removeAt(index);
    chapters.insert(next, item);

    setState(() {
      _manuscript = manuscript.copyWith(
        chapters: _normalizeChapterAndSceneOrder(chapters),
        updatedAt: DateTime.now(),
      );
    });
    _recordHistoryFor([chapter.id]);
    await _flushSave();
  }

  Future<void> _moveScene(ManuscriptScene scene, int delta) async {
    final manuscript = _manuscript;
    if (manuscript == null) {
      return;
    }
    final chapterIndex = manuscript.chapters
        .indexWhere((chapter) => chapter.id == scene.chapterId);
    if (chapterIndex < 0) {
      return;
    }
    final chapter = manuscript.chapters[chapterIndex];
    final sceneIndex = chapter.scenes.indexWhere((item) => item.id == scene.id);
    final next = sceneIndex + delta;
    if (sceneIndex < 0 || next < 0 || next >= chapter.scenes.length) {
      return;
    }

    final scenes = [...chapter.scenes];
    final item = scenes.removeAt(sceneIndex);
    scenes.insert(next, item);

    final chapters = [...manuscript.chapters];
    chapters[chapterIndex] =
        chapter.copyWith(scenes: scenes, updatedAt: DateTime.now());

    setState(() {
      _manuscript = manuscript.copyWith(
        chapters: _normalizeChapterAndSceneOrder(chapters),
        updatedAt: DateTime.now(),
      );
    });
    _recordHistoryFor([scene.id]);
    await _flushSave();
  }

  Future<void> _moveSceneToChapter(ManuscriptScene scene) async {
    final manuscript = _manuscript;
    if (manuscript == null) {
      return;
    }

    final choices = manuscript.chapters
        .where((chapter) => chapter.id != scene.chapterId)
        .toList();
    if (choices.isEmpty) {
      return;
    }

    String selectedChapterId = choices.first.id;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Move scene'),
          content: DropdownButtonFormField<String>(
            initialValue: selectedChapterId,
            items: choices
                .map((chapter) => DropdownMenuItem(
                      value: chapter.id,
                      child: Text(chapter.title),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setModalState(() => selectedChapterId = value);
              }
            },
            decoration: const InputDecoration(labelText: 'Destination chapter'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Move'),
            ),
          ],
        ),
      ),
    );

    if (accepted != true) {
      return;
    }

    final chapters = [...manuscript.chapters];
    final sourceIndex =
        chapters.indexWhere((chapter) => chapter.id == scene.chapterId);
    final destinationIndex =
        chapters.indexWhere((chapter) => chapter.id == selectedChapterId);
    if (sourceIndex < 0 || destinationIndex < 0) {
      return;
    }

    final sourceChapter = chapters[sourceIndex];
    final destinationChapter = chapters[destinationIndex];
    final sourceScenes =
        sourceChapter.scenes.where((item) => item.id != scene.id).toList();
    final movedScene = scene.copyWith(
        chapterId: destinationChapter.id, updatedAt: DateTime.now());
    final destinationScenes = [...destinationChapter.scenes, movedScene];

    chapters[sourceIndex] =
        sourceChapter.copyWith(scenes: sourceScenes, updatedAt: DateTime.now());
    chapters[destinationIndex] = destinationChapter.copyWith(
      scenes: destinationScenes,
      updatedAt: DateTime.now(),
    );

    final normalized = _normalizeChapterAndSceneOrder(chapters);
    setState(() {
      _manuscript =
          manuscript.copyWith(chapters: normalized, updatedAt: DateTime.now());
      _selection =
          _ManuscriptSelection.scene(destinationChapter.id, movedScene.id);
      _collapsedChapterIds.remove(destinationChapter.id);
    });
    _syncEditorWithSelection();
    _scheduleSave();
  }

  Future<void> _duplicateChapter(ManuscriptChapter chapter) async {
    final manuscript = _manuscript;
    if (manuscript == null) {
      return;
    }
    final now = DateTime.now();
    final newChapterId = ManuscriptId.create('chapter');

    final duplicatedScenes = chapter.scenes
        .map(
          (scene) => scene.copyWith(
            id: ManuscriptId.create('scene'),
            chapterId: newChapterId,
            createdAt: now,
            updatedAt: now,
          ),
        )
        .toList();

    final duplicate = chapter.copyWith(
      id: newChapterId,
      title: '${chapter.title} (Copy)',
      createdAt: now,
      updatedAt: now,
      scenes: duplicatedScenes,
    );

    final chapters = [...manuscript.chapters, duplicate];
    final normalized = _normalizeChapterAndSceneOrder(chapters);

    setState(() {
      _manuscript = manuscript.copyWith(chapters: normalized, updatedAt: now);
      _selection = _ManuscriptSelection.chapter(newChapterId);
      _collapsedChapterIds.remove(newChapterId);
    });
    _recordHistoryFor(
      [newChapterId, ...duplicatedScenes.map((item) => item.id)],
      changeType: AuditChangeType.duplicated,
    );
    _scheduleSave();
  }

  Future<void> _duplicateScene(ManuscriptScene scene) async {
    final manuscript = _manuscript;
    if (manuscript == null) {
      return;
    }

    final chapters = [...manuscript.chapters];
    final chapterIndex =
        chapters.indexWhere((chapter) => chapter.id == scene.chapterId);
    if (chapterIndex < 0) {
      return;
    }

    final chapter = chapters[chapterIndex];
    final now = DateTime.now();
    final duplicate = scene.copyWith(
      id: ManuscriptId.create('scene'),
      title: '${scene.title} (Copy)',
      createdAt: now,
      updatedAt: now,
    );

    final sceneIndex = chapter.scenes.indexWhere((item) => item.id == scene.id);
    final scenes = [...chapter.scenes];
    scenes.insert(sceneIndex + 1, duplicate);

    chapters[chapterIndex] = chapter.copyWith(scenes: scenes, updatedAt: now);
    final normalized = _normalizeChapterAndSceneOrder(chapters);

    setState(() {
      _manuscript = manuscript.copyWith(chapters: normalized, updatedAt: now);
      _selection = _ManuscriptSelection.scene(scene.chapterId, duplicate.id);
    });
    _recordHistoryFor([duplicate.id], changeType: AuditChangeType.duplicated);
    _syncEditorWithSelection();
    _scheduleSave();
  }

  Future<void> _setChapterStatus(
      ManuscriptChapter chapter, ManuscriptNodeStatus status) async {
    _recordHistoryFor([chapter.id], changeType: AuditChangeType.statusChanged);
    _updateChapter(chapter.id,
        (value) => value.copyWith(status: status, updatedAt: DateTime.now()));
  }

  Future<void> _setSceneStatus(
      ManuscriptScene scene, ManuscriptNodeStatus status) async {
    _recordHistoryFor([scene.id], changeType: AuditChangeType.statusChanged);
    _updateSceneById(scene.id,
        (value) => value.copyWith(status: status, updatedAt: DateTime.now()));
  }

  Future<void> _linkChapter(ManuscriptChapter chapter) async {
    final manuscript = _manuscript;
    if (manuscript == null) {
      return;
    }
    final choices = manuscript.chapters
        .where((candidate) =>
            candidate.id != chapter.id &&
            !chapter.linkedChapterIds.contains(candidate.id))
        .toList();
    if (choices.isEmpty) {
      return;
    }
    var selectedId = choices.first.id;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Link chapter'),
          content: DropdownButtonFormField<String>(
            initialValue: selectedId,
            decoration: const InputDecoration(labelText: 'Related chapter'),
            items: choices
                .map((candidate) => DropdownMenuItem(
                      value: candidate.id,
                      child: Text(candidate.title),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setModalState(() => selectedId = value);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Link'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true) {
      _updateChapter(
        chapter.id,
        (current) => current.copyWith(
          linkedChapterIds: [...current.linkedChapterIds, selectedId],
          updatedAt: DateTime.now(),
        ),
      );
    }
  }

  void _unlinkChapter(ManuscriptChapter chapter, String linkedChapterId) {
    _updateChapter(
      chapter.id,
      (current) => current.copyWith(
        linkedChapterIds: current.linkedChapterIds
            .where((id) => id != linkedChapterId)
            .toList(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _editChapterMetadata(ManuscriptChapter chapter) async {
    final pov = await _promptForText(
      title: 'Edit chapter details',
      label: 'POV',
      initialValue: chapter.pov,
    );
    if (pov == null) {
      return;
    }
    _updateChapter(
      chapter.id,
      (current) => current.copyWith(
        pov: pov,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _editSceneMetadata(ManuscriptScene scene) async {
    final povController = TextEditingController(text: scene.pov);
    final locationController = TextEditingController(text: scene.location);
    final timeController = TextEditingController(text: scene.timeLabel);
    final notesController = TextEditingController(text: scene.notes);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit scene details'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: povController,
                  decoration: const InputDecoration(labelText: 'POV'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(labelText: 'Location'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: timeController,
                  decoration: const InputDecoration(labelText: 'Time'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  maxLines: 4,
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
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      _updateSceneById(
        scene.id,
        (current) => current.copyWith(
          pov: povController.text.trim(),
          location: locationController.text.trim(),
          timeLabel: timeController.text.trim(),
          notes: notesController.text.trim(),
          updatedAt: DateTime.now(),
        ),
      );
    }
    povController.dispose();
    locationController.dispose();
    timeController.dispose();
    notesController.dispose();
  }

  Future<String?> _promptForText({
    required String title,
    required String label,
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
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

    if (accepted != true) {
      return null;
    }
    final value = controller.text.trim();
    if (value.isEmpty) {
      return null;
    }
    return value;
  }

  Future<bool> _confirmDelete({
    required String title,
    required String message,
  }) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    return accepted == true;
  }

  Future<void> _openExportDialog() async {
    final manuscript = _manuscript;
    if (manuscript == null) {
      return;
    }
    await _flushSave();
    if (!mounted) {
      return;
    }

    final selectedScene = _selection.kind == ManuscriptSelectionKind.scene
        ? manuscript.sceneById(_selection.sceneId)
        : null;

    final path = await showDialog<String>(
      context: context,
      builder: (context) => ManuscriptExportDialog(
        projectTitle: widget.project.title,
        sceneTitle: selectedScene?.title ?? 'Full Manuscript',
        manuscript: manuscript.exportAsSingleText(),
      ),
    );

    if (!mounted || path == null) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        // The browser owns the save dialog and reports no destination back, so
        // there is no path to name there — the file lands in downloads.
        content: Text(
          path.isEmpty ? 'Exported PDF to your downloads.' : 'Exported PDF to $path',
        ),
      ),
    );
  }

  List<_SceneSearchResult> _searchResults() {
    final manuscript = _manuscript;
    if (manuscript == null) {
      return const [];
    }
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return const [];
    }

    final results = <_SceneSearchResult>[];
    for (final chapter in manuscript.chapters) {
      final chapterText = '${chapter.title} ${chapter.prompt}'.toLowerCase();
      if (chapterText.contains(query)) {
        results.add(
          _SceneSearchResult(
            chapterId: chapter.id,
            sceneId: '',
            chapterTitle: chapter.title,
            sceneTitle: 'Chapter match',
            preview: chapter.prompt,
          ),
        );
      }
      for (final scene in chapter.scenes) {
        final haystack =
            '${scene.title} ${scene.content} ${scene.notes} ${scene.location} ${scene.pov}'
                .toLowerCase();
        if (haystack.contains(query)) {
          results.add(
            _SceneSearchResult(
              chapterId: chapter.id,
              sceneId: scene.id,
              chapterTitle: chapter.title,
              sceneTitle: scene.title,
              preview: scene.content,
            ),
          );
        }
      }
    }
    return results;
  }

  String _chapterTitle(String chapterId) {
    final chapter = _manuscript?.chapterById(chapterId);
    return chapter?.title ?? 'Chapter';
  }

  String _sceneTitle(String sceneId) {
    final scene = _manuscript?.sceneById(sceneId);
    return scene?.title ?? 'Scene';
  }

  SceneCursor? _previousSceneCursor() {
    final manuscript = _manuscript;
    if (manuscript == null ||
        _selection.kind != ManuscriptSelectionKind.scene) {
      return null;
    }
    final ordered = manuscript.orderedSceneCursors();
    final index = ordered.indexWhere(
      (cursor) =>
          cursor.chapterId == _selection.chapterId &&
          cursor.sceneId == _selection.sceneId,
    );
    if (index <= 0) {
      return null;
    }
    return ordered[index - 1];
  }

  SceneCursor? _nextSceneCursor() {
    final manuscript = _manuscript;
    if (manuscript == null ||
        _selection.kind != ManuscriptSelectionKind.scene) {
      return null;
    }
    final ordered = manuscript.orderedSceneCursors();
    final index = ordered.indexWhere(
      (cursor) =>
          cursor.chapterId == _selection.chapterId &&
          cursor.sceneId == _selection.sceneId,
    );
    if (index < 0 || index >= ordered.length - 1) {
      return null;
    }
    return ordered[index + 1];
  }

  void _toggleChapterCollapse(String chapterId) {
    setState(() {
      if (_collapsedChapterIds.contains(chapterId)) {
        _collapsedChapterIds.remove(chapterId);
      } else {
        _collapsedChapterIds.add(chapterId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final manuscript = _manuscript;
    if (manuscript == null) {
      return const SizedBox.shrink();
    }

    final scene = _selection.kind == ManuscriptSelectionKind.scene
        ? manuscript.sceneById(_selection.sceneId)
        : null;
    final chapter = _selection.kind == ManuscriptSelectionKind.manuscript
        ? null
        : manuscript.chapterById(_selection.chapterId);

    final body = widget.minimalMode
        ? _buildFocusEditor(manuscript, scene)
        : _buildStudioLayout(manuscript, chapter, scene);

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyN, control: true, shift: true):
            _NewSceneIntent(),
        SingleActivator(LogicalKeyboardKey.keyC, control: true, shift: true):
            _NewChapterIntent(),
        SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _SearchIntent(),
        SingleActivator(LogicalKeyboardKey.enter, control: true): _SaveIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _NewSceneIntent: CallbackAction<_NewSceneIntent>(
            onInvoke: (_) {
              final chapterId = _selection.kind == ManuscriptSelectionKind.scene
                  ? _selection.chapterId
                  : (_selection.kind == ManuscriptSelectionKind.chapter
                      ? _selection.chapterId
                      : '');
              if (chapterId.isNotEmpty) {
                _createScene(chapterId);
              }
              return null;
            },
          ),
          _NewChapterIntent: CallbackAction<_NewChapterIntent>(
            onInvoke: (_) {
              _createChapter();
              return null;
            },
          ),
          _SearchIntent: CallbackAction<_SearchIntent>(
            onInvoke: (_) {
              setState(() {
                _showSearchResults = true;
              });
              return null;
            },
          ),
          _SaveIntent: CallbackAction<_SaveIntent>(
            onInvoke: (_) {
              _flushSave();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: body,
        ),
      ),
    );
  }

  Widget _buildStudioLayout(
    ManuscriptProjectSummary manuscript,
    ManuscriptChapter? chapter,
    ManuscriptScene? scene,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1180;

        if (!isWide) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(manuscript, chapter, scene),
                const SizedBox(height: 12),
                SizedBox(height: 420, child: _buildNavigator(manuscript)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 560,
                  child: _buildCenterPanel(manuscript, chapter, scene),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 520,
                  child: _buildDetailsPanel(manuscript, chapter, scene),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(manuscript, chapter, scene),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 300, child: _buildNavigator(manuscript)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildCenterPanel(manuscript, chapter, scene)),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 320,
                    child: _buildDetailsPanel(manuscript, chapter, scene),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(
    ManuscriptProjectSummary manuscript,
    ManuscriptChapter? chapter,
    ManuscriptScene? scene,
  ) {
    final progress = manuscript.progressAgainst(widget.project.wordGoal);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
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
                  'Manuscript Studio',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              _badge('Words ${manuscript.wordCount}'),
              if (widget.startSprint) ...[
                const SizedBox(width: 8),
                _badge(_sprintLabel),
              ],
              const SizedBox(width: 8),
              _badge(_saving ? 'Saving' : 'Saved'),
            ],
          ),
          if (!_canEdit) ...[
            const SizedBox(height: 10),
            Container(
              key: const Key('manuscript-branch-banner'),
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The manuscript is Canon and read-only while the '
                      '${widget.activeBranchId} branch is active.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            widget.project.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            _selection.kind == ManuscriptSelectionKind.manuscript
                ? 'Manuscript'
                : (_selection.kind == ManuscriptSelectionKind.chapter
                    ? 'Manuscript / ${chapter?.title ?? ''}'
                    : 'Manuscript / ${chapter?.title ?? ''} / ${scene?.title ?? ''}'),
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _canEdit ? _createChapter : null,
                icon: const Icon(Icons.add),
                label: const Text('New Chapter'),
              ),
              OutlinedButton.icon(
                onPressed: chapter == null || !_canEdit
                    ? null
                    : () => _createScene(chapter.id),
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text('New Scene'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => _showSearchResults = !_showSearchResults);
                },
                icon: const Icon(Icons.search),
                label: const Text('Search'),
              ),
              IconButton.filledTonal(
                tooltip: 'Export manuscript',
                onPressed: _openExportDialog,
                icon: const Icon(Icons.ios_share_outlined),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildReadingRhythmControl(),
          const SizedBox(height: 10),
          ManuscriptProgressBar(
            label: scene != null
                ? 'Scene progress'
                : (chapter != null ? 'Chapter progress' : 'Manuscript progress'),
            progress: _service.progressFor(
              manuscript,
              goalWords: scene == null && chapter == null
                  ? widget.project.wordGoal
                  : 0,
              chapter: scene == null ? chapter : null,
              scene: scene,
            ),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            borderRadius: BorderRadius.circular(999),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text),
    );
  }

  Widget _buildNavigator(ManuscriptProjectSummary manuscript) {
    if (manuscript.chapters.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your manuscript is empty.',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
                'Start building your story by creating your first chapter.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _createChapter,
              icon: const Icon(Icons.add),
              label: const Text('New Chapter'),
            ),
          ],
        ),
      );
    }

    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('MANUSCRIPT',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                  '${manuscript.chapterCount} chapters • ${manuscript.sceneCount} scenes'),
              onTap: _selectManuscript,
              selected: _selection.kind == ManuscriptSelectionKind.manuscript,
            ),
            const Divider(),
            if (_showSearchResults) ...[
              ManuscriptFilterRail(
                manuscript: manuscript,
                filter: _filter,
                controller: _filterController,
                matchCount: _filterMatches.length,
                onChanged: _applyFilter,
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: !_showSearchResults || _filter.isEmpty
                  ? ListView(
                      children: [
                        for (final chapter in manuscript.chapters)
                          _buildChapterTreeNode(chapter),
                      ],
                    )
                  : ListView(
                      key: const Key('manuscript-filter-results'),
                      children: [
                        if (_filterMatches.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('No scenes match these filters.'),
                          ),
                        for (final match in _filterMatches)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Material(
                              color: match.scene.id == _selection.sceneId
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              child: ListTile(
                                key: Key('manuscript-match-${match.scene.id}'),
                                dense: true,
                                title: Text(
                                  '${match.chapter.title} / '
                                  '${match.scene.title}',
                                ),
                                subtitle: Text(
                                  match.snippet.isEmpty
                                      ? '${match.scene.status.label} • '
                                          '${match.scene.wordCount} words'
                                      : match.snippet,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () => _selectScene(
                                  match.chapter.id,
                                  match.scene.id,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterTreeNode(ManuscriptChapter chapter) {
    final isCollapsed = _collapsedChapterIds.contains(chapter.id);
    final chapterSelected =
        _selection.kind != ManuscriptSelectionKind.manuscript &&
            _selection.chapterId == chapter.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: chapterSelected
            ? Theme.of(context).colorScheme.primaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            ListTile(
              dense: true,
              onTap: () => _selectChapter(chapter.id),
              leading: IconButton(
                icon:
                    Icon(isCollapsed ? Icons.chevron_right : Icons.expand_more),
                onPressed: () => _toggleChapterCollapse(chapter.id),
              ),
              title: Text(
                  'Chapter ${chapter.order.toString().padLeft(2, '0')} - ${chapter.title}'),
              subtitle: Text(
                  '${chapter.scenes.length} scenes • ${chapter.wordCount} words'),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'open':
                      _selectChapter(chapter.id);
                    case 'rename':
                      _renameChapter(chapter);
                    case 'up':
                      _moveChapter(chapter, -1);
                    case 'down':
                      _moveChapter(chapter, 1);
                    case 'add_scene':
                      _createScene(chapter.id);
                    case 'duplicate':
                      _duplicateChapter(chapter);
                    case 'delete':
                      _deleteChapter(chapter);
                    case 'collapse':
                      _toggleChapterCollapse(chapter.id);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'open', child: Text('Open')),
                  PopupMenuItem(
                    value: 'rename',
                    enabled: _canEdit,
                    child: const Text('Rename'),
                  ),
                  PopupMenuItem(
                    key: ValueKey('chapter-move-up-${chapter.id}'),
                    value: 'up',
                    enabled: _canEdit,
                    child: const Text('Move up'),
                  ),
                  PopupMenuItem(
                    value: 'down',
                    enabled: _canEdit,
                    child: const Text('Move down'),
                  ),
                  PopupMenuItem(
                    value: 'add_scene',
                    enabled: _canEdit,
                    child: const Text('Add scene'),
                  ),
                  PopupMenuItem(
                    value: 'duplicate',
                    enabled: _canEdit,
                    child: const Text('Duplicate'),
                  ),
                  PopupMenuItem(
                    key: ValueKey('chapter-delete-${chapter.id}'),
                    value: 'delete',
                    enabled: _canEdit,
                    child: const Text('Delete'),
                  ),
                  const PopupMenuItem(
                      value: 'collapse', child: Text('Collapse/expand')),
                ],
              ),
            ),
            if (!isCollapsed)
              Padding(
                padding: const EdgeInsets.only(left: 38, right: 8, bottom: 8),
                child: Column(
                  children: [
                    for (final scene in chapter.scenes)
                      ListTile(
                        dense: true,
                        title: Text(
                            'Scene ${scene.order.toString().padLeft(2, '0')} - ${scene.title}'),
                        subtitle: Text('${scene.wordCount} words'),
                        selected:
                            _selection.kind == ManuscriptSelectionKind.scene &&
                                _selection.sceneId == scene.id,
                        onTap: () => _selectScene(chapter.id, scene.id),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            switch (value) {
                              case 'open':
                                _selectScene(chapter.id, scene.id);
                              case 'rename':
                                _renameScene(scene);
                              case 'up':
                                _moveScene(scene, -1);
                              case 'down':
                                _moveScene(scene, 1);
                              case 'duplicate':
                                _duplicateScene(scene);
                              case 'delete':
                                _deleteScene(scene);
                              case 'move_to':
                                _moveSceneToChapter(scene);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                                value: 'open', child: Text('Open')),
                            PopupMenuItem(
                              value: 'rename',
                              enabled: _canEdit,
                              child: const Text('Rename'),
                            ),
                            PopupMenuItem(
                              key: ValueKey('scene-move-up-${scene.id}'),
                              value: 'up',
                              enabled: _canEdit,
                              child: const Text('Move up'),
                            ),
                            PopupMenuItem(
                              key: ValueKey('scene-move-down-${scene.id}'),
                              value: 'down',
                              enabled: _canEdit,
                              child: const Text('Move down'),
                            ),
                            PopupMenuItem(
                              key: ValueKey('scene-duplicate-${scene.id}'),
                              value: 'duplicate',
                              enabled: _canEdit,
                              child: const Text('Duplicate'),
                            ),
                            PopupMenuItem(
                              key: ValueKey('scene-delete-${scene.id}'),
                              value: 'delete',
                              enabled: _canEdit,
                              child: const Text('Delete'),
                            ),
                            PopupMenuItem(
                              key: ValueKey('scene-move-to-${scene.id}'),
                              value: 'move_to',
                              enabled: _canEdit,
                              child: const Text('Move to chapter'),
                            ),
                          ],
                        ),
                      ),
                    if (chapter.scenes.isEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed:
                              !_canEdit ? null : () => _createScene(chapter.id),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Scene'),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterPanel(
    ManuscriptProjectSummary manuscript,
    ManuscriptChapter? chapter,
    ManuscriptScene? scene,
  ) {
    final previous = _previousSceneCursor();
    final next = _nextSceneCursor();

    if (_selection.kind == ManuscriptSelectionKind.manuscript) {
      return _buildManuscriptOverview(manuscript);
    }

    if (_selection.kind == ManuscriptSelectionKind.chapter) {
      if (chapter == null) {
        return const SizedBox.shrink();
      }
      return _buildChapterOverview(chapter);
    }

    if (scene == null || chapter == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${chapter.title} / ${scene.title}',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
              'Scene ${scene.order.toString().padLeft(2, '0')} • ${scene.wordCount} words'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: previous == null
                    ? null
                    : () => _selectScene(previous.chapterId, previous.sceneId),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Previous Scene'),
              ),
              OutlinedButton.icon(
                onPressed: next == null
                    ? null
                    : () => _selectScene(next.chapterId, next.sceneId),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next Scene'),
              ),
              TextButton(
                onPressed: _flushSave,
                child: const Text('Save now'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(maxWidth: _readingRhythm.editorWidth),
                child: TextField(
                  key: const Key('manuscript-draft-field'),
                  controller: _editorController,
                  readOnly: !_canEdit,
                  maxLines: null,
                  expands: true,
                  keyboardType: TextInputType.multiline,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: _readingRhythm.fontSize,
                        height: _readingRhythm.lineHeight,
                      ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Write this scene...',
                    contentPadding:
                        EdgeInsets.all(_readingRhythm.editorPadding),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusEditor(
      ManuscriptProjectSummary manuscript, ManuscriptScene? scene) {
    final chapter = _selection.kind == ManuscriptSelectionKind.scene
        ? manuscript.chapterById(_selection.chapterId)
        : null;
    final previous = _previousSceneCursor();
    final next = _nextSceneCursor();

    if (scene == null || chapter == null) {
      return _buildManuscriptOverview(manuscript);
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
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
                  'Manuscript / ${chapter.title} / ${scene.title}',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              _badge('${scene.wordCount} words'),
              if (widget.startSprint) ...[
                const SizedBox(width: 8),
                _badge(_sprintLabel),
              ],
              const SizedBox(width: 8),
              _badge(_saving ? 'Saving' : 'Saved'),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton(
                onPressed: previous == null
                    ? null
                    : () => _selectScene(previous.chapterId, previous.sceneId),
                child: const Text('Previous'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: next == null
                    ? null
                    : () => _selectScene(next.chapterId, next.sceneId),
                child: const Text('Next'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildReadingRhythmControl(),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(maxWidth: _readingRhythm.editorWidth),
                child: TextField(
                  key: const Key('manuscript-draft-field'),
                  controller: _editorController,
                  maxLines: null,
                  expands: true,
                  keyboardType: TextInputType.multiline,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: _readingRhythm.fontSize,
                        height: _readingRhythm.lineHeight,
                      ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Write this scene...',
                    contentPadding:
                        EdgeInsets.all(_readingRhythm.editorPadding),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManuscriptOverview(ManuscriptProjectSummary manuscript) {
    final progress = manuscript.progressAgainst(widget.project.wordGoal);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Manuscript Overview',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _metric('Total chapters', '${manuscript.chapterCount}'),
              _metric('Total scenes', '${manuscript.sceneCount}'),
              _metric('Total words', '${manuscript.wordCount}'),
              _metric('Goal progress', '${(progress * 100).round()}%'),
              _metric('Current chapter',
                  _chapterTitle(manuscript.currentChapterId)),
              _metric('Current scene', _sceneTitle(manuscript.currentSceneId)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 6),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildChapterOverview(ManuscriptChapter chapter) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(chapter.title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Total Word Count: ${chapter.wordCount}'),
          Text('Status: ${chapter.status.label}'),
          const SizedBox(height: 12),
          const Text('Scenes', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (chapter.scenes.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('This chapter has no scenes yet.'),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => _createScene(chapter.id),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Scene'),
                ),
              ],
            )
          else
            ...chapter.scenes.map(
              (scene) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                    '${scene.order.toString().padLeft(2, '0')} - ${scene.title}'),
                subtitle:
                    Text('${scene.wordCount} words • ${scene.status.label}'),
                onTap: () => _selectScene(chapter.id, scene.id),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailsPanel(
    ManuscriptProjectSummary manuscript,
    ManuscriptChapter? chapter,
    ManuscriptScene? scene,
  ) {
    final results = _searchResults();

    final nodeId = _selection.kind == ManuscriptSelectionKind.scene
        ? _selection.sceneId
        : (_selection.kind == ManuscriptSelectionKind.chapter
            ? _selection.chapterId
            : '');

    if (_showConnectedPane && nodeId.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDetailsModeSwitch(),
          const SizedBox(height: 8),
          Expanded(
            child: ManuscriptConnectedPanel(
              key: ValueKey('manuscript-panel-$nodeId'),
              service: _service,
              manuscript: manuscript,
              nodeId: nodeId,
              nodeKind: _selection.kind == ManuscriptSelectionKind.scene
                  ? ManuscriptNodeKind.scene
                  : ManuscriptNodeKind.chapter,
              onNavigate: widget.onNavigate,
              onChanged: _adoptManuscript,
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selection.kind == ManuscriptSelectionKind.manuscript
                ? 'MANUSCRIPT'
                : (_selection.kind == ManuscriptSelectionKind.chapter
                    ? 'CHAPTER'
                    : 'SCENE'),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: 8),
          if (nodeId.isNotEmpty) _buildDetailsModeSwitch(),
          const SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_showSearchResults) ...[
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Search manuscript',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (results.isEmpty)
                      const Text('No search results yet.')
                    else
                      ...results.map(
                        (item) => Material(
                          color: Colors.transparent,
                          child: ListTile(
                            dense: true,
                            title: Text(
                                '${item.chapterTitle} / ${item.sceneTitle}'),
                            subtitle: Text(
                              item.preview.trim().isEmpty
                                  ? 'No preview text.'
                                  : item.preview.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              if (item.sceneId.isEmpty) {
                                _selectChapter(item.chapterId);
                              } else {
                                _selectScene(item.chapterId, item.sceneId);
                              }
                            },
                          ),
                        ),
                      ),
                  ] else if (_selection.kind ==
                      ManuscriptSelectionKind.manuscript) ...[
                    _detailLine('Chapters', '${manuscript.chapterCount}'),
                    _detailLine('Scenes', '${manuscript.sceneCount}'),
                    _detailLine('Words', '${manuscript.wordCount}'),
                    _detailLine(
                        'Status',
                        manuscript.sceneCount == 0
                            ? 'Planned'
                            : 'Draft in progress'),
                  ] else if (_selection.kind ==
                          ManuscriptSelectionKind.chapter &&
                      chapter != null) ...[
                    _detailLine('Chapter', chapter.title),
                    _detailLine('Scenes', '${chapter.scenes.length}'),
                    _detailLine('Words', '${chapter.wordCount}'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<ManuscriptNodeStatus>(
                      initialValue: chapter.status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: ManuscriptNodeStatus.values
                          .map((status) => DropdownMenuItem(
                                value: status,
                                child: Text(status.label),
                              ))
                          .toList(),
                      onChanged: !_canEdit
                          ? null
                          : (value) {
                              if (value != null) {
                                _setChapterStatus(chapter, value);
                              }
                            },
                    ),
                    const SizedBox(height: 8),
                    _detailLine(
                        'POV', chapter.pov.isEmpty ? 'Not set' : chapter.pov),
                    OutlinedButton.icon(
                      onPressed: !_canEdit
                          ? null
                          : () => _editChapterMetadata(chapter),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit details'),
                    ),
                    const SizedBox(height: 12),
                    Text(
                        'Related chapters (${chapter.linkedChapterIds.length})',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: chapter.linkedChapterIds
                          .map(
                            (id) => InputChip(
                              label:
                                  Text(manuscript.chapterById(id)?.title ?? id),
                              onDeleted: () => _unlinkChapter(chapter, id),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: manuscript.chapters.length < 2 || !_canEdit
                          ? null
                          : () => _linkChapter(chapter),
                      icon: const Icon(Icons.add_link),
                      label: const Text('Link chapter'),
                    ),
                  ] else if (_selection.kind == ManuscriptSelectionKind.scene &&
                      scene != null) ...[
                    _detailLine('Scene', scene.title),
                    _detailLine('Word Count', '${scene.wordCount}'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<ManuscriptNodeStatus>(
                      initialValue: scene.status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: ManuscriptNodeStatus.values
                          .map((status) => DropdownMenuItem(
                                value: status,
                                child: Text(status.label),
                              ))
                          .toList(),
                      onChanged: !_canEdit
                          ? null
                          : (value) {
                              if (value != null) {
                                _setSceneStatus(scene, value);
                              }
                            },
                    ),
                    const SizedBox(height: 8),
                    _detailLine(
                        'POV', scene.pov.isEmpty ? 'Not set' : scene.pov),
                    _detailLine('Location',
                        scene.location.isEmpty ? 'Not set' : scene.location),
                    _detailLine('Time',
                        scene.timeLabel.isEmpty ? 'Not set' : scene.timeLabel),
                    _detailLine(
                        'Notes', scene.notes.isEmpty ? 'None' : scene.notes),
                    OutlinedButton.icon(
                      onPressed: !_canEdit
                          ? null
                          : () => _editSceneMetadata(scene),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit details'),
                    ),
                    const SizedBox(height: 8),
                    Text('Relationships (${scene.relationships.length})',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: scene.relationships
                          .map(
                            (link) => InputChip(
                              label: Text(
                                  '${link.type.label}: ${link.label.isEmpty ? link.targetId : link.label}'),
                              onDeleted: () => _updateSceneById(
                                scene.id,
                                (current) => current.copyWith(
                                  relationships: current.relationships
                                      .where((item) => item.id != link.id)
                                      .toList(),
                                  updatedAt: DateTime.now(),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed:
                          !_canEdit ? null : () => _addRelationship(scene),
                      icon: const Icon(Icons.add_link),
                      label: const Text('Add relationship'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsModeSwitch() => SegmentedButton<bool>(
        key: const Key('manuscript-details-mode'),
        segments: const [
          ButtonSegment(value: false, label: Text('Details')),
          ButtonSegment(value: true, label: Text('Connected')),
        ],
        selected: {_showConnectedPane},
        showSelectedIcon: false,
        onSelectionChanged: (selection) =>
            setState(() => _showConnectedPane = selection.first),
      );

  /// Adopts a manuscript a Phase 2 pane produced, without a storage reload.
  Future<void> _adoptManuscript(ManuscriptProjectSummary manuscript) async {
    if (!mounted) {
      return;
    }
    setState(() => _manuscript = manuscript);
    _syncEditorWithSelection();
    if (!_filter.isEmpty) {
      await _applyFilter(_filter);
    }
  }

  Widget _detailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(color: Colors.white70)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _addRelationship(ManuscriptScene scene) async {
    SceneRelationshipType type = SceneRelationshipType.relatedScene;
    final targetController = TextEditingController();
    final labelController = TextEditingController();

    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Add relationship'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<SceneRelationshipType>(
                  initialValue: type,
                  items: SceneRelationshipType.values
                      .map((value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setModalState(() => type = value);
                    }
                  },
                  decoration: const InputDecoration(labelText: 'Type'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: targetController,
                  decoration: const InputDecoration(
                    labelText: 'Target ID or reference',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: labelController,
                  decoration:
                      const InputDecoration(labelText: 'Label (optional)'),
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
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (accepted != true || targetController.text.trim().isEmpty) {
      return;
    }

    final now = DateTime.now();
    final relationship = SceneRelationship(
      id: ManuscriptId.create('relationship'),
      type: type,
      targetId: targetController.text.trim(),
      label: labelController.text.trim(),
    );

    _updateSceneById(
      scene.id,
      (current) => current.copyWith(
        relationships: [...current.relationships, relationship],
        updatedAt: now,
      ),
    );
  }
}

class _SceneSearchResult {
  const _SceneSearchResult({
    required this.chapterId,
    required this.sceneId,
    required this.chapterTitle,
    required this.sceneTitle,
    required this.preview,
  });

  final String chapterId;
  final String sceneId;
  final String chapterTitle;
  final String sceneTitle;
  final String preview;
}

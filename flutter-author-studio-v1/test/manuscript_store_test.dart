import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AuthorOsDatabase database;
  late ManuscriptStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AuthorOsDatabase(NativeDatabase.memory());
    store = ManuscriptStore(
      repository: DriftConnectedDomainRepository(database),
    );
  });

  tearDown(() => database.close());

  test('manuscript store persists drafts independently by project', () async {
    await store.save('project-a', 'The opening line.');
    await store.save('project-b', 'A different manuscript.');

    expect(await store.load('project-a'), 'The opening line.');
    expect(await store.load('project-b'), 'A different manuscript.');
    expect(await store.load('project-c'), isEmpty);
  });

  test('legacy manuscript text migrates into first scene without data loss',
      () async {
    SharedPreferences.setMockInitialValues({
      'author_studio.manuscript.project-legacy': 'Legacy draft line one.',
    });

    final manuscript = await store.loadStudio(
      'project-legacy',
      manuscriptTitle: 'Legacy Project',
      defaultChapters: const [
        ManuscriptChapterSeed(
          title: 'Chapter 01',
          scenes: ['Scene 01'],
        ),
      ],
      firstSceneTitle: 'Opening Scene',
    );

    expect(manuscript.chapters, hasLength(1));
    expect(manuscript.chapters.first.scenes, hasLength(1));
    expect(manuscript.chapters.first.scenes.first.title, 'Opening Scene');
    expect(manuscript.chapters.first.scenes.first.content,
        'Legacy draft line one.');
    expect(manuscript.migration['source'], 'legacy_text');
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences
          .getString('author_studio.manuscript_legacy_backup.project-legacy'),
      'Legacy draft line one.',
    );
  });

  test('structured manuscript persists chapter and scene ordering explicitly',
      () async {
    final repository = store.repository!;
    final now = DateTime(2026, 8, 16);

    final manuscript = ManuscriptProjectSummary(
      projectId: 'project-ordered',
      manuscriptTitle: 'Ordered Project',
      chapters: [
        ManuscriptChapter(
          id: 'chapter-b',
          title: 'Chapter B',
          order: 2,
          status: ManuscriptNodeStatus.draft,
          createdAt: now,
          updatedAt: now,
          scenes: [
            ManuscriptScene(
              id: 'scene-b2',
              chapterId: 'chapter-b',
              title: 'Scene B2',
              order: 2,
              content: 'Beta two',
              status: ManuscriptNodeStatus.draft,
              createdAt: now,
              updatedAt: now,
            ),
            ManuscriptScene(
              id: 'scene-b1',
              chapterId: 'chapter-b',
              title: 'Scene B1',
              order: 1,
              content: 'Beta one',
              status: ManuscriptNodeStatus.draft,
              createdAt: now,
              updatedAt: now,
            ),
          ],
        ),
        ManuscriptChapter(
          id: 'chapter-a',
          title: 'Chapter A',
          order: 1,
          status: ManuscriptNodeStatus.draft,
          linkedChapterIds: const ['chapter-b'],
          createdAt: now,
          updatedAt: now,
          scenes: [
            ManuscriptScene(
              id: 'scene-a1',
              chapterId: 'chapter-a',
              title: 'Scene A1',
              order: 1,
              content: 'Alpha one',
              status: ManuscriptNodeStatus.draft,
              relationships: const [
                SceneRelationship(
                  id: 'relationship-a-b',
                  type: SceneRelationshipType.nextScene,
                  targetId: 'scene-b1',
                  label: 'Continue to B',
                ),
              ],
              createdAt: now,
              updatedAt: now,
            ),
          ],
        ),
      ],
      currentChapterId: 'chapter-a',
      currentSceneId: 'scene-a1',
      createdAt: now,
      updatedAt: now,
      version: 2,
    );

    await store.saveStudio(manuscript);
    final loaded = await store.loadStudio(
      'project-ordered',
      manuscriptTitle: 'Ordered Project',
      defaultChapters: const [],
    );

    expect(loaded.chapters.map((chapter) => chapter.id),
        ['chapter-a', 'chapter-b']);
    expect(loaded.chapterById('chapter-b')!.scenes.map((scene) => scene.id),
        ['scene-b1', 'scene-b2']);
    expect(loaded.chapterById('chapter-a')!.linkedChapterIds, ['chapter-b']);
    expect(loaded.sceneById('scene-a1')!.relationships.single.targetId,
        'scene-b1');
    expect(loaded.sceneById('scene-a1')!.updatedAt, now);
    expect(loaded.orderedSceneCursors().map((cursor) => cursor.sceneId),
        ['scene-a1', 'scene-b1', 'scene-b2']);
    final exported = loaded.exportAsSingleText();
    expect(
        exported.indexOf('Chapter A'), lessThan(exported.indexOf('Chapter B')));
    expect(
        exported.indexOf('Scene B1'), lessThan(exported.indexOf('Scene B2')));
    expect(loaded.wordCount, greaterThan(0));

    final chapterNode = await repository.manuscriptNodeById('chapter-a');
    final sceneNode = await repository.manuscriptNodeById('scene-a1');
    expect(chapterNode?.nodeType, 'chapter');
    expect(chapterNode?.projectId, 'project-ordered');
    expect(chapterNode?.extensionData['order'], 1);
    expect(sceneNode?.nodeType, 'scene');
    expect(sceneNode?.extensionData['chapterId'], 'chapter-a');
    expect(sceneNode?.extensionData, isNot(contains('content')));
    expect(await repository.searchEntityIds('Scene A1'), ['scene-a1']);
  });

  test('large structured manuscript reloads with every scene addressable',
      () async {
    final now = DateTime(2026, 8, 16);
    final chapters = [
      for (var chapterIndex = 0; chapterIndex < 120; chapterIndex++)
        ManuscriptChapter(
          id: 'chapter-$chapterIndex',
          title: 'Chapter $chapterIndex',
          order: chapterIndex + 1,
          status: ManuscriptNodeStatus.draft,
          createdAt: now,
          updatedAt: now,
          scenes: [
            for (var sceneIndex = 0; sceneIndex < 5; sceneIndex++)
              ManuscriptScene(
                id: 'scene-$chapterIndex-$sceneIndex',
                chapterId: 'chapter-$chapterIndex',
                title: 'Scene $sceneIndex',
                order: sceneIndex + 1,
                content: 'Scene text $chapterIndex $sceneIndex',
                status: ManuscriptNodeStatus.draft,
                createdAt: now,
                updatedAt: now,
              ),
          ],
        ),
    ];
    final manuscript = ManuscriptProjectSummary(
      projectId: 'large-project',
      manuscriptTitle: 'Large Project',
      chapters: chapters,
      currentChapterId: chapters.first.id,
      currentSceneId: chapters.first.scenes.first.id,
      createdAt: now,
      updatedAt: now,
      version: 2,
    );

    await store.saveStudio(manuscript);
    final loaded = await store.loadStudio(
      'large-project',
      manuscriptTitle: 'Large Project',
      defaultChapters: const [],
    );

    expect(loaded.chapterCount, 120);
    expect(loaded.sceneCount, 600);
    expect(loaded.sceneById('scene-119-4')?.content, 'Scene text 119 4');
  });
}

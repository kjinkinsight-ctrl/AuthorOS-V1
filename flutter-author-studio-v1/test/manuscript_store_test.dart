import 'package:author_studio_v1/manuscript_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('manuscript store persists drafts independently by project', () async {
    const store = ManuscriptStore();

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

    const store = ManuscriptStore();
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
    expect(manuscript.chapters.first.scenes.first.content,
        'Legacy draft line one.');
    expect(manuscript.migration['source'], 'legacy_text');
  });

  test('structured manuscript persists chapter and scene ordering explicitly',
      () async {
    const store = ManuscriptStore();
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

    expect(loaded.chapterById('chapter-a'), isNotNull);
    expect(loaded.chapterById('chapter-b'), isNotNull);
    expect(loaded.exportAsSingleText(), contains('Chapter A'));
    expect(loaded.exportAsSingleText(), contains('Scene B1'));
    expect(loaded.wordCount, greaterThan(0));
  });
}
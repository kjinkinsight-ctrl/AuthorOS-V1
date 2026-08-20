import 'package:author_studio_v1/main.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/reading_rhythm.dart';
import 'package:author_studio_v1/release_destinations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AuthorOsDatabase database;
  late ManuscriptStore manuscriptStore;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AuthorOsDatabase(NativeDatabase.memory());
    manuscriptStore = ManuscriptStore(
      repository: DriftConnectedDomainRepository(database),
    );
  });

  tearDown(() => database.close());

  test('reading rhythm presets have distinct drafting geometry', () {
    expect(
      ReadingRhythmPreset.compact.editorWidth,
      greaterThan(ReadingRhythmPreset.standard.editorWidth),
    );
    expect(
      ReadingRhythmPreset.immersive.lineHeight,
      greaterThan(ReadingRhythmPreset.standard.lineHeight),
    );
    expect(
      ReadingRhythmPreset.immersive.fontSize,
      greaterThan(ReadingRhythmPreset.compact.fontSize),
    );
  });

  test('reading rhythm persists independently for each project', () async {
    const store = ReadingRhythmStore();

    await store.save('project-a', ReadingRhythmPreset.compact);
    await store.save('project-b', ReadingRhythmPreset.immersive);

    expect(await store.load('project-a'), ReadingRhythmPreset.compact);
    expect(await store.load('project-b'), ReadingRhythmPreset.immersive);
    expect(await store.load('project-c'), ReadingRhythmPreset.standard);
  });

  testWidgets('preset applies instantly and remains scoped to the project',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final project = NovelStarterKit.create(
      title: 'Rhythm Test',
      genre: 'Fantasy',
      projectType: 'Novel',
      wordGoal: 80000,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: AuthorStudioShell(
          project: project,
          manuscriptStore: manuscriptStore,
          openFirstDraft: true,
          themeId: 'obsidian',
          accentId: 'default',
          onThemeChanged: (_, __) {},
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reading-rhythm-control')), findsOneWidget);

    await tester.tap(find.text('Immersive'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.byKey(const Key('manuscript-draft-field')),
    );
    expect(field.style?.fontSize, ReadingRhythmPreset.immersive.fontSize);
    expect(field.style?.height, ReadingRhythmPreset.immersive.lineHeight);
    expect(
      await const ReadingRhythmStore().load(project.id),
      ReadingRhythmPreset.immersive,
    );
  });

  testWidgets('dashboard renders without layout overflow', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final project = NovelStarterKit.create(
      title: 'Dashboard Project',
      genre: 'Fantasy',
      projectType: 'Novel',
      wordGoal: 90000,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: AuthorStudioShell(
          project: project,
          manuscriptStore: manuscriptStore,
          themeId: 'obsidian',
          accentId: 'default',
          onThemeChanged: (_, __) {},
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('AUTHOROS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings page includes a user profile section', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: SettingsStudioView(
          themeId: 'obsidian',
          accentId: 'default',
          onThemeChanged: (_, __) {},
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Writer profile'), findsNothing);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Writer profile'), findsOneWidget);
  });
}

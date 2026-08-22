/// The Command Console, as an author meets it.
///
/// Two things are worth pinning at this level: that the console shows its
/// reading of a phrase before acting on it, and that the palette is actually
/// reachable by the shortcut the top bar has always advertised — including from
/// Manuscript Studio, which claims focus for shortcuts of its own.
library;

import 'package:author_studio_v1/command_console.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/search_models.dart';
import 'package:author_studio_v1/liquid_aurora_background.dart';
import 'package:author_studio_v1/main.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/theme/flutter/authoros_theme.dart';
import 'package:author_studio_v1/theme/theme_definition.dart';
import 'package:author_studio_v1/theme/theme_engine.dart';
import 'package:author_studio_v1/theme/resolved_theme.dart';
import 'package:author_studio_v1/theme/theme_persistence.dart';
import 'package:author_studio_v1/theme/theme_tokens.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _project = 'project-noxmere';
final _timestamp = DateTime.utc(2026, 8, 22, 9);

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    debugDisableAuroraAnimation = true;
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    await repository.putRecordsAndLinks(
      records: [
        AuthorRecord(
          id: 'kali',
          typeId: 'character',
          scopeType: RecordScopeType.project,
          scopeId: _project,
          projectId: _project,
          canonStatus: CanonStatus.canon,
          title: 'Kali',
          createdAt: _timestamp,
          updatedAt: _timestamp,
        ),
        AuthorRecord(
          id: 'endovier',
          typeId: 'location',
          scopeType: RecordScopeType.project,
          scopeId: _project,
          projectId: _project,
          canonStatus: CanonStatus.canon,
          title: 'Endovier',
          createdAt: _timestamp,
          updatedAt: _timestamp,
        ),
      ],
      links: [
        RecordLink(
          id: 'link-kali-livesIn-endovier',
          sourceId: 'kali',
          targetId: 'endovier',
          typeId: 'livesIn',
          scopeId: _project,
          createdAt: _timestamp,
          updatedAt: _timestamp,
        ),
      ],
    );
  });

  tearDown(() {
    database.close();
    debugDisableAuroraAnimation = false;
  });

  ResolvedTheme resolved() => ThemeEngine.standard(
        store: MemoryThemeSettingsStore(),
      ).resolveSelection(
        selection: const ThemeSelection(
          themeId: 'light',
          mode: AuthorOsThemeMode.light,
        ),
        hostBrightness: ThemeBrightness.light,
      );

  Future<void> pumpConsole(
    WidgetTester tester, {
    required ValueChanged<SearchNavigationTarget> onNavigate,
  }) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AuthorOsTheme.toThemeData(resolved()),
        home: Scaffold(
          body: CommandConsole(
            projectId: _project,
            repository: repository,
            onNavigate: onNavigate,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the console shows how it read the phrase', (tester) async {
    await pumpConsole(tester, onNavigate: (_) {});

    await tester.enterText(
      find.byKey(const Key('universal-search-field')),
      'Show everything connected to Kali',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('command-understanding')), findsOneWidget);
    expect(find.text('Understood as'), findsOneWidget);
    expect(find.text('Show'), findsOneWidget);
    expect(find.text('connected to'), findsOneWidget);
    expect(find.text('Kali'), findsOneWidget);
  });

  testWidgets('a result carries the author into the Studio that owns it',
      (tester) async {
    SearchNavigationTarget? navigated;
    await pumpConsole(tester, onNavigate: (target) => navigated = target);

    await tester.enterText(
      find.byKey(const Key('universal-search-field')),
      'Show everything connected to Kali',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('command-results')), findsOneWidget);
    await tester.tap(find.text('Endovier'));
    await tester.pumpAndSettle();

    expect(navigated?.recordId, 'endovier');
    expect(navigated?.destination, SearchDestination.worldStudio);
  });

  testWidgets('a command that would change the project asks first',
      (tester) async {
    await pumpConsole(tester, onNavigate: (_) {});

    await tester.enterText(
      find.byKey(const Key('universal-search-field')),
      'link Kali to Endovier',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('command-proposal')), findsOneWidget);
    expect(find.byKey(const Key('command-results')), findsNothing);
    // Nothing was written just by typing it.
    expect((await repository.snapshot()).links, hasLength(1));
  });

  testWidgets('an unreadable phrase searches instead of erroring',
      (tester) async {
    await pumpConsole(tester, onNavigate: (_) {});

    await tester.enterText(
      find.byKey(const Key('universal-search-field')),
      'Endovier',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('No command found, so:'), findsOneWidget);
    expect(find.byKey(const Key('command-results')), findsOneWidget);
  });

  group('the palette shortcut', () {
    Future<void> pumpShell(WidgetTester tester, StudioSection section) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final theme = resolved();
      await tester.pumpWidget(
        MaterialApp(
          theme: AuthorOsTheme.toThemeData(theme),
          home: StudioThemeScope(
            theme: theme,
            studio: StudioId.shell,
            child: AuthorStudioShell(
              project: NovelStarterKit.create(
                title: 'Northstar',
                genre: 'Fantasy',
                projectType: 'Novel',
                wordGoal: 90000,
              ),
              initialSection: section,
              manuscriptStore: ManuscriptStore(repository: repository),
              themeId: 'light',
              accentId: 'default',
              onThemeChanged: (_, __) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('Ctrl+K opens it', (tester) async {
      await pumpShell(tester, StudioSection.dashboard);
      expect(find.byKey(const Key('command-palette')), findsNothing);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('command-palette')), findsOneWidget);
    });

    testWidgets('Cmd+K opens it, so the shortcut works on a Mac',
        (tester) async {
      await pumpShell(tester, StudioSection.dashboard);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('command-palette')), findsOneWidget);
    });

    testWidgets('Manuscript Studio does not swallow it', (tester) async {
      // Manuscript Studio autofocuses for its own Ctrl+F and Ctrl+Shift+N
      // bindings. The palette's layer sits above it, so the key still arrives.
      await pumpShell(tester, StudioSection.manuscript);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('command-palette')), findsOneWidget);
    });
  });
}

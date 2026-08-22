import 'package:author_studio_v1/main.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The shell has to stay usable from a 1920px desktop window down to a phone
/// held in portrait, which on the web is not hypothetical: the same build
/// serves all of them. These tests pin the three layouts and, more importantly,
/// that all three are driving the *same* navigation.
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

  StarterProject project() => NovelStarterKit.create(
        title: 'Northstar',
        genre: 'Fantasy',
        projectType: 'Novel',
        wordGoal: 90000,
      );

  Future<void> pumpShellAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: AuthorStudioShell(
        project: project(),
        manuscriptStore: manuscriptStore,
        themeId: 'light',
        accentId: 'default',
        onThemeChanged: (_, __) {},
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('ShellLayout', () {
    test('picks the sidebar only where the workspace still has room', () {
      expect(ShellLayout.forWidth(1920), ShellLayout.expanded);
      expect(ShellLayout.forWidth(1440), ShellLayout.expanded);
      expect(ShellLayout.forWidth(1280), ShellLayout.expanded);
      expect(ShellLayout.forWidth(1180), ShellLayout.expanded);
    });

    test('falls back to the rail before the workspace gets crowded', () {
      // 1024 used to keep the full 280px sidebar, leaving the studios about
      // 700px to lay out in. The rail hands roughly 200px of that back.
      expect(ShellLayout.forWidth(1179), ShellLayout.rail);
      expect(ShellLayout.forWidth(1024), ShellLayout.rail);
      expect(ShellLayout.forWidth(900), ShellLayout.rail);
      expect(ShellLayout.forWidth(820), ShellLayout.rail);
    });

    test('gives the workspace the whole width once even a rail is too much',
        () {
      expect(ShellLayout.forWidth(819), ShellLayout.drawer);
      expect(ShellLayout.forWidth(600), ShellLayout.drawer);
      expect(ShellLayout.forWidth(390), ShellLayout.drawer);
    });
  });

  testWidgets('a desktop window shows the labelled sidebar', (tester) async {
    await pumpShellAt(tester, const Size(1440, 900));

    // The wordmark in the sidebar header, and labels on the tiles.
    expect(find.text('WORKSPACE'), findsWidgets);
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Story Codex'), findsWidgets);
    // No drawer, so no menu button competing with the sidebar beside it.
    expect(find.byKey(const Key('open-navigation')), findsNothing);
  });

  testWidgets('a small laptop collapses the sidebar to an icon rail',
      (tester) async {
    await pumpShellAt(tester, const Size(1024, 768));

    // Every section is still there and still reachable, but by icon: the
    // labels move into tooltips rather than disappearing.
    expect(find.text('Dashboard'), findsNothing);
    expect(find.byIcon(StudioSection.dashboard.icon), findsWidgets);
    expect(find.byIcon(StudioSection.timeline.icon), findsWidgets);
    expect(find.byKey(const Key('open-navigation')), findsNothing);

    final tooltips = tester
        .widgetList<Tooltip>(find.byType(Tooltip))
        .map((tooltip) => tooltip.message)
        .toSet();
    expect(tooltips, contains('Dashboard'));
    expect(tooltips, contains('Story Codex'));
  });

  testWidgets('a narrow window moves navigation into a drawer',
      (tester) async {
    await pumpShellAt(tester, const Size(600, 900));

    final menuButton = find.byKey(const Key('open-navigation'));
    expect(menuButton, findsOneWidget);
    // Nothing of the sidebar is left taking width from the workspace.
    expect(find.byType(Drawer), findsNothing);

    await tester.tap(menuButton);
    await tester.pumpAndSettle();

    expect(find.byType(Drawer), findsOneWidget);
    // The drawer carries the same sections, in the same groups.
    expect(find.text('WORKSPACE'), findsWidgets);
    expect(find.text('STORY'), findsWidgets);
    expect(find.text('Dashboard'), findsWidgets);

    // Seventeen sections do not fit a phone-height drawer, so the tail of the
    // list is reached by scrolling rather than being absent.
    final settingsTile = find.descendant(
      of: find.byType(Drawer),
      matching: find.text('Settings'),
    );
    await tester.dragUntilVisible(
      settingsTile,
      find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(ListView),
      ),
      const Offset(0, -80),
    );
    await tester.pumpAndSettle();
    expect(settingsTile, findsOneWidget);
  });

  testWidgets('choosing a section from the drawer opens it and closes the drawer',
      (tester) async {
    await pumpShellAt(tester, const Size(600, 900));

    await tester.tap(find.byKey(const Key('open-navigation')));
    await tester.pumpAndSettle();

    final dashboardTile = find.descendant(
      of: find.byType(Drawer),
      matching: find.text('Dashboard'),
    );
    await tester.tap(dashboardTile);
    await tester.pumpAndSettle();

    expect(find.byType(Drawer), findsNothing);
    // The top bar names the section the author is in, since the drawer layout
    // has no sidebar to show the selection.
    expect(
      find.descendant(
        of: find.byType(AuthorStudioShell),
        matching: find.text('Dashboard'),
      ),
      findsWidgets,
    );
  });

  testWidgets('no layout leaves the shell without a way to change section',
      (tester) async {
    for (final size in const [
      Size(1920, 1080),
      Size(1440, 900),
      Size(1280, 800),
      Size(1024, 768),
      Size(834, 1112),
      Size(600, 900),
    ]) {
      await pumpShellAt(tester, size);

      final hasSidebar = find.byIcon(StudioSection.dashboard.icon).evaluate().isNotEmpty;
      final hasMenu =
          find.byKey(const Key('open-navigation')).evaluate().isNotEmpty;

      expect(
        hasSidebar || hasMenu,
        isTrue,
        reason: 'no navigation reachable at ${size.width}x${size.height}',
      );
    }
  });
}

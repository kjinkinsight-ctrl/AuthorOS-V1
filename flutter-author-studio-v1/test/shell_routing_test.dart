import 'package:author_studio_v1/main.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The shell and the address bar have to move together in both directions:
/// choosing a section has to change the URL, and a URL arriving from outside --
/// a bookmark, browser back, a pasted link -- has to change the section.
///
/// Getting only one direction working is the failure mode that looks fine in
/// manual testing and breaks the moment someone presses back.
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

  /// Pumps the shell inside a host that stands in for the router: it holds the
  /// current section and re-supplies it, exactly as the delegate does.
  Future<void> pumpRoutedShell(
    WidgetTester tester, {
    required List<StudioSection> reported,
    StudioSection? initial,
    void Function(void Function(StudioSection)) exposeSetter =
        _ignoreSectionSetter,
  }) async {
    // Deliberately the drawer layout: there the top bar names the section the
    // shell is showing, which is the one public signal of the current section
    // that does not depend on a Studio's contents.
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_RoutedShellHost(
      project: project(),
      manuscriptStore: manuscriptStore,
      initial: initial,
      onSectionChanged: reported.add,
      exposeSetter: exposeSetter,
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('the shell opens on the section the URL asked for',
      (tester) async {
    final reported = <StudioSection>[];
    await pumpRoutedShell(
      tester,
      reported: reported,
      initial: StudioSection.statistics,
    );

    expect(currentSection(tester), 'Statistics');
    // Restoring a section is not the author choosing one, so it must not be
    // reported back as a new history entry.
    expect(reported, isEmpty);
  });

  testWidgets('choosing a section reports it so the URL can follow',
      (tester) async {
    final reported = <StudioSection>[];
    await pumpRoutedShell(tester, reported: reported);

    await chooseSection(tester, 'Statistics');

    expect(reported, [StudioSection.statistics]);
    expect(currentSection(tester), 'Statistics');
  });

  testWidgets('re-choosing the section already open reports nothing',
      (tester) async {
    final reported = <StudioSection>[];
    await pumpRoutedShell(
      tester,
      reported: reported,
      initial: StudioSection.statistics,
    );

    await chooseSection(tester, 'Statistics');

    expect(reported, isEmpty,
        reason: 'duplicate history entries make back look broken');
  });

  testWidgets('a section arriving from outside moves the shell',
      (tester) async {
    // This is browser back, a pasted URL, and a restored bookmark: the section
    // changes without the author touching the navigation.
    late void Function(StudioSection) goTo;
    final reported = <StudioSection>[];
    await pumpRoutedShell(
      tester,
      reported: reported,
      initial: StudioSection.dashboard,
      exposeSetter: (setter) => goTo = setter,
    );

    goTo(StudioSection.backup);
    await tester.pumpAndSettle();

    expect(currentSection(tester), 'Backup');
    // The shell followed the URL; it did not announce a new destination.
    expect(reported, isEmpty);
  });

  testWidgets('a section reported by the shell survives the rebuild it causes',
      (tester) async {
    // The router rebuilds the app after a selection. If the shell did not hold
    // its own selection through that, it would snap back to the default.
    late void Function(StudioSection) goTo;
    final reported = <StudioSection>[];
    await pumpRoutedShell(
      tester,
      reported: reported,
      exposeSetter: (setter) => goTo = setter,
    );

    await chooseSection(tester, 'Backup');
    goTo(reported.single);
    await tester.pumpAndSettle();

    expect(currentSection(tester), 'Backup');
    expect(reported, [StudioSection.backup]);
  });
}

/// The section the shell is showing, read from the top bar.
///
/// At drawer width the bar leads with the current section's name -- there is no
/// sidebar to carry the selection -- so the first Text in the shell is it.
String currentSection(WidgetTester tester) {
  final heading = find.descendant(
    of: find.byType(AuthorStudioShell),
    matching: find.byType(Text),
  );
  return tester.widgetList<Text>(heading).first.data ?? '';
}

/// Opens the drawer and picks a section, the way an author would.
Future<void> chooseSection(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const Key('open-navigation')));
  await tester.pumpAndSettle();

  final tile = find.descendant(
    of: find.byType(Drawer),
    matching: find.text(label),
  );
  await tester.dragUntilVisible(
    tile,
    find.descendant(
      of: find.byType(Drawer),
      matching: find.byType(ListView),
    ),
    const Offset(0, -80),
  );
  await tester.pumpAndSettle();
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

void _ignoreSectionSetter(void Function(StudioSection) setter) {}

/// Stands in for the router: holds the current section, re-supplies it to the
/// shell, and hands the test a way to change it from outside.
class _RoutedShellHost extends StatefulWidget {
  const _RoutedShellHost({
    required this.project,
    required this.manuscriptStore,
    required this.onSectionChanged,
    required this.exposeSetter,
    this.initial,
  });

  final StarterProject project;
  final ManuscriptStore manuscriptStore;
  final ValueChanged<StudioSection> onSectionChanged;
  final void Function(void Function(StudioSection)) exposeSetter;
  final StudioSection? initial;

  @override
  State<_RoutedShellHost> createState() => _RoutedShellHostState();
}

class _RoutedShellHostState extends State<_RoutedShellHost> {
  StudioSection? _section;

  @override
  void initState() {
    super.initState();
    _section = widget.initial;
    widget.exposeSetter((section) => setState(() => _section = section));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: AuthorStudioShell(
        project: widget.project,
        manuscriptStore: widget.manuscriptStore,
        themeId: 'light',
        accentId: 'default',
        onThemeChanged: (_, __) {},
        initialSection: _section,
        onSectionChanged: widget.onSectionChanged,
      ),
    );
  }
}

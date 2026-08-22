import 'package:author_studio_v1/welcome_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpWelcome(
  WidgetTester tester, {
  required List<WelcomeAction> recorded,
  Size size = const Size(1400, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: WelcomePage(onAction: recorded.add),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the welcome page shows the wordmark, promise and tagline',
      (tester) async {
    final recorded = <WelcomeAction>[];
    await _pumpWelcome(tester, recorded: recorded);

    expect(find.text('Welcome to'), findsOneWidget);
    expect(find.text('AuthorOS'), findsWidgets);
    expect(find.text('Your complete book creation studio.'), findsOneWidget);
    expect(
      find.text('PLAN  •  BUILD  •  WRITE  •  EXPLORE  •  CREATE'),
      findsOneWidget,
    );
    expect(
      find.text('Every great story starts\nwith a blank page.'),
      findsOneWidget,
    );
  });

  testWidgets('every sidebar entry reports its action', (tester) async {
    final recorded = <WelcomeAction>[];
    await _pumpWelcome(tester, recorded: recorded);

    for (final action in const [
      WelcomeAction.openProject,
      WelcomeAction.newProject,
      WelcomeAction.recentProjects,
      WelcomeAction.templates,
      WelcomeAction.worlds,
      WelcomeAction.settings,
    ]) {
      await tester.tap(find.byKey(Key('welcome-entry-${action.name}')));
      await tester.pump();
    }

    expect(recorded, const [
      WelcomeAction.openProject,
      WelcomeAction.newProject,
      WelcomeAction.recentProjects,
      WelcomeAction.templates,
      WelcomeAction.worlds,
      WelcomeAction.settings,
    ]);
  });

  testWidgets('quick start and continue writing report their actions',
      (tester) async {
    final recorded = <WelcomeAction>[];
    await _pumpWelcome(tester, recorded: recorded);

    await tester.tap(
      find.byKey(const Key('welcome-quick-createCharacter')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('welcome-continue-writing')));
    await tester.pump();

    expect(recorded, const [
      WelcomeAction.createCharacter,
      WelcomeAction.continueWriting,
    ]);
  });

  testWidgets('a greeting uses the author name when one is known',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WelcomePage(onAction: (_) {}, authorName: 'Kai'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back,'), findsOneWidget);
    expect(find.text('Kai'), findsOneWidget);
  });

  testWidgets('hero artwork replaces the painted monogram', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: WelcomePage(
          onAction: (_) {},
          heroImage: const AssetImage('assets/welcome-hero.png'),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('welcome-hero-artwork')), findsOneWidget);
    expect(find.byKey(const Key('welcome-hero-painted')), findsNothing);

    // The artwork already carries these, so they must not be drawn over it.
    expect(
      find.text('PLAN  •  BUILD  •  WRITE  •  EXPLORE  •  CREATE'),
      findsNothing,
    );
    expect(
      find.text('Every great story starts\nwith a blank page.'),
      findsNothing,
    );

    // Sidebar and quick start still belong to the app, not the artwork.
    expect(find.text('Your complete book creation studio.'), findsOneWidget);
    expect(find.byKey(const Key('welcome-continue-writing')), findsOneWidget);
  });

  testWidgets('the page lays out on a narrow browser window', (tester) async {
    final recorded = <WelcomeAction>[];
    await _pumpWelcome(
      tester,
      recorded: recorded,
      size: const Size(680, 900),
    );

    expect(find.byKey(const Key('welcome-narrow')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('welcome-entry-worlds')));
    await tester.pump();
    expect(recorded, const [WelcomeAction.worlds]);
  });
}

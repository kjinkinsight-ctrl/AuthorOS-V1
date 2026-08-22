import 'dart:io';

import 'package:author_studio_v1/manuscript_service.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/series_service.dart';
import 'package:author_studio_v1/series_studio_view.dart';
import 'package:author_studio_v1/theme/flutter/authoros_theme.dart';
import 'package:author_studio_v1/theme/resolved_theme.dart';
import 'package:author_studio_v1/theme/theme_definition.dart';
import 'package:author_studio_v1/theme/theme_engine.dart';
import 'package:author_studio_v1/theme/theme_persistence.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ResolvedTheme> _resolvedTheme() async {
  final engine = ThemeEngine.standard(store: MemoryThemeSettingsStore());
  return engine.resolveSelection(
    selection: const ThemeSelection(
      themeId: 'light',
      mode: AuthorOsThemeMode.light,
    ),
    hostBrightness: ThemeBrightness.light,
  );
}

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late SeriesService series;
  late ManuscriptService manuscripts;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    series = SeriesService(projectId: 'project-a', repository: repository);
    manuscripts = ManuscriptService(
      projectId: 'project-a',
      repository: repository,
      store: ManuscriptStore(repository: repository),
    );
  });

  tearDown(() => database.close());

  Future<void> pump(WidgetTester tester) async {
    final theme = await _resolvedTheme();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: StudioThemeScope(
            theme: theme,
            child: SeriesStudioView(
              projectTitle: 'Endovier',
              series: series,
              manuscripts: manuscripts,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a project with no books explains what a book is for',
      (tester) async {
    await pump(tester);

    expect(find.textContaining('Add a book to split this project'), findsOne);
    expect(find.byKey(const ValueKey('series-add-book')), findsOne);
  });

  testWidgets('books are listed in series order', (tester) async {
    await series.ensureSeries(title: 'Endovier Chronicles');
    await series.createBook(title: 'Book One');
    await series.createBook(title: 'Book Two');

    await pump(tester);

    expect(find.text('Endovier Chronicles'), findsOne);
    final tiles = tester
        .widgetList<Card>(find.byType(Card))
        .map((card) => (card.key as ValueKey<String>).value)
        .toList();
    expect(tiles, [
      'series-book-${(await series.books())[0].id}',
      'series-book-${(await series.books())[1].id}',
    ]);
  });

  testWidgets('an unfiled chapter can be added to the open book',
      (tester) async {
    await series.ensureSeries();
    final book = await series.createBook(title: 'Book One');
    await manuscripts.load(
      manuscriptTitle: 'Endovier',
      defaultChapters: const [
        ManuscriptChapterSeed(title: 'Chapter 01', scenes: ['Scene 01']),
      ],
    );

    await pump(tester);
    expect(find.text('Add to book'), findsOne);

    await tester.tap(find.text('Add to book'));
    await tester.pumpAndSettle();

    final manuscript = await manuscripts.load(manuscriptTitle: 'Endovier');
    expect(
      manuscripts.chaptersForBook(manuscript, book.id).map((each) => each.title),
      ['Chapter 01'],
    );
    expect(find.text('Remove'), findsOne);
  });

  testWidgets('the Studio holds no persistence of its own', (tester) async {
    // Everything on screen comes from SeriesService and ManuscriptService. A
    // second store here would be a second source of truth for what a book is.
    final source = File('lib/series_studio_view.dart').readAsStringSync();
    expect(source, isNot(contains('SharedPreferences')));
    expect(source, isNot(contains('DriftConnectedDomainRepository')));
    expect(source, isNot(contains('AuthorOsDatabase')));
  });
}

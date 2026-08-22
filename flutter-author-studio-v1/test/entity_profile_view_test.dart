import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/record_service.dart';
import 'package:author_studio_v1/entity_profile_service.dart';
import 'package:author_studio_v1/entity_profile_view.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/series_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late RecordService records;
  late SeriesService series;
  late EntityProfileService profiles;
  final timestamp = DateTime.utc(2026, 8, 21);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    records = RecordService(projectId: 'project-a', repository: repository);
    series = SeriesService(projectId: 'project-a', repository: repository);
    profiles = EntityProfileService(
      projectId: 'project-a',
      repository: repository,
    );
  });

  tearDown(() => database.close());

  Future<void> kali({Map<String, Object?> fields = const {}}) =>
      records.createRecord(
        AuthorRecord(
          id: 'kali',
          typeId: 'character',
          scopeType: RecordScopeType.project,
          scopeId: 'project-a',
          projectId: 'project-a',
          canonStatus: CanonStatus.canon,
          title: 'Kali Vale',
          templateId: 'character',
          fields: {
            'name': 'Kali Vale',
            'identity.fullName': 'Kali Vale',
            ...fields,
          },
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      ).then((_) {});

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: EntityProfileView(service: profiles, recordId: 'kali'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the header names the type, series, books and canon',
      (tester) async {
    await series.ensureSeries(title: 'Endovier Chronicles');
    final book = await series.createBook(title: 'Book One');
    await kali(fields: const {
      'aliases': ['Red Widow']
    });
    await series.recordBookAppearance('kali', book.id, role: 'protagonist');

    await pump(tester);

    expect(find.text('Kali Vale'), findsWidgets);
    expect(find.text('Character'), findsOne);
    expect(find.text('Endovier Chronicles'), findsOne);
    expect(find.text('Book One'), findsWidgets);
    expect(find.textContaining('Also known as Red Widow'), findsOne);
    expect(find.byKey(const Key('entity-profile-canon')), findsOne);
    expect(find.textContaining('Canon confidence'), findsOne);
  });

  testWidgets('an unused entry says so plainly', (tester) async {
    await kali();
    await pump(tester);

    expect(find.byKey(const Key('entity-profile-usage-empty')), findsOne);
  });

  testWidgets('a contradiction is surfaced, not resolved', (tester) async {
    final two = await series.createBook(title: 'Book Two');
    await kali(fields: const {'identity.age': 27});
    await series.setEntityState(
      'kali',
      two.id,
      overrides: const {'identity.age': 29},
    );

    await pump(tester);

    expect(find.byKey(const Key('entity-profile-conflicts')), findsOne);
    expect(find.textContaining('will not choose for you'), findsOne);
    expect(find.text('Contradicted'), findsOne);
  });

  testWidgets('usage lists each book with its role', (tester) async {
    final book = await series.createBook(title: 'Book One');
    await kali();
    await series.recordBookAppearance('kali', book.id, role: 'protagonist');

    await pump(tester);

    expect(find.byKey(const ValueKey('entity-usage-book-Book One')), findsOne);
    expect(find.textContaining('protagonist'), findsOne);
  });
}

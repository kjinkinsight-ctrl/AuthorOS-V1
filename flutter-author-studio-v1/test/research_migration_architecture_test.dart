import 'dart:io';

import 'package:author_studio_v1/analytics_service.dart';
import 'package:author_studio_v1/core/built_in_record_types.dart';
import 'package:author_studio_v1/core/research_record_types.dart';
import 'package:author_studio_v1/migrations/legacy_research_store.dart';
import 'package:author_studio_v1/migrations/research_migration.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guardrails: the migration must reuse the record system, not grow a second
/// one beside it. These read the shipping source, so a future change that
/// reintroduces a parallel research store fails here rather than in review.
void main() {
  final migration = File('lib/migrations/research_migration.dart');
  final legacyStore = File('lib/migrations/legacy_research_store.dart');
  final libraryFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList()
    ..sort((left, right) => left.path.compareTo(right.path));

  test('the migration source exists where the audit expects it', () {
    expect(migration.existsSync(), isTrue);
    expect(legacyStore.existsSync(), isTrue);
  });

  test('migration writes go through RecordService', () {
    final source = migration.readAsStringSync();

    expect(source, contains("import '../core/record_service.dart';"));
    expect(source, contains('records.createRecord('));
  });

  test('migration never writes to Drift tables directly', () {
    final source = migration.readAsStringSync();

    for (final forbidden in const [
      'package:drift/drift.dart',
      'authorRecordRows',
      'AuthorRecordRowsCompanion',
      'customStatement',
      'database.into(',
      'database.update(',
      'database.delete(',
      'putRecord(',
      'putRecordsAndLinks(',
      'putRecordWithHistory(',
    ]) {
      expect(
        source.contains(forbidden),
        isFalse,
        reason: 'The migration must not use $forbidden.',
      );
    }
  });

  test('migration does not bypass the repository with a global database', () {
    final source = migration.readAsStringSync();
    final serviceBody = source.substring(
      source.indexOf('class LegacyResearchMigrationService'),
      source.indexOf('class _LegacyResearchEntry'),
    );

    // The service takes its repository; only the shell's default runner is
    // allowed to reach for the app-wide one.
    expect(serviceBody, contains('final DriftConnectedDomainRepository repository;'));
    expect(serviceBody.contains('authorOsRepository'), isFalse);
    expect(serviceBody.contains('authorOsDatabase'), isFalse);
  });

  test('there is exactly one research persistence store in the app', () {
    final stores = libraryFiles
        .where((file) =>
            file.readAsStringSync().contains('author_studio.research_panel'))
        .map((file) => file.path)
        .toList();

    expect(stores, ['lib/migrations/legacy_research_store.dart']);
  });

  test('the migration creates no second SharedPreferences research store', () {
    final source = migration.readAsStringSync();

    // The only preference key the migration owns is its own marker.
    expect(source.contains('author_studio.research_panel'), isFalse);
    expect(source, contains('author_studio.research_migration.'));
    expect(
      RegExp(r"prefs\.setString\(").hasMatch(source),
      isFalse,
      reason: 'The migration stores a version marker, not research payloads.',
    );
  });

  test('the migration introduces no research model of its own', () {
    final declared = RegExp(r'^class (\w+)', multiLine: true)
        .allMatches(migration.readAsStringSync())
        .map((match) => match.group(1)!)
        .toList();

    // Result, state, and an internal pairing type — nothing that models a
    // research entry. Research is persisted as AuthorRecord and nothing else.
    expect(declared, [
      'ResearchMigrationFailure',
      'ResearchMigrationOutcome',
      'ResearchMigrationState',
      'LegacyResearchMigrationService',
      '_LegacyResearchEntry',
    ]);
  });

  test('the legacy DTO is the only model of legacy research content', () {
    final holders = libraryFiles
        .where((file) => file.readAsStringSync().contains('this.detail,'))
        .map((file) => file.path)
        .toList();

    expect(holders, ['lib/migrations/legacy_research_store.dart']);
  });

  test('migrated research uses the canonical built-in research type', () {
    final definition =
        BuiltInRecordTypes.registry().resolve(ResearchRecordTypes.baseTypeId);

    expect(ResearchRecordTypes.baseTypeId, 'research-entry');
    expect(definition.categoryId, 'research');
    expect(definition.builtIn, isTrue);
    // Every field the migration writes belongs to the existing template.
    expect(
      definition.fields.map((field) => field.id),
      containsAll(['name', 'summary']),
    );
  });

  test('migration writes no record field the research template does not own',
      () async {
    SharedPreferences.setMockInitialValues({});
    final database = AuthorOsDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftConnectedDomainRepository(database);
    await const ProjectResearchStore(projectId: 'project-a').save({
      ResearchTab.research: const [
        ResearchReference(title: 'Audited', detail: 'body', tag: 'World'),
      ],
    });

    await LegacyResearchMigrationService(
      projectId: 'project-a',
      repository: repository,
    ).migrate(timestamp: DateTime.utc(2026, 8, 21));
    final record = (await repository.recordsByScope('project-a')).single;
    final templateFieldIds = BuiltInRecordTypes.registry()
        .resolve(ResearchRecordTypes.baseTypeId)
        .fields
        .map((field) => field.id)
        .toSet();

    expect(record.fields.keys, isNotEmpty);
    expect(
      record.fields.keys.toSet().difference(templateFieldIds),
      isEmpty,
      reason: 'The migration may only write fields the template declares.',
    );
  });

  test('the field map is Research Studio\'s, not a parallel one', () {
    final source = migration.readAsStringSync();

    // The record's fields come from ResearchDraft, so the migration cannot
    // drift away from what the Studio itself writes.
    expect(source, contains('ResearchDraft('));
    expect(source, contains('draft.fields()'));
    expect(source, contains('ResearchRecordTypes.baseTypeId'));
  });

  test('the legacy tag maps to the real category field, and the tab is kept',
      () {
    final source = migration.readAsStringSync();
    final fieldIds = BuiltInRecordTypes.registry()
        .resolve(ResearchRecordTypes.baseTypeId)
        .fields
        .map((field) => field.id);

    // `researchCategory` is a real field on the canonical research template,
    // so the legacy tag is routed into it through ResearchDraft rather than
    // being dropped or given a field of the migration's own invention.
    expect(fieldIds, contains(ResearchRecordTypes.categoryFieldId));
    expect(source, contains('category: tag,'));

    // The tab names no field in the schema — not a category, not a kind — so
    // it is preserved verbatim in provenance instead.
    expect(source, contains("'legacyTab'"));
    expect(
      ResearchRecordTypes.categories.map((c) => c.toLowerCase()),
      isNot(contains('timeline')),
    );
  });

  test('analytics still counts the canonical record types', () {
    expect(AnalyticsService.researchTypeIds, contains(ResearchRecordTypes.baseTypeId));
    expect(
      File('lib/analytics_service.dart').readAsStringSync().contains(
            'author_studio.research_panel',
          ),
      isFalse,
      reason: 'Analytics reads the record system, never the legacy store.',
    );
  });

  test('the migration creates no second search index', () {
    final source = migration.readAsStringSync();

    for (final forbidden in const [
      'author_search',
      'CREATE VIRTUAL TABLE',
      'fts5',
      'searchIndex',
    ]) {
      expect(source.contains(forbidden), isFalse);
    }
  });

  test('the migration marker uses the existing preferences namespace', () {
    expect(
      const ResearchMigrationState(projectId: 'p').storageKey,
      startsWith('author_studio.'),
    );
    expect(ResearchMigrationState.keyPrefix,
        'author_studio.research_migration.');
    expect(ProjectResearchStore.keyPrefix, 'author_studio.research_panel.');
  });

  test('the migration does not depend on the app shell', () {
    final source = migration.readAsStringSync();

    expect(source.contains("import '../main.dart'"), isFalse);
    expect(source.contains('package:flutter/'), isFalse);
  });

  test('the legacy research panel is still present and untouched', () {
    final shell = File('lib/main.dart').readAsStringSync();

    // Removing the panel is a later milestone. Until then it must keep
    // reading and writing the same legacy store the migration drains.
    expect(shell, contains('_ResearchSidePanel'));
    expect(shell, contains('ProjectResearchStore(projectId: widget.projectId)'));
  });

  test('the migration never deletes the legacy store', () {
    final source = migration.readAsStringSync();

    expect(source.contains('prefs.remove('), isFalse);
    expect(source.contains('.clear()'), isFalse);
  });
}

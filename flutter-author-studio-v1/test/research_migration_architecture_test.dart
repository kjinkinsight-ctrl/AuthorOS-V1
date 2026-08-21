import 'dart:io';

import 'package:author_studio_v1/analytics_service.dart';
import 'package:author_studio_v1/core/built_in_record_types.dart';
import 'package:author_studio_v1/migrations/legacy_research_store.dart';
import 'package:author_studio_v1/migrations/research_migration.dart';
import 'package:flutter_test/flutter_test.dart';

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

  test('there is exactly one research entry model', () {
    final entryModel =
        RegExp(r'class Research(Entry|Record|Item|Note|Reference)\w*');
    final models = libraryFiles
        .where((file) => entryModel.hasMatch(file.readAsStringSync()))
        .map((file) => file.path)
        .toList();

    // `ResearchReference` is the legacy DTO the migration reads. No second
    // canonical research model exists: migrated research is an AuthorRecord.
    expect(models, ['lib/migrations/legacy_research_store.dart']);
  });

  test('migrated research uses the canonical built-in research type', () {
    final definition =
        BuiltInRecordTypes.registry().resolve(researchRecordTypeId);

    expect(researchRecordTypeId, 'research-entry');
    expect(definition.categoryId, 'research');
    expect(definition.builtIn, isTrue);
    // Every field the migration writes belongs to the existing template.
    expect(
      definition.fields.map((field) => field.id),
      containsAll(['name', 'summary']),
    );
  });

  test('migration writes no invented record fields', () {
    final definition =
        BuiltInRecordTypes.registry().resolve(researchRecordTypeId);
    final templateFieldIds =
        definition.fields.map((field) => field.id).toSet();
    final source = migration.readAsStringSync();
    final fieldsBlock = source.substring(
      source.indexOf('      fields: {'),
      source.indexOf('      // An empty legacy tag'),
    );
    final writtenLiterals = RegExp(r"'([A-Za-z][\w.]*)':")
        .allMatches(fieldsBlock)
        .map((match) => match.group(1)!)
        .toSet();

    expect(writtenLiterals, isNotEmpty);
    expect(
      writtenLiterals.difference(templateFieldIds),
      isEmpty,
      reason: 'Only existing template fields may be written by the migration.',
    );
    // The Codex-namespaced fields are the existing Story Codex convention.
    expect(fieldsBlock, contains('CodexFields.summary'));
    expect(fieldsBlock, contains('CodexFields.projectId'));
  });

  test('the legacy tab is preserved rather than mapped to an invented field',
      () {
    final source = migration.readAsStringSync();

    // No `researchCategory` field exists in the canonical schema, so the tab
    // lives in provenance where nothing is lost and no schema is invented.
    expect(source.contains('researchCategory'), isFalse);
    expect(source, contains("'legacyTab'"));
    expect(
      BuiltInRecordTypes.registry()
          .resolve(researchRecordTypeId)
          .fields
          .map((field) => field.id),
      isNot(contains('researchCategory')),
    );
  });

  test('analytics still counts the canonical record types', () {
    expect(AnalyticsService.researchTypeIds, contains(researchRecordTypeId));
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

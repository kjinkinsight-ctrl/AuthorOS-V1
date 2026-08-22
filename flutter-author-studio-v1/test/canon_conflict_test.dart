import 'package:author_studio_v1/canon_conflict_service.dart';
import 'package:author_studio_v1/continuity.dart';
import 'package:author_studio_v1/core/canon_facts.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/record_service.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/series_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Canon contradictions, found from typed facts and never from prose.
///
/// AuthorOS never decides canon. It points at both sides of a disagreement and
/// leaves the choice to the author.
void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late RecordService records;
  late SeriesService series;
  late CanonConflictAnalyzer analyzer;
  final timestamp = DateTime.utc(2026, 8, 21);

  setUp(() {
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    records = RecordService(projectId: 'project-a', repository: repository);
    series = SeriesService(projectId: 'project-a', repository: repository);
    analyzer = CanonConflictAnalyzer(
      projectId: 'project-a',
      repository: repository,
    );
  });

  tearDown(() => database.close());

  Future<AuthorRecord> character(
    String id,
    String name, {
    Map<String, Object?> fields = const {},
    CanonStatus canonStatus = CanonStatus.canon,
  }) =>
      records.createRecord(
        AuthorRecord(
          id: id,
          typeId: 'character',
          scopeType: RecordScopeType.project,
          scopeId: 'project-a',
          projectId: 'project-a',
          canonStatus: canonStatus,
          title: name,
          templateId: 'character',
          fields: {
            'name': name,
            'identity.fullName': name,
            ...fields,
          },
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      );

  group('canon versus a book state', () {
    test('the profile says 27 and a book says 29', () async {
      // The directive's own example, from two typed values the author entered.
      final three = await series.createBook(title: 'Book Three', order: 2);
      await character('kali', 'Kali Vale',
          fields: const {'identity.age': 27});
      await series.setEntityState(
        'kali',
        three.id,
        overrides: const {'identity.age': 29},
      );

      final report = await analyzer.analyze('kali');

      expect(report.isClean, isFalse);
      final finding = report.forField('identity.age').single;
      expect(finding.canonValue, 27);
      expect(finding.otherValue, 29);
      expect(finding.bookId, three.id);
      expect(finding.warning.type, ContinuityWarningType.canonContradiction);
      expect(finding.warning.message, contains('27'));
      expect(finding.warning.message, contains('29'));
    });

    test('a book agreeing with canon raises nothing', () async {
      final two = await series.createBook(title: 'Book Two');
      await character('kali', 'Kali Vale',
          fields: const {'identity.age': 27});
      await series.setEntityState(
        'kali',
        two.id,
        overrides: const {'identity.age': 27},
      );

      expect((await analyzer.analyze('kali')).isClean, isTrue);
    });

    test('a draft record differing from a draft book is not a contradiction',
        () async {
      // Two drafts are alternatives the author is still weighing, not a
      // disagreement about what is true.
      final two = await series.createBook(title: 'Book Two');
      await character(
        'kali',
        'Kali Vale',
        fields: const {'identity.age': 27},
        canonStatus: CanonStatus.draft,
      );
      final state = await series.setEntityState(
        'kali',
        two.id,
        overrides: const {'identity.age': 29},
      );
      await records.updateRecord(
        state.copyWith(canonStatus: CanonStatus.draft, updatedAt: timestamp),
      );

      expect((await analyzer.analyze('kali')).isClean, isTrue);
    });

    test('resolving the conflict clears it, with no extra write', () async {
      final two = await series.createBook(title: 'Book Two');
      await character('kali', 'Kali Vale',
          fields: const {'identity.age': 27});
      await series.setEntityState(
        'kali',
        two.id,
        overrides: const {'identity.age': 29},
      );
      expect((await analyzer.analyze('kali')).isClean, isFalse);

      // An ordinary edit — the author decides which side is right.
      final canon = (await records.getRecord('kali'))!;
      await records.updateRecord(
        canon.copyWith(
          fields: {...canon.fields, 'identity.age': 29},
          updatedAt: timestamp,
        ),
      );

      expect((await analyzer.analyze('kali')).isClean, isTrue);
    });
  });

  group('a number that cannot go backwards', () {
    test('age dropping between books is critical', () async {
      final two = await series.createBook(title: 'Book Two', order: 1);
      final three = await series.createBook(title: 'Book Three', order: 2);
      await character('kali', 'Kali Vale');
      await series
          .setEntityState('kali', two.id, overrides: const {'identity.age': 29});
      await series.setEntityState(
        'kali',
        three.id,
        overrides: const {'identity.age': 27},
      );

      final finding = (await analyzer.analyze('kali'))
          .findings
          .firstWhere((each) => each.warning.severity == ContinuitySeverity.critical);
      expect(finding.canonValue, 29);
      expect(finding.otherValue, 27);
      expect(finding.warning.message, contains('cannot decrease'));
    });

    test('age rising between books is fine', () async {
      final two = await series.createBook(title: 'Book Two', order: 1);
      final three = await series.createBook(title: 'Book Three', order: 2);
      await character('kali', 'Kali Vale');
      await series
          .setEntityState('kali', two.id, overrides: const {'identity.age': 27});
      await series.setEntityState(
        'kali',
        three.id,
        overrides: const {'identity.age': 29},
      );

      expect((await analyzer.analyze('kali')).isClean, isTrue);
    });

    test('a field nobody declared monotonic is left alone', () async {
      final two = await series.createBook(title: 'Book Two', order: 1);
      final three = await series.createBook(title: 'Book Three', order: 2);
      await character('kali', 'Kali Vale');
      await series
          .setEntityState('kali', two.id, overrides: const {'wealth': 900});
      await series
          .setEntityState('kali', three.id, overrides: const {'wealth': 10});

      expect((await analyzer.analyze('kali')).isClean, isTrue);
    });
  });

  group('duplicate canon', () {
    test('two canon records sharing a name are flagged', () async {
      await character('kali', 'Kali Vale', fields: const {
        'aliases': ['Red Widow']
      });
      await character('lucia', 'Lucia Vane', fields: const {
        'aliases': ['Red Widow']
      });

      final report = await analyzer.analyze('kali');
      final finding = report.findings
          .firstWhere((each) => each.warning.title.contains('answer to'));
      expect(finding.otherRecordId, 'lucia');
      expect(finding.warning.message, contains('cannot tell which one'));
    });

    test('a draft duplicate is not a canon conflict', () async {
      await character('kali', 'Kali Vale', fields: const {
        'aliases': ['Red Widow']
      });
      await character(
        'lucia',
        'Lucia Vane',
        fields: const {
          'aliases': ['Red Widow']
        },
        canonStatus: CanonStatus.draft,
      );

      expect((await analyzer.analyze('kali')).isClean, isTrue);
    });
  });

  group('a relationship there can only be one of', () {
    test('two birthplaces contradict', () async {
      await character('kali', 'Kali Vale');
      for (final id in const ['endovier', 'harbour']) {
        await records.createRecord(
          AuthorRecord(
            id: id,
            typeId: 'city',
            scopeType: RecordScopeType.project,
            scopeId: 'project-a',
            projectId: 'project-a',
            title: id,
            templateId: 'city',
            fields: {'name': id},
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
        await series.connections.connect(
          sourceId: 'kali',
          targetId: id,
          typeId: 'bornIn',
        );
      }

      final finding = (await analyzer.analyze('kali'))
          .findings
          .firstWhere((each) => each.warning.title.contains('bornIn'));
      expect(finding.warning.message, contains('only'));
    });

    test('two friends do not contradict', () async {
      await character('kali', 'Kali Vale');
      for (final id in const ['lucia', 'cassian']) {
        await character(id, id);
        await series.connections.connect(
          sourceId: 'kali',
          targetId: id,
          typeId: 'friendOf',
          direction: RecordLinkDirection.undirected,
        );
      }

      expect((await analyzer.analyze('kali')).isClean, isTrue);
    });
  });

  group('the analyzer never writes', () {
    test('analysing changes nothing', () async {
      final two = await series.createBook(title: 'Book Two');
      await character('kali', 'Kali Vale',
          fields: const {'identity.age': 27});
      await series.setEntityState(
        'kali',
        two.id,
        overrides: const {'identity.age': 29},
      );
      final before = await repository.snapshot();

      await analyzer.analyze('kali');
      await analyzer.confidenceFor('kali', 'identity.age');

      final after = await repository.snapshot();
      expect(after.records.length, before.records.length);
      expect(after.links.length, before.links.length);
      expect(
        after.records.map((record) => record.revision).toList(),
        before.records.map((record) => record.revision).toList(),
      );
    });

    test('a contradicted status is never stored', () async {
      await character('kali', 'Kali Vale');
      final canon = (await records.getRecord('kali'))!;
      expect(
        () => CanonFields.withFieldStatus(
          canon,
          'identity.age',
          CanonFactStatus.contradicted,
        ),
        throwsArgumentError,
      );
      expect(
        () => CanonFields.toRecordStatus(CanonFactStatus.unknown),
        throwsArgumentError,
      );
    });
  });

  group('canon status vocabulary', () {
    test('retired maps onto the existing deprecated status', () {
      expect(CanonFields.toRecordStatus(CanonFactStatus.retired),
          CanonStatus.deprecated);
      expect(CanonFields.fromRecordStatus(CanonStatus.deprecated),
          CanonFactStatus.retired);
    });

    test('a field with no declared status inherits the record', () async {
      await character(
        'kali',
        'Kali Vale',
        fields: const {'identity.age': 27},
        canonStatus: CanonStatus.proposed,
      );
      final canon = (await records.getRecord('kali'))!;
      expect(CanonFields.statusFor(canon, 'identity.age'),
          CanonFactStatus.proposed);
    });

    test('a declared per-field status wins over the record', () async {
      await character('kali', 'Kali Vale',
          fields: const {'identity.age': 27});
      final canon = (await records.getRecord('kali'))!;
      final updated = await records.updateRecord(
        canon.copyWith(
          fields: CanonFields.withFieldStatus(
            canon,
            'identity.age',
            CanonFactStatus.draft,
          ),
          updatedAt: timestamp,
        ),
      );
      expect(CanonFields.statusFor(updated, 'identity.age'),
          CanonFactStatus.draft);
      expect(CanonFields.statusFor(updated, 'summary'), CanonFactStatus.canon);
    });
  });

  group('confidence', () {
    test('is exactly this arithmetic and nothing else', () {
      // Pinned to the digit. A confidence an author cannot predict is a
      // confidence they cannot use.
      CanonFact fact({
        CanonFactStatus status = CanonFactStatus.canon,
        int sources = 0,
        int agreeing = 0,
        int contradictions = 0,
      }) =>
          CanonFact(
            recordId: 'kali',
            fieldId: 'identity.age',
            value: 27,
            status: status,
            sourceCount: sources,
            agreeingStateCount: agreeing,
            contradictionCount: contradictions,
          );

      expect(canonConfidence(fact()), 0.8, reason: 'canon, unsourced');
      expect(canonConfidence(fact(sources: 1)), 1.0);
      expect(canonConfidence(fact(agreeing: 1)), 1.0);
      expect(canonConfidence(fact(status: CanonFactStatus.proposed)), 0.6);
      expect(canonConfidence(fact(status: CanonFactStatus.draft)), 0.4);
      expect(canonConfidence(fact(status: CanonFactStatus.alternate)), 0.3);
      expect(canonConfidence(fact(status: CanonFactStatus.unknown)), 0.1);
      expect(canonConfidence(fact(status: CanonFactStatus.retired)), 0.0);
      expect(canonConfidence(fact(sources: 3, contradictions: 1)), 0.25);
      expect(
        canonConfidence(fact(status: CanonFactStatus.retired, contradictions: 1)),
        0.0,
        reason: 'retired outranks contradicted',
      );
    });

    test('a live contradiction drops confidence and lifts when resolved',
        () async {
      final two = await series.createBook(title: 'Book Two');
      await character('kali', 'Kali Vale',
          fields: const {'identity.age': 27});

      expect(await analyzer.confidenceFor('kali', 'identity.age'), 0.8);

      await series.setEntityState(
        'kali',
        two.id,
        overrides: const {'identity.age': 29},
      );
      expect(await analyzer.confidenceFor('kali', 'identity.age'), 0.25);

      await series.clearEntityState('kali', two.id);
      expect(await analyzer.confidenceFor('kali', 'identity.age'), 0.8);
    });

    test('a contradicted fact reads as contradicted without being stored',
        () async {
      final two = await series.createBook(title: 'Book Two');
      await character('kali', 'Kali Vale',
          fields: const {'identity.age': 27});
      await series.setEntityState(
        'kali',
        two.id,
        overrides: const {'identity.age': 29},
      );

      final fact = await analyzer.factFor('kali', 'identity.age');
      expect(fact.effectiveStatus, CanonFactStatus.contradicted);
      expect(fact.status, CanonFactStatus.canon, reason: 'the stored value');
      expect(
        (await records.getRecord('kali'))!.fields[CanonFields.fieldStatus],
        isNull,
      );
    });
  });
}

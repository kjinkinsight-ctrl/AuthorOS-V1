import 'dart:io';

import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/record_types.dart';
import 'package:author_studio_v1/core/story_codex_domain.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/story_codex_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late StoryCodexService codex;

  setUp(() {
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    codex = StoryCodexService(projectId: 'project-a', repository: repository);
  });

  tearDown(() => database.close());

  test('create load edit archive restore duplicate and soft delete', () async {
    final timestamp = DateTime.utc(2026, 8, 18);
    final created = await codex.createCodexEntry(
      const CodexEntryDraft(
        id: 'house-noxmere',
        title: 'House Noxmere',
        templateId: 'faction',
        categoryId: 'factions',
        summary: 'An old northern house.',
        content: 'Controls the northern passage.',
        structuredFields: {'leader': 'Lady Noxmere'},
        canonStatus: CodexCanonStatus.canon,
        seriesId: 'series-endovier',
        bookId: 'book-1',
      ),
      timestamp: timestamp,
    );

    expect(created.record.typeId, 'faction');
    expect(created.projectId, 'project-a');
    expect(created.seriesId, 'series-endovier');
    expect(created.bookId, 'book-1');
    expect(created.canonStatus, CodexCanonStatus.canon);
    expect(created.structuredFields['leader'], 'Lady Noxmere');

    final edited = await codex.updateCodexEntry(
      created.id,
      title: 'House Noxmere Revised',
      summary: 'The principal northern house.',
      canonStatus: CodexCanonStatus.proposed,
      structuredFields: {'motto': 'Hold the passage'},
      timestamp: timestamp.add(const Duration(minutes: 1)),
    );
    expect(edited.title, 'House Noxmere Revised');
    expect(edited.summary, 'The principal northern house.');
    expect(edited.canonStatus, CodexCanonStatus.proposed);
    expect(edited.structuredFields['motto'], 'Hold the passage');

    expect((await codex.archiveCodexEntry(created.id)).isArchived, isTrue);
    expect((await codex.restoreCodexEntry(created.id)).isArchived, isFalse);
    final duplicate = await codex.duplicateCodexEntry(
      created.id,
      timestamp: timestamp.add(const Duration(minutes: 2)),
    );
    expect(duplicate.id, isNot(created.id));
    expect(duplicate.title, 'House Noxmere Revised Copy');
    expect(duplicate.record.fields['motto'], 'Hold the passage');

    final deleted = await codex.deleteCodexEntry(created.id);
    expect(deleted.isDeleted, isTrue);
    expect(await codex.getCodexEntry(created.id), isNotNull);
    expect(await codex.getEntries(), hasLength(1));
  });

  test('categories tags collections pins and FTS use stable IDs', () async {
    final timestamp = DateTime.utc(2026, 8, 18);
    final category = await codex.createCategory(
      name: 'Noble Houses',
      parentId: 'factions',
      timestamp: timestamp,
    );
    final tag = await codex.createTag(
      name: 'Book One',
      description: 'Appears in the first book.',
      group: 'Books',
      color: '#7A4830',
      timestamp: timestamp,
    );
    final entry = await codex.createCodexEntry(
      CodexEntryDraft(
        id: 'widow-network',
        title: 'Widow Network',
        templateId: 'organisation',
        categoryId: category.id,
        summary: 'A covert network of cartographers.',
        content: 'Maintains hidden coastal routes.',
        tagIds: [tag.id],
      ),
      timestamp: timestamp,
    );
    final collection = await codex.createCollection(
      name: 'Book One Lore',
      recordIds: [entry.id],
      timestamp: timestamp,
    );
    await codex.setPinned(entry.id, true);

    expect(category.id, 'noble-houses');
    expect((await codex.getTags()).single.id, 'book-one');
    expect((await codex.getCodexByTag('book-one')).single.id, entry.id);
    expect((await codex.getCodexByCategory(category.id)).single.id, entry.id);
    expect(collection.recordIds, [entry.id]);
    expect((await codex.getPinnedEntries()).single.id, entry.id);
    expect((await codex.searchCodex('coastal routes')).single.id, entry.id);
  });

  test('connections are reversible and soft deletion preserves endpoints',
      () async {
    final timestamp = DateTime.utc(2026, 8, 18);
    final kali = await codex.createCodexEntry(
      const CodexEntryDraft(
        id: 'kali',
        title: 'Kali',
        templateId: 'character',
        categoryId: 'characters',
        structuredFields: {'identity.fullName': 'Kali'},
      ),
      timestamp: timestamp,
    );
    final network = await codex.createCodexEntry(
      const CodexEntryDraft(
        id: 'widow-network',
        title: 'Widow Network',
        templateId: 'organisation',
        categoryId: 'factions',
      ),
      timestamp: timestamp,
    );
    final link = await codex.connections.connect(
      sourceId: kali.id,
      targetId: network.id,
      typeId: 'memberOf',
      label: 'Member of',
      timestamp: timestamp,
    );

    expect((await codex.getCodexConnections(kali.id)).single.id, link.id);
    expect((await codex.getCodexConnections(network.id)).single.id, link.id);
    await codex.deleteCodexEntry(kali.id);
    expect(await repository.recordById(network.id), isNotNull);
    expect((await codex.getCodexConnections(network.id)).single.id, link.id);
  });

  test('project isolation and series scope metadata survive persistence',
      () async {
    final projectB = StoryCodexService(
      projectId: 'project-b',
      repository: repository,
    );
    final timestamp = DateTime.utc(2026, 8, 18);
    await codex.createCodexEntry(
      const CodexEntryDraft(
        id: 'project-a-entry',
        title: 'Project A Secret',
        templateId: 'secret',
        categoryId: 'plot',
      ),
      timestamp: timestamp,
    );
    await projectB.createCodexEntry(
      const CodexEntryDraft(
        id: 'project-b-entry',
        title: 'Project B Secret',
        templateId: 'secret',
        categoryId: 'plot',
        seriesId: 'series-b',
        bookId: 'book-b1',
      ),
      timestamp: timestamp,
    );

    expect((await codex.getEntries()).single.id, 'project-a-entry');
    expect((await projectB.getEntries()).single.id, 'project-b-entry');
    expect(await codex.getCodexEntry('project-b-entry'), isNull);
    expect(await projectB.getCodexEntry('project-a-entry'), isNull);
    expect(await codex.searchCodex('Project B'), isEmpty);
  });

  test('custom templates can be saved duplicated and archived', () async {
    const custom = RecordTypeDefinition(
      id: 'case',
      name: 'Case',
      categoryId: 'plot',
      scopeType: RecordScopeType.project,
      scopeId: 'project-a',
      fields: [
        RecordFieldDefinition(
          id: 'caseNumber',
          label: 'Case number',
          type: RecordFieldType.shortText,
          order: 0,
          required: true,
        ),
      ],
      sections: [
        RecordTemplateSection(
          id: 'identity',
          title: 'Identity',
          order: 0,
          fieldIds: ['caseNumber'],
        ),
      ],
    );
    await codex.saveTemplate(custom);
    final entry = await codex.createCodexEntry(const CodexEntryDraft(
      id: 'case-1',
      title: 'The Harbor Case',
      templateId: 'case',
      categoryId: 'plot',
      structuredFields: {'caseNumber': '001'},
    ));
    final duplicate = await codex.duplicateTemplate(
      'case',
      newId: 'cold-case',
      newName: 'Cold Case',
    );
    await codex.archiveTemplate('case');

    expect(entry.recordType, 'case');
    expect(duplicate.fields.single.id, 'caseNumber');
    expect(
      (await repository.recordTypeDefinitionById('case'))
          ?.extensionData['archived'],
      isTrue,
    );
  });

  test('records and organization survive database close and reopen', () async {
    await database.close();
    final directory = await Directory.systemTemp.createTemp('codex-service-');
    final file = File('${directory.path}${Platform.pathSeparator}codex.sqlite');
    final firstDatabase = AuthorOsDatabase(NativeDatabase(file));
    final first = StoryCodexService(
      projectId: 'durable-project',
      repository: DriftConnectedDomainRepository(firstDatabase),
    );
    await first.createTag(name: 'Durable');
    await first.createCodexEntry(const CodexEntryDraft(
      id: 'durable-entry',
      title: 'Durable Lore',
      templateId: 'general-lore',
      categoryId: 'lore',
      tagIds: ['durable'],
    ));
    await firstDatabase.close();

    final reopenedDatabase = AuthorOsDatabase(NativeDatabase(file));
    final reopened = StoryCodexService(
      projectId: 'durable-project',
      repository: DriftConnectedDomainRepository(reopenedDatabase),
    );
    expect((await reopened.getEntries()).single.id, 'durable-entry');
    expect((await reopened.getTags()).single.id, 'durable');
    await reopenedDatabase.close();
    await directory.delete(recursive: true);
  });
}

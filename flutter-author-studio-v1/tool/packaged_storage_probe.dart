import 'dart:io';

import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/record_types.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:flutter/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AuthorOsDatabase.defaults();
  try {
    final repository = DriftConnectedDomainRepository(database);
    final timestamp = DateTime.now().toUtc();
    final record = AuthorRecord(
      id: 'probe-character',
      typeId: 'character',
      scopeType: RecordScopeType.project,
      scopeId: 'probe-project',
      title: 'Packaged Probe Character',
      fields: const {'summary': 'Native asset lifecycle probe'},
      createdAt: timestamp,
      updatedAt: timestamp,
      extensionData: const {
        'probeFutureField': {'retained': true},
      },
    );
    final node = ManuscriptNodeReference(
      id: 'probe-scene',
      projectId: 'probe-project',
      nodeType: 'scene',
      title: 'Packaged Probe Scene',
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    final link = RecordLink(
      id: 'probe-link',
      sourceId: record.id,
      targetId: node.id,
      typeId: 'appearsIn',
      scopeId: 'probe-project',
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    const definition = RecordTypeDefinition(
      id: 'probe-template',
      name: 'Probe Template',
      categoryId: 'custom',
      scopeType: RecordScopeType.project,
      scopeId: 'probe-project',
      fields: [
        RecordFieldDefinition(
          id: 'summary',
          label: 'Summary',
          type: RecordFieldType.longText,
          order: 0,
        ),
      ],
      sections: [
        RecordTemplateSection(
          id: 'overview',
          title: 'Overview',
          order: 0,
          fieldIds: ['summary'],
        ),
      ],
    );

    await repository.replaceSnapshot(
      ConnectedDomainSnapshot(
        records: [record],
        manuscriptNodes: [node],
        links: [link],
        recordTypeDefinitions: [definition],
      ),
    );
    final restored = await repository.recordById(record.id);
    final restoredDefinition =
        await repository.recordTypeDefinitionById(definition.id);
    final backlinks = await repository.backlinks(node.id);
    final search = await repository.searchEntityIds('lifecycle');
    final foreignKeys = await database
        .customSelect('PRAGMA foreign_keys')
        .getSingle()
        .then((row) => row.read<int>('foreign_keys'));

    if (restored?.extensionData['probeFutureField'] is! Map ||
        restoredDefinition?.scopeId != 'probe-project' ||
        restoredDefinition?.fields.single.id != 'summary' ||
        backlinks.single.id != link.id ||
        !search.contains(record.id) ||
        foreignKeys != 1) {
      throw StateError('Packaged storage probe validation failed.');
    }
    stdout.writeln('AUTHOROS_STORAGE_PROBE_OK');
    await database.close();
    exit(0);
  } catch (error, stackTrace) {
    stderr.writeln(error);
    stderr.writeln(stackTrace);
    await database.close();
    exit(1);
  }
}

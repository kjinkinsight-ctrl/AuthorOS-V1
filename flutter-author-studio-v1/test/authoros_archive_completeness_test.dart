/// The archive carries the whole project, not just its graph.
///
/// Two things used to fall out of an `.authoros` file. Scene prose lives in
/// the Manuscript Studio's own store rather than the database, so a restore
/// returned a fully-connected graph of **empty scenes** (risk R-2). Writing
/// sessions are the twelfth table but were never written to the archive at
/// all, so a round trip lost every daily total and streak (risk R-22).
///
/// These prove both survive, and that an archive written before either
/// existed still imports.
library;

import 'dart:typed_data';

import 'package:author_studio_v1/archive/authoros_archive.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/writing_session.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

final _timestamp = DateTime.utc(2026, 8, 22, 9);

void main() {
  const service = AuthorOsArchiveService();

  WritingSession session(String id, {int words = 250}) => WritingSession(
        id: id,
        projectId: 'project-1',
        startedAt: _timestamp,
        endedAt: _timestamp.add(const Duration(minutes: 40)),
        startingWordCount: 1000,
        endingWordCount: 1000 + words,
        wordsAdded: words,
        wordsRemoved: 0,
        chapterId: 'chapter-1',
        sceneId: 'scene-1',
      );

  ManuscriptProjectSummary manuscript({required String prose}) =>
      ManuscriptProjectSummary(
        projectId: 'project-1',
        manuscriptTitle: 'The Blood Price',
        chapters: [
          ManuscriptChapter(
            id: 'chapter-1',
            title: 'Chapter One',
            order: 0,
            scenes: [
              ManuscriptScene(
                id: 'scene-1',
                chapterId: 'chapter-1',
                title: 'The Harbor',
                order: 0,
                content: prose,
                status: ManuscriptNodeStatus.draft,
                createdAt: _timestamp,
                updatedAt: _timestamp,
              ),
            ],
            status: ManuscriptNodeStatus.draft,
            createdAt: _timestamp,
            updatedAt: _timestamp,
          ),
        ],
        currentChapterId: 'chapter-1',
        currentSceneId: 'scene-1',
        createdAt: _timestamp,
        updatedAt: _timestamp,
        version: 1,
      );

  Uint8List export(
    ConnectedDomainSnapshot snapshot, {
    Iterable<Map<String, Object?>> manuscripts = const [],
  }) =>
      service.exportSnapshot(
        snapshot,
        archiveId: 'archive-1',
        rootId: 'project-1',
        applicationVersion: '2.0.0',
        platform: 'linux',
        createdAt: _timestamp,
        manuscripts: manuscripts,
      );

  ConnectedDomainSnapshot graphOnly({List<WritingSession> sessions = const []}) =>
      ConnectedDomainSnapshot(
        records: const [],
        manuscriptNodes: const [],
        links: const [],
        writingSessions: sessions,
      );

  group('R-22 — writing sessions survive a round trip', () {
    test('sessions are carried and restored', () {
      final bytes = export(graphOnly(sessions: [session('s-1'), session('s-2')]));

      final restored = service.importArchive(bytes).snapshot;

      expect(restored.writingSessions, hasLength(2));
      expect(
        restored.writingSessions.map((s) => s.id).toSet(),
        {'s-1', 's-2'},
      );
      expect(restored.writingSessions.first.wordsAdded, 250);
    });

    test('a session survives the database round trip too', () async {
      final database = AuthorOsDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftConnectedDomainRepository(database);

      await repository.replaceSnapshot(graphOnly(sessions: [session('s-1')]));
      final snapshot = await repository.snapshot();

      // The archive is only as complete as the snapshot feeding it, so the
      // repository has to carry sessions as well as the format.
      expect(snapshot.writingSessions.single.id, 's-1');
    });
  });

  group('R-2 — manuscript prose survives a round trip', () {
    test('scene content is carried and restored', () {
      const prose = 'The harbor smelled of salt and iron that morning.';
      final bytes = export(
        graphOnly(),
        manuscripts: [manuscript(prose: prose).toJson()],
      );

      final restored = service.importArchive(bytes).manuscripts;

      expect(restored, hasLength(1));
      final recovered = ManuscriptProjectSummary.fromJson(restored.single);
      // The whole point: a restore must not return an empty scene.
      expect(recovered.chapters.single.scenes.single.content, prose);
      expect(recovered.manuscriptTitle, 'The Blood Price');
      expect(recovered.chapters.single.scenes.single.title, 'The Harbor');
    });

    test('prose is byte-exact, not merely present', () {
      const prose = 'Line one.\n\n  Indented line — with an em dash, "quotes",\n'
          'and a trailing newline.\n';
      final bytes = export(
        graphOnly(),
        manuscripts: [manuscript(prose: prose).toJson()],
      );

      final recovered = ManuscriptProjectSummary.fromJson(
        service.importArchive(bytes).manuscripts.single,
      );

      expect(recovered.chapters.single.scenes.single.content, prose);
    });
  });

  group('backwards compatibility', () {
    test('an archive with neither entry still imports', () {
      // Nothing to say about sessions or prose, so neither entry is written —
      // exactly the shape of every archive produced before this change.
      final bytes = export(graphOnly());

      final contents = service.importArchive(bytes);

      expect(contents.snapshot.writingSessions, isEmpty);
      expect(contents.manuscripts, isEmpty);
    });

    test('importSnapshot still returns just the graph', () {
      final bytes = export(
        graphOnly(sessions: [session('s-1')]),
        manuscripts: [manuscript(prose: 'kept').toJson()],
      );

      // The narrower entry point keeps working for callers that only want the
      // graph, so adding prose did not force every caller to change.
      final snapshot = service.importSnapshot(bytes);

      expect(snapshot.writingSessions.single.id, 's-1');
    });

    test('integrity still covers the new entries', () {
      final bytes = export(
        graphOnly(sessions: [session('s-1')]),
        manuscripts: [manuscript(prose: 'kept').toJson()],
      );

      // Flipping one byte of the zip must be rejected, not silently restored.
      final tampered = Uint8List.fromList(bytes);
      tampered[tampered.length ~/ 2] ^= 0xFF;

      expect(() => service.importArchive(tampered), throwsA(anything));
    });
  });
}

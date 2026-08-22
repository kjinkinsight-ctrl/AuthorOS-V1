import 'package:author_studio_v1/core/prose_document.dart';
import 'package:author_studio_v1/core/scene_prose.dart';
import 'package:flutter_test/flutter_test.dart';

SceneProse _prose(
  String text, {
  DateTime? lastSnapshotAt,
  int revision = 1,
}) =>
    SceneProse(
      sceneId: 'scene-1',
      projectId: 'project-a',
      chapterId: 'chapter-1',
      document: ProseDocument.fromPlainText(text),
      updatedAt: DateTime.utc(2026, 8, 21, 9),
      revision: revision,
      lastSnapshotAt: lastSnapshotAt,
    );

void main() {
  final now = DateTime.utc(2026, 8, 21, 12);

  group('snapshot policy', () {
    const policy = SceneProseSnapshotPolicy();

    test('keeps the first state a scene is edited away from', () {
      // Nothing has ever been kept for this scene, so the words about to be
      // replaced are the only copy that exists.
      expect(
        policy.shouldCapture(
          outgoing: _prose('The opening line.'),
          incoming: ProseDocument.fromPlainText('The opening line, rewritten.'),
          now: now,
        ),
        isTrue,
      );
    });

    test('does not snapshot every autosave', () {
      // The point of the interval: an author typing produces a save roughly
      // twice a second, and none of those are history worth keeping.
      expect(
        policy.shouldCapture(
          outgoing: _prose(
            'The opening line.',
            lastSnapshotAt: now.subtract(const Duration(seconds: 20)),
          ),
          incoming: ProseDocument.fromPlainText('The opening line!'),
          now: now,
        ),
        isFalse,
      );
    });

    test('snapshots once the interval has passed', () {
      expect(
        policy.shouldCapture(
          outgoing: _prose(
            'The opening line.',
            lastSnapshotAt: now.subtract(const Duration(minutes: 5)),
          ),
          incoming: ProseDocument.fromPlainText('The opening line!'),
          now: now,
        ),
        isTrue,
      );
    });

    test('snapshots a large loss immediately, whatever the interval says', () {
      // This is the select-all-and-type case. It is the whole reason the
      // history exists, and it must not depend on when the timer last fired.
      final long = List.filled(200, 'word').join(' ');
      expect(
        policy.shouldCapture(
          outgoing: _prose(
            long,
            lastSnapshotAt: now.subtract(const Duration(seconds: 1)),
          ),
          incoming: ProseDocument.fromPlainText('oops'),
          now: now,
        ),
        isTrue,
      );
    });

    test('never snapshots an empty scene', () {
      expect(
        policy.shouldCapture(
          outgoing: _prose(''),
          incoming: ProseDocument.fromPlainText('The first words.'),
          now: now,
        ),
        isFalse,
      );
    });

    test('never snapshots prose that did not change', () {
      expect(
        policy.shouldCapture(
          outgoing: _prose('Unchanged.'),
          incoming: ProseDocument.fromPlainText('Unchanged.'),
          now: now,
        ),
        isFalse,
      );
    });
  });

  group('digests', () {
    SceneProseDigest digest({required bool isFormatted}) => SceneProseDigest(
          sceneId: 'scene-1',
          chapterId: 'chapter-1',
          plainText: 'Kali waited.',
          wordCount: 2,
          revision: 1,
          updatedAt: now,
          isFormatted: isFormatted,
        );

    test('unchanged plain prose is recognised without reading the document',
        () {
      expect(digest(isFormatted: false).matchesPlainText('Kali waited.'), isTrue);
      expect(digest(isFormatted: false).matchesPlainText('Kali waited'), isFalse);
    });

    test('formatted prose never matches on text alone', () {
      // The marks are invisible to a plain-text comparison, so the cheap path
      // has to decline rather than guess. Without this, toggling a word to
      // italic and back would read as "nothing changed".
      expect(digest(isFormatted: true).matchesPlainText('Kali waited.'), isFalse);
    });
  });

  group('records', () {
    test('a snapshot carries the prose forward unchanged', () {
      final snapshot = _prose('Kali waited.', revision: 4).snapshot(
        capturedAt: now,
        reason: SceneProseSnapshotReason.beforeRestore,
      );
      expect(snapshot.sceneId, 'scene-1');
      expect(snapshot.projectId, 'project-a');
      expect(snapshot.revision, 4);
      expect(snapshot.plainText, 'Kali waited.');
      expect(snapshot.wordCount, 2);
      expect(snapshot.reason, SceneProseSnapshotReason.beforeRestore);
      expect(snapshot.capturedAt, now);
    });

    test('ids do not collide inside one microsecond', () {
      final ids = {for (var index = 0; index < 500; index++) SceneProseId.create(now)};
      expect(ids, hasLength(500));
    });

    test('survives a JSON round trip', () {
      final original = _prose('Kali waited.', lastSnapshotAt: now, revision: 7);
      final restored = SceneProse.fromJson(
        Map<String, dynamic>.from(original.toJson()),
      );
      expect(restored.sceneId, original.sceneId);
      expect(restored.projectId, original.projectId);
      expect(restored.chapterId, original.chapterId);
      expect(restored.revision, 7);
      expect(restored.document, original.document);
      expect(restored.updatedAt, original.updatedAt);
      expect(restored.lastSnapshotAt, now);
    });

    test('an unknown snapshot reason reads back as a routine one', () {
      expect(
        SceneProseSnapshotReasonX.fromId('somethingNewer'),
        SceneProseSnapshotReason.autosave,
      );
    });
  });
}

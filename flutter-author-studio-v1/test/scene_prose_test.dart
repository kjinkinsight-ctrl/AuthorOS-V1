import 'package:author_studio_v1/core/prose_document.dart';
import 'package:author_studio_v1/core/scene_prose.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 22, 12);

  SceneProse prose(String text, {int revision = 1}) => SceneProse(
        sceneId: 'scene-1',
        projectId: 'project-a',
        chapterId: 'chapter-1',
        document: ProseDocument.fromPlainText(text),
        updatedAt: now,
        revision: revision,
      );

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
      expect(
        digest(isFormatted: false).matchesPlainText('Kali waited.'),
        isTrue,
      );
      expect(
        digest(isFormatted: false).matchesPlainText('Kali waited'),
        isFalse,
      );
    });

    test('formatted prose never matches on text alone', () {
      // The marks are invisible to a plain-text comparison, so the cheap path
      // has to decline rather than guess. Without this, toggling a word to
      // italic and back would read as "nothing changed".
      expect(
        digest(isFormatted: true).matchesPlainText('Kali waited.'),
        isFalse,
      );
    });
  });

  group('records', () {
    test('survives a JSON round trip', () {
      final restored = SceneProse.fromJson(
        Map<String, dynamic>.from(prose('Kali waited.', revision: 7).toJson()),
      );
      expect(restored.sceneId, 'scene-1');
      expect(restored.projectId, 'project-a');
      expect(restored.chapterId, 'chapter-1');
      expect(restored.revision, 7);
      expect(restored.plainText, 'Kali waited.');
      expect(restored.wordCount, 2);
      expect(restored.updatedAt, now);
    });

    test('carries no history of its own', () {
      // The architecture rule, asserted where it is easiest to break: this
      // library holds current prose. What a scene *used* to say belongs to
      // scene_revision.dart, and there is exactly one of it.
      final json = prose('Kali waited.').toJson();
      expect(json.keys, isNot(contains('snapshots')));
      expect(json.keys, isNot(contains('history')));
      expect(json.keys, isNot(contains('revisions')));
    });
  });
}

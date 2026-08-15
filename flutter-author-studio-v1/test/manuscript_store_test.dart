import 'package:author_studio_v1/manuscript_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('manuscript store persists drafts independently by project', () async {
    const store = ManuscriptStore();

    await store.save('project-a', 'The opening line.');
    await store.save('project-b', 'A different manuscript.');

    expect(await store.load('project-a'), 'The opening line.');
    expect(await store.load('project-b'), 'A different manuscript.');
    expect(await store.load('project-c'), isEmpty);
  });
}
/// Every mode is checked against the live registries.
///
/// A mode names record categories and connection type ids as plain strings. If
/// one is renamed or removed, the mode would quietly stop drawing part of the
/// graph and nothing would say so. These tests turn that into a failure.
library;

import 'package:author_studio_v1/core/built_in_connection_types.dart';
import 'package:author_studio_v1/core/built_in_record_types.dart';
import 'package:author_studio_v1/core/story_graph.dart';
import 'package:author_studio_v1/core/story_graph_modes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final recordTypes = BuiltInRecordTypes.registry();
  final connectionTypes = BuiltInConnectionTypes.registry();

  final knownCategories = {
    for (final definition in recordTypes.definitions)
      recordTypes.resolve(definition.id).categoryId,
  };
  final knownConnectionIds = {
    for (final definition in connectionTypes.definitions) definition.id,
  };

  test('every edge type a mode names exists in the registry', () {
    final unknown = <String>[];
    for (final mode in StoryGraphModes.all) {
      for (final typeId in mode.edgeTypeIds) {
        if (!knownConnectionIds.contains(typeId)) {
          unknown.add('${mode.id}: $typeId');
        }
      }
    }

    expect(
      unknown,
      isEmpty,
      reason: 'A mode names a connection type that no longer exists. The mode '
          'would silently stop drawing those relationships.',
    );
  });

  test('every category a mode names exists in the registry', () {
    final unknown = <String>[];
    for (final mode in StoryGraphModes.all) {
      for (final categoryId in {
        ...mode.rootCategoryIds,
        ...mode.nodeCategoryIds,
      }) {
        if (!knownCategories.contains(categoryId)) {
          unknown.add('${mode.id}: $categoryId');
        }
      }
    }

    expect(
      unknown,
      isEmpty,
      reason: 'A mode names a record category that no longer exists. Its nodes '
          'would be filtered out of their own view.',
    );
  });

  test('a rooted mode can always render its own root category', () {
    for (final mode in StoryGraphModes.all.where((mode) => mode.rooted)) {
      if (mode.nodeCategoryIds.isEmpty) continue;
      expect(
        mode.nodeCategoryIds,
        containsAll(mode.rootCategoryIds),
        reason: '${mode.id} anchors on a category its own node filter would '
            'exclude, so the root node would vanish from its own graph.',
      );
    }
  });

  test('every category maps to a bucket other than "other"', () {
    // `other` is the safety net for a project-defined category. No built-in
    // category should be landing there — that would mean a whole class of
    // record showing up unlabelled in the explorer.
    final unbucketed = [
      for (final categoryId in knownCategories)
        if (bucketForCategory(categoryId) == StoryGraphBucket.other) categoryId,
    ];

    expect(unbucketed, isEmpty);
  });

  test('modes have unique ids and the project mode accepts any root', () {
    expect(
      StoryGraphModes.all.map((mode) => mode.id).toSet(),
      hasLength(StoryGraphModes.all.length),
    );
    expect(StoryGraphModes.project.rooted, isFalse);
    expect(StoryGraphModes.byId('character'), StoryGraphModes.character);
    expect(StoryGraphModes.byId('nonsense'), isNull);
  });

  test('filterFrom keeps the scope choices the author already made', () {
    const base = StoryGraphFilter(bookId: 'book-1', includeArchived: true);

    final filter = StoryGraphModes.character.filterFrom(base);

    // Switching mode must not silently drop "Book 1 only".
    expect(filter.bookId, 'book-1');
    expect(filter.includeArchived, isTrue);
    expect(filter.categoryIds, StoryGraphModes.character.nodeCategoryIds);
    expect(filter.edgeTypeIds, StoryGraphModes.character.edgeTypeIds);
  });

  test('the plot mode keeps its wildcard edges despite the wildcard filter',
      () {
    final filter = StoryGraphModes.plot.filterFrom(StoryGraphFilter.unfiltered);
    final plannedFor = connectionTypes.resolve('plannedFor');

    // `plannedFor` is a `*` -> `*` type. It is also the only way a scene
    // attaches to a plot beat, so the mode naming it must win.
    expect(plannedFor.permits('*', '*'), isTrue);
    expect(filter.includeWildcardEdges, isFalse);
    expect(filter.allowsEdgeType('plannedFor', plannedFor), isTrue);
  });
}

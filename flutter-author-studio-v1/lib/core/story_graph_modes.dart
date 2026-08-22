/// The Knowledge Graph's focused views.
///
/// One graph of everything is a hairball: `relatedTo` alone is suggested on all
/// ~224 record types, and 73 of ~130 connection types permit `*` -> `*`. So the
/// product shows *modes* — a character's relationships, a world's geography, a
/// plot's spine, a manuscript's structure — each with its own node and edge
/// vocabulary.
///
/// A mode is **data, not a code path**. Adding one is a new [StoryGraphMode]
/// const; nothing branches on mode id. Every edge id named here is asserted
/// against the live registry by `test/story_graph_modes_test.dart`, so renaming
/// a connection type fails a test rather than silently emptying a view.
library;

import 'story_graph.dart';

/// How a mode's nodes are arranged.
enum StoryGraphLayout {
  /// Centre node, neighbours on rings by depth. Suits "what surrounds this".
  radial,

  /// Longest-path layering along directed edges. Suits sequences — a plot
  /// spine, a manuscript's book/chapter/scene descent.
  layered,
}

class StoryGraphMode {
  const StoryGraphMode({
    required this.id,
    required this.label,
    required this.description,
    required this.layout,
    this.rootCategoryIds = const {},
    this.nodeCategoryIds = const {},
    this.edgeTypeIds = const {},
    this.defaultDepth = 2,
  });

  final String id;
  final String label;

  /// Shown when the mode has nothing to draw, so an empty view explains itself.
  final String description;
  final StoryGraphLayout layout;

  /// Categories whose records may anchor this mode. Empty means the mode has no
  /// single root — the Project mode.
  final Set<String> rootCategoryIds;

  /// Categories that may appear. Empty means every category.
  final Set<String> nodeCategoryIds;

  /// Edge types that may appear. Empty means every non-wildcard type.
  ///
  /// Naming a type here is an explicit request, so it survives the wildcard
  /// filter — which is what lets the Plot mode use `plannedFor` and
  /// `resolvesIn`, the only edges scene-to-plot has.
  final Set<String> edgeTypeIds;

  final int defaultDepth;

  bool get rooted => rootCategoryIds.isNotEmpty;

  bool acceptsRoot(StoryGraphNode node) =>
      !rooted || rootCategoryIds.contains(node.categoryId);

  /// The starting filter for this mode, narrowed by [base]'s lifecycle and
  /// scope choices so switching mode does not silently reset "Book 1 only".
  StoryGraphFilter filterFrom(StoryGraphFilter base) => base.copyWith(
        categoryIds: nodeCategoryIds,
        edgeTypeIds: edgeTypeIds,
      );
}

/// The built-in modes, in the order the mode switcher shows them.
abstract final class StoryGraphModes {
  static const character = StoryGraphMode(
    id: 'character',
    label: 'Character',
    description: 'Who a character knows, where they live, what they carry, '
        'and the scenes they appear in.',
    layout: StoryGraphLayout.radial,
    defaultDepth: 1,
    rootCategoryIds: {'characters'},
    nodeCategoryIds: {
      'characters',
      'factions',
      'locations',
      'places',
      'world',
      'items',
      'plot',
      'manuscript',
      'timeline',
    },
    edgeTypeIds: {
      // Character to character.
      'friendOf', 'enemyOf', 'alliedWith', 'rivalOf', 'partnerOf',
      'parentOf', 'guardianOf', 'mentors', 'protects', 'employs',
      'trusts', 'distrusts', 'knows',
      // Allegiance and belongings.
      'memberOf', 'owns', 'uses', 'carries', 'controls',
      // Place.
      'livesIn', 'bornIn', 'worksIn', 'visits', 'currentlyAt', 'previouslyAt',
      'homeAt', 'safehouseAt', 'favouriteLocation', 'forbiddenFrom',
      'fromLocation',
      // Story.
      'appearsIn', 'mentionedIn', 'pursues', 'hasArc',
    },
  );

  static const world = StoryGraphMode(
    id: 'world',
    label: 'World',
    description: 'How places contain, border and connect to one another, and '
        'who is found in them.',
    layout: StoryGraphLayout.radial,
    rootCategoryIds: {'locations', 'places', 'world'},
    nodeCategoryIds: {
      'locations',
      'places',
      'world',
      'routes',
      'maps',
      'characters',
      'factions',
      'timeline',
    },
    edgeTypeIds: {
      // Containment and adjacency.
      'locatedIn', 'contains', 'inside', 'outside', 'surrounds', 'crosses',
      'passesThrough', 'above', 'below', 'northOf', 'southOf', 'adjacentTo',
      'borders', 'near', 'farFrom', 'accessibleFrom', 'inaccessibleFrom',
      'leadsTo',
      // Maps and routes.
      'maps', 'onMap', 'represents', 'routeFrom', 'routeTo',
      // Who and what is there.
      'livesIn', 'bornIn', 'worksIn', 'visits', 'currentlyAt', 'headquartersAt',
      'rules', 'governedBy', 'hasCulture', 'knownFor', 'controls', 'occursAt',
    },
  );

  static const plot = StoryGraphMode(
    id: 'plot',
    label: 'Plot',
    description: 'How threads cause, oppose and resolve one another, and which '
        'scenes carry them.',
    layout: StoryGraphLayout.layered,
    rootCategoryIds: {'plot'},
    nodeCategoryIds: {'plot', 'manuscript', 'characters', 'timeline'},
    edgeTypeIds: {
      // Plot's own vocabulary. Every one of these is a wildcard type: there is
      // no typed scene-to-plot edge in the architecture yet, and naming them
      // explicitly is what keeps them visible.
      'causes', 'changes', 'paidOffBy', 'plannedFor', 'fulfilledBy',
      'resolvesIn', 'dependsOn', 'opposes', 'motivatedBy', 'hasStake',
      'depicts',
      // Where a thread is carried and who carries it.
      'appearsIn', 'mentionedIn', 'pursues', 'hasArc', 'involves',
    },
  );

  static const manuscript = StoryGraphMode(
    id: 'manuscript',
    label: 'Manuscript',
    description: 'The book, its chapters and scenes, and the entities each '
        'scene touches.',
    layout: StoryGraphLayout.layered,
    rootCategoryIds: {'manuscript'},
    edgeTypeIds: {
      // Structure. Both are wildcards — the manuscript spine has no typed
      // containment edge, and chapter membership actually lives in the node's
      // extensionData, surfaced as a derived edge rather than a link.
      'partOf', 'contains',
      // What a scene is about.
      'appearsIn', 'mentionedIn', 'occursAt', 'involves', 'depicts',
      'revealedIn', 'introducedIn', 'foreshadowedIn', 'resolvesIn',
    },
  );

  static const project = StoryGraphMode(
    id: 'project',
    label: 'Project',
    description: 'Everything in the project. Filter it down to read it.',
    layout: StoryGraphLayout.radial,
    defaultDepth: 1,
  );

  static const List<StoryGraphMode> all = [
    character,
    world,
    plot,
    manuscript,
    project,
  ];

  static StoryGraphMode? byId(String id) {
    for (final mode in all) {
      if (mode.id == id) return mode;
    }
    return null;
  }

  /// The mode that best fits [node], for "open this in the graph" from another
  /// Studio. Falls back to [project], which accepts anything.
  static StoryGraphMode forNode(StoryGraphNode node) {
    for (final mode in all) {
      if (mode.rooted && mode.acceptsRoot(node)) return mode;
    }
    return project;
  }
}

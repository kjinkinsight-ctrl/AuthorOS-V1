/// The two rails either side of the canvas: filters on the left, the
/// Connection Explorer on the right.
///
/// Both are stateless. The filter rail raises a whole new [StoryGraphFilter]
/// rather than mutating one, and the explorer raises the node that was
/// clicked — the view owns all of it. That is the same shape Story Codex's
/// rail already uses, and it is what makes both testable without a harness.
library;

import 'package:flutter/material.dart';

import '../core/story_graph.dart';
import '../core/story_graph_modes.dart';
import 'graph_canvas.dart';

/// Filters, grouped the way the product describes them.
class GraphFilterRail extends StatelessWidget {
  const GraphFilterRail({
    super.key,
    required this.mode,
    required this.filter,
    required this.palette,
    required this.onFilterChanged,
    this.books = const [],
    this.hiddenCount = 0,
  });

  final StoryGraphMode mode;
  final StoryGraphFilter filter;
  final GraphPalette palette;
  final ValueChanged<StoryGraphFilter> onFilterChanged;

  /// (id, label) for every book in the project, for "Book 1 only".
  final List<(String, String)> books;

  /// How many of the focused node's connections the filters are hiding, so the
  /// rail can say so rather than leaving the author wondering where things
  /// went.
  final int hiddenCount;

  @override
  Widget build(BuildContext context) {
    // The mode decides which categories are even available; offering a filter
    // for something the mode never shows is noise.
    final categories = mode.nodeCategoryIds.isEmpty
        ? _allCategories
        : (mode.nodeCategoryIds.toList()..sort());

    return ListView(
      key: const Key('graph-filter-rail'),
      padding: const EdgeInsets.all(12),
      children: [
        _header('Show', palette),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final categoryId in categories)
              FilterChip(
                key: Key('graph-category-filter-$categoryId'),
                label: Text(_categoryLabel(categoryId)),
                avatar: Icon(
                  iconForBucket(bucketForCategory(categoryId)),
                  size: 15,
                ),
                selected: filter.categoryIds.contains(categoryId),
                onSelected: (_) =>
                    onFilterChanged(filter.toggleCategory(categoryId)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _header('Scope', palette),
        if (books.isEmpty)
          Text('No books in this project yet.', style: palette.label)
        else
          DropdownButton<String?>(
            key: const Key('graph-book-filter'),
            isExpanded: true,
            value: filter.bookId,
            hint: const Text('All books'),
            items: [
              const DropdownMenuItem<String?>(child: Text('All books')),
              for (final (id, label) in books)
                DropdownMenuItem<String?>(value: id, child: Text(label)),
            ],
            onChanged: (bookId) => onFilterChanged(
              bookId == null
                  ? filter.copyWith(clearBook: true)
                  : filter.copyWith(bookId: bookId),
            ),
          ),
        const SizedBox(height: 16),
        _header('Include', palette),
        // Each of these is off by default for a stated reason, so the switch
        // says the reason rather than just the name.
        _toggle(
          key: 'graph-toggle-related',
          label: 'Loose "related to" links',
          detail: 'Suggested on every record type. Busy.',
          value: filter.includeRelatedTo,
          onChanged: (value) =>
              onFilterChanged(filter.copyWith(includeRelatedTo: value)),
          palette: palette,
        ),
        _toggle(
          key: 'graph-toggle-wildcard',
          label: 'Untyped links',
          detail: 'Real relationships with no type discipline.',
          value: filter.includeWildcardEdges,
          onChanged: (value) =>
              onFilterChanged(filter.copyWith(includeWildcardEdges: value)),
          palette: palette,
        ),
        _toggle(
          key: 'graph-toggle-archived',
          label: 'Archived records',
          detail: 'Still connected, just retired.',
          value: filter.includeArchived,
          onChanged: (value) =>
              onFilterChanged(filter.copyWith(includeArchived: value)),
          palette: palette,
        ),
        _toggle(
          key: 'graph-toggle-deleted',
          label: 'Deleted records',
          detail: 'Deletion is soft; their links survive it.',
          value: filter.includeDeleted,
          onChanged: (value) =>
              onFilterChanged(filter.copyWith(includeDeleted: value)),
          palette: palette,
        ),
        if (hiddenCount > 0) ...[
          const SizedBox(height: 12),
          Container(
            key: const Key('graph-hidden-notice'),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.outlineVariant),
            ),
            // Never hide silently: a graph that quietly drops nodes is a
            // continuity hazard, not a tidy view. The count is of the focused
            // node's connections, which is what the filters were measured
            // against — so the wording says connections, not nodes.
            child: Text(
              '$hiddenCount ${hiddenCount == 1 ? 'connection is' : 'connections are'} '
              'hidden by these filters.',
              style: palette.label,
            ),
          ),
        ],
      ],
    );
  }

  Widget _toggle({
    required String key,
    required String label,
    required String detail,
    required bool value,
    required ValueChanged<bool> onChanged,
    required GraphPalette palette,
  }) =>
      SwitchListTile(
        key: Key(key),
        dense: true,
        contentPadding: EdgeInsets.zero,
        value: value,
        onChanged: onChanged,
        title: Text(label, style: palette.title),
        subtitle: Text(detail, style: palette.label),
      );

  Widget _header(String text, GraphPalette palette) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text.toUpperCase(), style: palette.label),
      );
}

/// Everything connected to the focused node, grouped and countable.
class ConnectionExplorer extends StatelessWidget {
  const ConnectionExplorer({
    super.key,
    required this.palette,
    required this.onNodeSelected,
    this.neighbourhood,
    this.summary,
    this.trail = const [],
    this.onTrailTapped,
    this.onOpenInStudio,
  });

  final GraphPalette palette;
  final ValueChanged<StoryGraphNode> onNodeSelected;
  final StoryGraphNeighbourhood? neighbourhood;
  final ConnectionSummary? summary;

  /// The nodes focused before this one, oldest first.
  final List<StoryGraphNode> trail;
  final ValueChanged<int>? onTrailTapped;
  final ValueChanged<StoryGraphNode>? onOpenInStudio;

  @override
  Widget build(BuildContext context) {
    final centre = neighbourhood?.centre;
    if (centre == null) {
      return Center(
        child: Padding(
          key: const Key('graph-explorer-empty'),
          padding: const EdgeInsets.all(20),
          child: Text(
            'Pick a node to see everything it connects to.',
            textAlign: TextAlign.center,
            style: palette.label,
          ),
        ),
      );
    }

    return ListView(
      key: const Key('graph-connection-explorer'),
      padding: const EdgeInsets.all(12),
      children: [
        if (trail.isNotEmpty) _breadcrumbs(),
        Row(
          children: [
            Icon(iconForBucket(centre.bucket), size: 18,
                color: palette.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                centre.title,
                key: const Key('graph-explorer-title'),
                style: palette.title,
              ),
            ),
          ],
        ),
        Text(centre.typeId, style: palette.label),
        if (!centre.versioned)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            // Being honest about the second node kind rather than offering
            // history that cannot exist.
            child: Text(
              'Manuscript node — its detail and history live in Manuscript '
              'Studio.',
              style: palette.label,
            ),
          ),
        if (centre.inspectable && onOpenInStudio != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('graph-open-in-studio'),
              onPressed: () => onOpenInStudio!(centre),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Open record'),
            ),
          ),
        const Divider(height: 24),
        if (summary != null) _summaryCard(summary!),
        for (final entry in neighbourhood!.buckets.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Text(
              '${entry.key.label} · ${entry.value.length}',
              style: palette.label,
            ),
          ),
          for (final node in entry.value)
            ListTile(
              key: Key('graph-explorer-node-${node.id}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(iconForBucket(node.bucket), size: 18),
              title: Text(node.title, style: palette.title),
              subtitle: Text(node.typeId, style: palette.label),
              // Selecting refocuses the whole graph on this node, which is
              // what makes the explorer a way of moving around rather than a
              // list of names.
              onTap: () => onNodeSelected(node),
            ),
        ],
        if (neighbourhood!.neighbours.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(
              'Nothing connects to this yet, or the filters hide it all.',
              key: const Key('graph-explorer-no-neighbours'),
              style: palette.label,
            ),
          ),
      ],
    );
  }

  Widget _breadcrumbs() => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var index = 0; index < trail.length; index++) ...[
              InkWell(
                key: Key('graph-breadcrumb-${trail[index].id}'),
                onTap: onTrailTapped == null
                    ? null
                    : () => onTrailTapped!(index),
                child: Text(trail[index].title, style: palette.label),
              ),
              Icon(Icons.chevron_right, size: 14,
                  color: palette.onSurfaceVariant),
            ],
          ],
        ),
      );

  Widget _summaryCard(ConnectionSummary summary) => Container(
        key: const Key('graph-connection-summary'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${summary.total} connections', style: palette.title),
            const SizedBox(height: 8),
            for (final bucket in summary.populated)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(bucket.label, style: palette.label),
                    ),
                    Text('${summary.countFor(bucket)}', style: palette.label),
                  ],
                ),
              ),
          ],
        ),
      );
}

/// Every built-in record category, for the Project mode's rail.
const List<String> _allCategories = [
  'characters',
  'creatures',
  'culture',
  'custom',
  'factions',
  'history',
  'items',
  'locations',
  'lore',
  'magic',
  'manuscript',
  'maps',
  'places',
  'plot',
  'reference',
  'religion',
  'research',
  'routes',
  'technology',
  'timeline',
  'world',
];

String _categoryLabel(String categoryId) => switch (categoryId) {
      'characters' => 'Characters',
      'creatures' => 'Creatures',
      'culture' => 'Culture',
      'custom' => 'Custom',
      'factions' => 'Factions',
      'history' => 'History',
      'items' => 'Items',
      'locations' => 'Locations',
      'lore' => 'Lore',
      'magic' => 'Magic',
      'manuscript' => 'Manuscript',
      'maps' => 'Maps',
      'places' => 'Places',
      'plot' => 'Plot',
      'reference' => 'Notes',
      'religion' => 'Religion',
      'research' => 'Research',
      'routes' => 'Routes',
      'technology' => 'Technology',
      'timeline' => 'Timeline',
      'world' => 'World',
      _ => categoryId,
    };

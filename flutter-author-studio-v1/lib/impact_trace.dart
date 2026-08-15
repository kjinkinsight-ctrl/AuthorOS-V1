import 'package:flutter/material.dart';

enum TraceEntityType { scene, character, plotline, note, plotBeat }

class TraceEntity {
  const TraceEntity({
    required this.id,
    required this.label,
    required this.type,
  });

  final String id;
  final String label;
  final TraceEntityType type;
}

class TraceLink {
  const TraceLink({
    required this.sourceId,
    required this.targetId,
    required this.label,
  });

  final String sourceId;
  final String targetId;
  final String label;
}

class ImpactTraceResult {
  const ImpactTraceResult({
    required this.source,
    required this.affected,
    required this.relationships,
  });

  final TraceEntity source;
  final List<TraceEntity> affected;
  final List<CharacterRelationship> relationships;
}

class CharacterRelationship {
  const CharacterRelationship({
    required this.firstCharacter,
    required this.secondCharacter,
    required this.sharedSceneCount,
  });

  final String firstCharacter;
  final String secondCharacter;
  final int sharedSceneCount;
}

class ImpactTraceAnalyzer {
  const ImpactTraceAnalyzer();

  ImpactTraceResult trace({
    required String sourceId,
    required List<TraceEntity> entities,
    required List<TraceLink> links,
    int maxDepth = 2,
  }) {
    final entityById = {for (final entity in entities) entity.id: entity};
    final source = entityById[sourceId];
    if (source == null) {
      throw ArgumentError.value(sourceId, 'sourceId', 'Unknown trace entity');
    }

    final visited = <String>{sourceId};
    var frontier = <String>{sourceId};
    for (var depth = 0; depth < maxDepth && frontier.isNotEmpty; depth++) {
      final next = <String>{};
      for (final link in links) {
        if (frontier.contains(link.sourceId) &&
            !visited.contains(link.targetId)) {
          next.add(link.targetId);
        }
        if (frontier.contains(link.targetId) &&
            !visited.contains(link.sourceId)) {
          next.add(link.sourceId);
        }
      }
      visited.addAll(next);
      frontier = next;
    }

    final affected = visited
        .where((id) => id != sourceId && entityById.containsKey(id))
        .map((id) => entityById[id]!)
        .toList()
      ..sort((left, right) {
        final byType = left.type.index.compareTo(right.type.index);
        return byType != 0 ? byType : left.label.compareTo(right.label);
      });

    return ImpactTraceResult(
      source: source,
      affected: affected,
      relationships: characterRelationships(entities: entities, links: links),
    );
  }

  List<CharacterRelationship> characterRelationships({
    required List<TraceEntity> entities,
    required List<TraceLink> links,
  }) {
    final characterIds = entities
        .where((entity) => entity.type == TraceEntityType.character)
        .map((entity) => entity.id)
        .toSet();
    final scenesByCharacter = <String, Set<String>>{};
    for (final link in links) {
      if (characterIds.contains(link.sourceId) &&
          link.targetId.startsWith('scene:')) {
        scenesByCharacter
            .putIfAbsent(link.sourceId, () => {})
            .add(link.targetId);
      }
      if (characterIds.contains(link.targetId) &&
          link.sourceId.startsWith('scene:')) {
        scenesByCharacter
            .putIfAbsent(link.targetId, () => {})
            .add(link.sourceId);
      }
    }

    final characters = entities
        .where((entity) => entity.type == TraceEntityType.character)
        .toList();
    final relationships = <CharacterRelationship>[];
    for (var leftIndex = 0; leftIndex < characters.length; leftIndex++) {
      for (var rightIndex = leftIndex + 1;
          rightIndex < characters.length;
          rightIndex++) {
        final left = characters[leftIndex];
        final right = characters[rightIndex];
        final shared = (scenesByCharacter[left.id] ?? const <String>{})
            .intersection(scenesByCharacter[right.id] ?? const <String>{});
        if (shared.isNotEmpty) {
          relationships.add(CharacterRelationship(
            firstCharacter: left.label,
            secondCharacter: right.label,
            sharedSceneCount: shared.length,
          ));
        }
      }
    }
    relationships.sort((left, right) =>
        right.sharedSceneCount.compareTo(left.sharedSceneCount));
    return relationships;
  }
}

class ImpactTracePanel extends StatelessWidget {
  const ImpactTracePanel({super.key, required this.result});

  final ImpactTraceResult result;

  @override
  Widget build(BuildContext context) {
    final grouped = <TraceEntityType, List<TraceEntity>>{};
    for (final entity in result.affected) {
      grouped.putIfAbsent(entity.type, () => []).add(entity);
    }

    return ExpansionTile(
      key: const Key('impact-trace-panel'),
      initiallyExpanded: true,
      leading: const Icon(Icons.hub_outlined, color: Color(0xFFC59B6D)),
      title: const Text('Impact trace'),
      subtitle: Text(
        'If ${result.source.label} changes, ${result.affected.length} linked items may be affected.',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        for (final type in TraceEntityType.values)
          if (grouped[type]?.isNotEmpty ?? false)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  '${_typeLabel(type)}: ${grouped[type]!.map((entity) => entity.label).join(', ')}',
                  key: Key('impact-group-${type.name}'),
                ),
              ),
            ),
        if (result.relationships.isNotEmpty) ...[
          const Divider(),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Character relationships',
                style: Theme.of(context).textTheme.titleSmall),
          ),
          const SizedBox(height: 8),
          for (final relationship in result.relationships)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${relationship.firstCharacter} ↔ ${relationship.secondCharacter} · ${relationship.sharedSceneCount} shared scene${relationship.sharedSceneCount == 1 ? '' : 's'}',
              ),
            ),
        ],
      ],
    );
  }

  String _typeLabel(TraceEntityType type) => switch (type) {
        TraceEntityType.scene => 'Scenes',
        TraceEntityType.character => 'Characters',
        TraceEntityType.plotline => 'Plotlines',
        TraceEntityType.note => 'Notes',
        TraceEntityType.plotBeat => 'Plot beats',
      };
}

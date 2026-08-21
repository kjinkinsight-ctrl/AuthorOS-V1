import 'package:flutter/material.dart';

import 'core/canon_facts.dart';
import 'core/connected_domain.dart';
import 'core/record_inspection.dart';
import 'entity_profile.dart';
import 'entity_profile_service.dart';

/// One entity's whole series on one page: what it is, where it is used, and
/// what disagrees about it.
///
/// Reusable across Studios on purpose. The profile is a property of the entity,
/// not of the screen that happens to be showing it, so a character reads the
/// same way in the Codex as it would anywhere else.
class EntityProfileView extends StatelessWidget {
  const EntityProfileView({
    super.key,
    required this.service,
    required this.recordId,
    this.onOpenRecord,
  });

  final EntityProfileService service;
  final String recordId;
  final ValueChanged<String>? onOpenRecord;

  @override
  Widget build(BuildContext context) => FutureBuilder<EntityProfile?>(
        key: ValueKey('entity-profile-$recordId'),
        future: service.profileFor(recordId),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Text(
              '${snapshot.error}',
              key: const Key('entity-profile-error'),
            );
          }
          final profile = snapshot.data;
          if (profile == null) {
            return const Text('This entry no longer exists.');
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(context, profile),
              const SizedBox(height: 16),
              _usage(context, profile.usage),
              const SizedBox(height: 16),
              for (final section in profile.nonEmptySections)
                _section(context, section),
            ],
          );
        },
      );

  Widget _header(BuildContext context, EntityProfile profile) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(profile.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(
              key: const Key('entity-profile-type'),
              label: Text(profile.typeName),
            ),
            if (profile.seriesTitle != null)
              Chip(label: Text(profile.seriesTitle!)),
            for (final book in profile.bookTitles) Chip(label: Text(book)),
            Chip(
              key: const Key('entity-profile-canon'),
              avatar: Icon(
                profile.canonStatus == CanonFactStatus.contradicted
                    ? Icons.warning_amber_outlined
                    : Icons.verified_outlined,
                size: 16,
              ),
              label: Text(canonFactStatusLabel(profile.canonStatus)),
            ),
          ],
        ),
        if (profile.aliases.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Also known as ${profile.aliases.join(', ')}',
            style: theme.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            SizedBox(
              width: 160,
              child: LinearProgressIndicator(
                key: const Key('entity-profile-confidence'),
                value: profile.confidence,
                minHeight: 8,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Canon confidence ${(profile.confidence * 100).round()}%',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        if (profile.conflictCount > 0) ...[
          const SizedBox(height: 8),
          Text(
            '${profile.conflictCount} '
            '${profile.conflictCount == 1 ? 'conflict needs' : 'conflicts need'}'
            ' review. AuthorOS will not choose for you.',
            key: const Key('entity-profile-conflicts'),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.error),
          ),
        ],
      ],
    );
  }

  Widget _usage(BuildContext context, EntityUsageReport usage) {
    final theme = Theme.of(context);
    if (usage.isEmpty && usage.derived.isEmpty) {
      return Text(
        'Nothing references this entry yet.',
        key: const Key('entity-profile-usage-empty'),
        style: theme.textTheme.bodySmall,
      );
    }
    return Column(
      key: const Key('entity-profile-usage'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Where this is used', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final book in usage.books)
          _bookTile(context, book.bookTitle, book.chapters, book.appearance),
        if (usage.unfiledChapters.isNotEmpty)
          _bookTile(context, 'Not in a book', usage.unfiledChapters, null),
        for (final group in usage.nonEmptyGroups)
          ExpansionTile(
            key: ValueKey('entity-usage-${group.kind.name}'),
            title: Text(_kindLabel(group.kind)),
            subtitle: Text('${group.references.length} references'),
            children: [
              for (final reference in group.references)
                ListTile(
                  dense: true,
                  title: Text(reference.entity.title),
                  onTap: onOpenRecord == null
                      ? null
                      : () => onOpenRecord!(reference.entity.id),
                ),
            ],
          ),
        if (usage.derived.isNotEmpty)
          ExpansionTile(
            key: const Key('entity-usage-derived'),
            title: const Text('Mentioned but not linked'),
            subtitle: Text(
              '${usage.derived.length} '
              '${usage.derived.length == 1 ? 'scene names' : 'scenes name'} '
              'this entry without a connection',
            ),
            children: [
              for (final derived in usage.derived)
                ListTile(
                  dense: true,
                  title: Text(derived.nodeTitle),
                  subtitle: Text('"${derived.matchedName}"'),
                ),
            ],
          ),
        if (usage.ghostNodeIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${usage.ghostNodeIds.length} references point at manuscript '
              'nodes that no longer resolve.',
              key: const Key('entity-usage-ghosts'),
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Widget _bookTile(
    BuildContext context,
    String title,
    List<ChapterUsage> chapters,
    RecordLink? appearance,
  ) {
    final scenes = chapters.fold<int>(
      0,
      (sum, chapter) => sum + chapter.scenes.length,
    );
    final role = appearance?.metadata['role']?.toString() ?? '';
    return ExpansionTile(
      key: ValueKey('entity-usage-book-$title'),
      title: Text(title),
      subtitle: Text([
        if (role.isNotEmpty) role,
        chapters.isEmpty
            ? 'Listed, with no scenes yet'
            : '${chapters.length} '
                '${chapters.length == 1 ? 'chapter' : 'chapters'}, '
                '$scenes ${scenes == 1 ? 'scene' : 'scenes'}',
      ].join(' · ')),
      children: [
        for (final chapter in chapters)
          ListTile(
            dense: true,
            title: Text(chapter.chapterTitle),
            subtitle: chapter.scenes.isEmpty
                ? null
                : Text(
                    chapter.scenes
                        .map((scene) => scene.entity.title)
                        .join(' · '),
                  ),
          ),
      ],
    );
  }

  Widget _section(BuildContext context, ProfileSection section) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          key: ValueKey('entity-profile-section-${section.id}'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(section.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            for (final entry in section.entries)
              ListTile(
                dense: true,
                title: Text(entry.label),
                subtitle: entry.detail.isEmpty ? null : Text(entry.detail),
                onTap: entry.recordId == null || onOpenRecord == null
                    ? null
                    : () => onOpenRecord!(entry.recordId!),
              ),
          ],
        ),
      );
}

String _kindLabel(ReferenceKind kind) => switch (kind) {
      ReferenceKind.manuscript => 'Manuscript',
      ReferenceKind.chapter => 'Chapters',
      ReferenceKind.scene => 'Scenes',
      ReferenceKind.codex => 'Research and lore',
      ReferenceKind.timeline => 'Timeline',
      ReferenceKind.plot => 'Plot',
      ReferenceKind.world => 'World',
      ReferenceKind.map => 'Map',
      ReferenceKind.universalRecord => 'Other records',
    };

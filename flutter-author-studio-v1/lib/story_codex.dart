import 'package:flutter/material.dart';

import 'core/built_in_record_types.dart';
import 'core/connected_domain.dart';
import 'core/record_types.dart';
import 'core/story_codex_domain.dart';
import 'persistence/authoros_database.dart';
import 'story_codex_service.dart';

class StoryCodexView extends StatefulWidget {
  const StoryCodexView({
    super.key,
    required this.projectId,
    this.repository,
  });

  final String projectId;
  final DriftConnectedDomainRepository? repository;

  @override
  State<StoryCodexView> createState() => _StoryCodexViewState();
}

class _StoryCodexViewState extends State<StoryCodexView> {
  final searchController = TextEditingController();
  late final StoryCodexService service;
  List<CodexEntry> entries = const [];
  List<CodexEntry> pinned = const [];
  List<CodexCategory> categories = const [];
  List<CodexTag> tags = const [];
  List<CodexCollection> collections = const [];
  List<RecordTypeDefinition> templates = const [];
  String? selectedId;
  String? selectedCategoryId;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    service = StoryCodexService(
      projectId: widget.projectId,
      repository: widget.repository ?? authorOsRepository,
    );
    _load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await service.ensureFoundation();
      final results = await Future.wait<Object>([
        service.getEntries(includeArchived: true),
        service.getPinnedEntries(),
        service.getCategories(),
        service.getTags(),
        service.getCollections(),
        service.templateRegistry(),
      ]);
      if (!mounted) return;
      final registry = results[5] as RecordTypeRegistry;
      setState(() {
        entries = results[0] as List<CodexEntry>;
        pinned = results[1] as List<CodexEntry>;
        categories = results[2] as List<CodexCategory>;
        tags = results[3] as List<CodexTag>;
        collections = results[4] as List<CodexCollection>;
        templates = registry.definitions
            .where((definition) =>
                definition.extensionData['selectableForNewRecords'] != false &&
                definition.extensionData['archived'] != true)
            .toList();
        loading = false;
        error = null;
        if (selectedId != null &&
            !entries.any((entry) => entry.id == selectedId)) {
          selectedId = null;
        }
      });
    } catch (caught) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = caught.toString();
      });
    }
  }

  Future<void> _search(String value) async {
    final results = await service.searchCodex(value);
    if (!mounted) return;
    setState(() {
      entries = results;
      selectedCategoryId = null;
    });
  }

  Future<void> _filterCategory(String? categoryId) async {
    final results = categoryId == null
        ? await service.getEntries(includeArchived: true)
        : await service.getCodexByCategory(categoryId);
    if (!mounted) return;
    setState(() {
      selectedCategoryId = categoryId;
      entries = results;
      searchController.clear();
    });
  }

  Future<void> _openEditor([CodexEntry? existing]) async {
    if (templates.isEmpty || categories.isEmpty) return;
    final result = await showDialog<_CodexEditorResult>(
      context: context,
      builder: (context) => _CodexEditorDialog(
        existing: existing,
        templates: templates,
        categories: categories,
        tags: tags,
      ),
    );
    if (result == null) return;
    final tagIds = <String>[];
    for (final name in result.tagNames) {
      final existingTag = tags.where(
        (tag) => tag.name.toLowerCase() == name.toLowerCase(),
      );
      final tag = existingTag.isNotEmpty
          ? existingTag.first
          : await service.createTag(name: name);
      tagIds.add(tag.id);
    }
    if (existing == null) {
      final created = await service.createCodexEntry(CodexEntryDraft(
        title: result.title,
        templateId: result.templateId,
        categoryId: result.categoryId,
        summary: result.summary,
        content: result.content,
        structuredFields: result.fields,
        tagIds: tagIds,
        canonStatus: result.canonStatus,
      ));
      selectedId = created.id;
    } else {
      await service.updateCodexEntry(
        existing.id,
        title: result.title,
        summary: result.summary,
        content: result.content,
        categoryId: result.categoryId,
        tagIds: tagIds,
        canonStatus: result.canonStatus,
        structuredFields: result.fields,
      );
    }
    await _load();
  }

  Future<void> _createCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New category'),
        content: TextField(
          key: const Key('codex-category-name-field'),
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Category name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('save-codex-category-button'),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    await service.createCategory(name: name);
    await _load();
  }

  Future<void> _createCollection() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New collection'),
        content: TextField(
          key: const Key('codex-collection-name-field'),
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Collection name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    await service.createCollection(name: name);
    await _load();
  }

  Future<void> _setPinned(CodexEntry entry) async {
    final isPinned = pinned.any((item) => item.id == entry.id);
    await service.setPinned(entry.id, !isPinned);
    await _load();
  }

  Future<void> _changeLifecycle(CodexEntry entry) async {
    if (entry.isArchived) {
      await service.restoreCodexEntry(entry.id);
    } else {
      await service.archiveCodexEntry(entry.id);
    }
    await _load();
  }

  Future<void> _delete(CodexEntry entry) async {
    final links = await service.getCodexConnections(entry.id);
    if (!mounted) return;
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${entry.title}?'),
        content: Text(
          links.isEmpty
              ? 'The entry will be recoverably removed.'
              : '${links.length} connection(s) will remain intact and connected records will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'archive'),
            child: const Text('Archive'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'delete'),
            child: const Text('Remove entry'),
          ),
        ],
      ),
    );
    if (action == 'archive') await service.archiveCodexEntry(entry.id);
    if (action == 'delete') await service.deleteCodexEntry(entry.id);
    if (action != null) {
      selectedId = null;
      await _load();
    }
  }

  Future<void> _connect(CodexEntry entry) async {
    final targets = entries
        .where((candidate) => candidate.id != entry.id && !candidate.isDeleted)
        .toList();
    if (targets.isEmpty) return;
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) => _ConnectionDialog(targets: targets),
    );
    if (result == null) return;
    await service.connections.connect(
      sourceId: entry.id,
      targetId: result.$1,
      typeId: result.$2,
      label: _linkLabel(result.$2),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final selected = selectedId == null
        ? null
        : entries.where((entry) => entry.id == selectedId).firstOrNull;
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Story Codex could not be opened.'),
            const SizedBox(height: 8),
            Text(error!, style: Theme.of(context).textTheme.bodySmall),
            TextButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }
    return LayoutBuilder(builder: (context, constraints) {
      final dashboard = _dashboard();
      final detail = selected == null
          ? null
          : CodexEntryView(
              entry: selected,
              service: service,
              categories: categories,
              tags: tags,
              pinned: pinned.any((entry) => entry.id == selected.id),
              onEdit: () => _openEditor(selected),
              onPin: () => _setPinned(selected),
              onArchive: () => _changeLifecycle(selected),
              onDelete: () => _delete(selected),
              onConnect: () => _connect(selected),
              onOpenRecord: (id) => setState(() => selectedId = id),
            );
      if (constraints.maxWidth >= 1050 && detail != null) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: dashboard),
            const SizedBox(width: 20),
            Expanded(flex: 4, child: detail),
          ],
        );
      }
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            dashboard,
            if (detail != null) ...[const SizedBox(height: 20), detail]
          ],
        ),
      );
    });
  }

  Widget _dashboard() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Story Codex',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    const Text('Connected story knowledge for this project.'),
                  ],
                ),
              ),
              FilledButton.icon(
                key: const Key('new-codex-entry-button'),
                onPressed: _openEditor,
                icon: const Icon(Icons.add),
                label: const Text('New Entry'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            key: const Key('story-codex-search-field'),
            controller: searchController,
            onChanged: _search,
            decoration: const InputDecoration(
              labelText: 'Search world and character knowledge',
              hintText: 'Search title, summary, content, tags, or type',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 18),
          _sectionHeader('Categories', onAdd: _createCategory),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: selectedCategoryId == null,
                onSelected: (_) => _filterCategory(null),
              ),
              for (final category in categories.where((item) => !item.archived))
                ChoiceChip(
                  label: Text(category.name),
                  selected: selectedCategoryId == category.id,
                  onSelected: (_) => _filterCategory(category.id),
                ),
            ],
          ),
          if (pinned.isNotEmpty) ...[
            const SizedBox(height: 20),
            _sectionHeader('Pinned Entries'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: pinned
                  .map((entry) => ActionChip(
                        avatar: const Icon(Icons.push_pin_outlined, size: 16),
                        label: Text(entry.title),
                        onPressed: () => setState(() => selectedId = entry.id),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 20),
          _sectionHeader('Collections', onAdd: _createCollection),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: collections
                .where((collection) =>
                    collection.kind != CodexCollectionKind.pinned)
                .map((collection) => Chip(
                      avatar: const Icon(Icons.collections_bookmark_outlined,
                          size: 16),
                      label: Text(collection.name),
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          _sectionHeader('Recent Entries'),
          const SizedBox(height: 8),
          if (entries.where((entry) => !entry.isDeleted).isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                  child: Text('Create the first connected Codex entry.')),
            )
          else
            ...entries.where((entry) => !entry.isDeleted).map(
                  (entry) => _EntryRow(
                    entry: entry,
                    selected: entry.id == selectedId,
                    onTap: () => setState(() => selectedId = entry.id),
                  ),
                ),
        ],
      );

  Widget _sectionHeader(String title, {VoidCallback? onAdd}) => Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (onAdd != null)
            IconButton(
              tooltip: 'Add $title',
              onPressed: onAdd,
              icon: const Icon(Icons.add),
            ),
        ],
      );
}

class CodexEntryView extends StatefulWidget {
  const CodexEntryView({
    super.key,
    required this.entry,
    required this.service,
    required this.categories,
    required this.tags,
    required this.pinned,
    required this.onEdit,
    required this.onPin,
    required this.onArchive,
    required this.onDelete,
    required this.onConnect,
    required this.onOpenRecord,
  });

  final CodexEntry entry;
  final StoryCodexService service;
  final List<CodexCategory> categories;
  final List<CodexTag> tags;
  final bool pinned;
  final VoidCallback onEdit;
  final VoidCallback onPin;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  final VoidCallback onConnect;
  final ValueChanged<String> onOpenRecord;

  @override
  State<CodexEntryView> createState() => _CodexEntryViewState();
}

class _CodexEntryViewState extends State<CodexEntryView> {
  late Future<List<RecordLink>> links;

  @override
  void initState() {
    super.initState();
    links = widget.service.getCodexConnections(widget.entry.id);
  }

  @override
  void didUpdateWidget(CodexEntryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.id != widget.entry.id ||
        oldWidget.entry.updatedAt != widget.entry.updatedAt) {
      links = widget.service.getCodexConnections(widget.entry.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.categories
        .where((item) => item.id == widget.entry.categoryId)
        .firstOrNull;
    final tagNames = widget.tags
        .where((tag) => widget.entry.tagIds.contains(tag.id))
        .map((tag) => tag.name)
        .toList();
    return Container(
      key: const Key('codex-entry-view'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.entry.title,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(category?.name ?? widget.entry.categoryId),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: widget.pinned ? 'Unpin' : 'Pin',
                  onPressed: widget.onPin,
                  icon: Icon(
                      widget.pinned ? Icons.push_pin : Icons.push_pin_outlined),
                ),
                IconButton(
                  tooltip: 'Edit',
                  onPressed: widget.onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Entry actions',
                  onSelected: (value) {
                    if (value == 'archive') widget.onArchive();
                    if (value == 'delete') widget.onDelete();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'archive',
                      child:
                          Text(widget.entry.isArchived ? 'Restore' : 'Archive'),
                    ),
                    const PopupMenuItem(value: 'delete', child: Text('Remove')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(widget.entry.recordType)),
                Chip(label: Text(category?.name ?? widget.entry.categoryId)),
                Chip(label: Text(_canonLabel(widget.entry.canonStatus))),
                if (widget.entry.isArchived)
                  const Chip(label: Text('Archived')),
                ...tagNames.map((tag) => Chip(label: Text(tag))),
              ],
            ),
            if (widget.entry.summary.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Summary', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(widget.entry.summary),
            ],
            if (widget.entry.content.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Content', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(widget.entry.content),
            ],
            if (widget.entry.structuredFields.isNotEmpty) ...[
              const SizedBox(height: 16),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Structured Fields'),
                children: widget.entry.structuredFields.entries
                    .where(
                        (field) => field.value != null && '$field'.isNotEmpty)
                    .map((field) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(field.key),
                          subtitle: Text('${field.value}'),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text('Connections',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                IconButton(
                  tooltip: 'Add connection',
                  onPressed: widget.onConnect,
                  icon: const Icon(Icons.add_link),
                ),
              ],
            ),
            FutureBuilder<List<RecordLink>>(
              future: links,
              builder: (context, snapshot) {
                final values = snapshot.data ?? const [];
                if (values.isEmpty) return const Text('No connections yet.');
                return Column(
                  children: values.map((link) {
                    final otherId = link.sourceId == widget.entry.id
                        ? link.targetId
                        : link.sourceId;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.hub_outlined),
                      title:
                          Text(link.label.isEmpty ? link.typeId : link.label),
                      subtitle: Text(otherId),
                      trailing: IconButton(
                        tooltip: 'Open connected record',
                        onPressed: () async {
                          final record =
                              await widget.service.getCodexEntry(otherId);
                          if (record != null) widget.onOpenRecord(otherId);
                        },
                        icon: const Icon(Icons.open_in_new),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final CodexEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          key: Key('codex-entry-${entry.id}'),
          selected: selected,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side:
                BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          leading: const Icon(Icons.auto_stories_outlined),
          title: Text(entry.title),
          subtitle:
              Text('${entry.recordType} · ${_canonLabel(entry.canonStatus)}'),
          trailing: entry.isArchived
              ? const Icon(Icons.archive_outlined)
              : const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}

class _CodexEditorDialog extends StatefulWidget {
  const _CodexEditorDialog({
    required this.existing,
    required this.templates,
    required this.categories,
    required this.tags,
  });

  final CodexEntry? existing;
  final List<RecordTypeDefinition> templates;
  final List<CodexCategory> categories;
  final List<CodexTag> tags;

  @override
  State<_CodexEditorDialog> createState() => _CodexEditorDialogState();
}

class _CodexEditorDialogState extends State<_CodexEditorDialog> {
  late final TextEditingController titleController;
  late final TextEditingController summaryController;
  late final TextEditingController contentController;
  late final TextEditingController tagsController;
  final fieldControllers = <String, TextEditingController>{};
  late String templateId;
  late String categoryId;
  late CodexCanonStatus canonStatus;

  RecordTypeDefinition get template => BuiltInRecordTypes.registry(
        additionalDefinitions: widget.templates.where((item) => !item.builtIn),
      ).resolve(templateId);

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    templateId = existing?.templateId ?? widget.templates.first.id;
    final templateCategory = widget.templates
        .where((item) => item.id == templateId)
        .firstOrNull
        ?.categoryId;
    categoryId = existing?.categoryId ??
        (widget.categories.any((item) => item.id == templateCategory)
            ? templateCategory!
            : widget.categories.first.id);
    canonStatus = existing?.canonStatus ?? CodexCanonStatus.draft;
    titleController = TextEditingController(text: existing?.title ?? '');
    summaryController = TextEditingController(text: existing?.summary ?? '');
    contentController = TextEditingController(text: existing?.content ?? '');
    tagsController = TextEditingController(
      text: widget.tags
          .where((tag) => existing?.tagIds.contains(tag.id) == true)
          .map((tag) => tag.name)
          .join(', '),
    );
    _syncFieldControllers();
  }

  void _syncFieldControllers() {
    for (final field in template.fields) {
      if (_isCoreField(field.id)) continue;
      fieldControllers.putIfAbsent(
        field.id,
        () => TextEditingController(
          text:
              '${widget.existing?.structuredFields[field.id] ?? field.defaultValue ?? ''}',
        ),
      );
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    summaryController.dispose();
    contentController.dispose();
    tagsController.dispose();
    for (final controller in fieldControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(
            widget.existing == null ? 'New Codex Entry' : 'Edit Codex Entry'),
        content: SizedBox(
          width: 680,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  key: const Key('codex-template-field'),
                  initialValue: templateId,
                  decoration: const InputDecoration(labelText: 'Template'),
                  items: widget.templates
                      .map((item) => DropdownMenuItem(
                            key: Key('codex-template-option-${item.id}'),
                            value: item.id,
                            child: Text(item.name),
                          ))
                      .toList(),
                  onChanged: widget.existing == null
                      ? (value) {
                          if (value == null) return;
                          setState(() {
                            templateId = value;
                            final selected = widget.templates
                                .where((item) => item.id == value)
                                .firstOrNull;
                            if (selected != null &&
                                widget.categories.any(
                                    (item) => item.id == selected.categoryId)) {
                              categoryId = selected.categoryId;
                            }
                            _syncFieldControllers();
                          });
                        }
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const Key('codex-category-field'),
                  initialValue: categoryId,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: widget.categories
                      .where((item) => !item.archived)
                      .map((item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.name),
                          ))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => categoryId = value ?? categoryId),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('codex-title-field'),
                  controller: titleController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('codex-summary-field'),
                  controller: summaryController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Summary'),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('codex-content-field'),
                  controller: contentController,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(labelText: 'Content'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<CodexCanonStatus>(
                  initialValue: canonStatus,
                  decoration: const InputDecoration(labelText: 'Canon status'),
                  items: CodexCanonStatus.values
                      .map((status) => DropdownMenuItem(
                            value: status,
                            child: Text(_canonLabel(status)),
                          ))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => canonStatus = value ?? canonStatus),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('codex-tags-field'),
                  controller: tagsController,
                  decoration: const InputDecoration(
                    labelText: 'Tags',
                    hintText: 'magic, book one, unresolved',
                  ),
                ),
                for (final section in template.sections) ...[
                  if (section.fieldIds.any((id) => !_isCoreField(id))) ...[
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(section.title,
                          style: Theme.of(context).textTheme.titleSmall),
                    ),
                    const SizedBox(height: 8),
                    for (final field in template.fields.where(
                      (field) =>
                          section.fieldIds.contains(field.id) &&
                          !_isCoreField(field.id),
                    )) ...[
                      TextField(
                        controller: fieldControllers[field.id],
                        minLines: field.type == RecordFieldType.longText ||
                                field.type == RecordFieldType.richText
                            ? 2
                            : 1,
                        maxLines: field.type == RecordFieldType.longText ||
                                field.type == RecordFieldType.richText
                            ? 5
                            : 1,
                        decoration: InputDecoration(
                          labelText:
                              field.required ? '${field.label} *' : field.label,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('save-codex-entry-button'),
            onPressed: () {
              if (titleController.text.trim().isEmpty) return;
              Navigator.pop(
                context,
                _CodexEditorResult(
                  title: titleController.text.trim(),
                  templateId: templateId,
                  categoryId: categoryId,
                  summary: summaryController.text.trim(),
                  content: contentController.text.trim(),
                  tagNames: tagsController.text
                      .split(',')
                      .map((value) => value.trim())
                      .where((value) => value.isNotEmpty)
                      .toList(),
                  canonStatus: canonStatus,
                  fields: {
                    for (final item in fieldControllers.entries)
                      if (item.value.text.trim().isNotEmpty)
                        item.key: item.value.text.trim(),
                  },
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      );
}

class _CodexEditorResult {
  const _CodexEditorResult({
    required this.title,
    required this.templateId,
    required this.categoryId,
    required this.summary,
    required this.content,
    required this.tagNames,
    required this.canonStatus,
    required this.fields,
  });

  final String title;
  final String templateId;
  final String categoryId;
  final String summary;
  final String content;
  final List<String> tagNames;
  final CodexCanonStatus canonStatus;
  final Map<String, Object?> fields;
}

class _ConnectionDialog extends StatefulWidget {
  const _ConnectionDialog({required this.targets});

  final List<CodexEntry> targets;

  @override
  State<_ConnectionDialog> createState() => _ConnectionDialogState();
}

class _ConnectionDialogState extends State<_ConnectionDialog> {
  late String targetId = widget.targets.first.id;
  String typeId = 'relatedTo';

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Add connection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: targetId,
              decoration: const InputDecoration(labelText: 'Record'),
              items: widget.targets
                  .map((entry) => DropdownMenuItem(
                        value: entry.id,
                        child: Text(entry.title),
                      ))
                  .toList(),
              onChanged: (value) =>
                  setState(() => targetId = value ?? targetId),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: typeId,
              decoration: const InputDecoration(labelText: 'Connection type'),
              items: const [
                DropdownMenuItem(value: 'relatedTo', child: Text('Related to')),
                DropdownMenuItem(value: 'memberOf', child: Text('Member of')),
                DropdownMenuItem(value: 'locatedIn', child: Text('Located in')),
                DropdownMenuItem(value: 'owns', child: Text('Owns')),
                DropdownMenuItem(value: 'uses', child: Text('Uses')),
                DropdownMenuItem(value: 'appearsIn', child: Text('Appears in')),
                DropdownMenuItem(value: 'opposes', child: Text('Opposes')),
                DropdownMenuItem(
                    value: 'alliedWith', child: Text('Allied with')),
              ],
              onChanged: (value) => setState(() => typeId = value ?? typeId),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, (targetId, typeId)),
            child: const Text('Connect'),
          ),
        ],
      );
}

bool _isCoreField(String id) => const {
      'summary',
      'content',
      'authorNotes',
      'researchNotes',
    }.contains(id);

String _canonLabel(CodexCanonStatus status) => switch (status) {
      CodexCanonStatus.canon => 'Canon',
      CodexCanonStatus.draft => 'Draft',
      CodexCanonStatus.proposed => 'Proposed',
      CodexCanonStatus.deprecated => 'Deprecated',
      CodexCanonStatus.nonCanon => 'Non-Canon',
      CodexCanonStatus.alternate => 'Alternate',
    };

String _linkLabel(String typeId) => switch (typeId) {
      'memberOf' => 'Member of',
      'locatedIn' => 'Located in',
      'alliedWith' => 'Allied with',
      'appearsIn' => 'Appears in',
      'relatedTo' => 'Related to',
      _ => typeId,
    };

import 'package:flutter/material.dart';

import 'core/connected_domain.dart';
import 'manuscript_service.dart';
import 'manuscript_store.dart';
import 'series_service.dart';
import 'theme/flutter/authoros_theme.dart';
import 'theme/theme_tokens.dart';

/// The books a project contains, and what belongs to each of them.
///
/// The project is the series, so this Studio is a view over ordinary records
/// and manuscript structure — it owns no storage. Books come from
/// [SeriesService], chapters from [ManuscriptService], and nothing here writes
/// to a repository directly.
class SeriesStudioView extends StatefulWidget {
  const SeriesStudioView({
    super.key,
    required this.projectTitle,
    required this.series,
    required this.manuscripts,
  });

  final String projectTitle;
  final SeriesService series;
  final ManuscriptService manuscripts;

  @override
  State<SeriesStudioView> createState() => _SeriesStudioViewState();
}

class _SeriesStudioViewState extends State<SeriesStudioView> {
  bool _loading = true;
  String? _error;
  AuthorRecord? _series;
  List<AuthorRecord> _books = const [];
  ManuscriptProjectSummary? _manuscript;
  Map<String, List<AuthorRecord>> _rosters = const {};
  String? _selectedBookId;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final seriesRecord = await widget.series.series();
      final books = await widget.series.books();
      final manuscript =
          await widget.manuscripts.load(manuscriptTitle: widget.projectTitle);
      final rosters = <String, List<AuthorRecord>>{};
      for (final book in books) {
        rosters[book.id] = await widget.series.recordsInBook(book.id);
      }
      if (!mounted) return;
      setState(() {
        _series = seriesRecord;
        _books = books;
        _manuscript = manuscript;
        _rosters = rosters;
        _selectedBookId = books.any((book) => book.id == _selectedBookId)
            ? _selectedBookId
            : books.isEmpty
                ? null
                : books.first.id;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
      await _reload();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    }
  }

  Future<void> _addBook() async {
    final title = await _promptForName(
      context,
      title: 'New book',
      label: 'Book title',
    );
    if (title == null) return;
    await _guard(() async {
      await widget.series.ensureSeries(title: widget.projectTitle);
      await widget.series.createBook(title: title);
    });
  }

  Future<void> _renameBook(AuthorRecord book) async {
    final title = await _promptForName(
      context,
      title: 'Rename book',
      label: 'Book title',
      initialValue: book.title,
    );
    if (title == null) return;
    await _guard(() => widget.series.renameBook(book.id, title));
  }

  Future<void> _archiveBook(AuthorRecord book) async {
    final roster = _rosters[book.id] ?? const <AuthorRecord>[];
    final chapters =
        widget.manuscripts.chaptersForBook(_manuscript!, book.id).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Archive ${book.title}?'),
        content: Text(
          chapters == 0 && roster.isEmpty
              ? 'Nothing is filed under this book.'
              : 'This book holds $chapters '
                  '${chapters == 1 ? 'chapter' : 'chapters'} and '
                  '${roster.length} '
                  '${roster.length == 1 ? 'entry' : 'entries'}. Archiving it '
                  'releases them to series canon — nothing is deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _guard(() async {
      final manuscript = _manuscript;
      if (manuscript != null) {
        var current = manuscript;
        for (final chapter
            in widget.manuscripts.chaptersForBook(manuscript, book.id)) {
          current = await widget.manuscripts
              .assignChapterToBook(current, chapter.id, null);
        }
      }
      await widget.series.archiveBook(book.id);
    });
  }

  Future<void> _moveBook(int index, int delta) async {
    final target = index + delta;
    if (target < 0 || target >= _books.length) return;
    final ordered = _books.map((book) => book.id).toList();
    final moved = ordered.removeAt(index);
    ordered.insert(target, moved);
    await _guard(() => widget.series.reorderBooks(ordered));
  }

  Future<void> _assignChapter(ManuscriptChapter chapter, String? bookId) async {
    final manuscript = _manuscript;
    if (manuscript == null) return;
    await _guard(() async {
      await widget.manuscripts
          .assignChapterToBook(manuscript, chapter.id, bookId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.of(context);
    final surface = scope.color(ThemeColorRef.surface);

    if (_loading) {
      return Container(
        color: surface,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      color: surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(scope),
          if (_error != null) _errorBanner(scope, _error!),
          Expanded(
            child: _books.isEmpty
                ? _emptyState(scope)
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 320, child: _bookList(scope)),
                      VerticalDivider(
                        width: 1,
                        color: scope.color(ThemeColorRef.outlineVariant),
                      ),
                      Expanded(child: _bookDetail(scope)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _header(StudioThemeScope scope) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _series?.title ?? '${widget.projectTitle} Series',
                    style: scope.text(
                      ThemeTextRole.heading,
                      colorRef: ThemeColorRef.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _books.isEmpty
                        ? 'No books yet.'
                        : '${_books.length} '
                            '${_books.length == 1 ? 'book' : 'books'} · '
                            'entries with no book are series canon and appear '
                            'in every one.',
                    style: scope.text(
                      ThemeTextRole.body,
                      colorRef: ThemeColorRef.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              key: const ValueKey('series-add-book'),
              onPressed: _addBook,
              icon: const Icon(Icons.add),
              label: const Text('Add book'),
            ),
          ],
        ),
      );

  Widget _errorBanner(StudioThemeScope scope, String message) => Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scope.color(ThemeColorRef.surfaceContainer),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scope.color(ThemeColorRef.outlineVariant)),
        ),
        child: Text(
          message,
          key: const ValueKey('series-error'),
          style: scope.text(
            ThemeTextRole.body,
            colorRef: ThemeColorRef.onSurfaceVariant,
          ),
        ),
      );

  Widget _emptyState(StudioThemeScope scope) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Add a book to split this project into a series. Everything you '
            'have already written stays where it is — a chapter with no book '
            'is simply unfiled, and an entry with no book is series canon.',
            textAlign: TextAlign.center,
            style: scope.text(
              ThemeTextRole.body,
              colorRef: ThemeColorRef.onSurfaceVariant,
            ),
          ),
        ),
      );

  Widget _bookList(StudioThemeScope scope) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        itemCount: _books.length,
        itemBuilder: (context, index) {
          final book = _books[index];
          final selected = book.id == _selectedBookId;
          final chapters = _manuscript == null
              ? 0
              : widget.manuscripts
                  .chaptersForBook(_manuscript!, book.id)
                  .length;
          return Card(
            key: ValueKey('series-book-${book.id}'),
            color: selected
                ? scope.color(ThemeColorRef.surfaceContainer)
                : scope.color(ThemeColorRef.surface),
            child: ListTile(
              selected: selected,
              onTap: () => setState(() => _selectedBookId = book.id),
              title: Text(
                book.title,
                style: scope.text(
                  ThemeTextRole.body,
                  colorRef: ThemeColorRef.onSurface,
                ),
              ),
              subtitle: Text(
                '$chapters ${chapters == 1 ? 'chapter' : 'chapters'} · '
                '${(_rosters[book.id] ?? const []).length} entries',
                style: scope.text(
                  ThemeTextRole.label,
                  colorRef: ThemeColorRef.onSurfaceVariant,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Move up',
                    onPressed:
                        index == 0 ? null : () => _moveBook(index, -1),
                    icon: const Icon(Icons.arrow_upward, size: 18),
                  ),
                  IconButton(
                    tooltip: 'Move down',
                    onPressed: index == _books.length - 1
                        ? null
                        : () => _moveBook(index, 1),
                    icon: const Icon(Icons.arrow_downward, size: 18),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) => switch (value) {
                      'rename' => _renameBook(book),
                      'archive' => _archiveBook(book),
                      _ => null,
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'rename', child: Text('Rename')),
                      PopupMenuItem(value: 'archive', child: Text('Archive')),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );

  Widget _bookDetail(StudioThemeScope scope) {
    final bookId = _selectedBookId;
    final manuscript = _manuscript;
    if (bookId == null || manuscript == null) {
      return _emptyState(scope);
    }
    final book = _books.firstWhere((each) => each.id == bookId);
    final inBook = widget.manuscripts.chaptersForBook(manuscript, bookId);
    final unfiled = widget.manuscripts.chaptersForBook(manuscript, null);
    final roster = _rosters[bookId] ?? const <AuthorRecord>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          book.title,
          style: scope.text(
            ThemeTextRole.heading,
            colorRef: ThemeColorRef.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        _sectionTitle(scope, 'Chapters in this book'),
        if (inBook.isEmpty)
          _hint(scope, 'No chapters filed under this book yet.')
        else
          for (final chapter in inBook)
            ListTile(
              key: ValueKey('series-chapter-${chapter.id}'),
              dense: true,
              title: Text(
                chapter.title,
                style: scope.text(
                  ThemeTextRole.body,
                  colorRef: ThemeColorRef.onSurface,
                ),
              ),
              trailing: TextButton(
                onPressed: () => _assignChapter(chapter, null),
                child: const Text('Remove'),
              ),
            ),
        const SizedBox(height: 20),
        _sectionTitle(scope, 'Unfiled chapters'),
        if (unfiled.isEmpty)
          _hint(scope, 'Every chapter belongs to a book.')
        else
          for (final chapter in unfiled)
            ListTile(
              key: ValueKey('series-unfiled-${chapter.id}'),
              dense: true,
              title: Text(
                chapter.title,
                style: scope.text(
                  ThemeTextRole.body,
                  colorRef: ThemeColorRef.onSurface,
                ),
              ),
              trailing: TextButton(
                onPressed: () => _assignChapter(chapter, bookId),
                child: const Text('Add to book'),
              ),
            ),
        const SizedBox(height: 20),
        _sectionTitle(scope, 'Entries specific to this book'),
        if (roster.isEmpty)
          _hint(
            scope,
            'Nothing is restricted to this book. Every Codex entry in the '
            'project is series canon and appears here as well.',
          )
        else
          for (final record in roster)
            ListTile(
              key: ValueKey('series-entry-${record.id}'),
              dense: true,
              title: Text(
                record.title,
                style: scope.text(
                  ThemeTextRole.body,
                  colorRef: ThemeColorRef.onSurface,
                ),
              ),
              subtitle: Text(
                record.typeId,
                style: scope.text(
                  ThemeTextRole.label,
                  colorRef: ThemeColorRef.onSurfaceVariant,
                ),
              ),
              trailing: TextButton(
                onPressed: () => _guard(
                  () => widget.series.promoteToSeriesCanon(record.id),
                ),
                child: const Text('Make series canon'),
              ),
            ),
      ],
    );
  }

  Widget _sectionTitle(StudioThemeScope scope, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          text,
          style: scope.text(
            ThemeTextRole.heading,
            colorRef: ThemeColorRef.onSurface,
          ),
        ),
      );

  Widget _hint(StudioThemeScope scope, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          text,
          style: scope.text(
            ThemeTextRole.label,
            colorRef: ThemeColorRef.onSurfaceVariant,
          ),
        ),
      );
}

Future<String?> _promptForName(
  BuildContext context, {
  required String title,
  required String label,
  String initialValue = '',
}) async {
  final controller = TextEditingController(text: initialValue);
  final value = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
        onSubmitted: (text) => Navigator.of(context).pop(text),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  controller.dispose();
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

/// Book Studio — the Write to Publish stage.
///
/// The studio walks the author along one pipeline: structure the book, format
/// it, design its chapters, see it, export it. The preview is the point. It is
/// painted from exactly the [PaginatedBook] the exporter writes, so changing a
/// trim size or a leading value reflows the real book in front of the author
/// rather than promising something the PDF may not honour.
library;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';

import 'book/book_cover.dart';
import 'book/book_dictionary.dart';
import 'book/book_document.dart';
import 'book/book_epub_exporter.dart';
import 'book/book_export_targets.dart';
import 'book/book_fonts.dart';
import 'book/book_format.dart';
import 'book/book_layout.dart';
import 'book/book_pdf_renderer.dart';
import 'book/book_preview_painter.dart';
import 'book/book_store.dart';
import 'book/epub_settings.dart';
import 'book/proof_rules.dart';
import 'book/proofing.dart';
import 'manuscript_continuity.dart';
import 'manuscript_service.dart';
import 'manuscript_store.dart';
import 'onboarding.dart';
import 'persistence/authoros_database.dart';

/// Asks the author for a cover image.
///
/// Returns the bytes rather than a path on purpose: `file_selector` hands back
/// a filesystem path on desktop but a session-scoped `blob:` URL in a browser,
/// and only the bytes mean the same thing on both.
Future<Uint8List?> pickCoverFile() async {
  const group = XTypeGroup(
    label: 'Cover image',
    extensions: ['jpg', 'jpeg', 'png'],
    mimeTypes: ['image/jpeg', 'image/png'],
  );
  final file = await openFile(acceptedTypeGroups: const [group]);
  if (file == null) return null;
  return file.readAsBytes();
}

/// The stages of the publishing pipeline.
enum BookStage { structure, editing, proofing, formatting, design, preview, export }

extension BookStageX on BookStage {
  String get label => switch (this) {
        BookStage.structure => 'Structure',
        BookStage.editing => 'Editing',
        BookStage.proofing => 'Proofing',
        BookStage.formatting => 'Formatting',
        BookStage.design => 'Design',
        BookStage.preview => 'Preview',
        BookStage.export => 'Export',
      };

  IconData get icon => switch (this) {
        BookStage.structure => Icons.account_tree_outlined,
        BookStage.editing => Icons.edit_note_outlined,
        BookStage.proofing => Icons.spellcheck_outlined,
        BookStage.formatting => Icons.straighten_outlined,
        BookStage.design => Icons.brush_outlined,
        BookStage.preview => Icons.menu_book_outlined,
        BookStage.export => Icons.ios_share_outlined,
      };

  /// Every stage of the pipeline is built.
  bool get isAvailable => true;

  String get summary => switch (this) {
        BookStage.structure =>
          'Front matter, parts and back matter, and the details that fill the '
              'title and copyright pages.',
        BookStage.editing =>
          'The mechanics of the text: spacing, quotation marks, stray indents '
              'and repeated words.',
        BookStage.proofing =>
          'What only the whole book can see: spelling, consistency, and the '
              'checks that need a finished layout.',
        BookStage.formatting => 'Trim size, margins and typography.',
        BookStage.design =>
          'Chapter openers, scene breaks, running heads and page numbers.',
        BookStage.preview =>
          'The finished book, page for page, exactly as it will export.',
        BookStage.export => 'Write the book out.',
      };
}

class BookStudioView extends StatefulWidget {
  const BookStudioView({
    super.key,
    required this.project,
    this.bookStore = const BookStore(),
    this.manuscriptStore = const ManuscriptStore(),
    this.fileSaver = const NativeBookFileSaver(),
    this.renderer = const BookPdfRenderer(),
    this.epubExporter = const BookEpubExporter(),
    this.coverStore = const BookCoverStore(),
    this.coverPicker = pickCoverFile,
    this.proofingEngine = const ProofingEngine(),
    this.database,
  });

  final StarterProject project;
  final BookStore bookStore;
  final ManuscriptStore manuscriptStore;
  final BookFileSaver fileSaver;
  final BookPdfRenderer renderer;
  final BookEpubExporter epubExporter;
  final BookCoverStore coverStore;

  /// Injected so a test can supply an image without a file dialog.
  final Future<Uint8List?> Function() coverPicker;

  final ProofingEngine proofingEngine;

  /// Where record names and manuscript history live. Defaults to the app's own.
  final AuthorOsDatabase? database;

  @override
  State<BookStudioView> createState() => _BookStudioViewState();
}

class _BookStudioViewState extends State<BookStudioView> {
  BookStage _stage = BookStage.structure;

  bool _loading = true;
  String? _error;
  bool _exporting = false;

  BookProject? _book;
  ManuscriptProjectSummary? _manuscript;
  BookFontAssets? _assets;

  BookDocument? _document;
  PaginatedBook? _paginated;
  BookCover? _cover;

  ProofReport _proof = ProofReport.empty;
  ProofReport _layoutProof = ProofReport.empty;
  BookDictionary? _dictionary;
  Set<String> _knownNames = const {};
  bool _proofing = false;
  bool _fixing = false;
  String _proofCacheKey = '';

  /// Guards repagination: a format tweak reflows the book, a repaint does not.
  String _layoutCacheKey = '';

  int _previewPage = 0;
  bool _spread = true;
  bool _showGuides = false;
  double _previewWidth = 300;
  BookExportFormat _exportFormat = BookExportFormat.printPdf;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final assets = await BookFontAssets.load();
      // Read-only on purpose. Book Studio consumes a manuscript snapshot and
      // must never write the source while laying a book out, so it uses the
      // reading path rather than the one that seeds a manuscript.
      final manuscript =
          await widget.manuscriptStore.readStudio(widget.project.id) ??
              _emptyManuscript();
      final book = await widget.bookStore.load(widget.project.id);
      final cover = await _loadCover();

      if (!mounted) return;
      setState(() {
        _assets = assets;
        _manuscript = manuscript;
        _book = book;
        _cover = cover;
        _loading = false;
      });
      _repaginate();
      _reproof();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Book Studio could not open this project. $error';
      });
    }
  }

  /// Reads the stored cover.
  ///
  /// A cover that cannot be read is not a reason the studio should fail to
  /// open: the book is still perfectly exportable without one.
  Future<BookCover?> _loadCover() async {
    try {
      return await widget.coverStore.load(widget.project.id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _chooseCover() async {
    final bytes = await widget.coverPicker();
    if (bytes == null) return;
    final imported = await BookCover.fromBytes(bytes);
    if (!imported.isAccepted) {
      _message(imported.message ?? 'That file could not be used as a cover.');
      return;
    }
    await widget.coverStore.save(widget.project.id, imported.cover!);
    if (!mounted) return;
    setState(() => _cover = imported.cover);
    _message('Cover set.');
  }

  Future<void> _removeCover() async {
    await widget.coverStore.remove(widget.project.id);
    if (!mounted) return;
    setState(() => _cover = null);
  }

  /// Stands in for a project that has not been written in yet.
  ///
  /// Never persisted: the studio shows an empty book rather than creating one.
  ManuscriptProjectSummary _emptyManuscript() => ManuscriptProjectSummary(
        projectId: widget.project.id,
        manuscriptTitle: widget.project.title,
        chapters: const [],
        currentChapterId: '',
        currentSceneId: '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
        version: 1,
      );

  /// Rebuilds the document and, when anything that affects layout changed,
  /// re-paginates.
  void _repaginate({bool force = false}) {
    final book = _book;
    final manuscript = _manuscript;
    final assets = _assets;
    if (book == null || manuscript == null || assets == null) return;

    final document = const BookDocumentBuilder().build(
      manuscript: manuscript,
      book: book,
      profileAuthorName: widget.project.title,
    );

    final key = '${manuscript.updatedAt.toIso8601String()}|'
        '${book.format.layoutFingerprint}|'
        '${document.frontMatter.length}|${document.backMatter.length}|'
        '${document.body.length}|${document.metadata.title}|'
        '${document.metadata.authorName}';
    if (!force && key == _layoutCacheKey && _paginated != null) {
      setState(() => _document = document);
      return;
    }

    final paginated = BookLayoutEngine(PdfBookFontMetrics(assets))
        .layout(document, book.format);

    setState(() {
      _document = document;
      _paginated = paginated;
      _layoutCacheKey = key;
      _previewPage = _previewPage.clamp(0, paginated.pageCount - 1);
    });
  }

  ManuscriptService get _manuscriptService {
    final database = widget.database;
    final repository = database == null
        ? authorOsRepository
        : DriftConnectedDomainRepository(database);
    return ManuscriptService(
      projectId: widget.project.id,
      repository: repository,
      // The store mirrors nodes into the same database the service uses; left
      // to its default it would reach for the app's own singleton.
      store: database == null
          ? widget.manuscriptStore
          : ManuscriptStore(repository: repository),
    );
  }

  /// Runs the rules over the manuscript, and over the laid-out book.
  ///
  /// Cached against the same inputs the layout is, so moving a slider does not
  /// re-proof a book that has not changed.
  void _reproof({bool force = false}) {
    final manuscript = _manuscript;
    final book = _book;
    if (manuscript == null || book == null) return;

    // Deliberately not keyed on the format: no text rule depends on a trim
    // size or a margin, so dragging a slider must not re-run sixteen rules
    // over the whole manuscript on every frame. The layout findings below are
    // recomputed regardless, and they are cheap.
    final key = '${manuscript.updatedAt.toIso8601String()}|'
        '${_dictionary != null}|${_knownNames.length}|'
        '${book.frontMatter.length}|${book.backMatter.length}|'
        '${book.copyrightYear}|${book.copyrightHolder}|'
        '${book.authorOverride}';
    final reuse = !force && key == _proofCacheKey;

    final report = reuse
        ? _proof
        : widget.proofingEngine.analyse(ProofContext(
            manuscript: manuscript,
            book: book,
            dictionary: _dictionary,
            knownNames: _knownNames,
          ));

    final paginated = _paginated;
    final layout = paginated == null
        ? ProofReport.empty
        : widget.proofingEngine.analyseLayout(paginated);

    setState(() {
      _proof = report;
      _layoutProof = layout;
      _proofCacheKey = key;
    });
  }

  /// Loads the dictionary the first time proofing is opened.
  ///
  /// Deliberately not part of studio start-up: it is 350 KB, and most sessions
  /// never open this stage.
  Future<void> _ensureDictionary() async {
    if (_dictionary != null || _proofing) return;
    setState(() => _proofing = true);
    try {
      final names = await _loadKnownNames();
      final dictionary = await BookDictionary.load(personal: names);
      if (!mounted) return;
      setState(() {
        _dictionary = dictionary;
        _knownNames = names;
        _proofing = false;
      });
      _reproof(force: true);
    } catch (error) {
      if (!mounted) return;
      // Spelling simply stays unchecked; the studio says so rather than
      // implying the book is clean.
      setState(() => _proofing = false);
      _message('The dictionary could not be loaded, so spelling was not '
          'checked. $error');
    }
  }

  /// Every record title and alias in the project.
  ///
  /// Reuses the set the continuity engine already builds, so an author's
  /// invented names are never flagged and nothing has to be trained.
  Future<Set<String>> _loadKnownNames() async {
    try {
      final records = await _manuscriptService.connectableRecords();
      return ManuscriptContinuityIntelligence.knownNames(records);
    } catch (_) {
      return const {};
    }
  }

  /// Applies fixes to the manuscript.
  ///
  /// This is the one place Book Studio writes prose, and it happens only when
  /// the author asks. It goes through [ManuscriptService] rather than the store
  /// so the change lands in the manuscript's own version history and can be
  /// undone from Manuscript Studio like any other edit.
  Future<void> _applyFixes(Iterable<ProofFinding> findings) async {
    var manuscript = _manuscript;
    if (manuscript == null || _fixing) return;

    final grouped = const ProofFixer().bySceneId(findings);
    if (grouped.isEmpty) return;

    setState(() => _fixing = true);
    var changed = 0;
    try {
      final service = _manuscriptService;
      for (final entry in grouped.entries) {
        final scene = manuscript!.sceneById(entry.key);
        if (scene == null) continue;
        final updated =
            const ProofFixer().apply(scene.content, entry.value);
        if (updated == scene.content) continue;
        manuscript = await service.writeSceneBody(
          manuscript,
          entry.key,
          updated,
          recordHistory: true,
        );
        changed += entry.value.length;
      }
      if (!mounted) return;
      setState(() {
        _manuscript = manuscript;
        _fixing = false;
      });
      _repaginate(force: true);
      _reproof(force: true);
      _message(changed == 0
          ? 'Nothing left to fix.'
          : 'Fixed $changed ${changed == 1 ? 'thing' : 'things'}.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _fixing = false);
      _message('Those fixes could not be applied. $error');
    }
  }

  Future<void> _update(BookProject Function(BookProject) change) async {
    final book = _book;
    if (book == null) return;
    final updated = change(book);
    setState(() => _book = updated);
    _repaginate();
    _reproof();
    await widget.bookStore.save(updated);
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _export() async {
    final paginated = _paginated;
    final document = _document;
    final assets = _assets;
    final book = _book;
    if (paginated == null || document == null || assets == null ||
        book == null) {
      return;
    }

    setState(() => _exporting = true);
    try {
      // Reflowable targets are built from the book's structure; paginated ones
      // from the laid-out pages. An EPUB must never inherit print pagination.
      final bytes = _exportFormat.isReflowable
          ? widget.epubExporter.export(
              document: document,
              settings: book.epub,
              projectId: widget.project.id,
              modified: _manuscript?.updatedAt ?? DateTime.utc(2000),
              cover: _cover,
              fonts: assets,
            )
          : await widget.renderer.render(paginated, assets);
      final path = await widget.fileSaver.save(
        suggestedName: suggestedBookFilename(
          title: paginated.metadata.title,
          format: _exportFormat,
        ),
        bytes: bytes,
        format: _exportFormat,
      );
      if (!mounted) return;
      setState(() => _exporting = false);
      if (path == null) return;
      _message(path.isEmpty
          ? 'Your book has been downloaded.'
          : 'Book exported to $path');
    } catch (error) {
      if (!mounted) return;
      setState(() => _exporting = false);
      _message('Export failed. $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Book Studio', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(_error!, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('book-retry-button'),
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(theme),
            const SizedBox(height: 16),
            Expanded(
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: 208, child: _stageRail(theme, false)),
                        const SizedBox(width: 16),
                        Expanded(child: _stageBody(theme)),
                      ],
                    )
                  : Column(
                      children: [
                        SizedBox(height: 56, child: _stageRail(theme, true)),
                        const SizedBox(height: 12),
                        Expanded(child: _stageBody(theme)),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _header(ThemeData theme) {
    final paginated = _paginated;
    final document = _document;
    return _Panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  document?.metadata.title ?? widget.project.title,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Write, format and publish without leaving AuthorOS.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (paginated != null) ...[
            _Stat(label: 'Pages', value: '${paginated.pageCount}'),
            const SizedBox(width: 12),
            _Stat(
              label: 'Words',
              value: _thousands(paginated.stats.wordCount),
            ),
            const SizedBox(width: 12),
            _Stat(label: 'Format', value: _book?.format.label ?? ''),
          ],
        ],
      ),
    );
  }

  Widget _stageRail(ThemeData theme, bool horizontal) {
    final tiles = [
      for (final stage in BookStage.values) _stageTile(theme, stage, horizontal),
    ];
    if (horizontal) {
      return ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tiles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) => tiles[index],
      );
    }
    return _Panel(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final tile in tiles) ...[tile, const SizedBox(height: 6)],
        ],
      ),
    );
  }

  Widget _stageTile(ThemeData theme, BookStage stage, bool horizontal) {
    final selected = stage == _stage;
    final enabled = stage.isAvailable;
    final foreground = !enabled
        ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
        : selected
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onSurface;

    return Tooltip(
      message: stage.summary,
      child: Material(
        color: selected
            ? theme.colorScheme.primaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: Key('book-stage-${stage.name}'),
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? () => setState(() => _stage = stage) : null,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: horizontal ? 10 : 12,
            ),
            child: Row(
              mainAxisSize: horizontal ? MainAxisSize.min : MainAxisSize.max,
              children: [
                Icon(stage.icon, size: 18, color: foreground),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    stage.label,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: foreground,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (!enabled) ...[
                  const SizedBox(width: 6),
                  Text(
                    'soon',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: foreground,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stageBody(ThemeData theme) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: KeyedSubtree(
          key: ValueKey(_stage),
          child: switch (_stage) {
            BookStage.structure => _structureStage(theme),
            BookStage.formatting => _formattingStage(theme),
            BookStage.design => _designStage(theme),
            BookStage.preview => _previewStage(theme),
            BookStage.export => _exportStage(theme),
            BookStage.editing => _findingsStage(theme, ProofStage.editing),
            BookStage.proofing => _findingsStage(theme, ProofStage.proofing),
          },
        ),
      );

  // --- structure ----------------------------------------------------------

  Widget _structureStage(ThemeData theme) {
    final book = _book!;
    final document = _document;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeading('The book', theme),
              const SizedBox(height: 4),
              Text(
                'Left blank, the title and author follow the manuscript and '
                'your profile, so renaming the project keeps the title page '
                'right.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _field('Title', book.titleOverride,
                      hint: _manuscript?.manuscriptTitle,
                      onChanged: (v) =>
                          _update((b) => b.copyWith(titleOverride: v))),
                  _field('Subtitle', book.subtitle,
                      onChanged: (v) => _update((b) => b.copyWith(subtitle: v))),
                  _field('Author', book.authorOverride,
                      onChanged: (v) =>
                          _update((b) => b.copyWith(authorOverride: v))),
                  _field('Series', book.seriesName,
                      onChanged: (v) =>
                          _update((b) => b.copyWith(seriesName: v))),
                  _field('Publisher', book.publisher,
                      onChanged: (v) =>
                          _update((b) => b.copyWith(publisher: v))),
                  _field('ISBN', book.isbn,
                      onChanged: (v) => _update((b) => b.copyWith(isbn: v))),
                  _field('Copyright year', book.copyrightYear,
                      onChanged: (v) =>
                          _update((b) => b.copyWith(copyrightYear: v))),
                  _field('Rights holder', book.copyrightHolder,
                      onChanged: (v) =>
                          _update((b) => b.copyWith(copyrightHolder: v))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _coverPanel(theme),
        const SizedBox(height: 12),
        _matterPanel(theme, 'Front matter', book.frontMatter, true),
        const SizedBox(height: 12),
        _partsPanel(theme),
        const SizedBox(height: 12),
        _matterPanel(theme, 'Back matter', book.backMatter, false),
        if (document != null && document.issues.isNotEmpty) ...[
          const SizedBox(height: 12),
          _issuesPanel(theme, document.issues.map((i) => i.message).toList()),
        ],
      ],
    );
  }

  Widget _coverPanel(ThemeData theme) {
    final cover = _cover;
    return _Panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 84,
            height: 126,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outlineVariant),
              color: theme.colorScheme.surfaceContainerHighest,
            ),
            child: cover == null
                ? Icon(Icons.image_outlined,
                    color: theme.colorScheme.onSurfaceVariant)
                : Image.memory(cover.bytes, fit: BoxFit.cover),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeading('Cover', theme),
                const SizedBox(height: 4),
                Text(
                  cover == null
                      ? 'Ebook stores require a cover. JPEG or PNG, at least '
                          '${BookCover.minEdge} pixels on the short side.'
                      : cover.summary,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton.icon(
                      key: const Key('book-choose-cover-button'),
                      onPressed: _chooseCover,
                      icon: const Icon(Icons.upload_outlined, size: 18),
                      label: Text(cover == null ? 'Add cover' : 'Replace'),
                    ),
                    if (cover != null) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        key: const Key('book-remove-cover-button'),
                        onPressed: _removeCover,
                        child: const Text('Remove'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _matterPanel(
    ThemeData theme,
    String title,
    List<BookSection> sections,
    bool isFront,
  ) =>
      _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeading(title, theme),
            const SizedBox(height: 10),
            for (final section in sections)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Switch(
                      key: Key('book-section-${section.id}'),
                      value: section.included,
                      onChanged: (value) => _update((b) => _replaceSection(
                            b,
                            isFront,
                            section.copyWith(included: value),
                          )),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(section.kind.label,
                              style: theme.textTheme.bodyMedium),
                          if (section.isGenerated)
                            Text(
                              section.kind == BookSectionKind.contents
                                  ? 'Built from your chapters every time the '
                                      'book is laid out.'
                                  : 'Built from the details above.',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!section.isGenerated && section.included)
                      OutlinedButton(
                        key: Key('book-edit-${section.id}'),
                        onPressed: () => _editSectionBody(section, isFront),
                        child: Text(
                            section.body.trim().isEmpty ? 'Write' : 'Edit'),
                      ),
                  ],
                ),
              ),
          ],
        ),
      );

  BookProject _replaceSection(
    BookProject book,
    bool isFront,
    BookSection replacement,
  ) {
    List<BookSection> replace(List<BookSection> list) => [
          for (final section in list)
            section.id == replacement.id ? replacement : section,
        ];
    return isFront
        ? book.copyWith(frontMatter: replace(book.frontMatter))
        : book.copyWith(backMatter: replace(book.backMatter));
  }

  Future<void> _editSectionBody(BookSection section, bool isFront) async {
    final controller = TextEditingController(text: section.body);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(section.kind.label),
        content: SizedBox(
          width: 520,
          child: TextField(
            key: const Key('book-section-body-field'),
            controller: controller,
            maxLines: 10,
            minLines: 5,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
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
    if (result == null) return;
    await _update((b) =>
        _replaceSection(b, isFront, section.copyWith(body: result)));
  }

  Widget _partsPanel(ThemeData theme) {
    final book = _book!;
    final chapters = _manuscript?.chapters ?? const <ManuscriptChapter>[];
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _SectionHeading('Parts', theme)),
              OutlinedButton.icon(
                key: const Key('book-add-part-button'),
                onPressed: chapters.isEmpty ? null : _addPart,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add part'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'A part opens on its own page before the chapter you anchor it to. '
            'Your chapters are not moved.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          if (book.parts.isEmpty)
            Text('No parts. The book runs straight through its chapters.',
                style: theme.textTheme.bodySmall)
          else
            for (final part in book.parts)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        part.title.isEmpty ? '(untitled part)' : part.title,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'from ${_chapterTitle(part.startsAtChapterId)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    IconButton(
                      key: Key('book-remove-part-${part.id}'),
                      tooltip: 'Remove part',
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: () => _update((b) => b.copyWith(
                            parts: b.parts
                                .where((p) => p.id != part.id)
                                .toList(),
                          )),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  String _chapterTitle(String chapterId) {
    final chapter = _manuscript?.chapterById(chapterId);
    return chapter?.title ?? 'a deleted chapter';
  }

  Future<void> _addPart() async {
    final chapters = _manuscript?.chapters ?? const <ManuscriptChapter>[];
    if (chapters.isEmpty) return;
    final book = _book!;
    final used = book.parts.map((p) => p.startsAtChapterId).toSet();
    final anchor = chapters.firstWhere(
      (chapter) => !used.contains(chapter.id),
      orElse: () => chapters.first,
    );
    await _update((b) => b.copyWith(
          parts: [
            ...b.parts,
            BookPart(
              id: 'part-${DateTime.now().microsecondsSinceEpoch}',
              startsAtChapterId: anchor.id,
              title: 'Part ${b.parts.length + 1}',
              order: b.parts.length,
            ),
          ],
        ));
  }

  // --- formatting ---------------------------------------------------------

  Widget _formattingStage(ThemeData theme) {
    final format = _book!.format;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeading('Preset', theme),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final preset in BookFormatPresets.paginated)
                    ChoiceChip(
                      key: Key('book-preset-${preset.id}'),
                      selected: format.id == preset.id ||
                          format.basePresetId == preset.id,
                      label: Text(preset.label),
                      onSelected: (_) =>
                          _update((b) => b.copyWith(format: preset)),
                    ),
                ],
              ),
              if (format.isCustomised) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Modified from '
                        '${BookFormatPresets.byId(format.basePresetId!).label}.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    TextButton(
                      key: const Key('book-reset-format-button'),
                      onPressed: () => _update((b) => b.copyWith(
                            format:
                                BookFormatPresets.byId(format.basePresetId!),
                          )),
                      child: const Text('Reset to preset'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeading('Trim size', theme),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final trim in TrimSize.printSizes)
                    ChoiceChip(
                      key: Key('book-trim-${trim.id}'),
                      selected: format.trim.id == trim.id,
                      label: Text(trim.label),
                      onSelected: (_) => _customise((f) => f.copyWith(trim: trim)),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeading('Typography', theme),
              const SizedBox(height: 10),
              _slider(theme, 'Body size', format.typography.bodySizePt, 8, 20,
                  (v) => _customise((f) => f.copyWith(
                      typography: f.typography.copyWith(bodySizePt: v))),
                  suffix: 'pt'),
              _slider(theme, 'Line spacing', format.typography.leadingMultiple,
                  1.0, 2.2,
                  (v) => _customise((f) => f.copyWith(
                      typography: f.typography.copyWith(leadingMultiple: v)))),
              _slider(theme, 'First-line indent',
                  format.typography.firstLineIndentPt, 0, 36,
                  (v) => _customise((f) => f.copyWith(
                      typography:
                          f.typography.copyWith(firstLineIndentPt: v))),
                  suffix: 'pt'),
              const SizedBox(height: 8),
              _enumRow<BookAlignment>(
                theme,
                'Alignment',
                BookAlignment.values,
                format.typography.alignment,
                (value) => _customise((f) => f.copyWith(
                    typography: f.typography.copyWith(alignment: value))),
                labels: const {
                  BookAlignment.left: 'Ragged right',
                  BookAlignment.justified: 'Justified',
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeading('Margins', theme),
              const SizedBox(height: 4),
              Text(
                'The inside margin is the spine edge, so it swaps sides between '
                'left- and right-hand pages.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              _slider(theme, 'Top', format.margins.topPt, 18, 108,
                  (v) => _customise((f) =>
                      f.copyWith(margins: f.margins.copyWith(topPt: v))),
                  suffix: 'pt'),
              _slider(theme, 'Bottom', format.margins.bottomPt, 18, 108,
                  (v) => _customise((f) =>
                      f.copyWith(margins: f.margins.copyWith(bottomPt: v))),
                  suffix: 'pt'),
              _slider(theme, 'Outside', format.margins.outsidePt, 18, 108,
                  (v) => _customise((f) =>
                      f.copyWith(margins: f.margins.copyWith(outsidePt: v))),
                  suffix: 'pt'),
              _slider(theme, 'Inside', format.margins.insidePt, 18, 108,
                  (v) => _customise((f) =>
                      f.copyWith(margins: f.margins.copyWith(insidePt: v))),
                  suffix: 'pt'),
              _slider(theme, 'Binding allowance', format.margins.gutterPt, 0, 72,
                  (v) => _customise((f) =>
                      f.copyWith(margins: f.margins.copyWith(gutterPt: v))),
                  suffix: 'pt'),
            ],
          ),
        ),
      ],
    );
  }

  // --- design -------------------------------------------------------------

  Widget _designStage(ThemeData theme) {
    final format = _book!.format;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeading('Chapter openers', theme),
              const SizedBox(height: 10),
              _enumRow<ChapterStartRule>(
                theme,
                'Start on',
                ChapterStartRule.values,
                format.chapter.startRule,
                (value) => _customise((f) =>
                    f.copyWith(chapter: f.chapter.copyWith(startRule: value))),
                labels: const {
                  ChapterStartRule.anyPage: 'Any page',
                  ChapterStartRule.nextPage: 'A new page',
                  ChapterStartRule.recto: 'A right-hand page',
                },
              ),
              const SizedBox(height: 6),
              if (format.requiresRectoStarts)
                Text(
                  'Right-hand starts insert blank left-hand pages, the way a '
                  'printed book does.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              const SizedBox(height: 10),
              _enumRow<ChapterNumberStyle>(
                theme,
                'Numbering',
                ChapterNumberStyle.values,
                format.chapter.numberStyle,
                (value) => _customise((f) =>
                    f.copyWith(chapter: f.chapter.copyWith(numberStyle: value))),
                labels: const {
                  ChapterNumberStyle.none: 'None',
                  ChapterNumberStyle.arabic: '1, 2, 3',
                  ChapterNumberStyle.word: 'One, Two',
                  ChapterNumberStyle.romanUpper: 'I, II, III',
                },
              ),
              const SizedBox(height: 10),
              _slider(theme, 'Sink', format.chapter.sinkFraction, 0, 0.5,
                  (v) => _customise((f) =>
                      f.copyWith(chapter: f.chapter.copyWith(sinkFraction: v)))),
              _SwitchRow(
                key: const Key('book-dropcap-switch'),
                title: 'Drop capital',
                value: format.chapter.dropCap,
                onChanged: (value) => _customise((f) =>
                    f.copyWith(chapter: f.chapter.copyWith(dropCap: value))),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeading('Scene breaks', theme),
              const SizedBox(height: 10),
              _enumRow<SceneBreakStyle>(
                theme,
                'Between scenes',
                SceneBreakStyle.values,
                format.chapter.sceneBreak,
                (value) => _customise((f) =>
                    f.copyWith(chapter: f.chapter.copyWith(sceneBreak: value))),
                labels: const {
                  SceneBreakStyle.blankLine: 'A blank line',
                  SceneBreakStyle.glyph: 'A mark',
                  SceneBreakStyle.ornament: 'An ornament',
                },
              ),
              if (format.chapter.sceneBreak == SceneBreakStyle.ornament) ...[
                const SizedBox(height: 10),
                _enumRow<BookOrnamentId>(
                  theme,
                  'Ornament',
                  BookOrnamentId.values,
                  format.chapter.ornament,
                  (value) => _customise((f) =>
                      f.copyWith(chapter: f.chapter.copyWith(ornament: value))),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeading('Running heads and page numbers', theme),
              const SizedBox(height: 10),
              _enumRow<RunningHeadContent>(
                theme,
                'Left page',
                RunningHeadContent.values,
                format.runningHead.verso,
                (value) => _customise((f) => f.copyWith(
                    runningHead: f.runningHead.copyWith(verso: value))),
              ),
              const SizedBox(height: 8),
              _enumRow<RunningHeadContent>(
                theme,
                'Right page',
                RunningHeadContent.values,
                format.runningHead.recto,
                (value) => _customise((f) => f.copyWith(
                    runningHead: f.runningHead.copyWith(recto: value))),
              ),
              const SizedBox(height: 12),
              _enumRow<PageNumberPosition>(
                theme,
                'Page numbers',
                PageNumberPosition.values,
                format.numbering.position,
                (value) => _customise((f) => f.copyWith(
                    numbering: f.numbering.copyWith(position: value))),
                labels: const {
                  PageNumberPosition.none: 'None',
                  PageNumberPosition.footerCentre: 'Foot, centred',
                  PageNumberPosition.footerOutside: 'Foot, outside',
                  PageNumberPosition.headerOutside: 'Head, outside',
                },
              ),
              _SwitchRow(
                key: const Key('book-roman-front-switch'),
                title: 'Number front matter separately',
                subtitle:
                    'Roman numerals before the body, restarting at 1.',
                value: format.numbering.countFrontMatterSeparately,
                onChanged: (value) => _customise((f) => f.copyWith(
                      numbering: f.numbering.copyWith(
                        countFrontMatterSeparately: value,
                        restartAtBody: value,
                      ),
                    )),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _epubPanel(theme),
      ],
    );
  }

  /// The reflowable half of the book.
  ///
  /// Kept apart from the print controls above because a reader reflows an
  /// ebook: trim size, margins and folios mean nothing here, and everything
  /// that does is relative rather than measured in points.
  Widget _epubPanel(ThemeData theme) {
    final epub = _book!.epub;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading('Ebook (EPUB)', theme),
          const SizedBox(height: 4),
          Text(
            'These settings apply only to the EPUB. The reader chooses the '
            'type size, so everything here is relative to it.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          _enumRow<BookAlignment>(
            theme,
            'Alignment',
            BookAlignment.values,
            epub.alignment,
            (value) => _updateEpub((e) => e.copyWith(alignment: value)),
            labels: const {
              BookAlignment.left: 'Ragged right',
              BookAlignment.justified: 'Justified',
            },
          ),
          const SizedBox(height: 10),
          _slider(theme, 'Line spacing', epub.lineHeight, 1.0, 2.2,
              (v) => _updateEpub((e) => e.copyWith(lineHeight: v))),
          _slider(theme, 'First-line indent', epub.firstLineIndentEm, 0, 3,
              (v) => _updateEpub((e) => e.copyWith(firstLineIndentEm: v)),
              suffix: 'em'),
          _slider(theme, 'Paragraph spacing', epub.paragraphSpacingEm, 0, 2,
              (v) => _updateEpub((e) => e.copyWith(paragraphSpacingEm: v)),
              suffix: 'em'),
          const SizedBox(height: 10),
          _enumRow<ChapterNumberStyle>(
            theme,
            'Numbering',
            ChapterNumberStyle.values,
            epub.chapterNumberStyle,
            (value) => _updateEpub((e) => e.copyWith(chapterNumberStyle: value)),
            labels: const {
              ChapterNumberStyle.none: 'None',
              ChapterNumberStyle.arabic: '1, 2, 3',
              ChapterNumberStyle.word: 'One, Two',
              ChapterNumberStyle.romanUpper: 'I, II, III',
            },
          ),
          const SizedBox(height: 10),
          _enumRow<SceneBreakStyle>(
            theme,
            'Scene breaks',
            SceneBreakStyle.values,
            epub.sceneBreak,
            (value) => _updateEpub((e) => e.copyWith(sceneBreak: value)),
            labels: const {
              SceneBreakStyle.blankLine: 'A blank line',
              SceneBreakStyle.glyph: 'A mark',
              SceneBreakStyle.ornament: 'An ornament',
            },
          ),
          _SwitchRow(
            key: const Key('book-epub-dropcap-switch'),
            title: 'Drop capital',
            value: epub.dropCap,
            onChanged: (value) =>
                _updateEpub((e) => e.copyWith(dropCap: value)),
          ),
          _SwitchRow(
            key: const Key('book-epub-embed-fonts-switch'),
            title: 'Embed fonts',
            subtitle: 'Roughly doubles the file, and many readers override it '
                'anyway. The font licence travels with the book.',
            value: epub.embedFonts,
            onChanged: (value) =>
                _updateEpub((e) => e.copyWith(embedFonts: value)),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 240,
            child: TextFormField(
              key: const Key('book-epub-language-field'),
              initialValue: epub.language,
              decoration: const InputDecoration(
                labelText: 'Language',
                helperText: 'A BCP 47 tag, such as en or en-GB.',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) {
                if (!EpubSettings.isValidLanguage(value)) return;
                _updateEpub((e) => e.copyWith(language: value.trim()));
              },
            ),
          ),
        ],
      ),
    );
  }

  void _updateEpub(EpubSettings Function(EpubSettings) change) {
    _update((book) => book.copyWith(epub: change(book.epub)));
  }

  void _customise(BookFormat Function(BookFormat) change) {
    _update((book) {
      final base = book.format.isCustomised
          ? book.format
          : book.format.customise();
      return book.copyWith(format: change(base));
    });
  }

  // --- preview ------------------------------------------------------------

  Widget _previewStage(ThemeData theme) {
    final paginated = _paginated;
    if (paginated == null || paginated.pages.isEmpty) {
      return _Panel(
        child: Text('There is nothing to lay out yet. Write a chapter first.',
            style: theme.textTheme.bodyMedium),
      );
    }

    final index = _previewPage.clamp(0, paginated.pageCount - 1);
    final page = paginated.pages[index];

    return Column(
      children: [
        _Panel(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              IconButton(
                key: const Key('book-preview-prev'),
                icon: const Icon(Icons.chevron_left),
                onPressed: index == 0
                    ? null
                    : () => setState(() => _previewPage = index - (_spread ? 2 : 1)),
              ),
              Text(
                'Page ${index + 1} of ${paginated.pageCount}'
                '${page.folio == null ? '' : '  ·  folio ${page.folio}'}',
                style: theme.textTheme.bodyMedium,
              ),
              IconButton(
                key: const Key('book-preview-next'),
                icon: const Icon(Icons.chevron_right),
                onPressed: index >= paginated.pageCount - 1
                    ? null
                    : () => setState(
                        () => _previewPage = index + (_spread ? 2 : 1)),
              ),
              const Spacer(),
              IconButton(
                key: const Key('book-preview-spread'),
                tooltip: _spread ? 'Single page' : 'Facing pages',
                isSelected: _spread,
                icon: const Icon(Icons.import_contacts_outlined),
                onPressed: () => setState(() => _spread = !_spread),
              ),
              IconButton(
                key: const Key('book-preview-guides'),
                tooltip: 'Show margins',
                isSelected: _showGuides,
                icon: const Icon(Icons.crop_free),
                onPressed: () => setState(() => _showGuides = !_showGuides),
              ),
              IconButton(
                tooltip: 'Smaller',
                icon: const Icon(Icons.zoom_out),
                onPressed: _previewWidth <= 160
                    ? null
                    : () => setState(() => _previewWidth -= 40),
              ),
              IconButton(
                tooltip: 'Larger',
                icon: const Icon(Icons.zoom_in),
                onPressed: _previewWidth >= 520
                    ? null
                    : () => setState(() => _previewWidth += 40),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _Panel(
            padding: const EdgeInsets.all(24),
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 3,
              child: Center(
                child: SingleChildScrollView(
                  child: BookPreviewSurface(
                    key: const Key('book-preview-surface'),
                    book: paginated,
                    pageIndex: index,
                    spread: _spread,
                    pageWidth: _previewWidth,
                    showTextBlockGuide: _showGuides,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (paginated.stats.blankPageCount > 0 ||
            paginated.issues.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Panel(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${paginated.pageCount} pages · '
                  '${paginated.stats.blankPageCount} blank · '
                  'laid out in ${paginated.stats.elapsed.inMilliseconds} ms',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                for (final issue in paginated.issues)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(issue.message,
                        style: theme.textTheme.bodySmall),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // --- export -------------------------------------------------------------

  Widget _exportStage(ThemeData theme) {
    final paginated = _paginated;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeading('Export', theme),
              const SizedBox(height: 10),
              for (final format in BookExportFormat.values)
                _ExportOption(
                  key: Key('book-export-${format.name}'),
                  format: format,
                  selected: _exportFormat == format,
                  onSelected: format.isAvailable
                      ? () => setState(() => _exportFormat = format)
                      : null,
                ),
              const SizedBox(height: 12),
              if (paginated != null)
                Text(
                  'This will write ${paginated.pageCount} pages at '
                  '${paginated.format.trim.label}.',
                  style: theme.textTheme.bodyMedium,
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('book-export-button'),
                onPressed:
                    _exporting || paginated == null ? null : _export,
                icon: _exporting
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined),
                label: Text(_exporting ? 'Exporting…' : 'Export book'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The Editing and Proofing stages, which differ only in which findings they
  /// show and whether the dictionary has to be loaded first.
  Widget _findingsStage(ThemeData theme, ProofStage stage) {
    final isProofing = stage == ProofStage.proofing;
    if (isProofing && _dictionary == null && !_proofing) {
      // Loading is deferred until the author actually asks for this stage.
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _ensureDictionary());
    }

    final findings = <ProofFinding>[
      ..._proof.forStage(stage),
      if (isProofing) ..._layoutProof.findings,
    ];
    final fixable = findings.where((finding) => finding.isFixable).toList();
    final grouped = <String, List<ProofFinding>>{};
    for (final finding in findings) {
      (grouped[finding.ruleId] ??= []).add(finding);
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _SectionHeading(stage.label, theme)),
                  if (fixable.isNotEmpty)
                    FilledButton.icon(
                      key: Key('book-fix-all-${stage.name}'),
                      onPressed:
                          _fixing ? null : () => _applyFixes(fixable),
                      icon: _fixing
                          ? const SizedBox.square(
                              dimension: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.auto_fix_high_outlined, size: 18),
                      label: Text('Fix all ${fixable.length}'),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(stage.summary,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final severity in ProofSeverity.values)
                    _Stat(
                      label: severity.label,
                      value: '${findings.where((f) =>
                          f.severity == severity).length}',
                    ),
                  _Stat(label: 'Can be fixed', value: '${fixable.length}'),
                ],
              ),
              if (isProofing) ...[
                const SizedBox(height: 12),
                Text(
                  _proofing
                      ? 'Loading the dictionary…'
                      : _dictionary == null
                          ? 'Spelling has not been checked.'
                          : 'Spelling checked against '
                              '${_dictionary!.wordCount} words, plus '
                              '${_knownNames.length} names from your records.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (findings.isEmpty)
          _Panel(
            child: Row(
              children: [
                Icon(Icons.check_circle_outline,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isProofing
                        ? 'Nothing to report. Every check passed.'
                        : 'The text is clean.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          )
        else
          for (final entry in grouped.entries) ...[
            _ruleGroup(theme, entry.key, entry.value),
            const SizedBox(height: 12),
          ],
        if (isProofing) ...[
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeading('Story continuity', theme),
                const SizedBox(height: 6),
                Text(
                  'Unlinked characters, impossible travel and the rest live in '
                  'Manuscript Studio\'s continuity panel, where they can be '
                  'resolved against your records. They are not repeated here.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _ruleGroup(
      ThemeData theme, String ruleId, List<ProofFinding> findings) {
    final rule = BuiltInProofRules.byId(ruleId);
    final fixable = findings.where((finding) => finding.isFixable).toList();
    final worst = findings
        .map((finding) => finding.severity)
        .reduce((a, b) => a.rank <= b.rank ? a : b);

    return _Panel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                switch (worst) {
                  ProofSeverity.critical => Icons.error_outline,
                  ProofSeverity.warning => Icons.warning_amber_outlined,
                  ProofSeverity.notice => Icons.info_outline,
                },
                size: 18,
                color: worst == ProofSeverity.notice
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${rule?.label ?? findings.first.title} · ${findings.length}',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (fixable.isNotEmpty)
                OutlinedButton(
                  key: Key('book-fix-$ruleId'),
                  onPressed: _fixing ? null : () => _applyFixes(fixable),
                  child: Text('Fix ${fixable.length}'),
                ),
            ],
          ),
          if (rule != null) ...[
            const SizedBox(height: 4),
            Text(rule.description,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 10),
          for (final finding in findings.take(8))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodySmall,
                        children: [
                          if (finding.found.trim().isNotEmpty)
                            TextSpan(
                              text: '"${_preview(finding.found)}"  ',
                              style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w700),
                            ),
                          TextSpan(text: finding.message),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 180,
                    child: Text(
                      finding.where,
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (findings.length > 8)
            Text('and ${findings.length - 8} more',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
        ],
      ),
    );
  }

  /// Keeps a snippet short and shows whitespace, which is otherwise invisible
  /// in exactly the findings that are about whitespace.
  static String _preview(String value) {
    final shown = value
        .replaceAll('\t', '→')
        .replaceAll('\n', '⏎')
        .replaceAll(' ', '·');
    return shown.length <= 32 ? shown : '${shown.substring(0, 32)}…';
  }

  Widget _issuesPanel(ThemeData theme, List<String> messages) => _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeading('Worth a look', theme),
            const SizedBox(height: 8),
            for (final message in messages)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('· $message', style: theme.textTheme.bodySmall),
              ),
          ],
        ),
      );

  // --- small shared controls ----------------------------------------------

  Widget _field(
    String label,
    String value, {
    String? hint,
    required ValueChanged<String> onChanged,
  }) =>
      SizedBox(
        width: 240,
        child: TextFormField(
          key: Key('book-field-${label.toLowerCase().replaceAll(' ', '-')}'),
          initialValue: value,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onFieldSubmitted: onChanged,
          onChanged: onChanged,
        ),
      );

  Widget _slider(
    ThemeData theme,
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    String suffix = '',
  }) =>
      Row(
        children: [
          SizedBox(
            width: 132,
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 58,
            child: Text(
              '${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)}$suffix',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      );

  Widget _enumRow<T extends Enum>(
    ThemeData theme,
    String label,
    List<T> values,
    T selected,
    ValueChanged<T> onChanged, {
    Map<T, String> labels = const {},
  }) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 132,
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final value in values)
                  ChoiceChip(
                    key: Key('book-${label.toLowerCase()
                        .replaceAll(' ', '-')}-${value.name}'),
                    selected: value == selected,
                    label: Text(labels[value] ?? _humanise(value.name)),
                    onSelected: (_) => onChanged(value),
                  ),
              ],
            ),
          ),
        ],
      );
}

String _humanise(String name) {
  final spaced = name.replaceAllMapped(
    RegExp('([a-z])([A-Z])'),
    (match) => '${match[1]} ${match[2]!.toLowerCase()}',
  );
  return spaced[0].toUpperCase() + spaced.substring(1);
}

String _thousands(int value) => value
    .toString()
    .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

/// A switch with a label, safe to place on a coloured panel.
///
/// `SwitchListTile` paints its ink on the nearest `Material` ancestor, so
/// dropping one straight onto a decorated container hides the splash — the
/// framework asserts about it in debug. Giving the tile its own transparent
/// `Material` keeps the ripple visible without changing the panel's surface.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Material(
        type: MaterialType.transparency,
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle!),
          value: value,
          onChanged: onChanged,
        ),
      );
}

/// The studio's standard surface: the same shape every other studio uses.
class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: child,
    );
  }
}

/// One selectable export target.
class _ExportOption extends StatelessWidget {
  const _ExportOption({
    super.key,
    required this.format,
    required this.selected,
    required this.onSelected,
  });

  final BookExportFormat format;
  final bool selected;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onSelected != null;
    final foreground = enabled
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onSelected,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 18,
                color: selected ? theme.colorScheme.primary : foreground,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(format.label,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: foreground)),
                        if (!enabled) ...[
                          const SizedBox(width: 8),
                          Text('later',
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: foreground)),
                        ],
                      ],
                    ),
                    Text(format.description,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: foreground)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text, this.theme);

  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: theme.textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(value,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

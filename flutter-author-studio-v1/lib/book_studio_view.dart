/// Book Studio — the Write to Publish stage.
///
/// The studio walks the author along one pipeline: structure the book, format
/// it, design its chapters, see it, export it. The preview is the point. It is
/// painted from exactly the [PaginatedBook] the exporter writes, so changing a
/// trim size or a leading value reflows the real book in front of the author
/// rather than promising something the PDF may not honour.
library;

import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';

import 'book/book_cover.dart';
import 'book/book_dictionary.dart';
import 'book/book_docx_exporter.dart';
import 'book/book_document.dart';
import 'book/book_epub_exporter.dart';
import 'book/book_export_targets.dart';
import 'book/book_fonts.dart';
import 'book/book_format.dart';
import 'book/inline_markup.dart';
import 'book/book_layout.dart';
import 'book/book_pdf_renderer.dart';
import 'book/book_preview_painter.dart';
import 'book/book_snapshot.dart';
import 'book/book_store.dart';
import 'book/book_template.dart';
import 'book/book_text_exporter.dart';
import 'book/epub_settings.dart';
import 'book/preflight.dart';
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
    this.docxExporter = const BookDocxExporter(),
    this.textExporter = const BookTextExporter(),
    this.coverStore = const BookCoverStore(),
    this.snapshotStore = const BookSnapshotStore(),
    this.templateStore = const BookTemplateStore(),
    this.preflightEngine = const PreflightEngine(),
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
  final BookDocxExporter docxExporter;
  final BookTextExporter textExporter;
  final BookCoverStore coverStore;
  final BookSnapshotStore snapshotStore;
  final BookTemplateStore templateStore;
  final PreflightEngine preflightEngine;

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

  /// Which job the Word file is for. Only shown once DOCX is chosen.
  DocxFlavour _docxFlavour = DocxFlavour.submission;

  /// How much of the book's structure the text file carries.
  TextExportStyle _textStyle = TextExportStyle.readable;

  /// What preflight found for the currently chosen target.
  ///
  /// Recomputed when the target or the book changes, never on a repaint: the
  /// checks walk every page and the Export stage is rebuilt on every keystroke
  /// elsewhere in the studio.
  PreflightReport _preflight = PreflightReport.empty;
  String _preflightCacheKey = '';

  List<BookTemplate> _templates = const [];

  /// Which snapshots the database still holds.
  ///
  /// A history row whose draft has been evicted is still worth showing — "you
  /// exported an EPUB last Tuesday" stays true — but its button has to say so
  /// rather than failing when pressed.
  Set<String> _availableSnapshots = const {};

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
      final templates = await widget.templateStore.load();
      final snapshots = await _loadSnapshotHashes();

      if (!mounted) return;
      setState(() {
        _assets = assets;
        _manuscript = manuscript;
        _book = book;
        _cover = cover;
        _templates = templates;
        _availableSnapshots = snapshots;
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
  Future<Set<String>> _loadSnapshotHashes() async {
    try {
      return (await widget.snapshotStore.hashes(widget.project.id)).toSet();
    } catch (_) {
      // A history row with no reachable draft is shown as unavailable, which is
      // also the right answer if the database cannot be read at all.
      return const {};
    }
  }

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

  /// Re-runs preflight when the target or the book actually changed.
  void _repreflight() {
    final document = _document;
    final book = _book;
    if (document == null || book == null) return;

    final key = [
      _exportFormat.name,
      _layoutCacheKey,
      _cover == null ? 'nocover' : 'cover',
      book.epub.embedFonts,
    ].join('|');
    if (key == _preflightCacheKey) return;

    final report = widget.preflightEngine.run(PreflightContext(
      document: document,
      target: _exportFormat,
      format: book.format,
      // A reflowable target has no pages, and handing it a paginated book is
      // how a print assumption leaks into a format that has none.
      paginated: _exportFormat.isReflowable ? null : _paginated,
      epub: book.epub,
      assets: _assets,
      cover: _cover,
    ));

    setState(() {
      _preflight = report;
      _preflightCacheKey = key;
    });
  }

  /// Produces the bytes for one export.
  ///
  /// Shared by the live export and by re-exporting an earlier snapshot, so the
  /// two cannot drift: a file rebuilt from a frozen book has to come out of the
  /// same code the original did, or "reproducible" means nothing.
  Future<Uint8List> _renderExport({
    required BookDocument document,
    required PaginatedBook paginated,
    required BookProject book,
    required ManuscriptProjectSummary manuscript,
    required BookExportFormat format,
    required String variant,
    required BookFontAssets assets,
    required BookCover? cover,
  }) async {
    // Reflowable targets are built from the book's structure; paginated ones
    // from the laid-out pages. A reflowable format must never inherit print
    // pagination — the reader decides where its pages fall, not this app.
    return switch (format) {
      BookExportFormat.epub => widget.epubExporter.export(
          document: document,
          settings: book.epub,
          projectId: widget.project.id,
          modified: manuscript.updatedAt,
          cover: cover,
          fonts: assets,
        ),
      BookExportFormat.docx => widget.docxExporter.export(
          document: document,
          flavour: _docxFlavourNamed(variant),
          modified: manuscript.updatedAt,
          format: book.format,
        ),
      BookExportFormat.txt => Uint8List.fromList(utf8.encode(
          widget.textExporter.export(
            document: document,
            style: _textStyleNamed(variant),
            format: book.format,
          ),
        )),
      BookExportFormat.printPdf || BookExportFormat.digitalPdf =>
        await widget.renderer
            .render(paginated, assets, modified: manuscript.updatedAt),
    };
  }

  /// Lays a frozen book out again, off the studio's own cached state.
  ({BookDocument document, PaginatedBook paginated}) _derive(
    ManuscriptProjectSummary manuscript,
    BookProject book,
    BookFontAssets assets,
  ) {
    final document = const BookDocumentBuilder().build(
      manuscript: manuscript,
      book: book,
      profileAuthorName: widget.project.title,
    );
    return (
      document: document,
      paginated: BookLayoutEngine(PdfBookFontMetrics(assets))
          .layout(document, book.format),
    );
  }

  static DocxFlavour _docxFlavourNamed(String name) =>
      DocxFlavour.values.firstWhere((f) => f.name == name,
          orElse: () => DocxFlavour.submission);

  static TextExportStyle _textStyleNamed(String name) =>
      TextExportStyle.values.firstWhere((s) => s.name == name,
          orElse: () => TextExportStyle.readable);

  Future<void> _export() async {
    final paginated = _paginated;
    final document = _document;
    final assets = _assets;
    final book = _book;
    final manuscript = _manuscript;
    if (paginated == null || document == null || assets == null ||
        book == null || manuscript == null) {
      return;
    }

    setState(() => _exporting = true);
    try {
      final bytes = await _renderExport(
        document: document,
        paginated: paginated,
        book: book,
        manuscript: manuscript,
        format: _exportFormat,
        variant: switch (_exportFormat) {
          BookExportFormat.docx => _docxFlavour.name,
          BookExportFormat.txt => _textStyle.name,
          _ => '',
        },
        assets: assets,
        cover: _cover,
      );
      final path = await widget.fileSaver.save(
        suggestedName: suggestedBookFilename(
          title: paginated.metadata.title,
          format: _exportFormat,
        ),
        bytes: bytes,
        format: _exportFormat,
      );
      if (!mounted) return;
      if (path == null) {
        setState(() => _exporting = false);
        return;
      }

      await _recordExport(paginated);

      if (!mounted) return;
      setState(() => _exporting = false);
      _message(path.isEmpty
          ? 'Your book has been downloaded.'
          : 'Book exported to $path');
    } catch (error) {
      if (!mounted) return;
      setState(() => _exporting = false);
      _message('Export failed. $error');
    }
  }

  /// Produces an earlier export again, from the book that was frozen with it.
  ///
  /// This is what the snapshot was for. The words, the trim, the typography and
  /// the copyright page all come from what was stored at the time, so the file
  /// is the file — not the old manuscript re-set in whatever the book looks
  /// like today.
  Future<void> _reExport(ExportRecord record) async {
    final assets = _assets;
    if (assets == null || _exporting) return;

    setState(() => _exporting = true);
    try {
      final snapshot = await widget.snapshotStore
          .load(widget.project.id, record.snapshotHash);

      if (snapshot == null) {
        if (!mounted) return;
        setState(() => _exporting = false);
        _message('That draft is no longer stored. Only the '
            '${BookSnapshotStore.retained} most recent are kept.');
        return;
      }

      final format = BookExportFormat.values.firstWhere(
          (f) => f.name == record.format,
          orElse: () => BookExportFormat.printPdf);

      final derived = _derive(snapshot.manuscript, snapshot.book, assets);
      final bytes = await _renderExport(
        document: derived.document,
        paginated: derived.paginated,
        book: snapshot.book,
        manuscript: snapshot.manuscript,
        format: format,
        variant: record.variant,
        assets: assets,
        // The cover is the only input not frozen — it is binary and large. If
        // it has changed since, the file will differ, and the author is told
        // rather than left to find out.
        cover: _cover,
      );

      final path = await widget.fileSaver.save(
        suggestedName: suggestedBookFilename(
          title: derived.paginated.metadata.title,
          format: format,
        ),
        bytes: bytes,
        format: format,
      );
      if (!mounted) return;
      if (path == null) {
        setState(() => _exporting = false);
        return;
      }

      await _recordExport(derived.paginated,
          format: format,
          variant: record.variant,
          manuscript: snapshot.manuscript,
          book: snapshot.book);

      if (!mounted) return;
      setState(() => _exporting = false);
      _message(_coverChangedSince(record)
          ? 'Exported again from that draft. The cover has changed since, so '
              'this file carries the current one.'
          : 'Exported again from that draft.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _exporting = false);
      _message('Export failed. $error');
    }
  }

  /// Whether the cover in use now is not the one that export was made with.
  bool _coverChangedSince(ExportRecord record) {
    final now = _cover == null ? '' : contentHash(_cover!.bytes);
    return now != record.coverHash;
  }

  /// Freezes the manuscript this export was built from, and remembers it.
  ///
  /// The master plan asks that exports be reproducible from a frozen snapshot.
  /// Without this the studio reads whatever the manuscript says at that
  /// instant, and a file exported last month cannot be produced again once
  /// another paragraph has been written.
  ///
  /// A failure here must never look like a failed export: the file has already
  /// been written and the author already has it. It is recorded and swallowed.
  Future<void> _recordExport(
    PaginatedBook paginated, {
    BookExportFormat? format,
    String? variant,
    ManuscriptProjectSummary? manuscript,
    BookProject? book,
  }) async {
    // A re-export passes the frozen book it was built from; a live export
    // passes nothing and gets the current one.
    final source = manuscript ?? _manuscript;
    final settings = book ?? _book;
    final current = _book;
    if (source == null || settings == null || current == null) return;

    final target = format ?? _exportFormat;

    try {
      final hash = await widget.snapshotStore
          .capture(widget.project.id, source, settings);

      final record = ExportRecord(
        exportedAt: DateTime.now().toUtc(),
        format: target.name,
        variant: variant ??
            switch (target) {
              BookExportFormat.docx => _docxFlavour.name,
              BookExportFormat.txt => _textStyle.name,
              _ => '',
            },
        snapshotHash: hash,
        manuscriptVersion: source.version,
        pageCount: target.isReflowable ? 0 : paginated.pageCount,
        wordCount: paginated.stats.wordCount,
        coverHash: _cover == null ? '' : contentHash(_cover!.bytes),
      );

      final history = [record, ...current.exportHistory]
          .take(BookProject.historyLimit)
          .toList();
      await _update((current) => current.copyWith(exportHistory: history));

      // Anything no remaining history entry names can never be asked for
      // again, so it goes now rather than sitting in the database forever.
      await widget.snapshotStore.prune(
        widget.project.id,
        {for (final entry in history) entry.snapshotHash},
      );

      final remaining = await _loadSnapshotHashes();
      if (!mounted) return;
      setState(() => _availableSnapshots = remaining);
    } catch (error) {
      debugPrint('Book Studio could not record the export snapshot: $error');
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
        _templatePanel(theme),
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
        _emphasisPanel(theme, format),
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

  /// What the author is about to get, in the terms of the format they chose.
  ///
  /// A page count is a promise only the PDFs can keep. Saying "412 pages" over
  /// an EPUB or a Word file would be a straightforwardly false statement: the
  /// reader's type size decides the first, and Word's paper decides the second.
  String _exportSummary(PaginatedBook? paginated) {
    final chapters = _document?.chapterCount ?? 0;
    final words = _document?.wordCount ?? 0;
    return switch (_exportFormat) {
      BookExportFormat.printPdf || BookExportFormat.digitalPdf =>
        paginated == null
            ? 'Laying the book out…'
            : 'This will write ${paginated.pageCount} pages at '
                '${paginated.format.trim.label}.',
      BookExportFormat.epub =>
        'This will write $chapters chapters. An EPUB has no fixed pages — the '
            'reader chooses the type size and the text reflows to fit.',
      BookExportFormat.docx =>
        'This will write $chapters chapters as ${_docxFlavour.label}. Word '
            'repaginates on whatever paper it is opened with.',
      BookExportFormat.txt =>
        'This will write $words words as plain text.',
    };
  }

  Widget _exportStage(ThemeData theme) {
    final paginated = _paginated;
    // Cheap when nothing changed; the key guards the walk over every page.
    WidgetsBinding.instance.addPostFrameCallback((_) => _repreflight());
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeading('Export', theme),
              const SizedBox(height: 10),
              for (final format in BookExportFormat.values) ...[
                _ExportOption(
                  key: Key('book-export-${format.name}'),
                  format: format,
                  selected: _exportFormat == format,
                  onSelected: format.isAvailable
                      ? () => setState(() => _exportFormat = format)
                      : null,
                ),
                // The variants belong to the format, so they are shown under
                // it rather than in a separate settings panel the author has
                // to go and find.
                if (_exportFormat == format &&
                    format == BookExportFormat.docx)
                  for (final flavour in DocxFlavour.values)
                    _VariantOption(
                      key: Key('book-docx-${flavour.name}'),
                      label: flavour.label,
                      description: flavour.description,
                      selected: _docxFlavour == flavour,
                      onSelected: () =>
                          setState(() => _docxFlavour = flavour),
                    ),
                if (_exportFormat == format && format == BookExportFormat.txt)
                  for (final style in TextExportStyle.values)
                    _VariantOption(
                      key: Key('book-txt-${style.name}'),
                      label: style.label,
                      description: style.description,
                      selected: _textStyle == style,
                      onSelected: () => setState(() => _textStyle = style),
                    ),
              ],
              const SizedBox(height: 12),
              Text(_exportSummary(paginated), style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              _preflightPanel(theme),
              FilledButton.icon(
                key: const Key('book-export-button'),
                onPressed:
                    _exporting || paginated == null ? null : _export,
                icon: _exporting
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(switch (_exportFormat) {
                        BookExportFormat.printPdf ||
                        BookExportFormat.digitalPdf =>
                          Icons.picture_as_pdf_outlined,
                        BookExportFormat.epub => Icons.menu_book_outlined,
                        BookExportFormat.docx => Icons.description_outlined,
                        BookExportFormat.txt => Icons.notes_outlined,
                      }),
                label: Text(_exporting ? 'Exporting…' : 'Export book'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _historyPanel(theme),
      ],
    );
  }

  /// What has been exported, and the way back to any of it.
  ///
  /// Every row names the manuscript it came from, so an author can produce a
  /// file again exactly as it was — the same words, the same trim, the same
  /// copyright page — after months of further writing. That is the whole
  /// reason the snapshot exists; without this it was data nobody could reach.
  Widget _historyPanel(ThemeData theme) {
    final history = _book?.exportHistory ?? const <ExportRecord>[];

    return _Panel(
      key: const Key('book-export-history'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading('Earlier exports', theme),
          const SizedBox(height: 6),
          if (history.isEmpty)
            Text(
              'Once you export, each file is listed here with the draft it was '
              'made from, so you can produce it again later.',
              style: theme.textTheme.bodySmall,
            )
          else ...[
            Text(
              'Each of these can be made again exactly as it was. The '
              '${BookSnapshotStore.retained} most recent drafts are kept.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < history.length; i++)
              _ExportHistoryRow(
                key: Key('book-history-$i'),
                record: history[i],
                available: _availableSnapshots.contains(history[i].snapshotHash),
                busy: _exporting,
                onExport: () => _reExport(history[i]),
              ),
          ],
        ],
      ),
    );
  }

  /// Save this book's look, or put a saved one on.
  ///
  /// Sits beside the presets because that is what a template is: a preset the
  /// author made. It never touches the book's title, ISBN or copyright — a
  /// series shares a design, not an identity.
  Widget _templatePanel(ThemeData theme) => _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeading('Your templates', theme),
            const SizedBox(height: 6),
            Text(
              'A template saves the trim, typography, chapter design, ebook '
              'settings and which sections a book has — never its title, ISBN '
              'or copyright.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            if (_templates.isEmpty)
              Text('You have not saved one yet.',
                  style: theme.textTheme.bodySmall)
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final template in _templates)
                    InputChip(
                      key: Key('book-template-${template.id}'),
                      label: Text(template.name),
                      onPressed: () => _applyTemplate(template),
                      onDeleted: () => _deleteTemplate(template),
                      deleteIcon: const Icon(Icons.close, size: 16),
                    ),
                ],
              ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const Key('book-save-template-button'),
              onPressed: _saveTemplate,
              icon: const Icon(Icons.bookmark_add_outlined, size: 18),
              label: const Text('Save this look as a template'),
            ),
          ],
        ),
      );

  Future<void> _saveTemplate() async {
    final book = _book;
    if (book == null) return;

    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _TemplateNameDialog(),
    );
    if (name == null || name.trim().isEmpty) return;

    final template = BookTemplate.from(
      book,
      name: name.trim(),
      createdAt: DateTime.now().toUtc(),
    );
    final templates = await widget.templateStore.save(template);
    if (!mounted) return;
    setState(() => _templates = templates);
    _message('Saved "${template.name}".');
  }

  Future<void> _applyTemplate(BookTemplate template) async {
    await _update(template.applyTo);
    if (!mounted) return;
    _message('Applied "${template.name}". Your title and copyright are '
        'unchanged.');
  }

  Future<void> _deleteTemplate(BookTemplate template) async {
    final templates = await widget.templateStore.delete(template.id);
    if (!mounted) return;
    setState(() => _templates = templates);
  }

  /// The inline emphasis convention, and what switching it on would do.
  ///
  /// Off by default, because turning it on reinterprets prose the author has
  /// already written — an underscore that was just an underscore becomes
  /// emphasis. So it says how many spans it found first, from the real parser
  /// over the real book, rather than asking them to switch it on and go
  /// looking.
  Widget _emphasisPanel(ThemeData theme, BookFormat format) {
    final on =
        format.typography.inlineMarkup == BookInlineMarkup.underscoreItalic;
    final document = _document;
    final found = document == null
        ? 0
        : countEmphasis(document, BookInlineMarkup.underscoreItalic);

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading('Italics', theme),
          const SizedBox(height: 6),
          Text(
            'Scene prose is plain text, so italics need a convention. Write '
            '_like this_ and it is set in italic — in the PDF, the ebook and '
            'the Word file alike.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          _SwitchRow(
            key: const Key('book-emphasis-switch'),
            title: 'Underscores mean italic',
            value: on,
            onChanged: (value) => _customise((f) => f.copyWith(
                  typography: f.typography.copyWith(
                    inlineMarkup: value
                        ? BookInlineMarkup.underscoreItalic
                        : BookInlineMarkup.none,
                  ),
                )),
          ),
          const SizedBox(height: 6),
          Text(
            switch ((on, found)) {
              (true, 0) =>
                'Nothing in this book uses the convention yet. Wrap a phrase '
                    'in underscores and it will appear in italic here.',
              (true, final n) =>
                'Set in italic in $n place${n == 1 ? '' : 's'}.',
              (false, 0) =>
                'Nothing in this book would change if you switched this on.',
              (false, final n) =>
                'Switching this on would set $n phrase${n == 1 ? '' : 's'} in '
                    'italic. Your writing is not altered either way — the '
                    'underscores stay in the manuscript.',
            },
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// What preflight found, above the button rather than in the way of it.
  ///
  /// It never disables the export. An author has context this engine does not
  /// — a proof copy, a printer with its own rules, a deliberate choice — and a
  /// tool that refuses to produce a file is one that gets worked around instead
  /// of read.
  Widget _preflightPanel(ThemeData theme) {
    final report = _preflight;
    final colors = theme.colorScheme;

    if (report.isClean) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          key: const Key('book-preflight-clean'),
          children: [
            Icon(Icons.check_circle_outline, size: 18, color: colors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Preflight found nothing to flag.',
                  style: theme.textTheme.bodySmall),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        key: const Key('book-preflight-panel'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: report.hasCritical ? colors.error : colors.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  report.hasCritical
                      ? Icons.error_outline
                      : Icons.info_outlined,
                  size: 18,
                  color: report.hasCritical
                      ? colors.error
                      : colors.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(report.summary,
                      style: theme.textTheme.bodyMedium),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final finding in report.findings)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${finding.severity.label} · ${finding.title}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: finding.severity == ProofSeverity.critical
                              ? colors.error
                              : colors.onSurface,
                        )),
                    Text(finding.message, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(
              report.hasCritical
                  ? 'You can still export. Nothing here stops you — but the '
                      'items marked as needing attention will be visible in '
                      'the finished book.'
                  : 'You can still export. These are worth knowing about, not '
                      'worth stopping for.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
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
    super.key,
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
/// One variant of an export format — a Word flavour, a text style.
///
/// Indented under its format so it reads as a property of that choice rather
/// than as a sixth format.
class _VariantOption extends StatelessWidget {
  const _VariantOption({
    super.key,
    required this.label,
    required this.description,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final String description;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 30, bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onSelected,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 16,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 2),
                    Text(description, style: theme.textTheme.bodySmall),
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

/// One earlier export, and the way back to it.
class _ExportHistoryRow extends StatelessWidget {
  const _ExportHistoryRow({
    super.key,
    required this.record,
    required this.available,
    required this.busy,
    required this.onExport,
  });

  final ExportRecord record;

  /// Whether the draft this was made from is still stored.
  final bool available;

  final bool busy;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final format = BookExportFormat.values.firstWhere(
        (f) => f.name == record.format,
        orElse: () => BookExportFormat.printPdf);

    final detail = [
      _when(record.exportedAt),
      if (record.pageCount > 0) '${record.pageCount} pages',
      '${_thousands(record.wordCount)} words',
      'draft ${record.snapshotHash.substring(0, 6)}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.variant.isEmpty
                      ? format.label
                      : '${format.label} · ${record.variant}',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(detail, style: theme.textTheme.bodySmall),
                if (!available)
                  Text(
                    'This draft is no longer stored, so it cannot be made '
                    'again.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton.icon(
            onPressed: available && !busy ? onExport : null,
            icon: const Icon(Icons.replay, size: 16),
            label: const Text('Export again'),
          ),
        ],
      ),
    );
  }

  /// A date an author reads, not a timestamp.
  static String _when(DateTime value) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June', 'July',
      'August', 'September', 'October', 'November', 'December',
    ];
    final local = value.toLocal();
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }

  static String _thousands(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}

/// Asks for a template's name.
///
/// Deliberately plain: saving a look is a small action and should not feel like
/// a decision. The name is the only thing the author has to supply, because
/// everything else is already on screen.
class _TemplateNameDialog extends StatefulWidget {
  const _TemplateNameDialog();

  @override
  State<_TemplateNameDialog> createState() => _TemplateNameDialogState();
}

class _TemplateNameDialogState extends State<_TemplateNameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Name this template'),
        content: TextField(
          key: const Key('book-template-name-field'),
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Ash Cycle paperback',
            helperText: 'Saving over a name replaces that template.',
          ),
          onSubmitted: (_) => _submit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('book-template-name-confirm'),
            onPressed: _submit,
            child: const Text('Save'),
          ),
        ],
      );
}

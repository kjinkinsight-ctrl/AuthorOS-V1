/// Book Studio Phase 5 — reusable style templates.
///
/// A template is a book's *look*, saved under a name and applied to another
/// book. It is the last of M7's deliverables, and it exists because a series
/// shares a design: book two of a trilogy should not be re-tuned from the
/// paperback preset by hand until it happens to match book one.
///
/// **What it deliberately does not carry.** Everything that identifies a
/// particular book:
///
///  * Title, author, subtitle, ISBN, edition, copyright year and holder, and
///    the series number. Carrying book one's ISBN into book two is a way to
///    publish something genuinely wrong, and it would be silent.
///  * Parts. A [BookPart] anchors to `startsAtChapterId`, which names a chapter
///    in *that* project; copied across, every part becomes a `danglingPart`.
///  * The cover, which is binary, per-book, and lives in the database.
///  * The prose of authored sections — a dedication and an epigraph belong to
///    one book. Only the *structure* of the matter travels: which sections
///    exist, their order, and whether they are switched on.
///
/// **Why it stores resolved values rather than a preset id and a diff.** The
/// same reason `BookFormat` does, recorded there: if a template stored only its
/// difference from `BookFormatPresets.paperback`, shipping a change to that
/// preset would silently reflow every book built on the template, including
/// ones already published.
///
/// **Where it lives.** One JSON array under a single global key, mirroring
/// `AuthorProfileStore`'s `author_studio.profiles`. Templates must be
/// cross-project — that is the entire point — which rules out both the record
/// graph (scope-isolated by design, and proven so by
/// `test/story_graph_architecture_test.dart`) and `BookStore`'s per-project key.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'book_document.dart';
import 'book_format.dart';
import 'epub_settings.dart';

/// A saved book design.
class BookTemplate {
  const BookTemplate({
    required this.id,
    required this.name,
    required this.createdAt,
    this.format = BookFormatPresets.paperback,
    this.epub = EpubSettings.defaults,
    this.frontMatter = const [],
    this.backMatter = const [],
  });

  final String id;
  final String name;
  final DateTime createdAt;

  final BookFormat format;
  final EpubSettings epub;

  /// Matter *structure* only: the bodies are stripped on capture.
  final List<BookSection> frontMatter;
  final List<BookSection> backMatter;

  /// Captures the look of [project], leaving its identity behind.
  factory BookTemplate.from(
    BookProject project, {
    required String name,
    required DateTime createdAt,
    String? id,
  }) =>
      BookTemplate(
        id: id ?? slug(name),
        name: name.trim(),
        createdAt: createdAt,
        format: project.format,
        epub: project.epub,
        frontMatter: _structureOf(project.frontMatter),
        backMatter: _structureOf(project.backMatter),
      );

  /// Returns [project] wearing this template.
  ///
  /// Identity is copied through from [project] untouched — this returns the
  /// same book, set differently.
  BookProject applyTo(BookProject project) => project.copyWith(
        format: format,
        epub: epub,
        frontMatter: _merge(project.frontMatter, frontMatter),
        backMatter: _merge(project.backMatter, backMatter),
      );

  /// Section structure with every authored body removed.
  ///
  /// A generated section ignores `body` anyway; an authored one — a dedication,
  /// an epigraph — is this book's own writing and must not travel.
  static List<BookSection> _structureOf(List<BookSection> sections) => [
        for (final section in sections) section.copyWith(body: ''),
      ];

  /// The template's structure, keeping whatever the book has already written.
  ///
  /// Matched on section id, which is a fixed literal per kind
  /// (`front-dedication` and so on) rather than a per-project uuid, so a
  /// dedication written in book two survives having book one's design applied.
  static List<BookSection> _merge(
    List<BookSection> existing,
    List<BookSection> template,
  ) {
    if (template.isEmpty) return existing;
    final bodies = {
      for (final section in existing) section.id: section.body,
    };
    return [
      for (final section in template)
        section.copyWith(body: bodies[section.id] ?? ''),
    ];
  }

  BookTemplate copyWith({String? name, DateTime? createdAt}) => BookTemplate(
        id: id,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
        format: format,
        epub: epub,
        frontMatter: frontMatter,
        backMatter: backMatter,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'format': format.toJson(),
        'epub': epub.toJson(),
        'frontMatter': [for (final s in frontMatter) s.toJson()],
        'backMatter': [for (final s in backMatter) s.toJson()],
      };

  factory BookTemplate.fromJson(Map<String, dynamic> json) => BookTemplate(
        id: (json['id'] as String?) ?? 'template',
        name: (json['name'] as String?) ?? 'Untitled',
        createdAt:
            DateTime.tryParse((json['createdAt'] as String?) ?? '')?.toUtc() ??
                DateTime.utc(2000),
        format: json['format'] is Map
            ? BookFormat.fromJson(
                Map<String, dynamic>.from(json['format'] as Map))
            : BookFormatPresets.paperback,
        epub: json['epub'] is Map
            ? EpubSettings.fromJson(
                Map<String, dynamic>.from(json['epub'] as Map))
            : EpubSettings.defaults,
        frontMatter: [
          for (final item in (json['frontMatter'] as List? ?? const []))
            BookSection.fromJson(Map<String, dynamic>.from(item as Map)),
        ],
        backMatter: [
          for (final item in (json['backMatter'] as List? ?? const []))
            BookSection.fromJson(Map<String, dynamic>.from(item as Map)),
        ],
      );

  /// A stable id derived from the name, so saving over a name replaces it.
  static String slug(String name) {
    final cleaned = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return cleaned.isEmpty ? 'template' : cleaned;
  }
}

/// The author's template library, shared across every project.
class BookTemplateStore {
  const BookTemplateStore();

  /// Global on purpose: a template that only applied to the project it was
  /// saved in would be useless.
  static const storageKey = 'author_studio.book_templates';

  /// Enough for a working author's imprints and series.
  ///
  /// A cap at all because this is `localStorage` on the web, and a template is
  /// a few kilobytes of resolved values.
  static const limit = 50;

  Future<List<BookTemplate>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(storageKey);
    if (encoded == null || encoded.isEmpty) return const [];
    try {
      final decoded = jsonDecode(encoded) as List;
      return [
        for (final item in decoded)
          BookTemplate.fromJson(Map<String, dynamic>.from(item as Map)),
      ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } catch (_) {
      // A mangled library should not stop the studio opening, the same way a
      // mangled book blob does not.
      return const [];
    }
  }

  /// Adds [template], replacing any with the same id.
  Future<List<BookTemplate>> save(BookTemplate template) async {
    final existing = await load();
    final next = [
      template,
      ...existing.where((other) => other.id != template.id),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final capped = next.take(limit).toList();
    await _write(capped);
    return capped;
  }

  Future<List<BookTemplate>> delete(String id) async {
    final next = (await load()).where((t) => t.id != id).toList();
    await _write(next);
    return next;
  }

  Future<void> _write(List<BookTemplate> templates) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      storageKey,
      jsonEncode([for (final template in templates) template.toJson()]),
    );
  }
}

/// Book Studio Phase 1 — persistence.
///
/// Book settings are presentation, not story. They are deliberately kept out of
/// the record graph and out of the embedded database:
///
///  * The graph's membership test is participation, not proximity. A copyright
///    page, an ISBN and a trim size are never the endpoint of a link, so making
///    them records would put "Copyright (c) 2026" into Universal Search and
///    write version history every time a margin moved.
///  * `test/story_graph_architecture_test.dart` pins the database's table set,
///    so adding a table here would register as a second persistence system.
///
/// What is left is the mechanism the prose itself already uses: a JSON blob in
/// shared preferences, keyed by project. The key deliberately mirrors
/// `ManuscriptStore`'s own studio key.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'book_document.dart';

class BookStore {
  const BookStore();

  static String storageKey(String projectId) =>
      'author_studio.book_studio.$projectId';

  /// Written once, the first time a book is saved over settings that already
  /// existed, so a bad migration is recoverable.
  static String backupKey(String projectId) =>
      'author_studio.book_studio_backup.$projectId';

  /// Loads the book settings, seeding the defaults on first open.
  ///
  /// Malformed stored JSON returns the defaults rather than throwing, matching
  /// how `ManuscriptStore.loadStudio` treats a corrupt blob: an author whose
  /// preferences got mangled should still be able to open the studio.
  Future<BookProject> load(String projectId) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(storageKey(projectId));
    if (encoded == null || encoded.isEmpty) {
      return BookProject.initial(projectId);
    }
    try {
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      final loaded = BookProject.fromJson(decoded);
      if (loaded.projectId == projectId) return loaded;
      // The blob can carry a different id if a profile was copied between
      // projects. Keep the settings, but re-home them on this project.
      return loaded.withProjectId(projectId);
    } catch (_) {
      return BookProject.initial(projectId);
    }
  }

  /// Persists the book settings.
  ///
  /// This never writes the manuscript's own keys. Book Studio consumes a
  /// manuscript snapshot and must not mutate the source while laying a book out.
  Future<void> save(BookProject book) async {
    final preferences = await SharedPreferences.getInstance();
    final key = storageKey(book.projectId);
    final existing = preferences.getString(key);
    if (existing != null &&
        existing.isNotEmpty &&
        preferences.getString(backupKey(book.projectId)) == null) {
      await preferences.setString(backupKey(book.projectId), existing);
    }
    await preferences.setString(key, jsonEncode(book.toJson()));
  }

  /// Removes the stored settings, leaving the backup in place.
  Future<void> clear(String projectId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(storageKey(projectId));
  }
}

/// Regenerates the layout golden fixtures.
///
/// Deliberately not named `*_test.dart`, so `flutter test` never runs it and
/// cannot silently rewrite the very files it is supposed to be checking. The
/// same reason `test/startup_screens_capture.dart` is named the way it is.
///
///     bash tool/update-book-goldens.sh
library;

import 'dart:io';

import 'package:author_studio_v1/book/book_fonts.dart';
import 'package:flutter_test/flutter_test.dart';

import 'book_golden_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('regenerate', () async {
    BookFontAssets.resetCache();
    final assets = await BookFontAssets.load();
    Directory(goldenDirectory).createSync(recursive: true);

    for (final book in goldenBooks) {
      File(goldenPath(book.name))
          .writeAsStringSync(renderGolden(book, assets));
      stdout.writeln('wrote ${goldenPath(book.name)}');
    }
  });
}

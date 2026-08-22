import 'package:author_studio_v1/main.dart';
import 'package:author_studio_v1/theme/theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the shell registers Book as a section', () {
    expect(StudioSection.values, contains(StudioSection.book));
  });

  test('Book sits directly after Manuscript', () {
    expect(
      StudioSection.values.indexOf(StudioSection.book),
      StudioSection.values.indexOf(StudioSection.manuscript) + 1,
      reason: 'formatting the book is the step after writing it',
    );
  });

  test('inserting Book left the other sections in place', () {
    // Map Studio pins its own position relative to World; Book must not have
    // disturbed anything downstream of it.
    expect(
      StudioSection.values.indexOf(StudioSection.map),
      StudioSection.values.indexOf(StudioSection.world) + 1,
    );
  });

  test('Book carries its own label and icon', () {
    expect(StudioSection.book.label, 'Book');
    expect(StudioSection.book.icon, Icons.import_contacts_outlined);
    // It must wear neither the manuscript's nor the codex's book icon.
    expect(StudioSection.book.icon, isNot(StudioSection.manuscript.icon));
    expect(StudioSection.book.icon, isNot(StudioSection.codex.icon));
  });

  test('every section label is still unique', () {
    final labels = StudioSection.values.map((section) => section.label);
    expect(labels.toSet(), hasLength(StudioSection.values.length));
  });

  test('Book can carry scoped theme tokens like every other studio', () {
    expect(StudioId.book.value, 'book');
  });
}

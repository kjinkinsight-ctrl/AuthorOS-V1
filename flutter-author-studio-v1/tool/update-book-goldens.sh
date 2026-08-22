#!/usr/bin/env bash
#
# Regenerates the Book Studio layout golden fixtures in test/fixtures/books.
#
# Run this ONLY after reading the diff that test/book_golden_test.dart produced.
# A change to a preset, to the break rules, or to the layout engine is supposed
# to rewrite these files — the diff is how a reviewer sees what actually moved.
# Regenerating without looking throws away the only thing the fixtures are for.
#
#   bash tool/update-book-goldens.sh          # rewrite the fixtures
#   bash tool/update-book-goldens.sh --check  # fail if they are out of date
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ "${1:-}" == "--check" ]]; then
  exec flutter test test/book_golden_test.dart
fi

flutter test test/update_book_goldens.dart
echo
echo "Fixtures regenerated. Review the diff before committing:"
echo "  git diff test/fixtures/books"

#!/usr/bin/env bash
#
# Validate an exported book against the official EPUB validator.
#
# The Dart suite in test/book_epub_test.dart asserts the package's structure and
# runs in CI, where only Flutter is installed. It cannot, however, speak for the
# whole specification. EPUBCheck is the reference implementation the retailers
# themselves run, and milestone M7's exit gate is written against it:
#
#     "EPUB passes a standard validator"
#
# This script is how that claim gets checked. It is deliberately not wired into
# .github/workflows/dart.yml: that job installs Flutter and nothing else, and
# adding a Java toolchain to it is a decision worth taking on its own merits
# rather than smuggling in with a feature.
#
# Usage:
#   tool/validate-epub.sh path/to/book.epub
#
# Requires Java and EPUBCheck. The simplest way to get the jar:
#   pip install epubcheck
#
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: $(basename "$0") <file.epub>" >&2
  exit 2
fi

TARGET="$1"

if [ ! -f "$TARGET" ]; then
  echo "No such file: $TARGET" >&2
  exit 2
fi

if ! command -v java >/dev/null 2>&1; then
  echo "Java is required to run EPUBCheck." >&2
  echo "Install a JRE, then: pip install epubcheck" >&2
  exit 2
fi

# Honour an explicit jar, then look where the pip package puts it.
if [ -n "${EPUBCHECK_JAR:-}" ]; then
  JAR="$EPUBCHECK_JAR"
else
  JAR="$(python3 - <<'PY' 2>/dev/null || true
import os.path
try:
    import epubcheck
    print(os.path.join(os.path.dirname(epubcheck.__file__), "epubcheck.jar"))
except Exception:
    pass
PY
)"
fi

if [ -z "${JAR:-}" ] || [ ! -f "$JAR" ]; then
  echo "EPUBCheck was not found." >&2
  echo "Install it with: pip install epubcheck" >&2
  echo "Or point EPUBCHECK_JAR at a downloaded epubcheck.jar." >&2
  exit 2
fi

echo "Validating $TARGET"
echo "Using $JAR"
echo

# EPUBCheck exits non-zero when it finds errors, which is exactly the gate.
java -jar "$JAR" "$TARGET"

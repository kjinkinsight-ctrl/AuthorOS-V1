#!/usr/bin/env bash
#
# Copy the two files drift needs to run SQLite in a browser into web/.
#
# Drift compiles SQLite to WebAssembly for the web and loads it, plus a worker
# that owns the OPFS/IndexedDB storage, from the site root at runtime. Both are
# shipped inside the `drift` package itself, so they are copied out of the
# resolved package rather than downloaded — that keeps them matched to the
# version in pubspec.lock and keeps the build offline-capable.
#
# The files are generated, not authored, so they are git-ignored. Run this
# after `flutter pub get` and before `flutter build web` (the Netlify build
# does exactly that). Run from the Flutter project directory.
set -euo pipefail

PACKAGE_CONFIG=".dart_tool/package_config.json"
WEB_DIR="web"

if [ ! -f "${PACKAGE_CONFIG}" ]; then
  echo "error: ${PACKAGE_CONFIG} not found — run 'flutter pub get' first." >&2
  exit 1
fi

# rootUri is a file: URI relative to .dart_tool/, which is where Dart resolves it from.
DRIFT_ROOT="$(
  python3 - "${PACKAGE_CONFIG}" <<'PY'
import json, os, sys, urllib.parse

config_path = sys.argv[1]
with open(config_path) as handle:
    config = json.load(handle)

for package in config["packages"]:
    if package["name"] != "drift":
        continue
    root = urllib.parse.urlparse(package["rootUri"])
    path = urllib.parse.unquote(root.path)
    if root.scheme != "file":
        # Relative rootUri, resolved against the directory holding package_config.json.
        path = os.path.join(os.path.dirname(config_path), package["rootUri"])
    print(os.path.normpath(path))
    break
else:
    sys.exit("drift is not in package_config.json")
PY
)"

echo "Using drift package at ${DRIFT_ROOT}"

WORKER_SRC="${DRIFT_ROOT}/drift_worker.js"
WASM_SRC="${DRIFT_ROOT}/extension/devtools/build/sqlite3.wasm"

for source in "${WORKER_SRC}" "${WASM_SRC}"; do
  if [ ! -f "${source}" ]; then
    echo "error: expected ${source} to ship with drift but it is missing." >&2
    echo "       If drift changed its layout, take sqlite3.wasm and drift_worker.js" >&2
    echo "       from https://github.com/simolus3/drift/releases instead." >&2
    exit 1
  fi
done

mkdir -p "${WEB_DIR}"
cp "${WORKER_SRC}" "${WEB_DIR}/drift_worker.js"
cp "${WASM_SRC}" "${WEB_DIR}/sqlite3.wasm"

echo "Provisioned:"
ls -l "${WEB_DIR}/drift_worker.js" "${WEB_DIR}/sqlite3.wasm"

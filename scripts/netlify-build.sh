#!/usr/bin/env bash
#
# Provision Flutter and build the AuthorOS web application for Netlify.
#
# Netlify's build image has no Flutter SDK, so this fetches the pinned stable
# release, then runs the ordinary production build. Run from the Flutter
# project directory (netlify.toml sets `base`, so that is already the cwd).
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.47.1}"
FLUTTER_HOME="${FLUTTER_HOME:-$HOME/flutter-sdk/flutter}"
ARCHIVE="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
BASE_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux"

if [ ! -x "${FLUTTER_HOME}/bin/flutter" ]; then
  echo "Provisioning Flutter ${FLUTTER_VERSION}..."
  mkdir -p "$(dirname "${FLUTTER_HOME}")"
  curl -fsSL --retry 4 --retry-delay 2 -o "/tmp/${ARCHIVE}" "${BASE_URL}/${ARCHIVE}"
  tar -xJf "/tmp/${ARCHIVE}" -C "$(dirname "${FLUTTER_HOME}")"
  rm -f "/tmp/${ARCHIVE}"
else
  echo "Reusing cached Flutter at ${FLUTTER_HOME}"
fi

export PATH="${FLUTTER_HOME}/bin:${PATH}"

# The SDK is unpacked fresh each build and is not a checkout Netlify owns.
git config --global --add safe.directory "${FLUTTER_HOME}" || true
flutter --disable-analytics >/dev/null 2>&1 || true

flutter --version
flutter pub get

# Drift runs SQLite as WebAssembly in the browser and loads it from the site
# root; without these two files every Drift-backed Studio fails to open.
bash ../scripts/provision-drift-web-assets.sh

# --no-web-resources-cdn keeps CanvasKit on kjii.info instead of fetching it
# from gstatic.com at runtime, so the site has no third-party dependency to
# render its first frame.
flutter build web --release --no-web-resources-cdn

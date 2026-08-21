# CI pipeline

Reference for how AuthorOS is built and validated by continuous integration,
and which targets CI does and does not cover.

## Repository layout

The Flutter application is **not** at the repository root. The root is a
container:

```
AuthorOS-V1/
├── .github/workflows/        # CI definitions (only workflows here execute)
├── flutter-author-studio-v1/ # the AuthorOS Flutter app — the only pubspec.yaml
│   ├── pubspec.yaml
│   ├── lib/
│   ├── test/
│   └── docs/
└── indiauthors-platform/     # a separate Node/TypeScript workspace
```

There is exactly one `pubspec.yaml` in the repository, at
`flutter-author-studio-v1/pubspec.yaml`. There is no Dart package at the
repository root, and none should be created — running `dart pub get` or
`flutter pub get` from the root is what broke CI historically.

`indiauthors-platform/.github/workflows/w00-guardrails.yml` exists but never
runs: GitHub Actions only discovers workflows in the repository root
`.github/workflows/` directory.

## How the workflow finds the project

`.github/workflows/dart.yml` sets a job-level default:

```yaml
defaults:
  run:
    working-directory: flutter-author-studio-v1
```

This applies to `run` steps only. `actions/checkout` and the Flutter setup
action still execute from the repository root, which is what they expect, while
every Dart/Flutter command runs inside the Flutter project.

## Toolchain

CI pins **Flutter 3.44.9 (stable, Dart 3.12.2)** — the version the repository
already carries, not an upgrade:

| Source | Value |
| --- | --- |
| `.metadata` framework revision | `6b182d2c7585eba26d4edce0f97630effd256c33` = Flutter 3.44.9 stable |
| `pubspec.lock` → `sdks` | `flutter: ">=3.44.0"`, `dart: ">=3.12.0"` |
| `pubspec.yaml` → `environment` | `sdk: ">=3.3.0 <4.0.0"`, `flutter: ">=3.19.0"` |

Note the mismatch: the `environment` block advertises `>=3.19.0`, but the
locked dependency set will not resolve on anything below 3.44.0. The binding
floor is the one in `pubspec.lock`. Pinning CI below it would fail `pub get`.
The stale `environment` block is left as-is; correcting it is a separate change.

When bumping Flutter, update `flutter-version` in the workflow deliberately
rather than switching to a floating channel, so a CI result stays reproducible.

### Lockfile drift

The committed `pubspec.lock` currently pins `meta` 1.19.0, `matcher` 0.12.20,
`test_api` 0.7.12, and `vector_math` 2.4.2. Flutter 3.44.9 — the version CI
pins — constrains those same packages to 1.18.0, 0.12.19, 0.7.11, and 2.2.0,
because the SDK bundles its own versions of them.

So the lockfile was last resolved by a Flutter newer than the one CI runs.
Nothing breaks: `flutter pub get` silently downgrades the four packages in the
runner and the suite passes either way. But it means the lockfile is not a
faithful record of what CI actually builds against, and a local `pub get` on
3.44.9 will show those four lines as modified every time.

Worth reconciling — either bump the CI pin to whatever produced the lockfile, or
re-resolve the lockfile on 3.44.9 — so that the pin and the lockfile agree.

## Steps CI runs

| Step | Command |
| --- | --- |
| Dependencies | `flutter pub get` |
| Static analysis | `flutter analyze --no-fatal-infos --no-fatal-warnings` |
| Tests | `flutter test` |
| Drift web assets | `bash ../scripts/provision-drift-web-assets.sh` |
| Web release build | `flutter build web --release --no-web-resources-cdn` |

The workflow also accepts `workflow_dispatch`, so it can be triggered manually
from the Actions tab without pushing.

Two details of the web build are easy to break by accident:

`provision-drift-web-assets.sh` copies the SQLite WebAssembly module and its
storage worker out of the resolved `drift` package into `web/`. Drift loads both
from the site root at runtime. They are generated, not authored, so they are
git-ignored and must be provisioned after `pub get` and before `build web` —
in CI and in any deploy pipeline alike.

`--no-web-resources-cdn` makes CanvasKit load from our own origin instead of
gstatic.com, matching how the app is actually deployed. Dropping the flag
produces a build that works locally and then reaches for a third-party CDN in
production.

### Why analysis uses `--no-fatal-infos --no-fatal-warnings`

The gate for this project is **zero analyzer errors**. The tree meets that, but
it also carries a standing backlog of warnings and lint infos — hygiene debt
accumulated across many changes rather than introduced by any one of them.

Bare `flutter analyze` exits non-zero on infos and warnings too, so it would
fail CI despite there being no errors. The flags make the exit status track the
actual gate. Every issue is still printed in full to the CI log, so the debt
stays visible rather than hidden.

Paying that debt down is worthwhile, but it belongs in its own change. Tightening
to `--fatal-warnings` is the natural follow-up once the backlog is cleared.

`analysis_options.yaml` additionally excludes `tool/storage_benchmark.dart` and
its generated counterpart — standalone benchmark tooling that imports
`package:isar_community`, which is no longer a dependency.

## Targets CI does not cover

### Linux desktop

`flutter build linux --release` is **not** run in CI.

The target itself works. It was verified successfully against this tree on
Ubuntu 24.04 with Flutter 3.44.9, producing
`build/linux/x64/release/bundle/author_studio_v1`.

It is excluded only because the GitHub-hosted `ubuntu-latest` image does not
ship the GTK 3 development libraries that `flutter build linux` needs. Enabling
it means installing system packages on the runner:

```yaml
      - name: Install Linux desktop dependencies
        run: sudo apt-get update && sudo apt-get install -y ninja-build libgtk-3-dev

      - name: Build Linux (release)
        run: flutter build linux --release
```

That adds install time to every run, so it is a deliberate decision to make
rather than an automatic one.

### Android, iOS, macOS, Windows

Not built in CI. Android and iOS need SDK provisioning and signing material;
macOS and Windows need non-Linux runners.

### Integration and golden tests

CI runs the full `flutter test` suite (unit and widget tests). There is no
`integration_test/` directory in the repository, so no driver tests run.

## Other workflows

`.github/workflows/generator-generic-ossf-slsa3-publish.yml` is an unmodified
SLSA provenance starter template. It triggers only on `workflow_dispatch` and on
release creation, so it does not participate in push/PR CI.

It has never been customised: its build step still emits placeholder files
(`echo "artifact1" > artifact1`), and its `hash` step writes an output named
`hashes` while the job declares its output as `digests`, so `digests` resolves
empty. It would need real artifacts and a corrected output name before it could
produce meaningful provenance.

## Reproducing CI locally

From the repository root:

```bash
cd flutter-author-studio-v1
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
bash ../scripts/provision-drift-web-assets.sh
flutter build web --release --no-web-resources-cdn
```

All of these should succeed: `pub get` resolves cleanly, `analyze` reports zero
errors (warnings and infos are expected — see above), the full test suite passes
with nothing skipped, and the web build completes.

Skipping the drift provisioning step still produces a build, but one that fails
at runtime in the browser when it tries to load the SQLite module.

Exact test and lint counts are deliberately not recorded here; they change with
every feature branch and a pinned number in a doc rots immediately. Read them
from the CI log for the commit you care about.

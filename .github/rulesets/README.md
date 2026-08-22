# Rulesets

Importable branch protection for the two trunks described in `BRANCHING.md`.
GitHub has no way to apply these from inside the repository — a ruleset is
account state, not repository content — so they have to be uploaded once.

## Importing

For each file: **Settings → Rules → Rulesets → New ruleset → Import a ruleset**,
choose the file, then **Create**.

| File | Applies to |
| --- | --- |
| `main-release-trunk.json` | `main` |
| `debug-integration-trunk.json` | `debug/base` |

Both take effect immediately on creation. To take one off temporarily, set its
enforcement to *Disabled* in the UI rather than deleting it.

## What each one does

Both trunks require a pull request and a passing `build` check, and neither can
be deleted. `build` is the job name in `.github/workflows/dart.yml`; if that job
is ever renamed, the required check here has to be renamed with it or merges
will block on a check that never reports.

`main` additionally blocks force pushes (`non_fast_forward`). The release tree
is what deploys and what tags point at, so its history must not move under
anyone. `debug/base` deliberately does not carry that rule: it is an
integration line, and being able to reset it is occasionally the cheapest way
out of a bad merge.

The two also differ on strictness:

- **`main` requires the branch to be up to date before merging**
  (`strict_required_status_checks_policy: true`). A promotion is the last gate
  before deploy, so it should be tested against exactly what it will become.
- **`debug/base` does not.** Thirteen family trunks merge into it; requiring
  each to be current would mean re-running the suite on every one of them every
  time any other landed.

## What they deliberately leave open

`required_approving_review_count` is **0** on both. The gate is CI and the pull
request itself, not a second person — on a single-developer repository a
review requirement blocks every merge with nobody able to satisfy it. Raise it
if that changes.

`bypass_actors` is empty, so the rules apply to everyone including the
repository owner. Adding yourself as a bypass actor would let a stray
`git push` reach `main` directly, which is the thing these rulesets exist to
prevent.

The family trunks (`debug/*/base`) are **not** protected. Adding a ruleset over
`refs/heads/debug/*/base` would enforce the same PR gate one level lower, at the
cost of no longer being able to advance a family trunk by re-pointing it. Worth
doing once the layout has settled; not while it is still moving.

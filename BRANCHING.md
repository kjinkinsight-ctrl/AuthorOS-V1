# Branching

AuthorOS is developed on two long-lived trees with identical layouts. Work
lands on the debug tree first and is promoted to the release tree once it is
finished. Nothing is ever committed straight to a trunk.

## The two trunks

| Tree | Trunk branch | What lives there |
| --- | --- | --- |
| Release | `main` | Finished, signed-off work only. Tagged on each promotion. Deploys to kjii.info. |
| Debug | `debug/base` | The integration line. Everything arrives here first. |

`main` is the release tree. It keeps that name rather than being renamed to
`release` because it is already GitHub's default branch, the base of every
existing pull request, and the branch Netlify treats as production; renaming it
would mean re-pointing all three for no behavioural gain.

## Branch families

Each tree carries the same set of families: one per studio, plus `core` for the
shared app layer (records, persistence, theme, navigation, startup), `platform`
for `indiauthors-platform/`, and `ci` for the workflow and build pipeline. The
debug tree prefixes them `debug/`, the release tree `rel/`.

```
debug/base                         main
├── debug/map-studio/base          ├── rel/map-studio/base
├── debug/manuscript-studio/base   ├── rel/manuscript-studio/base
├── debug/timeline-studio/base     ├── rel/timeline-studio/base
├── debug/world-studio/base        ├── rel/world-studio/base
├── debug/character-studio/base    ├── rel/character-studio/base
├── debug/plot-studio/base         ├── rel/plot-studio/base
├── debug/research-studio/base     ├── rel/research-studio/base
├── debug/analytics-studio/base    ├── rel/analytics-studio/base
├── debug/story-codex/base         ├── rel/story-codex/base
├── debug/core/base                ├── rel/core/base
├── debug/platform/base            ├── rel/platform/base
└── debug/ci/base                  └── rel/ci/base
```

Work that belongs to no family — a repository-wide audit, a document about the
tree as a whole — goes straight to a pull request against `debug/base`.

Individual pieces of work branch off a family trunk and sit beside it:

```
debug/map-studio/base
├── debug/map-studio/visuals
├── debug/map-studio/linking
└── debug/map-studio/export
```

### Why every trunk ends in `/base`

Git stores a branch as a file at `.git/refs/heads/<name>`, so a name cannot be
both a file and a directory. A branch called `debug/map-studio` and a branch
called `debug/map-studio/visuals` cannot coexist — creating the second fails
once the first exists. The `/base` suffix keeps `map-studio` a directory, so a
family trunk and its work branches live together.

The same rule applies one level up, which is why the debug trunk is
`debug/base` and not a plain `debug`: a branch named `debug` would block every
`debug/...` branch beneath it. Naming it `debug/base` also puts the entire tree
inside a single `debug/` folder in GitHub's branch list, which is what makes the
two trees read as trees.

## Flow

```
debug/map-studio/visuals ─PR▶ debug/map-studio/base ─PR▶ debug/base ─PR▶ main
      a piece of work                the studio           integration    release
```

Promote with a merge commit and tag `main` (`v0.5.0`, …) on arrival.

### The gate is entry to `debug/base`, not exit from it

Once several studios' work sits on `debug/base`, a merge to `main` takes all of
it — there is no way to merge one studio and leave the others behind. Pulling a
single studio out means cherry-picking, which copies commits rather than moving
them and produces repeated conflicts every time the two trees meet again.

So the decision point is **"is this ready to enter `debug/base`?"**, not "is
this ready to leave it?". Work that is not finished stays parked on its
`debug/<family>/base` branch for as long as it needs. `debug/base` stays a
clean, always-promotable line, and `debug/base → main` is simply "ship what is
baked".

### Hotfixes

A fix that has to go straight onto `main` is merged back down into `debug/base`
immediately afterwards. Skipping this is what makes two trees drift apart.

## The `rel/*` family branches

The release tree mirrors the debug layout so both trees read the same in the
branch list, and so a shipped studio can be patched without dragging in newer
debug work. They track `main` and are not developed on directly.

## What CI runs where

`.github/workflows/dart.yml` gates the flow:

- **push** to `main` or `debug/base` — the trunks are verified on every arrival.
- **pull request** into `main`, or into any `debug/**` or `rel/**` branch — so a
  broken studio branch is caught at its own family trunk, long before it reaches
  `debug/base`.

Pushes to work branches deliberately do not build. The job runs `flutter
analyze`, `flutter test` and a release web build; running that on every commit
of in-progress work costs more than it catches, and the pull request into the
family trunk covers the same ground.

## Settings that live outside this repository

Two parts of the model are dashboard settings and have to be set by hand.

**Branch protection** (GitHub → Settings → Branches):

- `main` — require a pull request, require the `build` check to pass, block
  force pushes and deletion.
- `debug/base` — require a pull request, require the `build` check to pass.

**Netlify branch deploys** (Site configuration → Build & deploy → Branches):
set branch deploys to *Let me add individual branches* and add `debug/base`
only. Leaving it on "all branches" would build every family and work branch in
the repository on every push.

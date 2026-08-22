# AuthorOS Web Community — Repository Reconciliation

Companion to `authoros-web-community-directive.md`.

| Field | Value |
| --- | --- |
| Status | Findings for review — no implementation performed |
| Verified against | commit `c9ae671` (merge of PR #22) |
| Date | 21 August 2026 |

The directive is a planning document written ahead of the code. This document records what
the repository actually contains today, so that acceptance is a decision made against real
state rather than an assumption. Every finding cites a file and line.

Directive §59 requires conflicts to be reported rather than silently resolved. Findings
(**F**) are observations. Conflicts (**X**) are points where the directive and the
repository cannot both be right, and which need a decision before Community Phase C1
begins.

---

## Findings

### F1 — A `publicProfile` flag already exists, and it defaults to public

`flutter-author-studio-v1/lib/release_destinations.dart:2695` declares:

```dart
bool publicProfile = true;
```

It is persisted at line 2882 and surfaced at line 3465 as a switch titled
"Public profile visibility", with the subtitle "Allow your author profile to appear in
shared previews."

Two problems:

1. **It is a single boolean.** Directive §43 says not to collapse `CanView`, `CanDiscover`,
   `CanShare`, `CanPublish`, `CanUnpublish` and `CanEditPublication` into one `isPublic`
   flag. This flag is exactly that shape, and it is already shipped in the UI.
2. **It defaults to `true`.** Directive I-C2 requires privacy by default. If this flag is
   ever wired to a publication backend as-is, every existing author becomes public without
   ever having chosen to publish.

Today the flag has no backend and controls nothing outside the settings screen, so nothing
leaks. The risk is that C1 adopts it as "the profile visibility control we already have".

**Recommendation:** C1 must not reuse this flag. Either retire it, or redefine it as a local
preference with no publication meaning, and introduce publication visibility as a separate,
default-private, server-enforced concept.

### F2 — Private project payloads already reach a cloud database

`flutter-author-studio-v1/lib/sync/project_sync_service.dart` queues every project save and
uploads it to Supabase. `flutter-author-studio-v1/supabase/schema.sql` defines:

- `public.projects` with `payload jsonb`
- `public.sync_records` with `payload jsonb`

Both have row-level security enabled, with policies scoped to `auth.uid() = user_id`.

This means directive §53's public/private cloud separation is not being designed on a blank
page. Private creative data is already in a cloud database, in a schema whose tables live in
the Postgres schema literally named `public`.

The concrete hazard: if public projections are later added to the same Supabase project, a
single permissive `select` policy — or one table without RLS — exposes whole private project
payloads to anonymous readers. Directive §52 is explicit that the boundary must be enforced
at the data layer, not the UI.

**Recommendation:** record as a hard rule before C1 that no anonymous or public-role read
policy may ever be attached to `projects` or `sync_records`, and that public projections
live in their own tables (ideally their own schema or their own project) that never contain
a private payload column.

### F3 — Supabase URL and publishable key are committed defaults

`flutter-author-studio-v1/lib/supabase_service.dart:10-12` hardcodes a project URL and a
`sb_publishable_…` key as compile-time defaults.

A publishable key is designed to be shipped to clients, so this is not a credential leak on
its own. It does mean the entire security boundary of the cloud data rests on RLS policies:
anyone with the app binary can address that Supabase project directly. That raises the cost
of any future policy mistake described in F2, and it is worth stating plainly in the C1
security review rather than discovered later.

### F4 — There is no "three-tier responsive shell" to build on

The original directive's §20 and status table assume a responsive web shell already in
development.

`indiauthors-platform/apps/site/components/site-shell.tsx` is a 27-line wrapper: a topbar
with a nav list, `<main>`, and a footer. A search for `responsive` across
`flutter-author-studio-v1/lib` and `indiauthors-platform/apps` matches only
`lib/main.authorstudio.backup.dart`, a backup file.

Routing does exist — the Next.js app router with `/`, `/authoros`, `/explore`, `/features`,
`/roadmap`, `/pricing`, `/downloads`, `/account` — so §19's route architecture has a real
foundation. The shell does not.

**Recommendation:** C1 should treat responsive shell work as in scope, not as a dependency
that is already satisfied. §61 of the directive has been corrected to reflect this.

### F5 — Three identity systems exist, none of them is a public author identity

1. **Local profiles.** `flutter-author-studio-v1/lib/author_profile_store.dart` defines
   `AuthorProfile` (display name, pen name, email, genres, goals, region, avatar) stored in
   `shared_preferences`. Several writing identities can exist on one machine.
2. **Supabase Auth.** `lib/supabase_service.dart`, used for sync and Google OAuth.
3. **Platform OIDC skeleton.** `indiauthors-platform/apps/api/src/domain/auth.ts` —
   `AUTH_MODE` defaults to `disabled`, and every capability except logout is gated on
   `integrationReady`. This is the platform's W08 milestone, not yet built.

Directive §32 says to reuse authentication infrastructure rather than create a competing
version. With three candidates, "reuse" is ambiguous, and §21's authentication boundary
cannot be settled without choosing one.

Note also that the local `AuthorProfile` already carries most of §6's identity fields but
has no username/handle — and §19's `/author/{username}` route requires a globally unique
handle, which is inherently a server-side concern and cannot be derived from a local
profile.

**Recommendation:** the C1 architecture milestone must name which system owns public author
identity, and how the local profile relates to it. This is the single largest open decision.

### F6 — `/explore` already exists and means something else

`indiauthors-platform/apps/site/app/explore/page.tsx` is the W05 interactive product demo —
"a browser-based simulation of AuthorOS workflows". `lib/product-discovery.ts` and
`apps/api/src/domain/product-discovery.ts` implement *product* feature/roadmap discovery,
not author or world discovery.

Directive §39 lists "Discover" as a community page type and §17 defines discovery over
authors, projects and worlds. These are different things sharing a word.

**Recommendation:** C4 must not reuse `/explore` or the `product-discovery` modules. Reserve
distinct routes and distinct naming.

### F7 — "Visibility" already has three unrelated meanings in the codebase

| Meaning | Location |
| --- | --- |
| Narrative knowledge visibility — who in the story knows a fact | `lib/core/story_codex_domain.dart:25` — `enum CodexFieldVisibility { publicKnowledge, privateKnowledge, authorKnowledge }` |
| Author-only record fields — e.g. a character's `secrets` table | `lib/core/world_record_types.dart:303` — `extensionData: {'visibility': 'author'}` |
| Map marker visibility on a map layer | `lib/core/world_record_types.dart:620` — a `visibility` field on the map-marker record type |

Directive §8 introduces a fourth: publication visibility (`PRIVATE` / `UNLISTED` /
`PUBLIC`).

The collision that matters is `CodexFieldVisibility.publicKnowledge`. It means "the
characters in this story know this", not "this may be shown on the internet". A future
publication projection that treats `publicKnowledge` as a publish signal would leak
in-world lore the author never chose to publish, while satisfying a naive reading of the
field name.

**Recommendation:** publication visibility must use its own vocabulary (e.g.
`publicationState`) and must never be inferred from any existing `visibility` field. Add
this to the C1 guardrails.

### F8 — World Board is a service-backed internal dashboard, as the directive assumes

`flutter-author-studio-v1/lib/world_board/` contains `world_board_models.dart`,
`world_board_sections.dart`, `world_board_service.dart` and `world_board_view.dart`. It is
an internal workspace, consistent with directive §4 and §31. No conflict — recorded so the
assumption is verified rather than assumed.

---

## Conflicts requiring a decision

### X-1 — The in-force Story Graph directive forbids starting Community work

`flutter-author-studio-v1/docs/story-graph-phase-0-integrity-directive.md:46` states, under
HARD RULES / DO NOT:

> Do not start Map Phase 3, Community, publishing, or further Analytics features.

Directive §47 says the Community project does not block on Story Graph Phase 0.

These are compatible only if §47 is read as an *architectural* independence claim (the
community design does not require the graph) rather than a *scheduling* permission (work may
start now). Recording this directive is planning, so nothing is violated today. Beginning C1
would violate the Story Graph directive as written.

**Decision required:** either amend the Story Graph Phase 0 directive to carve out Community
Phase C1, or sequence C1 after Story Graph Phase 0 completes. §47 of the directive has been
annotated to point here rather than resolving this unilaterally.

### X-2 — Which project hosts AuthorOS Web?

The directive says "AuthorOS Web" throughout without naming a codebase. The repository has
two candidates:

- `indiauthors-platform` — the commercial platform (Next.js site + Fastify-style API,
  W00–W18 gates, ADR-0001/0002 boundaries). It has SSR, routing, an API tier, and a planned
  identity system.
- `flutter-author-studio-v1/web/` — a Flutter web build target of the desktop application.

Directive §38 is decisive against the second option: "A public author profile should not
need to boot every Studio." A Flutter web build of AuthorOS boots the application.

This document therefore assumes `indiauthors-platform` hosts the community layer, and the
directive has been filed in its `docs/architecture/`. **This assumption needs explicit
confirmation**, because it also means the community layer inherits ADR-0001's boundary and
ADR-0002's split topology, and must be reconciled with the W-gate roadmap.

### X-3 — Community milestones versus platform milestones

Directive §60 requires the community initiative to be tracked separately from other AuthorOS
work. `indiauthors-platform/docs/architecture/milestone-gates.md` already defines W00–W18
for the same web project, and W08 (accounts) and W14 (admin) overlap with community identity
and moderation.

The directive's phases have been recorded as **C0–C8** so the two tracks cannot be confused
by number. Whether the community track runs in parallel with the W gates, or after a
specific gate (W08 accounts being the natural predecessor given F5), is unresolved.

**Decision required:** the ordering relationship between C1 and W08.

### X-4 — §61's original status table was optimistic

The original status table marked the web responsive shell and web URL routing as "in
progress". Routing is real; the responsive shell is not (F4). The table recorded in §61 of
the filed directive has been corrected against the repository and each row now cites what it
was verified against.

This is flagged rather than silently changed because a status table is a planning input:
anyone estimating C1 from the original table would assume a shell exists.

---

## What acceptance would authorise

Acceptance of the directive authorises **nothing to be built**. It fixes the architecture
and makes C1 the next milestone to be *specified*.

Before C1 implementation could begin, the following must be resolved:

1. X-1 — Story Graph Phase 0 sequencing.
2. X-2 — confirmation that `indiauthors-platform` hosts the community layer.
3. X-3 — the C1/W08 ordering relationship.
4. F5 — which system owns public author identity, and how handles are allocated.
5. F1 — the disposition of the existing `publicProfile` flag.
6. F2 — the cloud data-boundary rule for public projections alongside existing private sync
   tables.

# AuthorOS — Web Community & World Board Master Architecture Directive

| Field | Value |
| --- | --- |
| Status | Master planning directive — **awaiting acceptance** |
| Scope | Web-only Community & Public World layer |
| Platform | AuthorOS Web |
| Relationship to desktop AuthorOS | Complementary, not a replacement |
| Implementation status | Planning only — **no implementation authorised by this document** |
| Priority | Future strategic architecture |
| Date | 21 August 2026 |

Companion documents:

- `authoros-web-community-reconciliation.md` — what this directive assumes versus what the
  repository actually contains, and the conflicts that must be resolved before acceptance.
- `ADR-0003-community-publication-boundary.md` — the decision record for the boundary this
  directive establishes.

Nothing in this document is implemented. No section should be read as describing existing
behaviour unless it is explicitly marked otherwise.

---

## 0. Directive purpose

This document establishes the architectural boundary and long-term design for the AuthorOS
Web Community & World Board.

The purpose is to fix a stable architecture **before implementation begins**, preventing
community functionality from becoming entangled with:

- the desktop AuthorOS application
- private creative data
- the Universal Story Graph
- manuscript persistence
- local authoring workflows
- Map Studio's internal persistence
- Analytics' private historical data
- future social features

The directive deliberately separates:

> **AuthorOS as the place where authors create**
>
> from
>
> **AuthorOS Web as the place where authors choose to present, discover and eventually
> share that creation.**

---

## 1. Core product vision

AuthorOS ultimately consists of two complementary experiences.

### 1.1 AuthorOS creative application

The private authoring environment.

```text
AUTHOROS DESKTOP
│
├── Manuscript Studio
├── Plot Studio
├── Character Studio
├── Timeline Studio
├── Research Studio
├── Map Studio
├── World Board
├── Story Graph
├── Analytics
└── Project Management
```

Its primary purpose is **CREATE**.

### 1.2 AuthorOS Web

The public-facing and community-facing environment.

```text
AUTHOROS WEB
│
├── Author Profiles
├── Project Showcase
├── World Showcase
├── Map Showcase
├── Discovery
├── Public Statistics
├── Following
└── Future Community
```

Its primary purposes are **PRESENT**, **DISCOVER**, **SHARE**, **CONNECT**.

---

## 2. Fundamental architectural principle

**The web layer must never become the source of truth for private creative work.**

The author's primary project remains authoritative. The web receives published public
representations of that work.

```text
PRIVATE AUTHOROS PROJECT
          │
          │ Publish
          ▼
   PUBLIC REPRESENTATION
          │
          ├── Author Profile
          ├── Project Showcase
          ├── World Showcase
          ├── Map Showcase
          └── Selected Statistics
```

The public representation is a **publication layer**, not a second authoring database.

---

## 3. Browser-only decision

The Community & Public World layer is **web-first / browser-only**.

The desktop application does not become a social-media client. Desktop users create, write,
plan, research, build worlds, create maps, analyse writing, and publish selected content.
The web application handles public profiles, discovery, showcase pages, community
interaction, public statistics, public worlds, and future social functionality.

This separation is intentional.

---

## 4. Current World Board boundary

The existing World Board is **not** the community platform. It is the author's internal
world/project dashboard.

```text
CURRENT WORLD BOARD  =  PRIVATE AUTHOROS CREATIVE WORKSPACE
WEB WORLD BOARD      =  PUBLIC / COMMUNITY WORLD DISCOVERY
```

The internal World Board may eventually supply source material for a public World Showcase.
It must not be transformed into a social network in order to achieve that.

---

## 5. Community layers

The web experience is built progressively.

| Layer | Name | Contents |
| --- | --- | --- |
| 1 | Identity | Author |
| 2 | Publication | Project, World, Map |
| 3 | Discovery | Search, browse, genres, authors, projects, worlds |
| 4 | Social | Follow, like, comment, interact |
| 5 | Community | Groups, challenges, events, recommendations, activity |

Only layers 1–3 are early implementation scope. Layers 4–5 remain future opportunities.

---

## 6. Author profile

The eventual public Author Profile supports:

**Identity** — display name, username / public handle, profile image, biography, location if
voluntarily supplied, website, selected social links.

**Creative information** — genres, writing interests, current projects, completed projects,
published projects, featured world.

**Public statistics** — potentially projects, completed books, words written, writing
streak, writing sessions, milestones.

However:

> **Statistics must be explicitly publishable.** Private Analytics data must never
> automatically become public.

---

## 7. Public project

A Project Showcase represents a project the author has deliberately made public.

```text
PublicProject
├── id
├── authorId
├── title
├── subtitle
├── description
├── cover
├── genre
├── status
├── publicationStatus
├── tags
├── featured
├── visibility
├── publishedAt
└── updatedAt
```

This is a public representation. It is not a replacement for the private AuthorOS project.

---

## 8. Project visibility

Visibility is explicit. The initial model is:

| Value | Meaning |
| --- | --- |
| `PRIVATE` | Only the author can access it. |
| `UNLISTED` | Reachable through a deliberate share mechanism, never surfaced by discovery. |
| `PUBLIC` | Eligible for public profile pages and discovery. |

This distinction must exist before community functionality is built.

---

## 9. Public world

A World Showcase represents a world the author chooses to present publicly.

```text
PublicWorld
├── author
├── title
├── description
├── cover
├── genre
├── tags
├── featured
├── locations
├── maps
├── characters
├── timeline highlights
├── lore
└── projects
```

Not everything in the private world appears automatically. The author chooses what becomes
public.

---

## 10. Public maps

Maps can eventually become public showcase objects, providing map image, title, description,
world, selected locations, author, and optional interactive elements.

A public map is a **presentation representation**. It must not directly expose the private
Map Studio persistence model.

---

## 11. Public Story Graph

The Universal Story Graph will eventually power public relationships.

> **The Community layer must not require Story Graph completion to begin.**

Eventually a public world could expose relationships such as:

```text
Character
   │
   ├── belongs to → House
   ├── lives in → Location
   ├── appears in → Book
   └── connected to → Character
```

This is a future integration. The public layer must initially operate without the graph.

---

## 12. Universal Story Graph boundary

The Story Graph remains a creative-domain read model. The Community layer consumes selected
published graph information.

It must not:

- create a second graph
- create a second relationship model
- replace `ConnectionEngine`
- create community-specific graph edges
- modify private graph truth merely for public display

```text
AUTHOROS CREATIVE DATA
          ▼
UNIVERSAL STORY GRAPH
          ▼
PUBLICATION PROJECTION
          ▼
    AUTHOROS WEB
```

---

## 13. Publication projection

This is one of the most important concepts in the directive. The web receives a
**projection** of private data.

Private record:

```text
Private Character
Name: Seraphina Voss
Private Notes: ...
Secrets: ...
Unpublished Relationships: ...
Research: ...
```

Public projection:

```text
Seraphina Voss
High Fae detective
Aurelia Major Crimes
Featured character
```

The private record remains private.

---

## 14. No private-data leakage

The publication layer must explicitly prevent accidental exposure of: manuscript prose,
private notes, unpublished scenes, private research, hidden characters, secret
relationships, draft maps, unpublished locations, private analytics, audit history,
writing-session history, internal IDs where inappropriate, and private project metadata.

Publication must be intentional.

---

## 15. Writing analytics

AuthorOS already has private writing analytics. The community layer may eventually expose
selected metrics: books completed, words written, writing streak, projects, milestones.

The default is **PRIVATE**. Authors explicitly opt into public statistics.

Writing sessions remain historical/operational data and are **not** Story Graph entities.

---

## 16. Community statistics

Community statistics derive from public/published information. They must not query private
Analytics data directly.

```text
PRIVATE ANALYTICS
       │  opt-in publication
       ▼
PUBLIC AUTHOR STATISTICS
```

---

## 17. Discovery

The web experience should support discovery of authors (browse, search, genre, interests,
featured), projects (books, series, projects, genres, tags, status), and worlds (by genre).

Discovery operates only against publicly published data.

---

## 18. Search

Public search should eventually cover author, project, world, character, location, genre and
tag.

Private AuthorOS search remains separate. The public search index must never become an index
of private creative data.

---

## 19. URL architecture

Human-readable URLs:

```text
/author/{username}
/project/{projectSlug}
/world/{worldSlug}
/map/{mapSlug}
```

Future:

```text
/author/{username}/projects
/author/{username}/worlds
/world/{worldSlug}/characters
/world/{worldSlug}/locations
```

These routes are introduced through the web application's routing architecture rather than
scattered manual URL handling.

---

## 20. Responsive design

The community experience must be desktop, tablet and mobile compatible, and both keyboard
and touch accessible.

The responsive shell architecture of the web application is the foundation. No separate
mobile application is required for the community layer initially.

---

## 21. Authentication

Authentication belongs to the web/community boundary.

```text
Anonymous visitor ──► Public content

Authenticated author
       ├── Profile
       ├── Published projects
       ├── Published worlds
       └── Community features
```

Authentication must not imply that every private desktop project becomes cloud-visible.

---

## 22. Private projects and cloud data

A cloud-backed publication system must distinguish private creative data from public
published data.

The system must never treat:

> "User has logged in"

as equivalent to:

> "User has published their project."

Those are completely different states.

---

## 23. Publication workflow

```text
AuthorOS Desktop
       ▼
    Publish
       ▼
 Choose Content ── Project / World / Map / Characters / Statistics
       ▼
    Preview
       ▼
    Confirm
       ▼
    Publish
       ▼
 AuthorOS Web
```

The author must know exactly what is being published.

---

## 24. Unpublishing

Publication is reversible: publish, unpublish, update, republish.

Unpublishing removes the public representation while preserving the author's private
project.

---

## 25. Versioning

Public content may eventually need publication versions.

```text
Private Project
       ├── Draft 1
       ├── Draft 2
       └── Draft 3
                ▼
        Published Snapshot
```

Changing a private draft must not automatically modify the public page.

---

## 26. Community features — future only

The architecture may eventually support following, likes, comments, recommendations,
notifications, activity feeds, challenges, writing events, groups, collaborative
communities, author discovery and reader interaction.

None of these should be implemented merely because the architecture allows them.

---

## 27. Social safety / moderation

Before social interaction launches, the architecture must account for blocking, reporting,
moderation, content removal, abuse prevention, privacy, account controls, community
guidelines, and administrative moderation.

Social features must **not** be implemented before these concerns have their own
architecture.

---

## 28. Marketplace

This directive does **not** authorise selling books, maps, templates, assets or
commissions, nor creator payments, subscriptions or marketplace transactions. Those require
a separate architecture.

---

## 29. Community does not own AuthorOS

The community layer remains an extension of AuthorOS, not the product's architectural
centre.

```text
CREATE → ORGANISE → PUBLISH → SHARE → CONNECT
```

not:

```text
SOCIAL NETWORK → try to become a writing app
```

---

## 30. Data ownership principle

The author's creative work belongs to the author's project. Community functionality operates
through explicit publication and permission.

Never design a feature around "we'll just expose whatever is already in the database".
Design it around "what does the author explicitly want to publish?".

---

## 31. Current World Board → future web World Board

```text
CURRENT
World Board
└── Internal author workspace

FUTURE
World Board
├── Internal World Board
└── Public World Showcase
```

These are related experiences, not the same component.

---

## 32. Architectural reuse

The web community layer reuses existing AuthorOS architecture where appropriate: Theme
Engine, universal record model, connection architecture, project identity, Story Graph read
layer, Map Studio representations, Analytics public projections, authentication
infrastructure, the existing web shell, and routing architecture.

Do not create competing versions merely because the web has different screens.

---

## 33. No second Story Graph

Hard invariant. The community system must not create `CommunityGraph`, `SocialGraph`,
`PublicGraph` or `WorldGraph` as alternative representations of creative relationships.

There is one Universal Story Graph with public/private projections.

Social relationships such as "Author A follows Author B" are different from creative
relationships and may exist separately.

---

## 34. No second record system

The community layer must not invent `CommunityRecord`, `PublicRecord` or `WebRecord` unless
a future architecture review explicitly establishes a justified need.

Public entities are projections/publication models over canonical AuthorOS data.

---

## 35. No second map system

Public maps consume Map Studio output. Do not create a separate web mapping engine unless a
later architectural decision proves it necessary.

---

## 36. No second analytics system

Private Analytics remains responsible for authoring metrics. The community layer consumes
deliberately published statistics. No competing word-count implementation, writing-session
tracker or productivity engine.

---

## 37. No second search index for private data

Public search may have its own infrastructure when required. It indexes only public
projections. Private search remains private.

---

## 38. Web performance

The community layer is designed for fast first render, low asset payload, responsive
navigation, image optimisation, lazy loading, progressive content loading and accessible
fallback states.

Public pages must not require loading the entire AuthorOS desktop application. A public
author profile must not need to boot every Studio. This is particularly important.

---

## 39. Web page types

Initial: Landing, Author, Project, World, Map, Search, Discover, Login, Account.

Later: Feed, Notifications, Following, Community, Groups, Challenges.

---

## 40. Public world page

```text
┌─────────────────────────────────────┐
│             WORLD COVER             │
│              ENDOVIER               │
│              by Author              │
└─────────────────────────────────────┘

Overview   Characters   Locations
Maps       Timeline     Books      Lore

[ Explore World ]
```

This should feel like a beautiful world showcase, not a database dump.

---

## 41. Public project page

```text
┌──────────────┐
│    COVER     │
└──────────────┘

House of Shadows & Saints
by Author

Genre · Status · Series
Description
World · Characters · Maps

[ Author Profile ]   [ Explore World ]
```

The author controls which sections exist.

---

## 42. Public author page

```text
AUTHOR
Profile · Bio · Genres
Featured Project
Projects · Worlds · Maps
Public Statistics
Follow
```

Only deliberately public information appears.

---

## 43. Publication permissions

The system should distinguish `CanView`, `CanDiscover`, `CanShare`, `CanPublish`,
`CanUnpublish` and `CanEditPublication`.

Do not collapse these into a single `isPublic` flag if the product grows beyond simple
publication.

---

## 44. Author control

The author must always be able to answer:

> What is public? Who can see it? What information is displayed? Can people discover it?
> Can people interact with it?

This is a central UX principle.

---

## 45. Community feature flags

Community functionality is independently controllable: `publicProfiles`, `publicProjects`,
`publicWorlds`, `publicMaps`, `publicStatistics`, `discovery`, `following`, `comments`,
`likes`, `notifications`, `groups`, `challenges`.

Do not activate future functionality simply because its code exists.

---

## 46. Development phases

The community track is numbered **C0–C8** so it never collides with the platform's W00–W18
milestone gates (see §60).

| Phase | Name | Contents |
| --- | --- | --- |
| C0 | Architecture | This directive, data boundaries, publication model, privacy model, authentication boundary, routing, public projections. Planning only. |
| C1 | Public identity | Web author identity, public profile, profile editing, privacy controls, profile URL, public profile page. |
| C2 | Project publishing | Public project model, publication, preview, visibility, public project page, unpublish. |
| C3 | World publishing | World publication, world showcase, public locations, public maps, public characters, world/project relationships. |
| C4 | Discovery | Search, browse, genres, tags, featured authors/projects/worlds. |
| C5 | Public statistics | Opt-in statistics, achievements/milestones, writing history summaries, public project statistics. |
| C6 | Social | Follows, likes, comments, activity, notifications. Future. |
| C7 | Community | Groups, challenges, events, collaborative activities, community discovery. Future. |
| C8 | Marketplace | Separate architecture required. |

---

## 47. Story Graph dependency

The Community project does not block on Story Graph Phase 0 for its own architecture.

- C1–C2 can proceed without the Story Graph.
- C3 may use existing record relationships.
- Advanced World Showcase should integrate with the Universal Story Graph once the graph
  read layer is stable.

```text
Community C0 ──► Community C1
             └─► Community C2

Story Graph Phase 0
       ▼
Story Graph Read Layer
       ▼
Advanced World Showcase
```

This is an architectural dependency statement, not a scheduling permission. See conflict
**X-1** in the reconciliation document: the in-force Story Graph Phase 0 directive currently
forbids starting Community and publishing work, and that sequencing must be resolved
explicitly before C1 begins.

---

## 48. Currently out of scope

Explicitly **not** authorised: full social network, messaging, direct messaging,
marketplace, payments, subscriptions, reader accounts, book purchasing, public manuscript
hosting, collaborative editing, public access to private notes, automatic publishing,
automatic statistics publication, public writing sessions, public audit history, public
version history, a community Story Graph, and a community-specific creative relationship
database.

---

## 49. Architectural invariants

These become guardrails when implementation begins.

| ID | Invariant |
| --- | --- |
| I-C1 | Web is publication, not authoring. The web layer cannot replace the private authoring environment. |
| I-C2 | Private data remains private by default. No implicit publication. |
| I-C3 | Publication is explicit. The author chooses what becomes public. |
| I-C4 | No second Story Graph. Public creative relationships derive from canonical graph data. |
| I-C5 | No second record system. Community entities do not duplicate the canonical record architecture without architectural approval. |
| I-C6 | No second analytics engine. Public statistics derive from existing Analytics. |
| I-C7 | No second map system. Public maps derive from Map Studio. |
| I-C8 | Writing sessions remain historical. They do not become public Story Graph entities merely because statistics are displayed. |
| I-C9 | Unpublishing preserves private data. Removing a public projection never deletes the author's private project. |
| I-C10 | Public data is scoped. Only explicitly published fields/entities enter the public layer. |
| I-C11 | Desktop remains functional without community. AuthorOS is a complete creative application if community services are unavailable. |
| I-C12 | Community failure must not corrupt creative work. Web/community failure cannot modify or destroy private AuthorOS projects. |

---

## 50. Failure model

If the community service is unavailable, AuthorOS Desktop continues working. The author can
still write, save, edit, plan, map, research and analyse.

Community availability is not a prerequisite for creative work.

---

## 51. Offline principle

```text
PRIVATE CREATION = local-first
PUBLICATION      = online action
DISCOVERY        = online
COMMUNITY        = online
```

This reinforces the browser-only decision.

---

## 52. Security principle

Public/private separation is enforced at the data boundary, not in the UI. The architecture
cannot rely on "the button isn't visible" as a privacy mechanism. The backend/publication
layer must enforce what is actually accessible.

---

## 53. Future cloud boundary

If cloud infrastructure is used, the conceptual separation is:

| Public side | Private side |
| --- | --- |
| Author identity | Private creative database |
| Public profiles | Private manuscripts |
| Public projects | Private research |
| Public worlds | Private analytics |
| Public maps | Private notes |
| Discovery | Private drafts |
| Social relationships | |

The exact cloud schema is not prescribed by this directive; it is designed during the
implementation architecture milestone. See finding **F2** in the reconciliation document —
private project payloads already reach a cloud database, so this separation has to be
enforced against an existing system rather than designed on a blank page.

---

## 54. Community without Story Graph

The first public release must function without the Universal Story Graph:

```text
Author ──► Public Project ──► Public World
```

is sufficient. Graph-powered relationships layer in later. This prevents the community
project from blocking on Story Graph development.

---

## 55. Community without social features

The first release does not need likes, comments, follows or feeds. A useful first community
product is:

> **A beautiful place for authors to showcase their work and worlds.**

That is a much smaller and safer first target.

---

## 56. The long-term vision

```text
                         AUTHOROS
                            │
              ┌─────────────┴─────────────┐
       CREATIVE PLATFORM            COMMUNITY PLATFORM
              │                           │
       ┌──────┼──────┐              ┌─────┼─────┐
     Write   Plan   Build         Share Discover Connect
       └──────┴──────┘              └─────┴─────┘
              └───────────┬───────────────┘
                          │
                  UNIVERSAL STORY GRAPH
```

The graph becomes the connective tissue between creative domains. The web becomes the
presentation and community surface.

---

## 57. First implementation target

When this directive is accepted, the first implementation milestone is **not** "build the
social network". It is:

### Community Phase C1 — Public Author Identity

1. Author profile architecture
2. Public profile model
3. Profile visibility
4. Public author route
5. Profile page
6. Profile editing
7. Public/private controls
8. Theme integration
9. Responsive behaviour
10. Tests
11. Architecture guardrails
12. Web build verification

No project publishing. No world publishing. No social features. No community feed.

---

## 58. Required C1 testing

**Privacy** — a private profile cannot appear publicly; unpublished information is absent;
a public profile contains only approved fields.

**Routing** — the profile URL loads directly; refresh preserves the profile; browser back
and forward work; an invalid profile produces a proper error state.

**Responsive** — desktop, tablet, mobile.

**Failure** — unavailable profile, invalid profile, network failure, loading state.

**Architecture** — no private project data exposed; no second record system; no Story Graph
mutation; no manuscript loading requirement; no Analytics mutation.

---

## 59. Implementation rule

When this directive is handed to a development agent:

> **Do not improvise architecture.**

If an implementation requirement conflicts with this document:

1. stop
2. identify the conflict
3. report it
4. do not silently alter the architecture

The master architecture is updated deliberately rather than through accidental
implementation decisions.

Conflicts found while recording this directive are reported in
`authoros-web-community-reconciliation.md` rather than resolved here.

---

## 60. Relationship to the AuthorOS master roadmap

This initiative is tracked as **AuthorOS Web Community & World Board**, with its own C0–C8
milestones. It stays separate from Manuscript Studio, Map Studio, Story Graph, Analytics,
Research, Timeline and Plot Studio, and from the platform's W00–W18 gates, but may
eventually integrate with each through established APIs and publication projections.

---

## 61. Current status

Verified against commit `c9ae671` while recording this directive. Where the observed state
differs from the original directive's status table, the difference is recorded here and
explained in the reconciliation document.

| Component | Status | Notes |
| --- | --- | --- |
| Internal World Board | 🟢 Active | `flutter-author-studio-v1/lib/world_board/` |
| Platform web application | 🟢 Active | `indiauthors-platform/apps/site`, W00 foundation |
| Web responsive shell | 🔴 Not as assumed | `SiteShell` is a single header/main/footer wrapper; no tiered or responsive shell exists (F4) |
| Web URL routing | 🟢 Active | Next.js app router; no community routes exist |
| Public author profiles | ⚪ Not started | A desktop "Public profile visibility" toggle exists with no backend (F1) |
| Public projects | ⚪ Not started | |
| Public worlds | ⚪ Not started | |
| Public maps | ⚪ Not started | |
| Public statistics | ⚪ Not started | |
| Discovery | ⚪ Not started | `/explore` is a product demo, not author discovery (F6) |
| Following | ⚪ Future | |
| Comments | ⚪ Future | |
| Community | ⚪ Future | |
| Marketplace | ⚪ Separate future architecture | |
| Universal Story Graph | 🟡 Phase 0 directive issued, not implemented | `flutter-author-studio-v1/docs/story-graph-phase-0-integrity-directive.md` |

---

## 62. Final directive

The AuthorOS Community/Web layer exists to extend the creative platform outward. It does
not exist to pull private creative work into a social network.

> **AuthorOS Desktop = Create.**
> **AuthorOS Web = Present, Discover, Share.**
> **Future Community = Connect.**
> **Universal Story Graph = Connect the creative domains.**

The first community milestone is **Public Author Identity**.
The first community principle is **privacy by default**.
The first community architecture is **publication projection**.
The first community platform is **browser-only**.

And the first social feature is not social at all:

> **Give an author a beautiful public home for their work.**

**Implementation is not authorised until this directive is accepted as the master
architecture.**

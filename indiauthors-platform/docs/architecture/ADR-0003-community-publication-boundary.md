# ADR-0003: Community Publication Boundary

## Status
Proposed

The AuthorOS Web Community & World Board Master Architecture Directive
(`authoros-web-community-directive.md`) has been recorded but not accepted. This ADR moves
to Accepted only when that directive is accepted as the master architecture. Open conflicts
are listed in `authoros-web-community-reconciliation.md`.

## Context
AuthorOS is a local-first desktop creative application. A future community layer will let
authors present profiles, projects, worlds and maps publicly, and eventually discover and
follow each other.

The risk is that community functionality reaches directly into private creative data —
manuscripts, notes, secrets, research, analytics, audit history — because that data is
already available to the application that would render the public page. ADR-0001 already
keeps the AuthorOS runtime independent from the website runtime; it does not say anything
about what creative data may cross the boundary, or how.

The repository also shows this is not a clean-slate problem: private project payloads
already sync to a cloud database, a `publicProfile` boolean already exists in the desktop
settings and defaults to `true`, and the word "visibility" already carries three unrelated
in-app meanings.

## Decision
- The web community layer is a **publication layer**, never a second authoring database.
  The author's private project remains the source of truth.
- Public entities are **projections** over canonical AuthorOS data, not copies of it and not
  a parallel record system.
- Publication is **explicit and reversible**. Authentication is never treated as publication.
  Unpublishing removes the public representation and never touches private data.
- The public/private boundary is **enforced at the data layer**, not in the UI.
- The community layer is **browser-only**. The desktop application does not become a social
  client, and a public page never boots the desktop application.
- The community layer **reuses** the Story Graph read layer, the record model, Map Studio
  output and Analytics rather than creating community-specific versions of them.
- The layer is delivered in phases **C0–C8**, numbered separately from the platform's
  W00–W18 gates. C0 is architecture only.

## Consequences
- Public pages can be built, cached and served independently of the desktop application, and
  can stay fast because they load projections rather than creative databases.
- Community outage cannot affect authoring: the desktop application remains complete without
  the community service.
- Every public field must be deliberately projected, which is more work per feature than
  exposing existing records — this cost is accepted as the price of privacy by default.
- A publication projection model, a publication permission model, and a public identity with
  globally unique handles all become prerequisites for the first community milestone.
- Existing surfaces that imply publication — notably the desktop `publicProfile` toggle —
  must be retired or redefined rather than adopted, because they predate this boundary.
- Social features, moderation and marketplace each require their own architecture and are
  not authorised by this decision.

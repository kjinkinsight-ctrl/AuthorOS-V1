# ADR-0001: AuthorOS and Website Boundary

## Status
Accepted

## Context
AuthorOS already exists as a separate desktop application. The website must become the commercial and account ecosystem around AuthorOS without replacing the app itself.

## Decision
- Keep AuthorOS code and runtime independent from the website runtime.
- Build indiauthors.com as a separate platform project with separate deployment units.
- Integrate through explicit APIs only.
- Do not move local AuthorOS project data into the website by default.

## Consequences
- Platform can evolve account, licensing, commerce, and support independently.
- Desktop app remains local-first and stable.
- Future cloud integration can be added through versioned APIs.

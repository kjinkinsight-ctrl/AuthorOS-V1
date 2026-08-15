# ADR-0002: Runtime and Service Topology

## Status
Accepted

## Context
A real commercial platform requires SEO-capable public pages, authenticated account areas, payment webhooks, licensing authority, and admin operations.

## Decision
- Use a split topology with two deployable applications:
  - site frontend: SSR-capable web app for public and account UI
  - platform API: backend authority for auth, purchases, licensing, downloads, support, and admin APIs
- Store product, pricing, order, license, release, and support entities in a relational database.
- Treat payment and identity providers as external systems integrated via backend adapters.

## Consequences
- Frontend remains presentation and orchestration only.
- Security-sensitive workflows are backend-authoritative.
- System can scale independently by traffic profile.

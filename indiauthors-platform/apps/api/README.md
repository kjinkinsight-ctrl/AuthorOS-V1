# Platform API

Backend authority for identity, commerce, licensing, downloads, support, and admin operations.

## Scope
- authentication/session endpoints
- checkout session orchestration and payment webhooks
- order and license lifecycle
- download entitlement and signed artifact links
- support request lifecycle
- admin APIs with RBAC

## Boundaries
- verify provider webhook signatures server-side
- enforce authorization server-side
- store secrets only in secure environment configuration

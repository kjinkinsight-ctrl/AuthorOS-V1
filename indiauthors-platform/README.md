# Indie Authors Platform

This repository is the standalone platform project for indiauthors.com.

AuthorOS remains a separate desktop application in flutter-author-studio-v1. This project does not replace, move, or restructure AuthorOS internals.

## Purpose

The platform provides:
- public product and marketing pages
- account, purchase, license, and download workflows
- documentation, support, roadmap, and journal content
- admin operations for products, pricing, licenses, and content

## W00 Status

W00 is implemented as a production-grade foundation:
- architecture boundaries and ADRs
- API contract skeleton (OpenAPI)
- domain schema skeletons for order and license entities
- environment and secret boundaries
- baseline security and operational controls
- milestone gates for W00-W18

## Repository Layout

- apps/site: public website and authenticated account frontend
- apps/api: backend services and webhook entry points
- packages/contracts: API and domain contracts shared across services
- docs/architecture: ADRs, system boundaries, security, and milestones
- infra: environment templates and operational policy baselines

## Execution Policy

- No secrets in frontend code
- No payment confirmation in frontend
- No license authority in frontend
- No fake production authentication, payment, or licensing systems
- Clear integration boundary with AuthorOS desktop app

## Next Step

Implement W01 after W00 architecture sign-off.

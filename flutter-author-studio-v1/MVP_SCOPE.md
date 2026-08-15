# Author Studio MVP Scope

## Release goal

Ship a dependable, local-first writing workspace for individual authors. The MVP must let a writer create a project, draft and organize a manuscript, plan story elements, verify local recovery, and export a readable PDF without requiring a cloud account.

## Included in the MVP

- first-run onboarding and starter project templates
- project, manuscript, chapter, scene, character, world, timeline, and note workflows
- local manuscript persistence and configurable writing rhythm
- visual planning, continuity checks, and narrative impact tracing
- Story Codex metadata for people, places, factions, objects, and lore
- PDF export presets for standard manuscript, beta-reader, and print-draft output
- backup health and recovery verification
- optional Supabase authentication and synchronization with a local fallback
- Android packaging and Google Play launch preparation

## Deferred until after the MVP

- real-time multi-user collaboration
- required cloud accounts or cloud-only storage
- subscriptions, payments, and advertising
- AI-generated manuscript content
- iOS or desktop store publication
- advanced publishing-house and team administration

## Release quality gates

The MVP can enter internal testing when:

- `flutter analyze` reports no issues
- `flutter test` passes in full
- project creation, restart, autosave, backup recovery, and PDF export receive a manual smoke test on a release build
- the signed Android App Bundle installs through a Google Play testing track
- privacy, data-safety, content-rating, screenshots, feature graphic, and release notes are complete

## Release boundary

Local writing remains available when Supabase is absent, unavailable, or signed out. Cloud sync is optional for the first public release and must not weaken local persistence or recovery. Collaboration and cloud-dependent promises must stay out of store copy until they have production validation.
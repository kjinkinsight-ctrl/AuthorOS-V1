# Author Studio

Author Studio is a writing-focused workspace for authors, researchers, and creative teams to plan, draft, and organize their work.

## Product vision

The app is designed to give authors a streamlined environment for:
- organizing projects and manuscript ideas
- drafting and revising writing in a focused interface
- planning scenes, arcs, and character threads
- tracking continuity and story structure
- exporting polished manuscript output
- backing up work locally and preparing for sync-enabled workflows

## Current project status

The local-first MVP feature set is implemented through planning and continuity. Static analysis is clean, and automated tests cover onboarding, persistence, writing, planning, export, backup, themes, and sync. Public release remains blocked on manual device QA, production signing, store assets, privacy and compliance details, and Google Play testing-track validation.

See [MVP_SCOPE.md](MVP_SCOPE.md) for the release boundary and [docs/github-project-board.md](docs/github-project-board.md) for verified milestone status.

The proposed post-MVP evolution into the connected AuthorOS ecosystem is defined in [docs/authoros-2-master-plan.md](docs/authoros-2-master-plan.md). It is a planning document, not a claim about currently shipped features.

## Build roadmap

### M1: Launch foundation — complete in code
- launch scope and audience documented
- app metadata and initial store positioning drafted
- onboarding and first-run widget flows covered by automated tests
- project creation and local persistence implemented

### M2: Core writing workflow — complete in code
- manuscript, chapter, and note flows implemented
- project persistence, autosave settings, and local data safety covered
- empty-state and recovery paths implemented

### M3: Planning and continuity — complete in code
- visual planning board and scene workflow implemented
- timeline, continuity, Story Codex, and impact tracing implemented
- filters and structure overlays covered by automated tests

### M4: Release readiness — in progress
- PDF export and backup/recovery workflows implemented and tested
- local sync boundary implemented; live Supabase validation remains
- launcher icon configured; screenshots, feature graphic, and manual QA remain

### M5: Google Play launch — blocked on external setup
- generate and protect the production signing keystore
- prepare privacy policy, release notes, screenshots, and compliance forms
- upload a signed AAB and validate an internal or closed testing track

## Local development

```bash
flutter pub get
flutter test
flutter analyze
flutter run
```

## Android release validation

```bash
powershell -ExecutionPolicy Bypass -File tools/android-release.ps1
```

The release script prompts for signing passwords when they are not supplied. Do not commit the generated keystore or `android/key.properties`.

## Key project areas

- [lib/main.dart](lib/main.dart) — app shell, theme system, onboarding bootstrap
- [lib/onboarding.dart](lib/onboarding.dart) — project starter workflow and templates
- [lib/visual_planning.dart](lib/visual_planning.dart) — planning board and scene management
- [lib/continuity.dart](lib/continuity.dart) — continuity analysis and storyline checks
- [lib/manuscript_export.dart](lib/manuscript_export.dart) — manuscript export logic
- [lib/backup_health.dart](lib/backup_health.dart) — backup integrity workflows
- [lib/supabase_service.dart](lib/supabase_service.dart) — Supabase connectivity and data sync bridge
- [Play-Store-Listing.md](Play-Store-Listing.md) — launch metadata and App Store/Google Play checklist

## Launch checklist summary

Before release, the team should confirm:
- app name and positioning
- privacy policy URL
- screenshots and feature graphic
- signed release build
- testing tracks and release notes
- data safety and compliance disclosures

## Notes

This project is currently structured as a local-first writing tool with a path to cloud-ready sync. The first public release should prioritize writing quality, data safety, and a dependable Android packaging flow over broad feature expansion.

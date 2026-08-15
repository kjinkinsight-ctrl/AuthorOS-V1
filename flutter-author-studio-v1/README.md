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

This repository is an active Flutter build with a growing MVP foundation. The app already includes onboarding, project setup, writing-space navigation, planning tools, export workflows, backup health checks, and Supabase-ready hooks.

## Build roadmap

### Phase 1: Foundations
- confirm launch scope and audience
- finalize app metadata and store positioning
- verify project onboarding and first-run UX
- ensure the app loads and saves projects reliably

### Phase 2: Core writing workflow
- stabilize manuscript, chapter, and note flows
- validate project persistence and local data safety
- improve empty states and recovery patterns

### Phase 3: Creative planning
- refine visual planning board and scene editing
- verify timeline and continuity tools
- tune filters, structure overlays, and narrative insights

### Phase 4: Release readiness
- finalize PDF export and backup/restore workflows
- validate cloud and local sync boundaries
- complete app icon, screenshots, and quality assurance

### Phase 5: Google Play launch
- sign Android app bundle
- prepare privacy policy, release notes, and testing tracks
- publish to internal, closed, or production rollout

## Local development

```bash
flutter pub get
flutter test
flutter analyze
flutter run
```

## Android release validation

```bash
flutter build appbundle --release
```

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

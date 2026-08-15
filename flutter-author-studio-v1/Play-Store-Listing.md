# Google Play Store listing checklist

## Product build roadmap

### Phase 1: foundation and quality
- finalize product positioning and launch scope
- confirm the MVP is focused on writing, planning, and export
- validate the onboarding and project creation workflow
- ensure local data persistence is stable and recoverable

### Phase 2: writing workflow
- test manuscript drafting, chapter organization, and notes
- confirm autosave and continuity flows are practical for real writing sessions
- improve app navigation and empty states for first-time users

### Phase 3: planning and narrative intelligence
- validate visual planning board, scenes, arcs, and structure overlays
- confirm timeline and continuity tools are readable and helpful
- refine filters, editing patterns, and user guidance

### Phase 4: release and compliance
- finalize export output and backup/restore safety
- decide the release boundary for cloud sync and privacy disclosures
- prepare screenshots, store copy, and privacy policy documentation

### Phase 5: launch readiness
- run Android release build and QA pass
- sign and upload AAB to Google Play Console
- set up testing tracks and production rollout
- publish release notes and monitor early feedback

## Core app details
- App name: Author Studio
- Short description: Draft, organize, and refine your writing projects in one streamlined workspace.
- Full description:
  Author Studio is a writing-focused workspace for authors, researchers, and creative teams to plan, draft, and organize their work.

  Features include:
  - project organization and manuscript planning
  - writing workspace with autosave and version continuity
  - scene and world-building tools
  - export support for manuscript workflows
  - secure local data handling and cloud-ready sync options

  Built for authors who want a clear writing environment without losing momentum.

## Store metadata
- Category: Books & Reference or Productivity
- Tags: writing, authoring, creativity, productivity, planning
- App icon: 512x512 PNG, full-color, no transparency
- Feature graphic: 1024x500 JPG/PNG
- Screenshots: minimum 2, maximum 8, phone portrait recommended
- Privacy policy URL: required for apps with personal data collection

## Content and compliance
- Target age rating: select the appropriate age group
- Content rating questionnaire: complete for Google Play
- Data safety form: disclose collection, sharing, and security practices
- Ads: set to No ads unless applicable
- App access: declare any sensitive permissions used by the app

## Release setup
- Build a signed AAB with `flutter build appbundle --release`
- Upload the AAB to Google Play Console
- Set up testing tracks and production rollout
- Add release notes for each version

## Recommended launch screenshots
- Dashboard / project overview
- Writing editor / manuscript view
- Planning or scene board
- Export or project management workflow

## Minimum launch assets
- App icon
- Feature graphic
- Screenshots (phone, 2-8)
- Privacy URL
- App description
- Release notes

## Implementation note

The first release should prioritize a dependable writing experience, reliable local storage, and clean Android packaging. Cloud sync and advanced collaboration should be staged after the MVP is stable and validated.

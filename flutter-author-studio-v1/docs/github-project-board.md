# GitHub Project Board Setup for Author Studio

This project is already structured around a clear product roadmap. The fastest way to make the GitHub dashboard useful is to start with a small, launch-focused backlog and keep the board organized around execution, not feature sprawl.

## Verified milestone status

Status reflects the repository as validated locally on 2026-08-16. A merged pull request is not sufficient evidence by itself; move work to Done only when its changes are present on `main` and its acceptance check passes.

| Milestone | Status | Verified outcome | Remaining gate |
| --- | --- | --- | --- |
| M1: Launch foundation | Complete in code | MVP scope, onboarding, starter projects, metadata, and local project creation | Manual first-run smoke test on Android |
| M2: Writing workflow stability | Complete in code | Manuscript persistence, chapters, notes, reading rhythm, autosave settings, backup recovery, and automated tests | Long-session and restart smoke test on Android |
| M3: Planning and continuity | Complete in code | Planning board, filters, overlays, timeline, continuity, Story Codex, and impact tracing | Manual usability pass |
| M4: Release readiness | In progress | PDF export, backup verification, launcher icon, sync infrastructure, and release tooling | Live Supabase test, store assets, signed build, and release QA |
| M5: Play Store launch | Blocked | Store copy and launch checklist drafted | Privacy URL, compliance forms, Play Console app, testing track, and rollout |

## Current priorities

1. Run the full automated QA gate and preserve its result on the release PR.
2. Validate project restart, autosave, backup recovery, and PDF export on an Android release build.
3. Test Supabase authentication, RLS, offline queueing, and conflict behavior against the production-bound project.
4. Produce screenshots, the 1024x500 feature graphic, privacy policy, data-safety answers, and release notes.
5. Generate the production keystore, build the signed AAB, and upload it to an internal testing track.

## Board columns

Create a project board with these columns:

- Backlog
  - Ideas, future improvements, and non-urgent work
- Planned
  - Approved work for the next sprint or milestone
- In Progress
  - Active work with an owner
- In Review
  - PRs, QA, or validation work
- Blocked
  - Waiting on dependency, decision, or external resource
- Done
  - Shipped and validated work

## Suggested starter issues

### Foundation / product clarity
- Finalize app positioning and target audience
- Define the first public release scope
- Confirm onboarding flow and first-run UX
- Set a minimum viable release checklist

### Stability and reliability
- Validate project creation and local save flow
- Audit backup/restore recovery paths
- Improve error handling for empty states and missing data
- Confirm app launches reliably across platforms

### Core writing workflow
- Stabilize manuscript editing experience
- Add chapter and note management refinement
- Review continuity and planning tool integration
- Improve navigation and writing-session focus

### Release readiness
- Validate PDF/export workflow
- Prepare Android release and signing checklist
- Create privacy policy, store listing, and screenshots plan
- Prepare launch notes and QA sign-off

## Labels to add

- area: onboarding
- area: manuscript
- area: planning
- area: export
- area: backup
- area: release
- type: bug
- type: feature
- type: research
- type: qa
- priority: low
- priority: medium
- priority: high
- status: blocked

## Working rules for the dashboard

- Keep no more than 3 active items in progress at once.
- Every card should have an owner and a clear outcome.
- Use milestone naming to match the roadmap phases.
- Move cards to "Done" only after validation is complete.
- Keep backlog items small enough to estimate quickly.

## GitHub milestone sequence

- M1: Launch foundation
- M2: Writing workflow stability
- M3: Planning and continuity
- M4: Release readiness
- M5: Play Store launch

This structure matches the roadmap already written in the project README and keeps the board practical for a Flutter app in a growing MVP stage.

## Required evidence for Done

- Code work: the change is present on `main`, `flutter analyze` passes, and relevant tests pass.
- UX work: record the tested device, workflow, and result in the issue or pull request.
- Release work: attach the artifact or Play Console result and record version name and build number.
- External work: link the final policy, asset, form, or console configuration rather than closing a planning-only pull request.

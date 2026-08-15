# GitHub Project Board Setup for Author Studio

This project is already structured around a clear product roadmap. The fastest way to make the GitHub dashboard useful is to start with a small, launch-focused backlog and keep the board organized around execution, not feature sprawl.

## Recommended starting point

Start with Phase 1 and Phase 2 work only:

1. Foundation and launch scope
2. Manuscript workflow stability
3. Core project persistence and backup safety
4. Release-readiness validation

This keeps the board aligned with the actual product goal: shipping a dependable writing tool before broad feature expansion.

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

## Suggested GitHub milestone sequence

- M1: Launch foundation
- M2: Writing workflow stability
- M3: Planning and continuity
- M4: Release readiness
- M5: Play Store launch

This structure matches the roadmap already written in the project README and keeps the board practical for a Flutter app in a growing MVP stage.

## Recommended first sprint

Start with these four cards:

1. Finalize initial app scope and positioning
2. Validate onboarding and first-run experience
3. Stabilize project persistence and backup reliability
4. Review manuscript editing workflow and usability gaps

These four tasks create the most leverage with the least risk and set the stage for the rest of the board.

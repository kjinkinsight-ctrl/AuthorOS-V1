# ADR-0006: Architectural Precedence

## Status

Accepted

## Date

August 22, 2026

## Context

AuthorOS has accumulated a strong architecture and a strong feature backlog at
the same time, and the two have not been ranked against each other.

The pattern the repository keeps producing is visible in its own history. A
studio is designed correctly, an implementation map states the right rule, and
then a specific feature needs something the architecture does not yet offer. The
feature ships with a local workaround, the workaround is recorded as debt, and
the debt is scheduled for "a retrofit later". Concrete instances already in the
tree:

- `RecordFieldDefinition` has no `searchable` flag, so `world_record_types.dart`
  puts one in `extensionData`. The concept now exists in AuthorOS twice: once as
  an informal convention in one file, and nowhere as a contract.
- `SceneRelationship` predates `RecordLink` and still describes scene-to-target
  connections in the manuscript store, so AuthorOS has two answers to "what is a
  relationship" depending on which side of the manuscript boundary you ask.
- `continuity.dart` holds the deterministic-intelligence vocabulary and a Flutter
  widget in one library, so the vocabulary cannot be consumed without Flutter.

None of these were mistakes at the moment they were made. Each was the cheapest
way to ship the thing in front of the author. The problem is that no rule existed
saying which side gives way, so the architecture gave way every time — quietly,
locally, and by default.

Twenty specialist systems, procedural generation, a universal field system, and a
list of competitor-derived capabilities are all ahead of us. Applied to that
volume of work, "ship it and retrofit later" produces a feature collection with
an architecture diagram attached, rather than an operating system.

The counter-risk is real and must be named: a precedence rule can be read as a
mandate to rewrite working code until it matches the diagram. That is its own
failure mode, and an expensive one. AuthorOS has substantial, tested, shipping
systems — Map Studio through Phase 6, the Codex, Character and World Studios,
manuscript prose persistence, the Theme Engine — that are architecturally sound.
Churning them to look more like a drawing would spend the project's remaining
runway on motion.

## Decision

**When a new feature conflicts with an established AuthorOS architectural
principle, the feature must adapt to the architecture — the architecture must not
be weakened to accommodate the feature.**

Existing production code is changed only where necessary to:

- achieve architectural compliance with a locked principle,
- preserve canonical data,
- remove genuine duplication, or
- correct a verified architectural conflict.

New features must not create:

- parallel sources of truth,
- isolated entity models,
- duplicate relationship systems,
- unnecessary navigation surfaces, or
- feature-specific persistence mechanisms.

The locked principles this rule defends are enumerated in the
[AuthorOS Architecture Lock](authoros-architecture-lock.md).

### How the rule is applied

1. A feature that needs something the architecture does not offer **raises the
   gap against the architecture**. The shared capability is designed once, for
   everyone, and the feature is built on it.
2. Where that is genuinely impractical within the feature's scope, the gap is
   recorded as a named conflict in the compliance audit with an owner and a step
   in the sequence — not as a comment in a source file, and not as an informal
   convention in `extensionData`.
3. A locked principle changes only by explicit amendment to the lock document,
   reviewed as an architectural decision. Shipping a feature is never an
   amendment.

### What the rule does not authorise

Compliance is not a licence to rebuild. A working system that predates a lock is
corrected where it violates that lock and left alone everywhere else. "This file
would look more like the diagram if it were restructured" is not a violation.

## Consequences

### Accepted costs

- Some features take longer, because the shared capability they need is built
  first. The universal field system is the immediate example: several studios
  would each be faster building their own entry surface, and all of them are
  asked to wait.
- Some features are redesigned or deferred at the gate rather than shipped in a
  shape that would have worked locally.
- Every implementation map carries an architecture section it did not carry
  before.

### Gains

- The cost of the twentieth system is roughly the cost of the second, rather than
  compounding.
- Deterministic intelligence keeps working, because it keeps having one set of
  data to reason over. Every parallel store would be a blind spot in continuity,
  canon, and analysis.
- Export and archive stay complete, because there is nowhere for creative data to
  hide.
- Debt stops being invisible. A conflict is a tracked item in the audit, not a
  local workaround that only its author remembers.

### Enforcement

- The ten-question feature gate in the lock document, answered in writing in each
  implementation map before implementation starts.
- `test/architecture_lock_test.dart`, which fails CI for the locks that can be
  checked mechanically.
- The compliance audit, re-run at each step of the sequence.

## Related

- [AuthorOS Architecture Lock](authoros-architecture-lock.md)
- [ADR-0003: Connected Creative Domain Model](ADR-0003-connected-domain-model.md)
- [ADR-0004: Embedded Database](ADR-0004-embedded-database.md)
- [ADR-0005: Portable Archive](ADR-0005-portable-archive.md)
- [AuthorOS Architecture Compliance Audit](../authoros-architecture-compliance-audit.md)

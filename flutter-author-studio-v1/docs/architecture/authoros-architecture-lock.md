# AuthorOS Architecture Lock

Status: **Locked**
Locked: August 22, 2026
Applies to: every future feature, system, studio phase, and pull request
Supersedes: nothing — it constrains everything

---

## What this document is

The [AuthorOS 2.0 Master Plan](../authoros-2-master-plan.md) describes what
AuthorOS is going to be. This document describes what AuthorOS is **not allowed
to stop being** while it gets there.

Everything below was, until now, held as a set of good intentions spread across
implementation maps, ADRs, and audit documents. Good intentions do not survive
feature pressure. A locked principle does, because a feature that conflicts with
it is the thing that changes.

The distinction that matters:

> A roadmap says what to build next.
> A lock says what any build must be true of.

Roadmap items can be reordered, deferred, or dropped. Locked principles can only
be changed by an explicit amendment to this document, reviewed as an
architectural decision in its own right — never as a side effect of shipping
something.

---

## The hierarchy

```text
AUTHOROS
│
├── UNIVERSAL CREATIVE MODEL
│   ├── Canonical entities
│   ├── Canonical relationships
│   ├── Universal fields
│   ├── Universal templates
│   ├── Project configuration
│   └── Cross-system identity
│
├── CREATIVE DOMAINS
│   ├── Manuscript      ├── Timeline
│   ├── Story           ├── Codex / Knowledge
│   ├── Characters      ├── Research
│   ├── World           ├── Relationships
│   ├── Maps            └── Production
│
├── SYSTEMS
│   ├── Magic           ├── Government
│   ├── Languages       ├── Biology
│   ├── Religion        ├── Technology
│   ├── Economy         ├── Bestiary
│   └── ...future systems
│
├── EXTENSIONS
│   ├── Genre-aware presets
│   ├── Optional capabilities
│   └── Custom systems
│
└── DETERMINISTIC INTELLIGENCE
    ├── Validation      ├── Relationships
    ├── Continuity      ├── Dependencies
    ├── Canon           ├── Consequences
    ├── Timeline        └── Analysis
```

Read the arrows downward as *"is expressed in terms of"*, never as *"is stored
separately from"*. A System is not a database. A Domain is not a database. There
is one store, one identity space, one relationship model, and everything above is
a way of looking at it.

---

## The twelve locks

### Lock 1 — One canonical representation of creative information

There is exactly one record of a thing. Every studio, view, board, map, graph,
and export is a **lens** over that record.

```text
Character
   ├── Character view
   ├── Map view
   ├── Timeline view
   ├── Plot view
   ├── Codex view
   ├── Relationship view
   └── Manuscript references
```

Never:

```text
Character record
Character map record
Character timeline record
Character plot record
```

**Implementation contract.** `AuthorRecord` (`lib/core/connected_domain.dart`) is
the only creative entity envelope in AuthorOS. A feature that needs to say
something new about a character adds a **field, a relationship, or a view** — not
a class, not a table, not a store.

**Manuscript is the one sanctioned specialisation.** Parts, chapters, and scenes
stay a specialised ordered structure because ordering, editing, and export carry
requirements a general record cannot meet. They participate in the model through
stable IDs like everything else, and there is still exactly one of each of them.

---

### Lock 2 — One relationship model

`RecordLink` is the only edge in AuthorOS. Every cross-domain, cross-system, and
cross-studio connection is a typed link between stable IDs.

A feature does not get its own relationship table because its relationships "feel
different". Time-bounded, directional, labelled, and scoped are all already
expressible. If a genuinely new property is needed, it is added to the edge model
once, for everyone.

Links refer only to IDs. Display names are always resolved through the record
layer, so renaming never breaks a connection.

---

### Lock 3 — Views are not records

Boards, canvases, map layouts, filters, column choices, panel positions, zoom
level, and selection are **saved views**. They own no creative data.

Moving a character on a relationship canvas changes the canvas. It does not
change the character.

The corollary that has already caught real bugs: presentation data that belongs
to a view (terrain paint, scenery, layout) lives in view or map fields and is
**never** an `AuthorRecord` and never an endpoint of a `RecordLink`. A map with
two thousand trees adds two thousand pieces of scenery and zero nodes to the
story graph.

---

### Lock 4 — Universal fields and templates are infrastructure, not a studio feature

Every entry surface in AuthorOS resolves through one chain:

```text
Universal field
      ↓
Field definition
      ↓
Field library
      ↓
Template
      ↓
Project configuration
      ↓
Entry configuration
      ↓
Specialised view
```

There is no Character form, Location form, Faction form, Magic form, Weapon form,
and Religion form each independently deciding what a field is, how it validates,
whether it is searchable, and how it renders.

A field definition must be able to carry all of:

| Capability | Meaning |
|---|---|
| Enabled | Present in this project's configuration at all |
| Required | Must hold a value before the record is complete |
| Input type | The primitive the field stores and the control it offers |
| Options | The enumerated values a choice field offers |
| Custom values | Whether the author may enter a value outside the options |
| Default | The value a new record starts with |
| Quick Create | Appears in the fast-entry surface |
| Main View | Appears on the record's primary view rather than behind a section |
| Searchable | Contributes to the universal search index |
| Track Changes | Field-level history is retained |
| Conditional availability | Shown only when another field or configuration says so |
| Relationships | Field is a typed reference to other records |
| Calculated values | Derived deterministically from other fields and links |

This is a **foundation to be built once** (Step 4 of the sequence below), not a
capability each studio grows independently. A studio that needs one of these
today and finds it missing raises the gap against the field system; it does not
smuggle the concept through `extensionData` and move on.

---

### Lock 5 — Systems live inside domains, not beside them

The specialist systems — Magic, Languages, Religion, Economy, Government,
Biology, Technology, Bestiary, and whatever follows — are **capabilities within
the appropriate domain**, activated per project.

```text
WORLD
 ├── Locations
 ├── Cultures
 ├── Factions
 └── Systems
      ├── Magic
      ├── Religion
      ├── Languages
      ├── Economy
      └── ...
```

Not twenty top-level destinations. The navigation surface does not grow linearly
with capability; that is the entire point of having an architecture rather than a
feature list.

A System contributes record types, field definitions, relationship types,
templates, and views. A System **does not** contribute a store, an identity
space, a relationship model, or a permanent navigation destination.

---

### Lock 6 — Deactivation hides; it never deletes

`inactive ≠ deleted` is a persistence rule, not a UI preference.

Turning a system or extension off means: hide its interface and its specialised
views. It does not mean: remove its records, drop its relationships, or discard
its fields. Turning it back on must return the author to exactly what they had.

Any feature that cannot honour this is not ready to ship.

---

### Lock 7 — Presets configure; they never restrict

A genre preset is a helpful starting configuration. It may suggest that a fantasy
project enable Magic, Bestiary, Religion, Languages, and Bloodlines.

It may never say *"because this is fantasy, Economics cannot be enabled."*

Presets are configuration helpers. They are not capability gates, and no code
path may treat them as one.

---

### Lock 8 — Intelligence is deterministic, and it shows its work

AuthorOS has no AI layer. It has an inference layer:

```text
Canonical data
      ↓
Relationships
      ↓
Indexes
      ↓
Rules
      ↓
Inference
      ↓
Analysis
      ↓
AuthorOS intelligence
```

What that produces:

> Character X cannot be in two places at the same moment.
> Scene 42 references a character who is dead in the current canon state.
> This plot thread has an unresolved setup.
> This relationship contradicts an earlier canonical relationship.
> This location is outside the character's established travel range.

Three constraints hold it together:

1. **Nothing is invented.** Where the canonical data does not say, the answer is
   "not defined" — never a plausible value.
2. **Everything is reproducible.** The same records and links always produce the
   same findings, in the same order.
3. **Every finding is evidence-backed.** A finding names the records, fields, and
   links that produced it. A contradiction the author cannot inspect is an
   accusation, not an analysis.

Prose is never parsed for facts. Facts come from structured data, which is why
AuthorOS can point at both sides of a contradiction instead of guessing.

---

### Lock 9 — Generation produces canonical entities

This is the lock that governs Phase 7 and everything like it.

```text
Procedural generator
        ↓
Canonical entities
        ↓
Canonical relationships
        ↓
Universal fields
        ↓
Universal templates
        ↓
Maps / Codex / Timeline / Story / ...
```

A generated world is not a parallel world database. A generated city is a city
record, its buildings are building records, its districts and streets are records
and relationships, and its geometry is map placement on those records.

**The map is a view of the world, not the world itself.**

Generation rules, all locked:

- deterministic
- seed-driven
- reproducible
- model-independent
- provenance stored on what it produces
- generated in a sandbox, not straight into canon
- adopted into canon only on explicit author approval
- regeneration must respect author modifications

---

### Lock 10 — Navigation is broad domains, not one destination per capability

The navigation philosophy:

```text
HOME        Dashboard · Projects
CREATE      Manuscript · Story · Characters · World · Maps · Timeline
KNOWLEDGE   Codex · Research · Relationships
TOOLS       Systems · Analysis · Production
PROJECT     Files · Versions · Settings
```

Not every item must exist today. The lock is on the shape: **future feature work
does not create a permanent top-level destination for every new capability.**
Adding one is an architectural change, and is treated as one.

---

### Lock 11 — Competitor features are implementation targets, never architecture

AuthorOS can absolutely aim at Scrivener's manuscript control, Novelcrafter's
codex, Plottr's visual planning, World Anvil's structured worldbuilding,
Obsidian-style graph relationships, Campfire's specialist systems, and
professional-grade production and export.

It does not copy how any of them are built. The translation is always:

```text
What user problem does this solve?
        ↓
Universal Creative Model
        ↓
Canonical entity
        ↓
Relationship
        ↓
Specialised view
        ↓
Deterministic intelligence
```

A competitor's data model is evidence about user needs. It is not a design.

---

### Lock 12 — Dependency direction is fixed

```text
core (plain Dart, no Flutter)
  ↓
persistence
  ↓
services
  ↓
studios / views
```

Nothing in `core` imports Flutter, `dart:ui`, a theme, a store, or a studio. The
creative model and the intelligence that reads it must be resolvable in a test
without a Flutter binding, because a domain that can only run inside a widget
tree is a domain that will eventually be reasoned about inside one.

---

## The precedence rule

Recorded formally as
[ADR-0006](ADR-0006-architectural-precedence.md). Stated here because it is the
rule that makes the other twelve mean anything:

> ### 🔒 ARCHITECTURAL PRECEDENCE RULE
>
> **When a new feature conflicts with an established AuthorOS architectural
> principle, the feature must adapt to the architecture — the architecture must
> not be weakened to accommodate the feature.**
>
> Existing production code should only be changed where necessary to achieve
> architectural compliance, preserve canonical data, remove genuine duplication,
> or correct a verified architectural conflict.
>
> New features must not create parallel sources of truth, isolated entity models,
> duplicate relationship systems, unnecessary navigation surfaces, or
> feature-specific persistence mechanisms.

The second paragraph is as binding as the first. **Compliance is not a licence to
rebuild.** Working systems are not rewritten to make them look like the diagram;
they are corrected where they genuinely violate a lock, and otherwise left alone.

---

## The feature gate

Every proposed feature — new studio, new system, new phase, competitor-derived
capability, anything — answers these ten questions **before implementation
starts**, in the implementation map for that work.

| # | Question | A failing answer means |
|---|---|---|
| 1 | Does it use canonical data? | It has invented a second source of truth |
| 2 | Does it introduce duplicate data? | Two things will disagree, and one is wrong |
| 3 | Can it use universal fields? | It is about to reimplement field handling |
| 4 | Can it use universal templates? | It is about to reimplement entry configuration |
| 5 | Does it create a new relationship type unnecessarily? | The edge model already expresses this |
| 6 | Does it require a new sidebar destination? | It belongs inside a domain |
| 7 | Does it work through deterministic intelligence? | It is guessing, or it is a second engine |
| 8 | Does deactivation preserve data? | It deletes the author's work to tidy the UI |
| 9 | Does export remain possible? | It has created content the author cannot take with them |
| 10 | Does it introduce unnecessary complexity? | The simpler shape was not looked for |

A feature that fails any of these **stops and is redesigned before code is
written**. That is cheaper than every alternative, and this is the point in the
process where it is cheapest.

---

## The sequence

New feature work is paused until the architecture is reconciled. The order:

| Step | Work | State |
|---|---|---|
| 🔒 1 | **Architecture lock** — this document, ADR-0006, master plan reconciliation | ✅ Complete |
| 🔍 2 | **Compliance audit** of the actual `main` tree against these locks | ✅ Complete — [audit](../authoros-architecture-compliance-audit.md) |
| 🔧 3 | **Correct genuine conflicts** — only what the audit marks 🔴, and only as far as compliance requires | Next |
| 🧱 4 | **Universal field and template foundation** — the full configuration surface from Lock 4 | After Step 3 |
| 🌐 5 | **Universal Creative Model integration** — remaining holdouts consume the canonical model | After Step 4 |
| 🗺️ 6 | **Re-audit Map Studio Phase 7** against the reconciled architecture | After Step 5 |
| ▶️ 7 | **Phase 7 implementation** — 7A → 7A.1 → 7B → 7C → 7D | After Step 6 |

Step 3 is deliberately narrow. The audit found the tree in good architectural
health; the correction pass is a short list, not a rebuild.

---

## Enforcement

Three mechanisms, in increasing order of reliability:

1. **This document**, cited in every implementation map's opening section.
2. **The feature gate**, answered in writing before implementation starts.
3. **`test/architecture_lock_test.dart`**, which fails CI when a lock that can be
   checked mechanically is broken.

The third exists because the first two depend on someone remembering. The test
suite already carries this pattern — `map_architecture_test.dart` and
`command_architecture_test.dart` guard their own areas the same way. The lock
test guards the model itself: one record envelope, one edge model, studios that
own no persistence, a Flutter-free core, a bounded navigation surface, and no
generative dependency.

A lock that cannot be expressed as a test is not weaker — it is simply waiting
for the code that would make it checkable. When Step 4 lands the field
configuration surface, and Step 5 lands project configuration, their locks become
testable too, and the test grows to cover them.

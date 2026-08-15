"use client";

import { useMemo, useState } from "react";

type ExplorerPanel = {
  id: string;
  label: string;
  summary: string;
  widgets: string[];
};

const explorerPanels: ExplorerPanel[] = [
  {
    id: "dashboard",
    label: "Dashboard",
    summary: "A quick pulse of your active writing projects and today's goals.",
    widgets: [
      "Daily word target: 1,800 words",
      "Current manuscript progress: 63%",
      "Continuity alerts requiring review: 2",
      "Backup health: Last successful snapshot 14 minutes ago"
    ]
  },
  {
    id: "library",
    label: "Story Library",
    summary: "Organize all active, paused, and archived books in one timeline-aware shelf.",
    widgets: [
      "Ember and Salt - Drafting",
      "The Quiet Cartographer - Structural edit",
      "City of Feathers - Archived outline"
    ]
  },
  {
    id: "manuscript",
    label: "Manuscript Studio",
    summary: "Draft scenes with chapter context, pacing notes, and continuity side rails.",
    widgets: [
      "Chapter 14: The Chapel Door",
      "Scene POV: Isha | Timeline marker: Day 42",
      "Reading rhythm: Balanced cadence"
    ]
  },
  {
    id: "plot",
    label: "Plot Studio",
    summary: "Track beats, turning points, and unresolved narrative tension.",
    widgets: [
      "Act II midpoint confirmed",
      "Thread: Missing ledger unresolved",
      "Arc confidence score: 82/100"
    ]
  },
  {
    id: "characters",
    label: "Characters",
    summary: "Profile growth arcs, relationships, and contradiction checks across scenes.",
    widgets: [
      "Isha Hale - trust arc in progress",
      "Noor Vance - hidden motive tagged",
      "Relationship map updated in 3 scenes"
    ]
  },
  {
    id: "timeline",
    label: "Timeline",
    summary: "Visualize sequence consistency and travel-time plausibility.",
    widgets: [
      "Era block: Winter Siege",
      "Conflict warning: Two scenes overlap by 6 hours",
      "Travel validation: route mismatch detected"
    ]
  },
  {
    id: "research",
    label: "Research and Notes",
    summary: "Keep source snippets and world references linked to story elements.",
    widgets: [
      "Research set: Maritime law notes",
      "Reference note pinned to Chapter 08",
      "Citation snippets: 14 linked"
    ]
  },
  {
    id: "protection",
    label: "Backup and Export",
    summary: "Run project snapshots and produce handoff-ready manuscript exports.",
    widgets: [
      "Snapshot schedule: Every 45 minutes",
      "Last export: Beta Reader PDF",
      "Recovery drill status: Verified"
    ]
  },
  {
    id: "settings",
    label: "Settings",
    summary: "Tune writing environment, sync preferences, and profile controls.",
    widgets: [
      "Theme: Obsidian",
      "Session hardening: Re-auth for sensitive actions",
      "Sync alerts: Enabled"
    ]
  }
];

export function ExplorerDemo() {
  const [activeId, setActiveId] = useState(explorerPanels[0]?.id ?? "dashboard");

  const activePanel = useMemo(
    () => explorerPanels.find((panel) => panel.id === activeId) ?? explorerPanels[0],
    [activeId]
  );

  return (
    <section className="stack" aria-labelledby="explorer-demo-title">
      <h2 id="explorer-demo-title">Interactive AuthorOS explorer</h2>
      <p className="section-copy">
        This is a simulated product demonstration using curated sample data. It is not connected to real user projects.
      </p>

      <div className="explorer-layout">
        <nav aria-label="Explorer modules" className="explorer-nav">
          {explorerPanels.map((panel) => (
            <button
              key={panel.id}
              type="button"
              className={panel.id === activeId ? "explorer-tab is-active" : "explorer-tab"}
              onClick={() => setActiveId(panel.id)}
            >
              {panel.label}
            </button>
          ))}
        </nav>

        <article className="explorer-canvas" aria-live="polite">
          <header>
            <h3>{activePanel?.label}</h3>
            <p>{activePanel?.summary}</p>
          </header>
          <ul className="feature-list">
            {activePanel?.widgets.map((widget) => (
              <li key={widget}>{widget}</li>
            ))}
          </ul>
        </article>
      </div>
    </section>
  );
}

export const authorOsContent = {
  hero: {
    eyebrow: "AuthorOS product experience",
    title: "A focused writing operating system for independent authors",
    summary:
      "AuthorOS combines drafting, planning, continuity awareness, and project protection in one local-first desktop workspace.",
    ctas: [
      { label: "Explore AuthorOS", href: "/explore", style: "primary" as const },
      { label: "View pricing", href: "/pricing", style: "secondary" as const }
    ]
  },
  philosophy: [
    "Writers should not switch tools every 20 minutes to keep story context intact.",
    "Planning and drafting belong in the same workflow, not in disconnected apps.",
    "Data safety and ownership are first-class concerns for long-form creative work.",
    "Commercial services should support the writing tool, not replace local author control."
  ],
  capabilityGroups: [
    {
      title: "Drafting",
      points: [
        "Manuscript, chapter, and scene organization",
        "Session-ready writing workspace",
        "Goal and progress support"
      ]
    },
    {
      title: "Story architecture",
      points: [
        "Plot planning and structure overlays",
        "Continuity checks and conflict signals",
        "Timeline visibility"
      ]
    },
    {
      title: "Character and world context",
      points: [
        "Character references and relationship context",
        "World notes and lore links",
        "Story element traceability"
      ]
    },
    {
      title: "Protection and release",
      points: [
        "Backup and recovery workflows",
        "Export pathways",
        "Version-aware release and update awareness"
      ]
    }
  ],
  workflow: [
    {
      step: "Start with intent",
      detail: "Create a project, define narrative goals, and prepare your story shell."
    },
    {
      step: "Build the structure",
      detail: "Map arcs, scenes, and timeline context before or during drafting."
    },
    {
      step: "Draft with context",
      detail: "Write while keeping characters, plot, and continuity anchors nearby."
    },
    {
      step: "Validate and refine",
      detail: "Review continuity and impact signals to reduce narrative drift."
    },
    {
      step: "Protect and export",
      detail: "Back up project state and export manuscript deliverables."
    }
  ],
  systemRequirements: [
    {
      platform: "Windows",
      requirement: "64-bit OS with modern CPU and 8 GB RAM recommended"
    },
    {
      platform: "macOS",
      requirement: "Recent macOS release with Apple Silicon or Intel support"
    },
    {
      platform: "Linux",
      requirement: "64-bit desktop environment with standard graphics stack"
    }
  ],
  versioning: {
    current: "1.0.0",
    channel: "Stable",
    notes:
      "Version metadata and release notes are served through platform-managed release records."
  },
  roadmapStates: [
    {
      state: "Completed",
      note: "Core writing, planning, and local-first workflows"
    },
    {
      state: "Current",
      note: "Commerce, account, licensing, and download platform layers"
    },
    {
      state: "In Development",
      note: "Interactive explorer depth and support/documentation expansion"
    },
    {
      state: "Planned",
      note: "Operational automation and richer author account services"
    },
    {
      state: "Future Ideas",
      note: "Cloud extensions and ecosystem modules"
    }
  ]
};

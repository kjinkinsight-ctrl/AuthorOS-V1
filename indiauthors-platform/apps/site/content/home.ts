export type HomeFeatureCategory = {
  title: string;
  items: string[];
  availability: "available" | "planned";
};

export const homeContent = {
  hero: {
    kicker: "Software for serious independent authors",
    title:
      "Build stories with AuthorOS. Run your author business with Indie Authors.",
    summary:
      "Indiauthors.com is the commercial and account platform around AuthorOS. Move from discovery to purchase with confidence, then manage licenses, downloads, and support in one place.",
    ctas: [
      { label: "Explore AuthorOS", href: "/explore", style: "primary" as const },
      { label: "Get AuthorOS", href: "/pricing", style: "secondary" as const }
    ]
  },
  valuePillars: [
    {
      title: "Discover",
      body: "Understand who Indie Authors is and why AuthorOS exists for long-form writing workflows."
    },
    {
      title: "Explore",
      body: "Preview key AuthorOS concepts through a guided interactive explorer before purchase."
    },
    {
      title: "Trust",
      body: "Get clear product information, roadmap transparency, and accountable release notes."
    },
    {
      title: "Purchase",
      body: "Buy with backend-verified checkout and entitlement-aware license delivery."
    }
  ],
  featureCategories: [
    {
      title: "Writing",
      availability: "available",
      items: [
        "Manuscript management",
        "Chapters and scenes",
        "Word count awareness",
        "Writing goals",
        "Focus tools"
      ]
    },
    {
      title: "Story Planning",
      availability: "available",
      items: [
        "Plot structure planning",
        "Beat overlays",
        "Story arc visibility",
        "Visual planning boards"
      ]
    },
    {
      title: "Characters and World",
      availability: "available",
      items: [
        "Character profiles",
        "Relationship context",
        "Worldbuilding references",
        "Connected story elements"
      ]
    },
    {
      title: "Protection",
      availability: "available",
      items: [
        "Backup workflows",
        "Export pathways",
        "Recovery confidence",
        "Project preservation"
      ]
    },
    {
      title: "Cloud Extensions",
      availability: "planned",
      items: [
        "Cloud sync",
        "Cross-device settings",
        "Advanced account services"
      ]
    }
  ] as HomeFeatureCategory[],
  roadmap: [
    { lane: "Completed", notes: "Core local-first AuthorOS writing and planning modules" },
    { lane: "Current", notes: "Commercial web platform, accounts, licensing, and downloads" },
    { lane: "In Development", notes: "Interactive AuthorOS explorer and expanded docs/support surfaces" },
    { lane: "Planned", notes: "Operational automation, richer content workflows, and release operations" },
    { lane: "Future Ideas", notes: "Cloud author services, templates, and ecosystem capabilities" }
  ],
  journey: [
    "Discover",
    "Explore",
    "Understand",
    "Create Account",
    "Purchase",
    "Receive License",
    "Download AuthorOS",
    "Use AuthorOS",
    "Manage Account and Support"
  ]
};

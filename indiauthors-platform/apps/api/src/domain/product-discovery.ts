import { z } from "zod";

export const featureCategorySchema = z.object({
  id: z.string().min(1),
  title: z.string().min(1),
  availability: z.enum(["available", "planned"]),
  description: z.string().min(1),
  capabilities: z.array(z.string().min(1)).min(1)
});

export const roadmapItemSchema = z.object({
  id: z.string().min(1),
  lane: z.enum(["completed", "current", "in_development", "planned", "future_ideas"]),
  title: z.string().min(1),
  summary: z.string().min(1),
  updatedAt: z.string().datetime()
});

export type FeatureCategory = z.infer<typeof featureCategorySchema>;
export type RoadmapItem = z.infer<typeof roadmapItemSchema>;

const now = new Date().toISOString();

const featureCategoriesSeed: FeatureCategory[] = [
  {
    id: "writing",
    title: "Writing",
    availability: "available",
    description: "Draft chapters and scenes with sustained context for long-form projects.",
    capabilities: [
      "Manuscript management",
      "Chapter and scene structure",
      "Session writing focus",
      "Progress awareness"
    ]
  },
  {
    id: "story-planning",
    title: "Story Planning",
    availability: "available",
    description: "Map narrative arcs and structural beats without leaving the writing workflow.",
    capabilities: [
      "Plot scaffolding",
      "Story structure overlays",
      "Beat and arc visibility",
      "Planning boards"
    ]
  },
  {
    id: "characters",
    title: "Characters",
    availability: "available",
    description: "Maintain character continuity and relationship context across scenes.",
    capabilities: [
      "Character profiles",
      "Relationship context",
      "Motivation and arc notes",
      "Character-linked references"
    ]
  },
  {
    id: "worldbuilding",
    title: "Worldbuilding",
    availability: "available",
    description: "Track places, lore, and organizations connected to active story threads.",
    capabilities: [
      "Location and lore notes",
      "Faction and organization references",
      "Connected world elements",
      "Cross-reference anchors"
    ]
  },
  {
    id: "organization",
    title: "Organization",
    availability: "available",
    description: "Keep projects, notes, and timeline context aligned as manuscripts grow.",
    capabilities: [
      "Project library",
      "Research and notes",
      "Timeline sequencing",
      "Story workspace structure"
    ]
  },
  {
    id: "protection",
    title: "Protection",
    availability: "available",
    description: "Protect writing progress through backup, export, and recovery workflows.",
    capabilities: [
      "Backup health",
      "Recovery simulation",
      "Export presets",
      "Project preservation"
    ]
  },
  {
    id: "cloud-services",
    title: "Cloud Services",
    availability: "planned",
    description: "Planned account-connected services that extend local-first workflows.",
    capabilities: [
      "Cloud sync",
      "Cross-device settings",
      "Account-linked release services"
    ]
  }
];

const roadmapItemsSeed: RoadmapItem[] = [
  {
    id: "rm-1",
    lane: "completed",
    title: "Local-first writing core",
    summary: "Drafting, planning, continuity, timeline, backup, and export foundations are in place.",
    updatedAt: now
  },
  {
    id: "rm-2",
    lane: "current",
    title: "Commercial website platform",
    summary: "Public product experience, pricing architecture, accounts, licensing, and downloads foundation.",
    updatedAt: now
  },
  {
    id: "rm-3",
    lane: "in_development",
    title: "Interactive explorer and support architecture",
    summary: "Expanding the simulated product explorer and support/documentation experiences.",
    updatedAt: now
  },
  {
    id: "rm-4",
    lane: "planned",
    title: "Operational automation",
    summary: "Admin workflows, release operations, and observability hardening.",
    updatedAt: now
  },
  {
    id: "rm-5",
    lane: "future_ideas",
    title: "Extended author ecosystem",
    summary: "Future cloud extensions, community surfaces, and premium service options.",
    updatedAt: now
  }
];

export function listFeatureCategories(): FeatureCategory[] {
  return featureCategoriesSeed.map((item) => featureCategorySchema.parse(item));
}

export function listRoadmapItems(): RoadmapItem[] {
  return roadmapItemsSeed.map((item) => roadmapItemSchema.parse(item));
}

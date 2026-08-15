export type FeatureCategory = {
  id: string;
  title: string;
  availability: "available" | "planned";
  description: string;
  capabilities: string[];
};

export type RoadmapLane =
  | "completed"
  | "current"
  | "in_development"
  | "planned"
  | "future_ideas";

export type RoadmapItem = {
  id: string;
  lane: RoadmapLane;
  title: string;
  summary: string;
  updatedAt: string;
};

const defaultApiBaseUrl = "http://localhost:4000";

function resolveApiBaseUrl() {
  return process.env.API_BASE_URL ?? process.env.NEXT_PUBLIC_API_BASE_URL ?? defaultApiBaseUrl;
}

export async function fetchFeatureCategories(): Promise<FeatureCategory[]> {
  const response = await fetch(`${resolveApiBaseUrl()}/v1/features/categories`, {
    cache: "no-store",
    headers: { Accept: "application/json" }
  });

  if (!response.ok) {
    throw new Error(`Feature categories fetch failed with status ${response.status}`);
  }

  const payload = (await response.json()) as { items?: FeatureCategory[] };
  return payload.items ?? [];
}

export async function fetchRoadmapItems(): Promise<RoadmapItem[]> {
  const response = await fetch(`${resolveApiBaseUrl()}/v1/roadmap/items`, {
    cache: "no-store",
    headers: { Accept: "application/json" }
  });

  if (!response.ok) {
    throw new Error(`Roadmap fetch failed with status ${response.status}`);
  }

  const payload = (await response.json()) as { items?: RoadmapItem[] };
  return payload.items ?? [];
}

export function laneLabel(lane: RoadmapLane): string {
  switch (lane) {
    case "completed":
      return "Completed";
    case "current":
      return "Current";
    case "in_development":
      return "In Development";
    case "planned":
      return "Planned";
    case "future_ideas":
      return "Future Ideas";
    default:
      return "Planned";
  }
}

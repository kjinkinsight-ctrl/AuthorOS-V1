import type { Metadata } from "next";
import { SiteShell } from "../../components/site-shell";
import { buildPageMetadata } from "../../lib/seo";
import {
  fetchRoadmapItems,
  laneLabel,
  type RoadmapItem
} from "../../lib/product-discovery";

export const metadata: Metadata = buildPageMetadata({
  title: "AuthorOS Roadmap | Indie Authors",
  description:
    "Track AuthorOS delivery states across completed work, current initiatives, active development, and planned priorities.",
  path: "/roadmap",
  keywords: [
    "AuthorOS roadmap",
    "writing software roadmap",
    "indie author platform updates"
  ]
});

export default async function RoadmapPage() {
  let items: RoadmapItem[] = [];
  let fetchError = "";

  try {
    items = await fetchRoadmapItems();
  } catch (error) {
    fetchError = error instanceof Error ? error.message : "Unable to load roadmap items.";
  }

  return (
    <SiteShell>
      <section className="stack" style={{ marginTop: "2rem" }} aria-labelledby="roadmap-title">
        <h1 id="roadmap-title">AuthorOS roadmap</h1>
        <p className="section-copy">
          Roadmap entries are grouped by delivery state and can be updated from backend-managed records.
        </p>

        {fetchError ? (
          <article className="card" role="status" aria-live="polite">
            <h2>Roadmap unavailable</h2>
            <p>{fetchError}</p>
          </article>
        ) : null}

        <div className="grid grid-three">
          {items.map((item) => (
            <article className="card" key={item.id}>
              <p className="status-pill" data-availability={item.lane === "completed" ? "available" : "planned"}>
                {laneLabel(item.lane)}
              </p>
              <h2>{item.title}</h2>
              <p>{item.summary}</p>
            </article>
          ))}
        </div>
      </section>
    </SiteShell>
  );
}

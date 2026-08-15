import type { Metadata } from "next";
import { SiteShell } from "../../components/site-shell";
import { buildPageMetadata } from "../../lib/seo";
import {
  fetchFeatureCategories,
  type FeatureCategory
} from "../../lib/product-discovery";

export const metadata: Metadata = buildPageMetadata({
  title: "AuthorOS Features | Indie Authors",
  description:
    "Review AuthorOS feature categories across writing, planning, characters, worldbuilding, organization, and protection.",
  path: "/features",
  keywords: [
    "AuthorOS features",
    "writing software features",
    "story planning tool"
  ]
});

export default async function FeaturesPage() {
  let items: FeatureCategory[] = [];
  let fetchError = "";

  try {
    items = await fetchFeatureCategories();
  } catch (error) {
    fetchError = error instanceof Error ? error.message : "Unable to load feature catalog.";
  }

  return (
    <SiteShell>
      <section className="stack" style={{ marginTop: "2rem" }} aria-labelledby="features-title">
        <h1 id="features-title">Feature architecture</h1>
        <p className="section-copy">
          AuthorOS capabilities are grouped by workflow so authors can evaluate fit with clarity.
        </p>

        {fetchError ? (
          <article className="card" role="status" aria-live="polite">
            <h2>Feature catalog unavailable</h2>
            <p>{fetchError}</p>
          </article>
        ) : null}

        <div className="grid grid-three">
          {items.map((category) => (
            <article className="card" key={category.id}>
              <p className="status-pill" data-availability={category.availability}>
                {category.availability === "available" ? "Available" : "Planned"}
              </p>
              <h2>{category.title}</h2>
              <p>{category.description}</p>
              <ul className="feature-list">
                {category.capabilities.map((capability) => (
                  <li key={capability}>{capability}</li>
                ))}
              </ul>
            </article>
          ))}
        </div>
      </section>
    </SiteShell>
  );
}

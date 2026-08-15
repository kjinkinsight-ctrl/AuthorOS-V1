import type { Metadata } from "next";
import { SiteShell } from "../../components/site-shell";
import { ExplorerDemo } from "../../components/explorer-demo";
import { buildPageMetadata } from "../../lib/seo";

export const metadata: Metadata = buildPageMetadata({
  title: "Explore AuthorOS | Interactive Demo",
  description:
    "Experience a browser-based simulation of AuthorOS workflows, from dashboard to manuscript, plotting, and project protection.",
  path: "/explore",
  keywords: [
    "AuthorOS demo",
    "writing workflow explorer",
    "story planning demo"
  ]
});

export default function ExplorePage() {
  return (
    <SiteShell>
      <section className="hero" aria-labelledby="explore-title">
        <p className="hero-kicker">Explore before purchase</p>
        <h1 id="explore-title">See how AuthorOS feels across core writing workflows</h1>
        <p className="hero-copy">
          Tour a browser-based representation of key AuthorOS surfaces including manuscript, planning, timeline,
          research, backup, export, and settings.
        </p>
      </section>

      <ExplorerDemo />
    </SiteShell>
  );
}

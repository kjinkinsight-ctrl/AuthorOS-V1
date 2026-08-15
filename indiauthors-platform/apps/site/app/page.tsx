import type { Metadata } from "next";
import Link from "next/link";
import { SiteShell } from "../components/site-shell";
import { homeContent } from "../content/home";
import {
  buildPageMetadata,
  organizationStructuredData,
  softwareStructuredData
} from "../lib/seo";

export const metadata: Metadata = buildPageMetadata({
  title: "Indie Authors | Discover AuthorOS",
  description:
    "Discover Indie Authors and explore AuthorOS with clear product information, roadmap visibility, and secure purchase pathways.",
  path: "/",
  keywords: [
    "author software",
    "book planning software",
    "author productivity",
    "story planning software",
    "AuthorOS"
  ]
});

export default function HomePage() {
  const organizationSchema = organizationStructuredData();
  const softwareSchema = softwareStructuredData();

  return (
    <SiteShell>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(organizationSchema) }}
      />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(softwareSchema) }}
      />

      <section className="hero" aria-labelledby="hero-title">
        <p className="hero-kicker">{homeContent.hero.kicker}</p>
        <h1 id="hero-title">{homeContent.hero.title}</h1>
        <p className="hero-copy">
          {homeContent.hero.summary}
        </p>
        <div className="hero-cta-row">
          {homeContent.hero.ctas.map((cta) => (
            <Link
              key={cta.href}
              className={cta.style === "primary" ? "button-primary" : "button-secondary"}
              href={cta.href}
            >
              {cta.label}
            </Link>
          ))}
        </div>
      </section>

      <section className="grid grid-four" aria-label="Value pillars">
        {homeContent.valuePillars.map((pillar) => (
          <article className="card" key={pillar.title}>
            <h2>{pillar.title}</h2>
            <p>{pillar.body}</p>
          </article>
        ))}
      </section>

      <section className="stack" aria-labelledby="feature-architecture-title">
        <h2 id="feature-architecture-title">Feature architecture</h2>
        <p className="section-copy">
          Features are grouped by workflow so visitors can quickly map AuthorOS to their writing process.
          Planned items are clearly marked to avoid overstating current functionality.
        </p>
        <div className="grid grid-three">
          {homeContent.featureCategories.map((category) => (
            <article className="card" key={category.title}>
              <p className="status-pill" data-availability={category.availability}>
                {category.availability === "available" ? "Available" : "Planned"}
              </p>
              <h3>{category.title}</h3>
              <ul className="feature-list">
                {category.items.map((item) => (
                  <li key={item}>{item}</li>
                ))}
              </ul>
            </article>
          ))}
        </div>
      </section>

      <section className="stack" aria-labelledby="journey-title">
        <h2 id="journey-title">Visitor journey</h2>
        <ol className="journey-list">
          {homeContent.journey.map((step) => (
            <li key={step}>{step}</li>
          ))}
        </ol>
      </section>

      <section className="stack" aria-labelledby="roadmap-title">
        <h2 id="roadmap-title">Roadmap states</h2>
        <div className="grid grid-roadmap">
          {homeContent.roadmap.map((item) => (
            <article className="card" key={item.lane}>
              <h3>{item.lane}</h3>
              <p>{item.notes}</p>
            </article>
          ))}
        </div>
      </section>
    </SiteShell>
  );
}

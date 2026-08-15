import type { Metadata } from "next";
import Link from "next/link";
import { SiteShell } from "../../components/site-shell";
import { authorOsContent } from "../../content/authoros";
import { buildPageMetadata } from "../../lib/seo";

export const metadata: Metadata = buildPageMetadata({
  title: "AuthorOS | Product Experience",
  description:
    "Explore AuthorOS philosophy, capabilities, workflows, requirements, and roadmap clarity before purchasing.",
  path: "/authoros",
  keywords: [
    "AuthorOS",
    "novel writing software",
    "book planning software",
    "story writing tool"
  ]
});

export default function AuthorOsPage() {
  return (
    <SiteShell>
      <section className="hero" aria-labelledby="authoros-title">
        <p className="hero-kicker">{authorOsContent.hero.eyebrow}</p>
        <h1 id="authoros-title">{authorOsContent.hero.title}</h1>
        <p className="hero-copy">{authorOsContent.hero.summary}</p>
        <div className="hero-cta-row">
          {authorOsContent.hero.ctas.map((cta) => (
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

      <section className="stack" aria-labelledby="philosophy-title">
        <h2 id="philosophy-title">Product philosophy</h2>
        <ul className="feature-list">
          {authorOsContent.philosophy.map((point) => (
            <li key={point}>{point}</li>
          ))}
        </ul>
      </section>

      <section className="stack" aria-labelledby="capabilities-title">
        <h2 id="capabilities-title">Core capabilities</h2>
        <div className="grid grid-three">
          {authorOsContent.capabilityGroups.map((group) => (
            <article className="card" key={group.title}>
              <h3>{group.title}</h3>
              <ul className="feature-list">
                {group.points.map((point) => (
                  <li key={point}>{point}</li>
                ))}
              </ul>
            </article>
          ))}
        </div>
      </section>

      <section className="stack" aria-labelledby="workflow-title">
        <h2 id="workflow-title">Workflow</h2>
        <ol className="journey-list">
          {authorOsContent.workflow.map((item) => (
            <li key={item.step}>
              <strong>{item.step}:</strong> {item.detail}
            </li>
          ))}
        </ol>
      </section>

      <section className="stack" aria-labelledby="requirements-title">
        <h2 id="requirements-title">System requirements</h2>
        <div className="grid grid-three">
          {authorOsContent.systemRequirements.map((entry) => (
            <article className="card" key={entry.platform}>
              <h3>{entry.platform}</h3>
              <p>{entry.requirement}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="stack" aria-labelledby="version-title">
        <h2 id="version-title">Version information</h2>
        <article className="card">
          <p>
            <strong>Current version:</strong> {authorOsContent.versioning.current}
          </p>
          <p>
            <strong>Release channel:</strong> {authorOsContent.versioning.channel}
          </p>
          <p>{authorOsContent.versioning.notes}</p>
        </article>
      </section>

      <section className="stack" aria-labelledby="authoros-roadmap-title">
        <h2 id="authoros-roadmap-title">Roadmap</h2>
        <div className="grid grid-roadmap">
          {authorOsContent.roadmapStates.map((item) => (
            <article className="card" key={item.state}>
              <h3>{item.state}</h3>
              <p>{item.note}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="stack" aria-label="Download and purchase actions">
        <div className="hero-cta-row">
          <Link className="button-primary" href="/pricing">
            Purchase AuthorOS
          </Link>
          <Link className="button-secondary" href="/account">
            Access downloads
          </Link>
        </div>
      </section>
    </SiteShell>
  );
}

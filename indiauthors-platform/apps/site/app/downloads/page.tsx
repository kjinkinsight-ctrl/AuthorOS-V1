import type { Metadata } from "next";
import { SiteShell } from "../../components/site-shell";
import { buildPageMetadata } from "../../lib/seo";
import { fetchDownloadConfig, fetchEntitledReleases } from "../../lib/downloads";

export const metadata: Metadata = buildPageMetadata({
  title: "Download Centre | Indie Authors",
  description:
    "Access AuthorOS release builds with entitlement-aware download controls and versioned release notes.",
  path: "/downloads",
  keywords: [
    "AuthorOS download",
    "license downloads",
    "software release notes"
  ]
});

export default async function DownloadsPage() {
  const [config, releases] = await Promise.all([
    fetchDownloadConfig(),
    fetchEntitledReleases("authoros-desktop")
  ]);

  const releaseItems = releases.data?.items ?? [];

  return (
    <SiteShell>
      <section className="stack" style={{ marginTop: "2rem" }} aria-labelledby="downloads-title">
        <h1 id="downloads-title">AuthorOS Download Centre</h1>
        <p className="section-copy">
          Release artifacts are served through entitlement-gated API flows. Frontend pages do not self-authorize downloads.
        </p>

        <article className="card">
          <h2>Delivery configuration</h2>
          <p>
            <strong>Config endpoint status:</strong> {config.status}
          </p>
          <p>
            <strong>Signing configured:</strong> {config.data?.signingConfigured ? "Yes" : "No"}
          </p>
          <p>
            <strong>URL TTL:</strong> {config.data?.urlTtlSeconds ?? "unknown"}
          </p>
        </article>

        <article className="card">
          <h2>Entitled release listing</h2>
          <p>
            <strong>Catalog endpoint status:</strong> {releases.status}
          </p>
          {releases.status !== 200 ? (
            <p>
              {releases.data?.summary ??
                "Sign-in and entitlement are required to list downloadable release artifacts."}
            </p>
          ) : null}
        </article>

        <div className="grid grid-three">
          {releaseItems.map((release) => (
            <article className="card" key={release.id}>
              <p className="status-pill" data-availability={release.channel === "stable" ? "available" : "planned"}>
                {release.channel.toUpperCase()}
              </p>
              <h2>{release.version}</h2>
              <p>{release.notes}</p>
              <ul className="feature-list">
                {release.artifacts.map((artifact) => (
                  <li key={`${release.id}-${artifact.platform}`}>
                    <strong>{artifact.platform}</strong>: {artifact.fileName}
                  </li>
                ))}
              </ul>
            </article>
          ))}
        </div>
      </section>
    </SiteShell>
  );
}

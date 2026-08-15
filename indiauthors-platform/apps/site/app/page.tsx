import Link from "next/link";
import { SiteShell } from "../components/site-shell";

export default function HomePage() {
  return (
    <SiteShell>
      <section className="hero" aria-labelledby="hero-title">
        <p className="hero-kicker">Software for serious independent authors</p>
        <h1 id="hero-title">Build stories with AuthorOS. Run your author business with Indie Authors.</h1>
        <p className="hero-copy">
          Indiauthors.com is the commercial and account home around AuthorOS.
          Discover features, explore the product, purchase licenses, and manage downloads and support.
        </p>
        <div className="hero-cta-row">
          <Link className="button-primary" href="/explore">Explore AuthorOS</Link>
          <Link className="button-secondary" href="/pricing">Get AuthorOS</Link>
        </div>
      </section>

      <section className="grid" aria-label="Foundation modules">
        <article className="card">
          <h2>Public Platform</h2>
          <p>Marketing, product, roadmap, docs, and journal are delivered here for discovery and trust.</p>
        </article>
        <article className="card">
          <h2>Commercial Core</h2>
          <p>Pricing, checkout, order confirmation, and licensing run through backend authority.</p>
        </article>
        <article className="card">
          <h2>Account and Support</h2>
          <p>Users can access profile, licenses, downloads, and support workflows in one account space.</p>
        </article>
      </section>
    </SiteShell>
  );
}

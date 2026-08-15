import { SiteShell } from "../../components/site-shell";

export default function ExplorePage() {
  return (
    <SiteShell>
      <section className="card" style={{ marginTop: "2rem" }}>
        <h1>Explore AuthorOS</h1>
        <p>This route will host the interactive browser-based AuthorOS explorer in W05, using simulated data only.</p>
      </section>
    </SiteShell>
  );
}

import { SiteShell } from "../../components/site-shell";

export default function PricingPage() {
  return (
    <SiteShell>
      <section className="card" style={{ marginTop: "2rem" }}>
        <h1>Pricing and Purchase</h1>
        <p>This route will consume backend product and pricing data in W07. No frontend payment authority is implemented.</p>
      </section>
    </SiteShell>
  );
}

import { SiteShell } from "../../components/site-shell";

export default function AccountPage() {
  return (
    <SiteShell>
      <section className="card" style={{ marginTop: "2rem" }}>
        <h1>Account Dashboard</h1>
        <p>This route is reserved for W08-W10 account, license, and downloads workflows with secure backend auth.</p>
      </section>
    </SiteShell>
  );
}

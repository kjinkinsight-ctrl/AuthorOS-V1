import type { Metadata } from "next";
import { SiteShell } from "../../components/site-shell";
import { buildPageMetadata } from "../../lib/seo";
import { fetchAccountSummary, fetchAuthConfig } from "../../lib/account";

export const metadata: Metadata = buildPageMetadata({
  title: "Account | Indie Authors",
  description:
    "Manage profile, licenses, downloads, purchases, devices, and support requests through your Indie Authors account.",
  path: "/account",
  keywords: [
    "author account",
    "AuthorOS licenses",
    "software downloads"
  ]
});

export default async function AccountPage() {
  const authConfig = await fetchAuthConfig();
  const accountSummary = await fetchAccountSummary();

  const accountAreas = [
    "Profile",
    "Licenses",
    "Purchases",
    "Downloads",
    "Devices",
    "Support Requests",
    "Account Settings"
  ];

  return (
    <SiteShell>
      <section className="stack" style={{ marginTop: "2rem" }} aria-labelledby="account-title">
        <h1 id="account-title">Account dashboard architecture</h1>
        <p className="section-copy">
          This account surface is connected to backend auth and session boundaries. It does not fabricate user identity,
          purchases, or licenses.
        </p>

        <article className="card">
          <h2>Authentication status</h2>
          {authConfig ? (
            <>
              <p>
                <strong>Mode:</strong> {authConfig.mode}
              </p>
              <p>
                <strong>Provider:</strong> {authConfig.provider}
              </p>
              <p>
                <strong>Integration readiness:</strong> {authConfig.integrationReady ? "Ready" : "Not configured"}
              </p>
            </>
          ) : (
            <p>Unable to load authentication configuration.</p>
          )}
        </article>

        <article className="card">
          <h2>Account access check</h2>
          <p>
            <strong>Endpoint status:</strong> {accountSummary.status}
          </p>
          <p>{accountSummary.data?.summary ?? "No summary returned."}</p>
          {accountSummary.data?.error ? (
            <p>
              <strong>Code:</strong> {accountSummary.data.error}
            </p>
          ) : null}
        </article>

        <article className="card">
          <h2>Account modules</h2>
          <ul className="feature-list">
            {accountAreas.map((area) => (
              <li key={area}>{area}</li>
            ))}
          </ul>
        </article>
      </section>
    </SiteShell>
  );
}

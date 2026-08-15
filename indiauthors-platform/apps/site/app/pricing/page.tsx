import type { Metadata } from "next";
import { SiteShell } from "../../components/site-shell";
import { buildPageMetadata } from "../../lib/seo";
import {
  fetchCatalogProducts,
  formatMinorCurrency,
  type CatalogProduct
} from "../../lib/catalog";

export const metadata: Metadata = buildPageMetadata({
  title: "AuthorOS Pricing | Indie Authors",
  description:
    "Review AuthorOS license options and pricing. Checkout is backend-verified for secure order and license delivery.",
  path: "/pricing",
  keywords: [
    "AuthorOS pricing",
    "author software license",
    "indie author tools pricing"
  ]
});

export default async function PricingPage() {
  let products: CatalogProduct[] = [];
  let fetchError = "";

  try {
    products = await fetchCatalogProducts();
  } catch (error) {
    fetchError = error instanceof Error ? error.message : "Unable to load pricing catalog.";
  }

  return (
    <SiteShell>
      <section className="stack" style={{ marginTop: "2rem" }} aria-labelledby="pricing-title">
        <h1 id="pricing-title">Pricing and purchase</h1>
        <p className="section-copy">
          Pricing is served from backend catalog data so product, license, and promotional rules can evolve without
          frontend rewrites.
        </p>

        {fetchError ? (
          <article className="card" role="status" aria-live="polite">
            <h2>Catalog temporarily unavailable</h2>
            <p>{fetchError}</p>
          </article>
        ) : null}

        <div className="grid grid-three">
          {products.map((product) => (
            <article className="card" key={product.productCode}>
              <p className="status-pill" data-availability={product.availability === "active" ? "available" : "planned"}>
                {product.availability === "active" ? "Available" : "Coming soon"}
              </p>
              <h2>{product.name}</h2>
              <p>{product.description}</p>
              <ul className="feature-list">
                {product.licenseTypes.map((license) => {
                  const currentPrice = formatMinorCurrency(license.priceAmountMinor, license.currency);
                  const compareAt =
                    typeof license.compareAtAmountMinor === "number"
                      ? formatMinorCurrency(license.compareAtAmountMinor, license.currency)
                      : null;

                  return (
                    <li key={`${product.productCode}-${license.licenseType}`}>
                      <strong>{license.title}</strong> ({license.billingModel === "one_time" ? "One-time" : "Subscription"})
                      <div>
                        <span>{currentPrice}</span>
                        {compareAt ? <span className="compare-price"> {compareAt}</span> : null}
                      </div>
                      {license.promoLabel ? <span className="promo-label">{license.promoLabel}</span> : null}
                    </li>
                  );
                })}
              </ul>
            </article>
          ))}
        </div>
      </section>
    </SiteShell>
  );
}

export type CatalogLicenseType = {
  licenseType: string;
  title: string;
  billingModel: "one_time" | "subscription";
  priceAmountMinor: number;
  currency: string;
  compareAtAmountMinor?: number;
  promoLabel?: string;
};

export type CatalogProduct = {
  productCode: string;
  name: string;
  description: string;
  licenseTypes: CatalogLicenseType[];
  availability: "active" | "coming_soon";
};

export async function fetchCatalogProducts(): Promise<CatalogProduct[]> {
  const apiBaseUrl =
    process.env.API_BASE_URL ?? process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:4000";

  const response = await fetch(`${apiBaseUrl}/v1/catalog/products`, {
    cache: "no-store",
    headers: {
      Accept: "application/json"
    }
  });

  if (!response.ok) {
    throw new Error(`Catalog fetch failed with status ${response.status}`);
  }

  const payload = (await response.json()) as { items?: CatalogProduct[] };
  return payload.items ?? [];
}

export function formatMinorCurrency(amountMinor: number, currency: string): string {
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency,
    maximumFractionDigits: 2
  }).format(amountMinor / 100);
}

import { z } from "zod";

export const catalogLicenseTypeSchema = z.object({
  licenseType: z.string().min(1),
  title: z.string().min(1),
  billingModel: z.enum(["one_time", "subscription"]),
  priceAmountMinor: z.number().int().nonnegative(),
  currency: z.string().length(3),
  compareAtAmountMinor: z.number().int().nonnegative().optional(),
  promoLabel: z.string().min(1).optional()
});

export const catalogProductSchema = z.object({
  productCode: z.string().min(1),
  name: z.string().min(1),
  description: z.string().min(1),
  availability: z.enum(["active", "coming_soon"]),
  licenseTypes: z.array(catalogLicenseTypeSchema).min(1)
});

export type CatalogProduct = z.infer<typeof catalogProductSchema>;

const catalogSeed: CatalogProduct[] = [
  {
    productCode: "authoros-desktop",
    name: "AuthorOS Desktop",
    description:
      "Local-first writing and planning workspace for independent authors.",
    availability: "active",
    licenseTypes: [
      {
        licenseType: "personal_lifetime",
        title: "Personal Lifetime",
        billingModel: "one_time",
        priceAmountMinor: 9900,
        compareAtAmountMinor: 12900,
        currency: "INR",
        promoLabel: "Launch offer"
      },
      {
        licenseType: "professional_lifetime",
        title: "Professional Lifetime",
        billingModel: "one_time",
        priceAmountMinor: 14900,
        currency: "INR"
      }
    ]
  },
  {
    productCode: "authoros-studio-plus",
    name: "AuthorOS Studio Plus",
    description:
      "Expanded services bundle reserved for future online account features.",
    availability: "coming_soon",
    licenseTypes: [
      {
        licenseType: "plus_subscription",
        title: "Studio Plus",
        billingModel: "subscription",
        priceAmountMinor: 899,
        currency: "INR",
        promoLabel: "Planned"
      }
    ]
  }
];

export function listCatalogProducts(): CatalogProduct[] {
  return catalogSeed.map((item) => catalogProductSchema.parse(item));
}

export function getCatalogProduct(productCode: string): CatalogProduct | null {
  const record = catalogSeed.find((item) => item.productCode === productCode);
  return record ? catalogProductSchema.parse(record) : null;
}

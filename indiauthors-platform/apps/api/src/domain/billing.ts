import { z } from "zod";

export const purchaseStatusSchema = z.enum([
  "paid",
  "pending",
  "refunded",
  "disputed",
  "failed"
]);

export const billingRecordStatusSchema = z.enum([
  "issued",
  "paid",
  "refunded",
  "void"
]);

export const billingAddressSchema = z.object({
  line1: z.string().min(1),
  line2: z.string().nullable(),
  city: z.string().min(1),
  state: z.string().min(1),
  postalCode: z.string().min(1),
  countryCode: z.string().length(2)
});

export const purchaseLineItemSchema = z.object({
  productCode: z.string().min(1),
  licenseType: z.string().min(1),
  quantity: z.number().int().positive(),
  unitAmountMinor: z.number().int().nonnegative(),
  lineTotalAmountMinor: z.number().int().nonnegative()
});

export const purchaseRecordSchema = z.object({
  id: z.string().uuid(),
  userId: z.string().min(1),
  orderNumber: z.string().min(1),
  paymentProvider: z.string().min(1),
  paymentReference: z.string().min(1),
  status: purchaseStatusSchema,
  currency: z.string().regex(/^[A-Z]{3}$/),
  subtotalAmountMinor: z.number().int().nonnegative(),
  taxAmountMinor: z.number().int().nonnegative(),
  totalAmountMinor: z.number().int().nonnegative(),
  purchasedAt: z.string().datetime(),
  lineItems: z.array(purchaseLineItemSchema).min(1),
  licenseId: z.string().uuid(),
  invoiceNumber: z.string().min(1)
});

export const billingRecordSchema = z.object({
  id: z.string().uuid(),
  userId: z.string().min(1),
  purchaseId: z.string().uuid(),
  invoiceNumber: z.string().min(1),
  status: billingRecordStatusSchema,
  currency: z.string().regex(/^[A-Z]{3}$/),
  subtotalAmountMinor: z.number().int().nonnegative(),
  taxAmountMinor: z.number().int().nonnegative(),
  totalAmountMinor: z.number().int().nonnegative(),
  issuedAt: z.string().datetime(),
  paidAt: z.string().datetime().nullable(),
  buyerLegalName: z.string().min(1),
  buyerTaxId: z.string().nullable(),
  billingAddress: billingAddressSchema,
  metadata: z.record(z.string(), z.string()).default({})
});

export type PurchaseRecord = z.infer<typeof purchaseRecordSchema>;
export type BillingRecord = z.infer<typeof billingRecordSchema>;

const purchaseStore: PurchaseRecord[] = [
  {
    id: "9dbf3d9e-4ffc-425f-bda9-71828df4f2bb",
    userId: "user_demo_active",
    orderNumber: "ORD-2026-00031",
    paymentProvider: "stripe",
    paymentReference: "pi_3QxZ3kA9Ha",
    status: "paid",
    currency: "INR",
    subtotalAmountMinor: 599900,
    taxAmountMinor: 107982,
    totalAmountMinor: 707882,
    purchasedAt: "2026-07-21T09:30:00.000Z",
    lineItems: [
      {
        productCode: "authoros-desktop",
        licenseType: "personal_lifetime",
        quantity: 1,
        unitAmountMinor: 599900,
        lineTotalAmountMinor: 599900
      }
    ],
    licenseId: "8d2084bc-8aa3-42db-8b27-a17e70ba7f46",
    invoiceNumber: "INV-2026-00128"
  },
  {
    id: "3414f8ce-f9c3-47f1-90d5-fc9de3e9ba34",
    userId: "user_demo_suspended",
    orderNumber: "ORD-2026-00018",
    paymentProvider: "stripe",
    paymentReference: "pi_3QwR2dM2Xx",
    status: "disputed",
    currency: "INR",
    subtotalAmountMinor: 899900,
    taxAmountMinor: 161982,
    totalAmountMinor: 1061882,
    purchasedAt: "2026-06-10T12:00:00.000Z",
    lineItems: [
      {
        productCode: "authoros-desktop",
        licenseType: "professional_lifetime",
        quantity: 1,
        unitAmountMinor: 899900,
        lineTotalAmountMinor: 899900
      }
    ],
    licenseId: "2e122ef7-4478-4c50-b035-4ca1fd99b0e1",
    invoiceNumber: "INV-2026-00079"
  }
].map((purchase) => purchaseRecordSchema.parse(purchase));

const billingStore: BillingRecord[] = [
  {
    id: "5e8d1adb-6200-4f3b-b47f-c6f7cfee63ee",
    userId: "user_demo_active",
    purchaseId: "9dbf3d9e-4ffc-425f-bda9-71828df4f2bb",
    invoiceNumber: "INV-2026-00128",
    status: "paid",
    currency: "INR",
    subtotalAmountMinor: 599900,
    taxAmountMinor: 107982,
    totalAmountMinor: 707882,
    issuedAt: "2026-07-21T09:33:00.000Z",
    paidAt: "2026-07-21T09:35:00.000Z",
    buyerLegalName: "Priya Menon",
    buyerTaxId: "29ABCDE1234F1Z6",
    billingAddress: {
      line1: "14 Banyan Street",
      line2: null,
      city: "Bengaluru",
      state: "Karnataka",
      postalCode: "560034",
      countryCode: "IN"
    },
    metadata: {
      invoiceSchema: "india-gst-v1",
      paymentTerms: "due_on_receipt"
    }
  },
  {
    id: "4f73f257-a1e8-4897-a53d-877f1200fc4f",
    userId: "user_demo_suspended",
    purchaseId: "3414f8ce-f9c3-47f1-90d5-fc9de3e9ba34",
    invoiceNumber: "INV-2026-00079",
    status: "refunded",
    currency: "INR",
    subtotalAmountMinor: 899900,
    taxAmountMinor: 161982,
    totalAmountMinor: 1061882,
    issuedAt: "2026-06-10T12:03:00.000Z",
    paidAt: "2026-06-10T12:06:00.000Z",
    buyerLegalName: "Rohan Patel",
    buyerTaxId: null,
    billingAddress: {
      line1: "22 Green Residency",
      line2: "Flat 7C",
      city: "Ahmedabad",
      state: "Gujarat",
      postalCode: "380015",
      countryCode: "IN"
    },
    metadata: {
      invoiceSchema: "india-gst-v1",
      refundReason: "charge_dispute"
    }
  }
].map((record) => billingRecordSchema.parse(record));

export function listPurchasesForUser(userId: string): PurchaseRecord[] {
  return purchaseStore
    .filter((purchase) => purchase.userId === userId)
    .sort((a, b) => (a.purchasedAt < b.purchasedAt ? 1 : -1));
}

export function listBillingRecordsForUser(userId: string): BillingRecord[] {
  return billingStore
    .filter((record) => record.userId === userId)
    .sort((a, b) => (a.issuedAt < b.issuedAt ? 1 : -1));
}

export function evaluatePurchaseEligibilityForLicense(licenseId: string): {
  eligible: boolean;
  reason:
    | "ok"
    | "purchase_not_found"
    | "purchase_not_settled"
    | "invoice_not_found"
    | "invoice_not_settled";
  purchase: PurchaseRecord | null;
  billingRecord: BillingRecord | null;
} {
  const purchase =
    purchaseStore.find((candidate) => candidate.licenseId === licenseId) ?? null;

  if (!purchase) {
    return {
      eligible: false,
      reason: "purchase_not_found",
      purchase: null,
      billingRecord: null
    };
  }

  if (purchase.status !== "paid") {
    return {
      eligible: false,
      reason: "purchase_not_settled",
      purchase,
      billingRecord: null
    };
  }

  const billingRecord =
    billingStore.find((record) => record.purchaseId === purchase.id) ?? null;

  if (!billingRecord) {
    return {
      eligible: false,
      reason: "invoice_not_found",
      purchase,
      billingRecord: null
    };
  }

  if (billingRecord.status !== "paid") {
    return {
      eligible: false,
      reason: "invoice_not_settled",
      purchase,
      billingRecord
    };
  }

  return {
    eligible: true,
    reason: "ok",
    purchase,
    billingRecord
  };
}

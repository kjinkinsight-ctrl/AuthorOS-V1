import { z } from "zod";

export const licenseStatusSchema = z.enum([
  "active",
  "suspended",
  "expired",
  "revoked",
  "cancelled"
]);

export const versionAccessSchema = z.object({
  minVersion: z.string().min(1),
  maxVersion: z.string().nullable()
});

export const licenseSchema = z.object({
  id: z.string().uuid(),
  userId: z.string().min(1),
  productCode: z.string().min(1),
  licenseType: z.string().min(1),
  status: licenseStatusSchema,
  purchaseDate: z.string().datetime(),
  activationDate: z.string().datetime().nullable(),
  expiryDate: z.string().datetime().nullable(),
  allowedDevices: z.number().int().positive(),
  versionAccess: versionAccessSchema,
  devices: z.array(z.string().min(1)).default([])
});

export const verifyEntitlementInputSchema = z.object({
  userId: z.string().min(1),
  productCode: z.string().min(1),
  appVersion: z.string().min(1),
  deviceId: z.string().min(1)
});

export type LicenseStatus = z.infer<typeof licenseStatusSchema>;
export type LicenseRecord = z.infer<typeof licenseSchema>;
export type VerifyEntitlementInput = z.infer<typeof verifyEntitlementInputSchema>;

const licenseStore: LicenseRecord[] = [
  {
    id: "8d2084bc-8aa3-42db-8b27-a17e70ba7f46",
    userId: "user_demo_active",
    productCode: "authoros-desktop",
    licenseType: "personal_lifetime",
    status: "active",
    purchaseDate: "2026-07-21T09:30:00.000Z",
    activationDate: "2026-07-21T10:00:00.000Z",
    expiryDate: null,
    allowedDevices: 2,
    versionAccess: {
      minVersion: "1.0.0",
      maxVersion: null
    },
    devices: ["device-a"]
  },
  {
    id: "2e122ef7-4478-4c50-b035-4ca1fd99b0e1",
    userId: "user_demo_suspended",
    productCode: "authoros-desktop",
    licenseType: "professional_lifetime",
    status: "suspended",
    purchaseDate: "2026-06-10T12:00:00.000Z",
    activationDate: "2026-06-10T12:30:00.000Z",
    expiryDate: null,
    allowedDevices: 3,
    versionAccess: {
      minVersion: "1.0.0",
      maxVersion: null
    },
    devices: ["device-z"]
  }
].map((record) => licenseSchema.parse(record));

const allowedTransitions: Record<LicenseStatus, Set<LicenseStatus>> = {
  active: new Set(["suspended", "expired", "revoked", "cancelled"]),
  suspended: new Set(["active", "expired", "revoked", "cancelled"]),
  expired: new Set(["active", "revoked", "cancelled"]),
  revoked: new Set([]),
  cancelled: new Set([])
};

function parseVersionParts(version: string): number[] {
  const parts = version
    .split(".")
    .map((part) => Number.parseInt(part.replace(/\D/g, ""), 10))
    .filter((value) => Number.isFinite(value));

  return parts.length > 0 ? parts : [0];
}

function compareVersions(left: string, right: string): number {
  const leftParts = parseVersionParts(left);
  const rightParts = parseVersionParts(right);
  const maxLen = Math.max(leftParts.length, rightParts.length);

  for (let i = 0; i < maxLen; i += 1) {
    const l = leftParts[i] ?? 0;
    const r = rightParts[i] ?? 0;

    if (l > r) {
      return 1;
    }

    if (l < r) {
      return -1;
    }
  }

  return 0;
}

export function listLicensesForUser(userId: string): LicenseRecord[] {
  return licenseStore.filter((license) => license.userId === userId);
}

export function transitionLicenseStatus(
  licenseId: string,
  nextStatus: LicenseStatus
): { ok: true; license: LicenseRecord } | { ok: false; error: string } {
  const idx = licenseStore.findIndex((license) => license.id === licenseId);

  if (idx < 0) {
    return { ok: false, error: "license_not_found" };
  }

  const current = licenseStore[idx]!;
  if (current.status === nextStatus) {
    return { ok: true, license: current };
  }

  if (!allowedTransitions[current.status].has(nextStatus)) {
    return { ok: false, error: "invalid_status_transition" };
  }

  const updated: LicenseRecord = {
    ...current,
    status: nextStatus,
    expiryDate:
      nextStatus === "expired" && current.expiryDate === null
        ? new Date().toISOString()
        : current.expiryDate
  };

  licenseStore[idx] = licenseSchema.parse(updated);
  return { ok: true, license: licenseStore[idx]! };
}

export function verifyEntitlement(input: VerifyEntitlementInput): {
  entitled: boolean;
  reason:
    | "ok"
    | "license_not_found"
    | "inactive_license"
    | "expired_date"
    | "version_out_of_range"
    | "device_limit_reached";
  license: LicenseRecord | null;
} {
  const license = licenseStore.find(
    (item) => item.userId === input.userId && item.productCode === input.productCode
  );

  if (!license) {
    return {
      entitled: false,
      reason: "license_not_found",
      license: null
    };
  }

  if (license.status !== "active") {
    return {
      entitled: false,
      reason: "inactive_license",
      license
    };
  }

  if (license.expiryDate && new Date(license.expiryDate).getTime() < Date.now()) {
    return {
      entitled: false,
      reason: "expired_date",
      license
    };
  }

  if (compareVersions(input.appVersion, license.versionAccess.minVersion) < 0) {
    return {
      entitled: false,
      reason: "version_out_of_range",
      license
    };
  }

  if (
    license.versionAccess.maxVersion &&
    compareVersions(input.appVersion, license.versionAccess.maxVersion) > 0
  ) {
    return {
      entitled: false,
      reason: "version_out_of_range",
      license
    };
  }

  const deviceExists = license.devices.includes(input.deviceId);
  if (!deviceExists && license.devices.length >= license.allowedDevices) {
    return {
      entitled: false,
      reason: "device_limit_reached",
      license
    };
  }

  if (!deviceExists) {
    const updated: LicenseRecord = {
      ...license,
      activationDate: license.activationDate ?? new Date().toISOString(),
      devices: [...license.devices, input.deviceId]
    };

    const index = licenseStore.findIndex((item) => item.id === license.id);
    licenseStore[index] = licenseSchema.parse(updated);
  }

  return {
    entitled: true,
    reason: "ok",
    license: licenseStore.find((item) => item.id === license.id) ?? null
  };
}

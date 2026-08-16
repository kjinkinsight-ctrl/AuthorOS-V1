import { z } from "zod";
import type { LicenseRecord } from "./licenses.js";

export const platformSchema = z.enum(["windows", "macos", "linux"]);

export const releaseArtifactSchema = z.object({
  platform: platformSchema,
  fileName: z.string().min(1),
  fileSizeBytes: z.number().int().positive(),
  checksumSha256: z.string().min(1),
  contentType: z.string().min(1)
});

export const releaseSchema = z.object({
  id: z.string().min(1),
  productCode: z.string().min(1),
  version: z.string().min(1),
  channel: z.enum(["stable", "beta", "legacy"]),
  publishedAt: z.string().datetime(),
  notes: z.string().min(1),
  artifacts: z.array(releaseArtifactSchema).min(1)
});

export const downloadEnvSchema = z.object({
  DOWNLOAD_BASE_URL: z.string().url().default("https://downloads.indiauthors.com"),
  DOWNLOAD_SIGNING_KEY: z.string().optional(),
  DOWNLOAD_URL_TTL_SECONDS: z.coerce.number().int().positive().default(900)
});

export type Platform = z.infer<typeof platformSchema>;
export type ReleaseRecord = z.infer<typeof releaseSchema>;
export type DownloadEnv = z.infer<typeof downloadEnvSchema>;

const releasesStore: ReleaseRecord[] = [
  {
    id: "release-1.0.0",
    productCode: "authoros-desktop",
    version: "1.0.0",
    channel: "stable",
    publishedAt: "2026-08-01T08:00:00.000Z",
    notes: "Initial stable release with local-first manuscript, planning, and backup workflows.",
    artifacts: [
      {
        platform: "windows",
        fileName: "AuthorOS-1.0.0-windows-x64.zip",
        fileSizeBytes: 154321876,
        checksumSha256: "sha256:79f6f797f9afcb9a0cfe1904fd22f2c6b8084e8f2dde634443d2f6a4d38c6174",
        contentType: "application/zip"
      },
      {
        platform: "macos",
        fileName: "AuthorOS-1.0.0-macos.dmg",
        fileSizeBytes: 162019451,
        checksumSha256: "sha256:84a8d1f65c2f9c8a7ced689998f2cd4f9306978d53d1e6e4bc68c3ab8491f2aa",
        contentType: "application/x-apple-diskimage"
      },
      {
        platform: "linux",
        fileName: "AuthorOS-1.0.0-linux-x64.tar.gz",
        fileSizeBytes: 141118023,
        checksumSha256: "sha256:6d2f15f9128fefdd9c149f4f9d96b34c8dc3f99c6bc255a868bce73311afc482",
        contentType: "application/gzip"
      }
    ]
  },
  {
    id: "release-0.9.8",
    productCode: "authoros-desktop",
    version: "0.9.8",
    channel: "legacy",
    publishedAt: "2026-07-10T09:45:00.000Z",
    notes: "Pre-stable candidate with legacy migration safeguards.",
    artifacts: [
      {
        platform: "windows",
        fileName: "AuthorOS-0.9.8-windows-x64.zip",
        fileSizeBytes: 149820552,
        checksumSha256: "sha256:5a3388d90af76ffcfc5f5b2f20dedf1163de0fe7038be32d3978a9db77b4f2bb",
        contentType: "application/zip"
      }
    ]
  }
].map((release) => releaseSchema.parse(release));

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

export function isReleaseWithinLicenseRange(
  releaseVersion: string,
  license: LicenseRecord
): boolean {
  if (compareVersions(releaseVersion, license.versionAccess.minVersion) < 0) {
    return false;
  }

  if (
    license.versionAccess.maxVersion &&
    compareVersions(releaseVersion, license.versionAccess.maxVersion) > 0
  ) {
    return false;
  }

  return true;
}

export function listReleasesForProduct(
  productCode: string,
  platform?: Platform
): ReleaseRecord[] {
  return releasesStore
    .filter((release) => release.productCode === productCode)
    .map((release) => {
      if (!platform) {
        return release;
      }

      return {
        ...release,
        artifacts: release.artifacts.filter((artifact) => artifact.platform === platform)
      };
    })
    .filter((release) => release.artifacts.length > 0)
    .sort((a, b) => (a.publishedAt < b.publishedAt ? 1 : -1));
}

export function findReleaseById(releaseId: string): ReleaseRecord | null {
  return releasesStore.find((release) => release.id === releaseId) ?? null;
}

export function createSignedDownloadUrl(input: {
  releaseId: string;
  platform: Platform;
  fileName: string;
  env: DownloadEnv;
  userId: string;
}): { url: string; expiresAt: string } | null {
  if (!input.env.DOWNLOAD_SIGNING_KEY || input.env.DOWNLOAD_SIGNING_KEY.trim().length === 0) {
    return null;
  }

  const expiry = new Date(Date.now() + input.env.DOWNLOAD_URL_TTL_SECONDS * 1000);
  const tokenPayload = `${input.userId}:${input.releaseId}:${input.platform}:${expiry.toISOString()}`;
  const signature = Buffer.from(
    `${tokenPayload}:${input.env.DOWNLOAD_SIGNING_KEY}`,
    "utf8"
  ).toString("base64url");

  const url = new URL(
    `${input.env.DOWNLOAD_BASE_URL.replace(/\/$/, "")}/authoros/${encodeURIComponent(
      input.fileName
    )}`
  );

  url.searchParams.set("expires", expiry.toISOString());
  url.searchParams.set("sig", signature);

  return {
    url: url.toString(),
    expiresAt: expiry.toISOString()
  };
}

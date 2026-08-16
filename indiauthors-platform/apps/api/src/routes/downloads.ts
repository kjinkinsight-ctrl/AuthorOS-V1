import type { FastifyInstance } from "fastify";
import { z } from "zod";
import type { AuthEnv } from "../domain/auth.js";
import {
  createSignedDownloadUrl,
  downloadEnvSchema,
  findReleaseById,
  isReleaseWithinLicenseRange,
  listReleasesForProduct,
  platformSchema,
  type DownloadEnv
} from "../domain/downloads.js";
import { listLicensesForUser, verifyEntitlement } from "../domain/licenses.js";

const querySchema = z.object({
  productCode: z.string().min(1).default("authoros-desktop"),
  platform: platformSchema.optional()
});

const paramsSchema = z.object({
  releaseId: z.string().min(1)
});

const accessBodySchema = z.object({
  productCode: z.string().min(1).default("authoros-desktop"),
  deviceId: z.string().min(1),
  platform: platformSchema
});

function requireSessionUser(request: any, authEnv: AuthEnv): string | null {
  const token = request.cookies[authEnv.AUTH_SESSION_COOKIE_NAME];
  if (!token) {
    return null;
  }

  return token;
}

export async function registerDownloadRoutes(
  app: FastifyInstance,
  authEnv: AuthEnv,
  downloadEnv: DownloadEnv
) {
  app.get("/v1/downloads/releases", async (request, reply) => {
    const userId = requireSessionUser(request, authEnv);

    if (!userId) {
      reply.status(401);
      return {
        error: "auth_required",
        summary: "Sign in is required to access release downloads."
      };
    }

    const query = querySchema.safeParse(request.query);
    if (!query.success) {
      reply.status(400);
      return {
        error: "invalid_query"
      };
    }

    const licenses = listLicensesForUser(userId).filter(
      (license) =>
        license.productCode === query.data.productCode && license.status === "active"
    );

    if (licenses.length === 0) {
      reply.status(403);
      return {
        error: "not_entitled",
        summary: "No active license is available for this product."
      };
    }

    const releases = listReleasesForProduct(query.data.productCode, query.data.platform).filter(
      (release) => licenses.some((license) => isReleaseWithinLicenseRange(release.version, license))
    );

    return {
      items: releases,
      releaseCount: releases.length
    };
  });

  app.post("/v1/downloads/releases/:releaseId/access", async (request, reply) => {
    const userId = requireSessionUser(request, authEnv);

    if (!userId) {
      reply.status(401);
      return {
        error: "auth_required",
        summary: "Sign in is required to request download access."
      };
    }

    const params = paramsSchema.safeParse(request.params);
    const body = accessBodySchema.safeParse(request.body);

    if (!params.success || !body.success) {
      reply.status(400);
      return {
        error: "invalid_request"
      };
    }

    const release = findReleaseById(params.data.releaseId);
    if (!release || release.productCode !== body.data.productCode) {
      reply.status(404);
      return {
        error: "release_not_found"
      };
    }

    const artifact = release.artifacts.find(
      (candidate) => candidate.platform === body.data.platform
    );

    if (!artifact) {
      reply.status(404);
      return {
        error: "artifact_not_found"
      };
    }

    const entitlement = verifyEntitlement({
      userId,
      productCode: body.data.productCode,
      appVersion: release.version,
      deviceId: body.data.deviceId
    });

    if (!entitlement.entitled) {
      reply.status(403);
      return {
        error: "entitlement_denied",
        reason: entitlement.reason,
        license: entitlement.license
      };
    }

    const signed = createSignedDownloadUrl({
      releaseId: release.id,
      platform: artifact.platform,
      fileName: artifact.fileName,
      env: downloadEnv,
      userId
    });

    if (!signed) {
      reply.status(503);
      return {
        error: "download_signing_not_configured",
        summary:
          "DOWNLOAD_SIGNING_KEY must be configured before secure artifact URLs can be issued."
      };
    }

    return {
      access: "granted",
      releaseId: release.id,
      version: release.version,
      platform: artifact.platform,
      fileName: artifact.fileName,
      checksumSha256: artifact.checksumSha256,
      contentType: artifact.contentType,
      fileSizeBytes: artifact.fileSizeBytes,
      downloadUrl: signed.url,
      expiresAt: signed.expiresAt
    };
  });

  app.get("/v1/downloads/config", async () => {
    return {
      downloadBaseUrl: downloadEnv.DOWNLOAD_BASE_URL,
      signingConfigured:
        !!downloadEnv.DOWNLOAD_SIGNING_KEY &&
        downloadEnv.DOWNLOAD_SIGNING_KEY.trim().length > 0,
      urlTtlSeconds: downloadEnv.DOWNLOAD_URL_TTL_SECONDS
    };
  });
}

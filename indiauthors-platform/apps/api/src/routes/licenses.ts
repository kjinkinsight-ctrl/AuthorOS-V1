import type { FastifyInstance } from "fastify";
import { z } from "zod";
import type { AuthEnv } from "../domain/auth.js";
import {
  licenseStatusSchema,
  listLicensesForUser,
  transitionLicenseStatus,
  verifyEntitlement,
  verifyEntitlementInputSchema
} from "../domain/licenses.js";

const lifecycleSchema = z.object({
  nextStatus: licenseStatusSchema
});

const paramsSchema = z.object({
  licenseId: z.string().uuid()
});

function requireSessionUser(request: any, authEnv: AuthEnv): string | null {
  const token = request.cookies[authEnv.AUTH_SESSION_COOKIE_NAME];
  if (!token) {
    return null;
  }

  return token;
}

export async function registerLicenseRoutes(app: FastifyInstance, authEnv: AuthEnv) {
  app.get("/v1/account/licenses", async (request, reply) => {
    const userId = requireSessionUser(request, authEnv);

    if (!userId) {
      reply.status(401);
      return {
        error: "auth_required",
        summary: "Sign in is required to access licenses."
      };
    }

    return {
      items: listLicensesForUser(userId)
    };
  });

  app.post("/v1/licenses/verify-entitlement", async (request, reply) => {
    const parsed = verifyEntitlementInputSchema.safeParse(request.body);

    if (!parsed.success) {
      reply.status(400);
      return {
        error: "invalid_request"
      };
    }

    return verifyEntitlement(parsed.data);
  });

  app.post("/v1/admin/licenses/:licenseId/status", async (request, reply) => {
    const actor = request.headers["x-admin-subject"];

    if (!actor || typeof actor !== "string") {
      reply.status(403);
      return {
        error: "admin_required"
      };
    }

    const paramsResult = paramsSchema.safeParse(request.params);
    const bodyResult = lifecycleSchema.safeParse(request.body);

    if (!paramsResult.success || !bodyResult.success) {
      reply.status(400);
      return {
        error: "invalid_request"
      };
    }

    const result = transitionLicenseStatus(
      paramsResult.data.licenseId,
      bodyResult.data.nextStatus
    );

    if (!result.ok) {
      const status = result.error === "license_not_found" ? 404 : 409;
      reply.status(status);
      return {
        error: result.error
      };
    }

    return {
      status: "updated",
      actor,
      license: result.license
    };
  });
}

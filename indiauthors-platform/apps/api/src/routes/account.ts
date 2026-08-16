import type { FastifyInstance } from "fastify";
import { buildAuthConfig, type AuthEnv } from "../domain/auth.js";
import {
  listBillingRecordsForUser,
  listPurchasesForUser
} from "../domain/billing.js";

function requireSessionUser(request: any, authEnv: AuthEnv): string | null {
  const token = request.cookies[authEnv.AUTH_SESSION_COOKIE_NAME];
  if (!token) {
    return null;
  }

  return token;
}

export async function registerAccountRoutes(app: FastifyInstance, authEnv: AuthEnv) {
  app.get("/v1/account/summary", async (request, reply) => {
    const authConfig = buildAuthConfig(authEnv);

    if (!authConfig.integrationReady) {
      reply.status(503);
      return {
        error: "auth_integration_required",
        summary:
          "Account services require external identity provider integration before production use."
      };
    }

    const sessionCookie = request.cookies[authEnv.AUTH_SESSION_COOKIE_NAME];

    if (!sessionCookie) {
      reply.status(401);
      return {
        error: "auth_required",
        summary: "Sign in is required to access account data."
      };
    }

    reply.status(501);
    return {
      error: "session_verification_not_implemented",
      summary:
        "Session verification callback integration is required before account data can be returned."
    };
  });

  app.get("/v1/account/purchases", async (request, reply) => {
    const userId = requireSessionUser(request, authEnv);

    if (!userId) {
      reply.status(401);
      return {
        error: "auth_required",
        summary: "Sign in is required to access purchase history."
      };
    }

    const items = listPurchasesForUser(userId);

    return {
      items,
      purchaseCount: items.length
    };
  });

  app.get("/v1/account/billing-records", async (request, reply) => {
    const userId = requireSessionUser(request, authEnv);

    if (!userId) {
      reply.status(401);
      return {
        error: "auth_required",
        summary: "Sign in is required to access billing records."
      };
    }

    const items = listBillingRecordsForUser(userId);

    return {
      items,
      billingRecordCount: items.length
    };
  });
}

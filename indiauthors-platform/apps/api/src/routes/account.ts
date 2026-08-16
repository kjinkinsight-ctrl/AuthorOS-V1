import type { FastifyInstance } from "fastify";
import { buildAuthConfig, type AuthEnv } from "../domain/auth.js";

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
}

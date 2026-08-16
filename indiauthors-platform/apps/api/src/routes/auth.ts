import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { buildAuthConfig, type AuthEnv } from "../domain/auth.js";

const loginStartSchema = z.object({
  returnUrl: z.string().url()
});

export async function registerAuthRoutes(app: FastifyInstance, authEnv: AuthEnv) {
  app.get("/v1/auth/config", async () => {
    return buildAuthConfig(authEnv);
  });

  app.post("/v1/auth/login/start", async (request, reply) => {
    const payload = loginStartSchema.safeParse(request.body);
    if (!payload.success) {
      reply.status(400);
      return {
        error: "invalid_request"
      };
    }

    const authConfig = buildAuthConfig(authEnv);
    if (!authConfig.integrationReady) {
      reply.status(503);
      return {
        error: "auth_integration_required",
        message:
          "Auth provider integration is not configured. Set AUTH_MODE=external_oidc and required provider environment values."
      };
    }

    const authorizeUrl = new URL(authEnv.AUTH_PROVIDER_AUTHORIZE_URL!);
    authorizeUrl.searchParams.set("client_id", authEnv.AUTH_PROVIDER_CLIENT_ID!);
    authorizeUrl.searchParams.set("redirect_uri", authEnv.AUTH_REDIRECT_URL!);
    authorizeUrl.searchParams.set("response_type", "code");
    authorizeUrl.searchParams.set("scope", "openid profile email");
    authorizeUrl.searchParams.set("state", encodeURIComponent(payload.data.returnUrl));

    reply.status(201);
    return {
      authorizeUrl: authorizeUrl.toString()
    };
  });

  app.post("/v1/auth/logout", async (_request, reply) => {
    reply.clearCookie(authEnv.AUTH_SESSION_COOKIE_NAME, {
      path: "/",
      httpOnly: true,
      secure: authEnv.AUTH_SESSION_COOKIE_SECURE,
      sameSite: "lax"
    });

    return {
      status: "logged_out"
    };
  });
}

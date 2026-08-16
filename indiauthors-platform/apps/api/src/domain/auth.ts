import { z } from "zod";

export const authModeSchema = z.enum(["disabled", "external_oidc"]);

export const authEnvSchema = z.object({
  AUTH_MODE: authModeSchema.default("disabled"),
  AUTH_PROVIDER_NAME: z.string().default("OIDC"),
  AUTH_PROVIDER_AUTHORIZE_URL: z.string().url().optional(),
  AUTH_PROVIDER_LOGOUT_URL: z.string().url().optional(),
  AUTH_PROVIDER_CLIENT_ID: z.string().optional(),
  AUTH_REDIRECT_URL: z.string().url().optional(),
  AUTH_SESSION_COOKIE_NAME: z.string().default("ia_session"),
  AUTH_SESSION_COOKIE_SECURE: z
    .enum(["true", "false"])
    .default("true")
    .transform((value) => value === "true")
});

export type AuthEnv = z.infer<typeof authEnvSchema>;

export function buildAuthConfig(env: AuthEnv) {
  const integrationReady =
    env.AUTH_MODE === "external_oidc" &&
    !!env.AUTH_PROVIDER_AUTHORIZE_URL &&
    !!env.AUTH_PROVIDER_CLIENT_ID &&
    !!env.AUTH_REDIRECT_URL;

  return {
    mode: env.AUTH_MODE,
    provider: env.AUTH_PROVIDER_NAME,
    integrationReady,
    capabilities: {
      register: integrationReady,
      login: integrationReady,
      logout: true,
      passwordRecovery: integrationReady,
      accountDashboard: true
    }
  };
}

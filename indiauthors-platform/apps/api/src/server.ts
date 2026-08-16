import cookie from "@fastify/cookie";
import Fastify from "fastify";
import { z } from "zod";
import { authEnvSchema } from "./domain/auth.js";
import { registerSecurityPlugins } from "./plugins/security.js";
import { registerAccountRoutes } from "./routes/account.js";
import { registerAuthRoutes } from "./routes/auth.js";
import { registerCatalogRoutes } from "./routes/catalog.js";
import { registerHealthRoutes } from "./routes/health.js";
import { registerLicenseRoutes } from "./routes/licenses.js";
import { registerProductDiscoveryRoutes } from "./routes/product-discovery.js";

const envSchema = z.object({
  API_PORT: z.coerce.number().int().positive().default(4000),
  PUBLIC_SITE_URL: z.string().url().default("http://localhost:3000")
});

async function buildServer() {
  const env = envSchema.parse(process.env);
  const authEnv = authEnvSchema.parse(process.env);

  const app = Fastify({
    logger: true,
    trustProxy: true
  });

  await app.register(cookie);

  await registerSecurityPlugins(app);
  await registerAuthRoutes(app, authEnv);
  await registerAccountRoutes(app, authEnv);
  await registerLicenseRoutes(app, authEnv);
  await registerHealthRoutes(app);
  await registerCatalogRoutes(app);
  await registerProductDiscoveryRoutes(app);

  app.get("/", async () => {
    return {
      name: "indie-authors-platform-api",
      status: "online"
    };
  });

  return { app, env };
}

const { app, env } = await buildServer();

try {
  await app.listen({
    port: env.API_PORT,
    host: "0.0.0.0"
  });
} catch (error) {
  app.log.error(error);
  process.exit(1);
}

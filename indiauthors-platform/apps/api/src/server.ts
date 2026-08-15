import Fastify from "fastify";
import { z } from "zod";
import { registerSecurityPlugins } from "./plugins/security.js";
import { registerCatalogRoutes } from "./routes/catalog.js";
import { registerHealthRoutes } from "./routes/health.js";

const envSchema = z.object({
  API_PORT: z.coerce.number().int().positive().default(4000),
  PUBLIC_SITE_URL: z.string().url().default("http://localhost:3000")
});

async function buildServer() {
  const env = envSchema.parse(process.env);

  const app = Fastify({
    logger: true,
    trustProxy: true
  });

  await registerSecurityPlugins(app);
  await registerHealthRoutes(app);
  await registerCatalogRoutes(app);

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

import type { FastifyInstance } from "fastify";

export async function registerHealthRoutes(app: FastifyInstance) {
  app.get("/v1/health", async () => {
    return {
      status: "ok",
      service: "indiauthors-platform-api",
      timestamp: new Date().toISOString()
    };
  });
}

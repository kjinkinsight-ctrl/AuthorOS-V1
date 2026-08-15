import type { FastifyInstance } from "fastify";
import { listFeatureCategories, listRoadmapItems } from "../domain/product-discovery.js";

export async function registerProductDiscoveryRoutes(app: FastifyInstance) {
  app.get("/v1/features/categories", async () => {
    return {
      items: listFeatureCategories()
    };
  });

  app.get("/v1/roadmap/items", async () => {
    return {
      items: listRoadmapItems()
    };
  });
}

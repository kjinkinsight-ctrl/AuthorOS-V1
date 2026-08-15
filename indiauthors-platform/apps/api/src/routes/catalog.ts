import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { getCatalogProduct, listCatalogProducts } from "../domain/catalog.js";

const paramsSchema = z.object({
  productCode: z.string().min(1)
});

export async function registerCatalogRoutes(app: FastifyInstance) {
  app.get("/v1/catalog/products", async () => {
    return {
      items: listCatalogProducts()
    };
  });

  app.get("/v1/catalog/products/:productCode", async (request, reply) => {
    const parseResult = paramsSchema.safeParse(request.params);
    if (!parseResult.success) {
      reply.status(400);
      return {
        error: "invalid_product_code"
      };
    }

    const product = getCatalogProduct(parseResult.data.productCode);
    if (!product) {
      reply.status(404);
      return {
        error: "not_found"
      };
    }

    return product;
  });
}

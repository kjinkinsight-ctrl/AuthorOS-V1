import cors from "@fastify/cors";
import helmet from "@fastify/helmet";
import type { FastifyInstance } from "fastify";

export async function registerSecurityPlugins(app: FastifyInstance) {
  await app.register(helmet, {
    global: true,
    contentSecurityPolicy: false
  });

  await app.register(cors, {
    origin: (origin, callback) => {
      const allowedOrigin = process.env.PUBLIC_SITE_URL;

      if (!origin) {
        callback(null, true);
        return;
      }

      if (allowedOrigin && origin === allowedOrigin) {
        callback(null, true);
        return;
      }

      callback(new Error("Origin not allowed"), false);
    },
    credentials: true,
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
  });
}

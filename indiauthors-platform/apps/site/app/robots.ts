import type { MetadataRoute } from "next";
import { siteConfig } from "../content/site";

export default function robots(): MetadataRoute.Robots {
  return {
    rules: {
      userAgent: "*",
      allow: ["/"],
      disallow: ["/admin"]
    },
    sitemap: `${siteConfig.baseUrl}/sitemap.xml`,
    host: siteConfig.domain
  };
}

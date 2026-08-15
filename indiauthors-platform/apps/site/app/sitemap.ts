import type { MetadataRoute } from "next";
import { siteConfig } from "../content/site";

export default function sitemap(): MetadataRoute.Sitemap {
  const now = new Date();

  const routes = ["/", "/authoros", "/explore", "/pricing", "/account"];

  return routes.map((route) => ({
    url: `${siteConfig.baseUrl}${route}`,
    lastModified: now,
    changeFrequency: route === "/" ? "daily" : "weekly",
    priority: route === "/" ? 1 : 0.7
  }));
}

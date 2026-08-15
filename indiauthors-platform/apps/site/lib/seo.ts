import type { Metadata } from "next";
import { siteConfig } from "../content/site";

type SeoInput = {
  title: string;
  description: string;
  path?: string;
  keywords?: string[];
};

export function buildPageMetadata({
  title,
  description,
  path = "/",
  keywords = []
}: SeoInput): Metadata {
  const url = `${siteConfig.baseUrl}${path}`;

  return {
    title,
    description,
    keywords,
    alternates: {
      canonical: url
    },
    openGraph: {
      title,
      description,
      url,
      siteName: siteConfig.brand,
      type: "website"
    },
    twitter: {
      card: "summary_large_image",
      title,
      description
    }
  };
}

export function organizationStructuredData() {
  return {
    "@context": "https://schema.org",
    "@type": "Organization",
    name: siteConfig.brand,
    url: siteConfig.baseUrl,
    brand: {
      "@type": "Brand",
      name: siteConfig.brand
    }
  };
}

export function softwareStructuredData() {
  return {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    name: siteConfig.product,
    applicationCategory: "WritingApplication",
    operatingSystem: "Windows, macOS, Linux",
    publisher: {
      "@type": "Organization",
      name: siteConfig.brand
    }
  };
}

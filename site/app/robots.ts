import type { MetadataRoute } from "next";
import { site } from "@/lib/site";

export default function robots(): MetadataRoute.Robots {
  const production = !process.env.VERCEL_ENV || process.env.VERCEL_ENV === "production";
  return {
    rules: [production ? { userAgent: "*", allow: "/" } : { userAgent: "*", disallow: "/" }],
    sitemap: `${site.url}/sitemap.xml`,
    host: site.url,
  };
}

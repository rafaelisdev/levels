import type { MetadataRoute } from "next";
import { pages } from "@/lib/pages";
import { site } from "@/lib/site";

export default function sitemap(): MetadataRoute.Sitemap {
  const newest = pages.map((p) => p.updated).sort().at(-1)!;
  return [
    { url: site.url, lastModified: newest, changeFrequency: "monthly", priority: 1 },
    { url: `${site.url}/guides`, lastModified: newest, changeFrequency: "monthly", priority: 0.7 },
    ...pages.map((p) => ({
      url: `${site.url}${p.href}`,
      lastModified: p.updated,
      changeFrequency: "monthly" as const,
      priority: p.kind === "changelog" ? 0.4 : 0.8,
    })),
  ];
}

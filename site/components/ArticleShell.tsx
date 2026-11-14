import Link from "next/link";
import type { ReactNode } from "react";
import { InstallCommand } from "@/components/InstallCommand";
import { SiteFooter, SiteHeader } from "@/components/SiteChrome";
import { pages, type PageInfo } from "@/lib/pages";
import { site } from "@/lib/site";

const nice = (iso: string) =>
  new Date(`${iso}T12:00:00Z`).toLocaleDateString("en-US", { year: "numeric", month: "long", day: "numeric", timeZone: "UTC" });

const section = { guide: ["Guides", "/guides"], compare: ["Compare", "/guides"], changelog: ["Changelog", "/changelog"] } as const;

/** Layout for guides, comparisons and the changelog: breadcrumbs, article, install box, related pages, JSON-LD. */
export function ArticleShell({ info, lead, children, cta = true }: { info: PageInfo; lead: ReactNode; children: ReactNode; cta?: boolean }) {
  const [sectionName, sectionHref] = section[info.kind];
  const url = `${site.url}${info.href}`;
  const related = pages.filter((p) => p.href !== info.href && p.kind !== "changelog").slice(0, 4);

  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": info.kind === "changelog" ? "WebPage" : "TechArticle",
        headline: info.title,
        description: info.description,
        url,
        mainEntityOfPage: url,
        datePublished: info.published,
        dateModified: info.updated,
        inLanguage: "en",
        author: { "@type": "Organization", name: "Levels", url: site.url },
        publisher: { "@type": "Organization", name: "Levels", url: site.url, logo: { "@type": "ImageObject", url: `${site.url}/icon.png` } },
        image: `${site.url}/opengraph-image`,
      },
      {
        "@type": "BreadcrumbList",
        itemListElement: [
          { "@type": "ListItem", position: 1, name: "Levels", item: site.url },
          ...(info.kind === "changelog" ? [] : [{ "@type": "ListItem", position: 2, name: sectionName, item: `${site.url}${sectionHref}` }]),
          { "@type": "ListItem", position: info.kind === "changelog" ? 2 : 3, name: info.short, item: url },
        ],
      },
    ],
  };

  return (
    <>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
      <SiteHeader />
      <main className="frame">
        <article className="section article">
          <nav className="crumbs" aria-label="Breadcrumb">
            <Link href="/">Levels</Link>
            {info.kind !== "changelog" && <><span>/</span><Link href={sectionHref}>{sectionName}</Link></>}
            <span>/</span><span aria-current="page">{info.short}</span>
          </nav>
          <h1>{info.title}</h1>
          <p className="article-meta">Updated <time dateTime={info.updated}>{nice(info.updated)}</time></p>
          <div className="article-lead">{lead}</div>
          <div className="prose">{children}</div>

          {cta && (
            <aside className="article-cta">
              <strong>Try Levels</strong>
              <p>A free menu bar app with a volume slider for every app. macOS 14.2 or later for per-app volume.</p>
              <InstallCommand />
            </aside>
          )}

          <nav className="related" aria-label="Related pages">
            <strong>Related</strong>
            <div className="related-grid">
              {related.map((p) => (
                <Link key={p.href} href={p.href} className="related-card">
                  <span>{p.kind === "compare" ? "Compare" : "Guide"}</span>
                  {p.title}
                </Link>
              ))}
            </div>
          </nav>
        </article>
      </main>
      <SiteFooter />
    </>
  );
}

/** "Step 1 ..." style ordered list used in guides. */
export function Steps({ children }: { children: ReactNode }) {
  return <ol className="prose-steps">{children}</ol>;
}

export function Note({ children }: { children: ReactNode }) {
  return <div className="note">{children}</div>;
}

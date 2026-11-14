import type { Metadata } from "next";
import Link from "next/link";
import { SiteFooter, SiteHeader } from "@/components/SiteChrome";
import { pages } from "@/lib/pages";
import { site } from "@/lib/site";

const title = "Mac audio guides and comparisons";
const description = "Short guides to per-app volume, muting single apps and playing sound on two outputs on a Mac, plus fair comparisons with other audio apps.";

export const metadata: Metadata = {
  title,
  description,
  alternates: { canonical: "/guides" },
  openGraph: { type: "website", url: "/guides", title, description },
};

export default function Page() {
  const list = (kind: "guide" | "compare") => pages.filter((p) => p.kind === kind);
  const jsonLd = {
    "@context": "https://schema.org",
    "@type": "CollectionPage",
    name: title,
    description,
    url: `${site.url}/guides`,
    hasPart: pages.filter((p) => p.kind !== "changelog").map((p) => ({ "@type": "TechArticle", headline: p.title, url: `${site.url}${p.href}` })),
  };

  return (
    <>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
      <SiteHeader />
      <main className="frame">
        <section className="section article">
          <nav className="crumbs" aria-label="Breadcrumb"><Link href="/">Levels</Link><span>/</span><span aria-current="page">Guides</span></nav>
          <h1>{title}</h1>
          <div className="article-lead"><p>{description}</p></div>
          {(["guide", "compare"] as const).map((kind) => (
            <div key={kind} className="hub-group">
              <p className="eyebrow">{kind === "guide" ? "Guides" : "Comparisons"}</p>
              <div className="hub-list">
                {list(kind).map((p) => (
                  <Link key={p.href} href={p.href} className="hub-item">
                    <strong>{p.title}</strong>
                    <span>{p.description}</span>
                  </Link>
                ))}
              </div>
            </div>
          ))}
        </section>
      </main>
      <SiteFooter />
    </>
  );
}

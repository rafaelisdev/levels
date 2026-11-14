import Link from "next/link";
import { LevelsMark } from "@/components/LevelsMark";
import { pages } from "@/lib/pages";
import { site } from "@/lib/site";

export const Arrow = () => (
  <svg width={14} height={14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.6} strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
    <path d="M7 17 17 7M9 7h8v8" />
  </svg>
);

export function SiteHeader() {
  return (
    <header className="header">
      <div className="header-in">
        <Link className="brand" href="/" aria-label="Levels home"><LevelsMark size={22} />Levels</Link>
        <nav className="nav" aria-label="Sections">
          <Link href="/#how">How it works</Link>
          <Link href="/#features">Features</Link>
          <Link href="/guides">Guides</Link>
          <Link href="/#install">Install</Link>
          <Link href="/#faq">FAQ</Link>
        </nav>
        <div className="header-actions">
          <a className="btn" href={site.github} target="_blank" rel="noopener">GitHub <Arrow /></a>
          <Link className="btn btn-dark" href="/#install">Install</Link>
        </div>
      </div>
    </header>
  );
}

export function SiteFooter() {
  const guides = pages.filter((p) => p.kind === "guide");
  const compare = pages.filter((p) => p.kind === "compare");
  return (
    <footer className="footer">
      <div className="footer-in">
        <div className="footer-brand">
          <Link className="brand" href="/" style={{ color: "var(--ink)" }}><LevelsMark size={18} />Levels</Link>
          <span>Per-app volume for macOS. Free and open source (MIT).</span>
        </div>
        <nav className="footer-cols" aria-label="Footer">
          <div>
            <strong>Guides</strong>
            {guides.map((p) => <Link key={p.href} href={p.href}>{p.short}</Link>)}
          </div>
          <div>
            <strong>Compare</strong>
            {compare.map((p) => <Link key={p.href} href={p.href}>{p.short}</Link>)}
          </div>
          <div>
            <strong>Project</strong>
            <Link href="/changelog">Changelog</Link>
            <a href={site.github} target="_blank" rel="noopener">GitHub</a>
            <a href={site.releases} target="_blank" rel="noopener">Releases</a>
            <a href="/llms.txt">llms.txt</a>
          </div>
        </nav>
      </div>
    </footer>
  );
}

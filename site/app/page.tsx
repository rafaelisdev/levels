import Image from "next/image";
import Link from "next/link";
import { InstallCommand } from "@/components/InstallCommand";
import { LevelsMark } from "@/components/LevelsMark";
import { PanelDemo, SyncPreview } from "@/components/PanelDemo";
import { Arrow, SiteFooter, SiteHeader } from "@/components/SiteChrome";
import { pages } from "@/lib/pages";
import { faq, features, site } from "@/lib/site";
import hero from "@/public/renders/hero.png";
import macro from "@/public/renders/macro.png";
import top from "@/public/renders/top.png";

/** What the hero badge says about the current version. */
const news: Record<string, string> = {
  "1.3": `now in ${site.languages.length} languages`,
  "1.4": "plays on several outputs in sync",
};

const icon = { width: 18, height: 18, viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", strokeWidth: 1.6, strokeLinecap: "round", strokeLinejoin: "round", "aria-hidden": true } as const;

const jsonLd = {
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "SoftwareApplication",
      name: site.name,
      description: site.description,
      url: site.url,
      image: `${site.url}/opengraph-image`,
      applicationCategory: "UtilitiesApplication",
      operatingSystem: "macOS 14.2 or later (on macOS 11 to 14.1 it controls the output device volume only)",
      softwareVersion: site.version,
      inLanguage: ["en", "es", "de", "fr", "pt", "ru", "ja", "zh-Hans", "ko"],
      downloadUrl: site.zip,
      installUrl: site.github,
      fileSize: "0.8 MB",
      featureList: features,
      license: "https://opensource.org/licenses/MIT",
      isAccessibleForFree: true,
      offers: { "@type": "Offer", price: "0", priceCurrency: "USD" },
    },
    {
      "@type": "FAQPage",
      mainEntity: faq.map(({ q, a }) => ({ "@type": "Question", name: q, acceptedAnswer: { "@type": "Answer", text: a } })),
    },
  ],
};

export default function Home() {
  const guides = pages.filter((p) => p.kind !== "changelog");
  return (
    <>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
      <SiteHeader />

      <main className="frame" id="top">
        <section className="section hero">
          <div>
            <div className="pill"><span className="dot" /><b>v{site.version}</b> {news[site.version]}</div>
            <h1>A volume slider for every app.</h1>
            <p className="lead">
              Levels is a free menu bar app for macOS that gives each app its own volume. Turn a call down
              and keep the music up. It runs on Apple’s Core Audio and installs no drivers.
            </p>
            <InstallCommand />
            <div className="hero-links">
              <a className="btn" href={site.github} target="_blank" rel="noopener">View on GitHub <Arrow /></a>
              <a className="btn" href={site.zip}>Download .zip</a>
            </div>
            <div className="specs">
              <span>Free and open source</span><span>0.8 MB download</span><span>Apple Silicon &amp; Intel</span><span>macOS 14.2+</span><span>{site.languages.length} languages</span>
            </div>
          </div>
          <div className="hero-art">
            <Image src={hero} alt="Levels shown as a white three-fader mixer" priority sizes="(max-width: 960px) 92vw, 560px" />
          </div>
        </section>

        <section className="section" id="how">
          <div className="split">
            <PanelDemo />
            <div>
              <p className="eyebrow">How it works</p>
              <h2>One click away, in the menu bar.</h2>
              <p className="lead">Every app that plays sound gets its own fader. This is the real panel rebuilt for the web: drag the sliders, click an icon to mute, or click the device name to pick outputs.</p>
              <ul className="checks">
                <li><span>Turn a noisy browser down without touching your music.</span></li>
                <li><span>Click an app’s icon to mute it, and click again to bring it back.</span></li>
                <li><span>Click the device name to play on several outputs at once, lined up so they sound together.</span></li>
                <li><span>Each app gets its volume back the next time it plays.</span></li>
              </ul>
            </div>
          </div>
        </section>

        <section className="section" id="features">
          <p className="eyebrow">Features</p>
          <h2>Small app, precise control.</h2>
          <div className="grid">
            <article className="card wide">
              <div className="card-text">
                <h3>Feels like hardware</h3>
                <p>Each app has a fader and a mute button. Volume changes ramp smoothly while you drag.</p>
              </div>
              <div className="card-art">
                <Image src={macro} alt="Close-up of a black fader cap" sizes="(max-width: 720px) 92vw, 420px" />
              </div>
            </article>
            <article className="card">
              <div className="card-icon"><svg {...icon}><rect x="6" y="6" width="12" height="12" rx="2" /><path d="M9 2v4M15 2v4M9 18v4M15 18v4M2 9h4M2 15h4M18 9h4M18 15h4" /></svg></div>
              <h3>Nothing to install in the system</h3>
              <p>Levels uses the process taps Apple added to Core Audio in macOS 14.2. There are no drivers or kernel extensions.</p>
            </article>
            <article className="card wide full">
              <div className="card-text">
                <h3>Several outputs, in sync</h3>
                <p>Play on the Mac’s speakers, a TV and headphones at once. Levels holds the faster outputs back until the slowest catches up, so you hear one sound and no echo. Any device can be nudged by ear.</p>
                <Link className="card-link" href="/guides/sync-audio-outputs-mac">How the sync works</Link>
              </div>
              <div className="card-art sync-art">
                <SyncPreview />
              </div>
            </article>
            <article className="card">
              <div className="card-icon"><svg {...icon}><path d="M6 3h12v18l-6-4-6 4z" /></svg></div>
              <h3>Remembers every app</h3>
              <p>Set your music to 40% once and Levels applies it every time that app starts playing.</p>
            </article>
            <article className="card">
              <div className="card-icon"><svg {...icon}><path d="M12 3 4 6v6c0 4.5 3.4 8.3 8 9 4.6-.7 8-4.5 8-9V6z" /><path d="m9 12 2 2 4-4" /></svg></div>
              <h3>Fails safe</h3>
              <p>If Levels quits, every app returns to its normal volume right away. Audio stays on your Mac.</p>
            </article>
            <article className="card">
              <span className="stat">0.8 MB</span>
              <h3>Native and small</h3>
              <p>That is the whole download: one universal Swift app for Apple Silicon and Intel, with nothing running in the background besides the menu bar icon.</p>
            </article>
            <article className="card wide full">
              <div className="card-text">
                <h3>Stays out of the way</h3>
                <p>There is no Dock icon and no window. Levels opens from the menu bar, closes on Escape and can start at login.</p>
              </div>
              <div className="card-art">
                <Image src={top} className="top-art" alt="Three faders seen from above, the Levels symbol" sizes="(max-width: 720px) 92vw, 520px" />
              </div>
            </article>
          </div>
        </section>

        <section className="section" id="install">
          <p className="eyebrow">Install</p>
          <h2>Ready in under a minute.</h2>
          <ol className="steps">
            <li className="step">
              <div>
                <h3>Install with Homebrew</h3>
                <p>You can also use the curl script. It downloads the latest release, checks its SHA-256 and moves Levels to Applications.</p>
                <InstallCommand />
              </div>
            </li>
            <li className="step">
              <div>
                <h3>Open Levels</h3>
                <p>Launch it from Spotlight or Applications (the curl script opens it for you). Levels has no Dock icon and lives in the menu bar. Click the faders icon to open the panel and press Esc to close it.</p>
              </div>
            </li>
            <li className="step">
              <div>
                <h3>Move a slider</h3>
                <p>The first time, macOS asks for “System Audio Recording Only” access. Allow it once. Levels processes sound on your Mac and never records it.</p>
              </div>
            </li>
          </ol>
          <div className="extras">
            <div className="extra"><strong>Update</strong><code>brew upgrade levels</code></div>
            <div className="extra"><strong>Uninstall</strong><code>brew uninstall --zap levels</code></div>
            <div className="extra">
              <strong>Manual download</strong>
              Get <a href={site.releases} className="mono" style={{ textDecoration: "underline" }}>Levels.zip</a> from GitHub Releases. The app isn’t notarized yet, so macOS blocks the first launch. Open System Settings → Privacy &amp; Security and click “Open Anyway”.
            </div>
          </div>
        </section>

        <section className="section" id="faq">
          <p className="eyebrow">FAQ</p>
          <h2>Common questions</h2>
          <div className="faq">
            {faq.map(({ q, a }) => (
              <details key={q}>
                <summary>{q}</summary>
                <p>{a}</p>
              </details>
            ))}
          </div>
          <div className="guide-links">
            <span className="muted">Guides and comparisons:</span>
            {guides.map((p) => <Link key={p.href} href={p.href}>{p.short}</Link>)}
          </div>
        </section>

        <section className="section cta">
          <LevelsMark size={44} />
          <h2 style={{ marginTop: 22 }}>Turn the call down.<br />Keep the music up.</h2>
          <InstallCommand />
          <div className="hero-links" style={{ justifyContent: "center" }}>
            <a className="btn" href={site.github} target="_blank" rel="noopener">Source on GitHub <Arrow /></a>
          </div>
        </section>
      </main>

      <SiteFooter />
    </>
  );
}

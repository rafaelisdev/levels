import Image from "next/image";
import { InstallCommand } from "@/components/InstallCommand";
import { LevelsMark } from "@/components/LevelsMark";
import { PanelDemo } from "@/components/PanelDemo";
import { faq, site } from "@/lib/site";
import hero from "@/public/renders/hero.png";
import macro from "@/public/renders/macro.png";
import top from "@/public/renders/top.png";

const icon = { width: 18, height: 18, viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", strokeWidth: 1.6, strokeLinecap: "round", strokeLinejoin: "round", "aria-hidden": true } as const;

const Arrow = () => (
  <svg {...icon} width={14} height={14}><path d="M7 17 17 7M9 7h8v8" /></svg>
);

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
      operatingSystem: "macOS 11 or later (per-app volume: macOS 14.2 or later)",
      softwareVersion: site.version,
      downloadUrl: site.zip,
      installUrl: site.github,
      fileSize: "0.8 MB",
      offers: { "@type": "Offer", price: "0", priceCurrency: "USD" },
    },
    {
      "@type": "FAQPage",
      mainEntity: faq.map(({ q, a }) => ({ "@type": "Question", name: q, acceptedAnswer: { "@type": "Answer", text: a } })),
    },
  ],
};

export default function Home() {
  return (
    <>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />

      <header className="header">
        <div className="header-in">
          <a className="brand" href="#top" aria-label="Levels home"><LevelsMark size={22} />Levels</a>
          <nav className="nav" aria-label="Sections">
            <a href="#how">How it works</a>
            <a href="#features">Features</a>
            <a href="#install">Install</a>
            <a href="#faq">FAQ</a>
          </nav>
          <div className="header-actions">
            <a className="btn" href={site.github} target="_blank" rel="noopener">GitHub <Arrow /></a>
            <a className="btn btn-dark" href="#install">Install</a>
          </div>
        </div>
      </header>

      <main className="frame" id="top">
        <section className="section hero">
          <div>
            <div className="pill"><span className="dot" /><b>v{site.version}</b> now on Homebrew</div>
            <h1>A volume slider for every app.</h1>
            <p className="lead">
              Levels lives in your Mac’s menu bar and gives each app its own volume. Turn the call down,
              keep the music up — no drivers, no kernel extensions, just Core Audio.
            </p>
            <InstallCommand />
            <div className="hero-links">
              <a className="btn" href={site.github} target="_blank" rel="noopener">View on GitHub <Arrow /></a>
              <a className="btn" href={site.zip}>Download .zip</a>
            </div>
            <div className="specs">
              <span>Free</span><span>Under 1 MB</span><span>Apple Silicon &amp; Intel</span><span>macOS 11+</span>
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
              <p className="lead">Every app that plays sound shows up with its own fader. Try the panel — it works like the real one.</p>
              <ul className="checks">
                <li><span><b>Per-app sliders.</b> Lower a noisy browser tab without touching your music.</span></li>
                <li><span><b>Click to mute.</b> Tap an app’s icon to silence it, tap again to bring it back.</span></li>
                <li><span><b>Device volume too.</b> The output device and its level sit at the top.</span></li>
                <li><span><b>Remembers.</b> Each app’s level comes back the next time it plays.</span></li>
              </ul>
            </div>
          </div>
        </section>

        <section className="section" id="features">
          <p className="eyebrow">Features</p>
          <h2>Small app. Precise control.</h2>
          <div className="grid">
            <article className="card wide">
              <div className="card-text">
                <h3>Feels like hardware.</h3>
                <p>A fader and a mute button for each app, with smooth gain ramps so nothing clicks or pops while you drag.</p>
              </div>
              <div className="card-art">
                <Image src={macro} alt="Close-up of a black fader cap" sizes="(max-width: 720px) 92vw, 420px" />
              </div>
            </article>
            <article className="card">
              <div className="card-icon"><svg {...icon}><rect x="6" y="6" width="12" height="12" rx="2" /><path d="M9 2v4M15 2v4M9 18v4M15 18v4M2 9h4M2 15h4M18 9h4M18 15h4" /></svg></div>
              <h3>No drivers, no kexts</h3>
              <p>Built on Core Audio process taps from macOS 14.2. Nothing is installed into the system.</p>
            </article>
            <article className="card">
              <div className="card-icon"><svg {...icon}><path d="M6 3h12v18l-6-4-6 4z" /></svg></div>
              <h3>Remembers every app</h3>
              <p>Set your music to 40% once. Levels applies it every time that app starts playing.</p>
            </article>
            <article className="card">
              <div className="card-icon"><svg {...icon}><path d="M12 3 4 6v6c0 4.5 3.4 8.3 8 9 4.6-.7 8-4.5 8-9V6z" /><path d="m9 12 2 2 4-4" /></svg></div>
              <h3>Fails safe</h3>
              <p>If Levels quits, every app returns to its normal volume instantly. Audio never leaves your Mac.</p>
            </article>
            <article className="card">
              <span className="stat">&lt;1 MB</span>
              <h3>Native and tiny</h3>
              <p>A universal Swift binary for Apple Silicon and Intel. No Electron, no background services.</p>
            </article>
            <article className="card wide full">
              <div className="card-text">
                <h3>Made to stay out of the way.</h3>
                <p>No Dock icon and no windows. Levels opens from the menu bar, closes on Escape and can start at login.</p>
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
                <p>Or use the curl script: it downloads the latest release, checks its SHA-256 and moves Levels to Applications.</p>
                <InstallCommand />
              </div>
            </li>
            <li className="step">
              <div>
                <h3>Open it from the menu bar</h3>
                <p>Levels has no Dock icon. Click the faders icon in the menu bar to open the panel; press Esc to close it.</p>
              </div>
            </li>
            <li className="step">
              <div>
                <h3>Move a slider</h3>
                <p>The first time, macOS asks for “System Audio Recording Only” access. Allow it once — Levels processes sound on your Mac and never records it.</p>
              </div>
            </li>
          </ol>
          <div className="extras">
            <div className="extra"><strong>Update</strong><code>brew upgrade levels</code></div>
            <div className="extra"><strong>Uninstall</strong><code>brew uninstall --zap levels</code></div>
            <div className="extra">
              <strong>Manual download</strong>
              Get <a href={site.releases} className="mono" style={{ textDecoration: "underline" }}>Levels.zip</a> from GitHub Releases. The app isn’t notarized yet, so open it the first time with right-click → Open.
            </div>
          </div>
        </section>

        <section className="section" id="faq">
          <p className="eyebrow">FAQ</p>
          <h2>Questions.</h2>
          <div className="faq">
            {faq.map(({ q, a }) => (
              <details key={q}>
                <summary>{q}</summary>
                <p>{a}</p>
              </details>
            ))}
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

      <footer className="footer">
        <div className="footer-in">
          <a className="brand" href="#top" style={{ color: "var(--ink)" }}><LevelsMark size={18} />Levels</a>
          <span>Per-app volume for macOS.</span>
          <nav aria-label="Footer">
            <a href={site.github} target="_blank" rel="noopener">GitHub</a>
            <a href={site.releases} target="_blank" rel="noopener">Releases</a>
            <a href="/llms.txt">llms.txt</a>
          </nav>
        </div>
      </footer>
    </>
  );
}

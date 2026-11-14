import type { Metadata } from "next";
import { ArticleShell } from "@/components/ArticleShell";
import { page } from "@/lib/pages";
import { site } from "@/lib/site";

const info = page("/changelog");

export const metadata: Metadata = {
  title: { absolute: info.title },
  description: info.description,
  alternates: { canonical: info.href },
  openGraph: { type: "article", url: info.href, title: info.title, description: info.description },
};

const all: { version: string; date: string; label: string; notes: string[] }[] = [
  {
    // Shown once site.version is "1.4". Fill in the date and label on release day.
    version: "1.4", date: "", label: "",
    notes: [
      "Play on several outputs at once. Click the device name in the panel, tick the outputs, and every app plays on all of them, lined up so they sound together.",
      "A Sync section shows each output’s delay and how long Levels holds it back. Every device except the built-in one has a slider to fine-tune it by ear, and the setting is saved per device.",
      "The panel stays responsive while outputs change, with a “Lining up…” indicator while Levels rebuilds them.",
      "The new screens are translated into all 8 languages.",
    ],
  },
  {
    version: "1.3", date: "2026-11-13", label: "November 13, 2026",
    notes: [
      "The interface is now in English and follows the system language in Spanish, German, French, Portuguese, Russian, Japanese, Simplified Chinese and Korean.",
      "Long translations in the panel footer shrink to fit instead of wrapping.",
    ],
  },
  {
    version: "1.2", date: "2026-11-13", label: "November 13, 2026",
    notes: [
      "Renamed from VolumeMixer to Levels, with a new app icon and menu bar symbol.",
      "Saved app volumes carry over from VolumeMixer.",
      "The Homebrew cask is now called levels. The old name redirects to it.",
    ],
  },
  {
    version: "1.1", date: "2026-11-13", label: "November 13, 2026",
    notes: [
      "First public release, under the name VolumeMixer.",
      "Volume and mute for each app, output device volume, and volumes remembered per app.",
      "Universal app for Apple Silicon and Intel. Runs on macOS 11 and later, with per-app volume on macOS 14.2 and later.",
      "An app you adjust stays routed through the app even at 100%, which removes a jump in volume between 99% and 100%.",
      "Install with Homebrew or with a script.",
    ],
  },
  {
    version: "1.0", date: "2026-11-07", label: "November 7, 2026",
    notes: ["First build. Not released."],
  },
];

const releases = all.filter((r) => Number(r.version) <= Number(site.version));

export default function Page() {
  return (
    <ArticleShell
      info={info}
      lead={<p>Downloads for every version are on <a href={site.releases.replace("/latest", "")}>GitHub Releases</a>. Homebrew users get updates with <code>brew upgrade levels</code>.</p>}
    >
      {releases.map((r) => (
        <section key={r.version} className="release">
          <h2 id={`v${r.version}`}>Levels {r.version}</h2>
          {r.date && <p className="article-meta"><time dateTime={r.date}>{r.label}</time></p>}
          <ul>{r.notes.map((n) => <li key={n}>{n}</li>)}</ul>
        </section>
      ))}
    </ArticleShell>
  );
}

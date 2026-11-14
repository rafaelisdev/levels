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

const releases: { version: string; date: string; label: string; notes: string[] }[] = [
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

export default function Page() {
  return (
    <ArticleShell
      info={info}
      lead={<p>Downloads for every version are on <a href={site.releases.replace("/latest", "")}>GitHub Releases</a>. Homebrew users get updates with <code>brew upgrade levels</code>.</p>}
    >
      {releases.map((r) => (
        <section key={r.version} className="release">
          <h2 id={`v${r.version}`}>Levels {r.version}</h2>
          <p className="article-meta"><time dateTime={r.date}>{r.label}</time></p>
          <ul>{r.notes.map((n) => <li key={n}>{n}</li>)}</ul>
        </section>
      ))}
    </ArticleShell>
  );
}

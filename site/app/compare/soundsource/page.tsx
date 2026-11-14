import type { Metadata } from "next";
import Link from "next/link";
import { ArticleShell, Note } from "@/components/ArticleShell";
import { page } from "@/lib/pages";

const info = page("/compare/soundsource");

export const metadata: Metadata = {
  title: info.title,
  description: info.description,
  alternates: { canonical: info.href },
  openGraph: { type: "article", url: info.href, title: info.title, description: info.description },
};

const rows: [string, string, string][] = [
  ["Price", "Free", "$49, upgrades from $25, free trial"],
  ["License", "Open source (MIT)", "Commercial"],
  ["macOS", "11 or later, per-app volume on 14.2 or later", "15 Sequoia or later"],
  ["Per-app volume and mute", "Yes", "Yes"],
  ["Per-app EQ and effects", "No", "Yes"],
  ["Send an app to another output", "Not yet", "Yes, including AirPlay"],
  ["Output device controls", "Volume and mute", "Volume, balance, sample rate, maximum volume, device groups"],
  ["How it gets the audio", "macOS process taps, nothing else installed", "Rogue Amoeba’s ARK audio component, installed during setup"],
];

export default function Page() {
  return (
    <ArticleShell
      info={info}
      lead={<p>SoundSource by Rogue Amoeba is the best-known paid app for controlling sound per app on a Mac. Levels is a free app that covers the most common part of that job: a volume slider and a mute button for each app.</p>}
    >
      <h2>Side by side</h2>
      <div className="table-wrap">
        <table>
          <thead><tr><th></th><th>Levels</th><th>SoundSource 6</th></tr></thead>
          <tbody>
            {rows.map(([k, a, b]) => <tr key={k}><th scope="row">{k}</th><td>{a}</td><td>{b}</td></tr>)}
          </tbody>
        </table>
      </div>

      <h2>When SoundSource is the better choice</h2>
      <p>
        SoundSource changes how apps sound as well as how loud they are. It has equalizers and audio effects for each app,
        can send one app to a different output or to an AirPlay speaker, and groups output devices. It is a mature
        product with paid support behind it. If you work with audio or want that level of control, it is worth the price.
      </p>

      <h2>When Levels is enough</h2>
      <p>
        If you mainly want to turn one app down and another up, Levels does that for free, installs nothing besides the
        app, and its code is open. It also covers older systems: per-app volume works from macOS 14.2, while SoundSource 6
        requires macOS 15.
      </p>
      <Note>
        Avoid running both at the same time. Each one takes over the sound of the apps you adjust, and two tools doing
        that to the same app can cut or double its sound.
      </Note>

      <h2>Sources</h2>
      <p>
        SoundSource prices, requirements and features come from{" "}
        <a href="https://www.rogueamoeba.com/company/lists/archives/press/2025-12-soundsource-600.html" rel="noopener">Rogue Amoeba’s SoundSource 6 announcement</a>{" "}
        and the <a href="https://rogueamoeba.com/soundsource/" rel="noopener">SoundSource page</a>. Prices can change, so check
        their site before buying. For the other free option, see <Link href="/compare/background-music">Levels vs Background Music</Link>.
      </p>
    </ArticleShell>
  );
}

import type { Metadata } from "next";
import Link from "next/link";
import { ArticleShell, Note } from "@/components/ArticleShell";
import { page } from "@/lib/pages";

const info = page("/compare/background-music");

export const metadata: Metadata = {
  title: info.title,
  description: info.description,
  alternates: { canonical: info.href },
  openGraph: { type: "article", url: info.href, title: info.title, description: info.description },
};

const rows: [string, string, string][] = [
  ["Price", "Free", "Free"],
  ["License", "MIT", "GPL-2.0"],
  ["macOS", "11 or later, per-app volume on 14.2 or later", "Also runs on versions before 14.2"],
  ["Per-app volume", "Yes", "Yes"],
  ["Stereo balance per app", "No", "Yes"],
  ["Pauses music when another app plays", "No", "Yes"],
  ["Installs an audio driver", "No", "Yes, a virtual audio device"],
  ["System output while running", "Stays on your device", "Switches to the Background Music device"],
];

export default function Page() {
  return (
    <ArticleShell
      info={info}
      lead={<p>Background Music and Levels are both free, open source menu bar apps that add per-app volume to macOS. They solve the problem in different ways, and that difference mostly decides which one suits your Mac.</p>}
    >
      <h2>How each one works</h2>
      <p>
        Background Music installs a virtual audio device. While it runs, that device becomes the system output: every app
        plays into it, and Background Music passes the sound on to your speakers with each app’s volume applied. The
        driver is installed with a package and stays in the system until you remove it.
      </p>
      <p>
        Levels uses process taps, a Core Audio feature Apple added in macOS 14.2. It takes over the sound of the apps you
        adjust and plays it back at the volume you set. Your output device stays selected, apps you never touch play
        directly as usual, and nothing is installed into the system.
      </p>

      <h2>Side by side</h2>
      <div className="table-wrap">
        <table>
          <thead><tr><th></th><th>Levels</th><th>Background Music</th></tr></thead>
          <tbody>
            {rows.map(([k, a, b]) => <tr key={k}><th scope="row">{k}</th><td>{a}</td><td>{b}</td></tr>)}
          </tbody>
        </table>
      </div>

      <h2>Which one to pick</h2>
      <p>
        Background Music makes sense on a Mac older than macOS 14.2, where process taps do not exist. It also has two
        features Levels lacks: stereo balance per app and pausing your music player automatically when another app starts
        playing.
      </p>
      <p>
        On macOS 14.2 or later, Levels gives you per-app volume and mute without an audio driver and without changing your
        output device. Removing it is just deleting the app.
      </p>
      <Note>Run one of them at a time. Both change the sound of the same apps, and running them together can make it cut out or double.</Note>

      <h2>Sources</h2>
      <p>
        Details about Background Music come from its{" "}
        <a href="https://github.com/kyleneideck/BackgroundMusic" rel="noopener">GitHub repository and release notes</a>. For the
        paid option, see <Link href="/compare/soundsource">Levels vs SoundSource</Link>.
      </p>
    </ArticleShell>
  );
}

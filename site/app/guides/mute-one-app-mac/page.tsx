import type { Metadata } from "next";
import Link from "next/link";
import { ArticleShell, Note } from "@/components/ArticleShell";
import { page } from "@/lib/pages";

const info = page("/guides/mute-one-app-mac");

export const metadata: Metadata = {
  title: info.title,
  description: info.description,
  alternates: { canonical: info.href },
  openGraph: { type: "article", url: info.href, title: info.title, description: info.description },
};

export default function Page() {
  return (
    <ArticleShell
      info={info}
      lead={<p>The mute key on a Mac silences every app at once. To mute one app and keep the rest playing, the right method depends on what is making the noise.</p>}
    >
      <h2>Mute a browser tab</h2>
      <ul>
        <li><strong>Safari.</strong> A tab that plays sound shows a speaker icon, and so does the address field. Click it to mute that tab.</li>
        <li><strong>Chrome.</strong> Right-click the tab and choose <em>Mute site</em>. Chrome keeps the site muted until you unmute it, including in new tabs.</li>
        <li><strong>Firefox.</strong> Click the speaker icon on the tab, or right-click the tab and choose <em>Mute Tab</em>.</li>
        <li><strong>Edge.</strong> Right-click the tab and choose <em>Mute tab</em>.</li>
      </ul>

      <h2>Turn off notification sounds for one app</h2>
      <p>
        If an app keeps chiming, open System Settings → Notifications, pick the app and turn off <strong>Play sound for
        notifications</strong>. Its banners still appear, without the sound. A Focus mode goes further and holds back
        notifications from most apps.
      </p>

      <h2>Mute an app that has no mute button</h2>
      <p>
        Games, meeting apps and video editors often have no mute control, and macOS has no built-in way to silence one of
        them. Levels, a free menu bar app, can mute any app that plays sound:
      </p>
      <ol>
        <li>Open Levels and click the faders icon in the menu bar.</li>
        <li>Click the icon of the app you want to silence. It turns gray and gets a red badge.</li>
        <li>Click it again to bring the sound back at the level it had before.</li>
      </ol>
      <Note>
        Muting in Levels only silences the sound. The app keeps running, and a video keeps playing, so you will not
        lose your place.
      </Note>

      <h2>Find the app that is making the sound</h2>
      <p>
        Sometimes the problem is knowing where the sound comes from, such as a hidden tab or an app in the background.
        In Levels, apps that are playing right now show a small animated indicator next to their name, so you can find
        the noisy one and mute it from the same list.
      </p>
      <p>
        If you want the app quieter rather than silent, see{" "}
        <Link href="/guides/per-app-volume-mac">how to change the volume of individual apps</Link>.
      </p>
    </ArticleShell>
  );
}

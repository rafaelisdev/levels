import type { Metadata } from "next";
import Link from "next/link";
import { ArticleShell, Note, Steps } from "@/components/ArticleShell";
import { page } from "@/lib/pages";
import { site } from "@/lib/site";

const info = page("/guides/per-app-volume-mac");

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
      lead={<p>macOS has a single output volume. The slider in Control Center and the volume keys move every app at once, and System Settings has no mixer for individual apps. There are still a few ways to give apps different volumes.</p>}
    >
      <h2>Use the app’s own volume control</h2>
      <p>
        Many media apps have a volume slider of their own: Music, Spotify, QuickTime Player, VLC and the video players on
        most websites. It works on top of the main volume, so turning Music down in Music leaves every other app as it was.
      </p>
      <p>
        The catch is that plenty of apps that make noise have no such slider, or hide it deep in their settings. Games
        and meeting apps are common examples, and browsers have no volume per tab at all.
      </p>

      <h2>Turn down alerts and notification sounds separately</h2>
      <p>
        System Settings → Sound has an <strong>Alert volume</strong> slider. It changes the system alert sounds without
        touching music or video.
      </p>
      <p>
        To silence the notification sounds of one app, open System Settings → Notifications, choose the app and turn off
        <strong> Play sound for notifications</strong>. Its banners still appear.
      </p>

      <h2>Use a per-app volume app</h2>
      <p>
        Apps that add a real mixer to the Mac use one of two methods. Older ones install a virtual audio device: every app
        plays into it, and the tool passes the sound on to your speakers at the volume you chose for each app. Since
        macOS 14.2, Core Audio also has process taps, which let one app take over another app’s sound directly, so no
        driver is needed.
      </p>
      <p>Levels is a free menu bar app built on process taps. To set a volume for each app with it:</p>
      <Steps>
        <li>Install it with <code>{site.brew}</code>, or download the zip from <a href={site.releases}>GitHub Releases</a>.</li>
        <li>Open Levels from Spotlight. A faders icon appears in the menu bar.</li>
        <li>Click the icon. Apps that are playing sound are listed at the top, each with its own slider.</li>
        <li>Drag a slider. The first time, macOS asks for “System Audio Recording Only” access. Allow it.</li>
      </Steps>
      <p>
        Levels remembers the level of each app and applies it the next time that app plays. Clicking an app’s icon mutes
        it, which is covered in more detail in <Link href="/guides/mute-one-app-mac">how to mute a single app</Link>.
      </p>
      <Note>
        App sliders set the balance between apps. The volume keys and the slider in Control Center still change
        everything together, so you can keep using them as before.
      </Note>

      <h2>If an app is missing from the list</h2>
      <ul>
        <li>An app appears once it opens an audio stream. Start playback and it shows up.</li>
        <li>Browsers and many other apps play sound through helper processes. Levels groups those under the main app’s name.</li>
        <li>Per-app volume needs macOS 14.2 or later. On older versions Levels can only change the output device volume.</li>
      </ul>

      <h2>Other apps that do this</h2>
      <p>
        SoundSource is a paid app with equalizers and per-app output routing, and Background Music is a free, open source
        app that uses a virtual audio device. Both comparisons are on this site:{" "}
        <Link href="/compare/soundsource">Levels vs SoundSource</Link> and{" "}
        <Link href="/compare/background-music">Levels vs Background Music</Link>.
      </p>
    </ArticleShell>
  );
}

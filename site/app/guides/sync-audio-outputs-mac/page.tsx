import type { Metadata } from "next";
import Link from "next/link";
import { ArticleShell, Note, Steps } from "@/components/ArticleShell";
import { page } from "@/lib/pages";

const info = page("/guides/sync-audio-outputs-mac");

export const metadata: Metadata = {
  title: info.title,
  description: info.description,
  alternates: { canonical: info.href },
  openGraph: { type: "article", url: info.href, title: info.title, description: info.description },
};

const rows: [string, string, string][] = [
  ["Where you set it up", "The Levels panel in the menu bar", "Audio MIDI Setup, then System Settings → Sound"],
  ["System output", "Stays on your usual device", "Switches to the combined device"],
  ["Clock drift between devices", "Absorbed by resampling against the Mac’s clock", "Drift Correction"],
  ["Different delays of the devices", "Lined up to the slowest output", "Left as they are"],
  ["Fine tuning per device", "From −200 to +500 ms, in 1 ms steps", "None"],
];

export default function Page() {
  return (
    <ArticleShell
      info={info}
      lead={
        <p>
          A Mac can send its sound to several outputs at once, but they don’t play at the same moment. A TV or Bluetooth
          headphones run behind the built-in speakers, and in one room that sounds like an echo. Levels 1.4 plays every
          app on the outputs you pick and holds the faster ones back, so all of them sound together.
        </p>
      }
    >
      <h2>Why outputs play at different times</h2>
      <p>
        Every output needs some time between receiving audio and making a sound. The built-in speakers are quick. A TV
        runs the sound through its own processing first, and Bluetooth headphones buffer audio to keep the wireless link
        steady. macOS keeps a latency figure for each device, but it only knows what the device reports.
      </p>
      <p>
        The Multi-Output Device in Audio MIDI Setup keeps the clocks of its devices in step, so they don’t drift further
        apart over time. It doesn’t line up their delays, though, and a slow device stays exactly as late as it started.
        Setting one up is covered in <Link href="/guides/two-audio-outputs-mac">how to play sound through two outputs</Link>.
      </p>

      <h2>Play on several outputs with Levels</h2>
      <Steps>
        <li>Install Levels 1.4 or later. Playing on several outputs needs macOS 14.2 or later.</li>
        <li>Click the Levels icon in the menu bar, then click the device name at the top of the panel. The <strong>Outputs</strong> page opens in the same panel.</li>
        <li>Under <strong>Play on</strong>, tick the outputs you want. The Mac’s default output always plays and is marked <strong>Default</strong>. You can change it in System Settings → Sound.</li>
        <li>Play something. While Levels sets up the outputs, <strong>Lining up…</strong> shows next to the title for a moment. After that every app with sound plays on all the ticked outputs.</li>
        <li>If a device still sounds early or late, play something with a clear beat and move its slider under <strong>Sync</strong> until the echo is gone. The <strong>−</strong> and <strong>+</strong> buttons move it by 1 ms. Levels remembers the setting for that device.</li>
      </Steps>
      <p>
        The panel on the <Link href="/#how">home page</Link> is a working copy: click the device name to open Outputs,
        tick a device and move the sliders.
      </p>

      <h2>How Levels lines them up</h2>
      <p>
        Levels captures each app’s sound with a Core Audio process tap and writes it into a buffer, together with the time
        each piece was captured. Every output gets its own player, which runs on that output’s own clock.
      </p>
      <p>
        The shared delay is the path of the slowest output. Levels holds every other output back by the difference, so
        each sound leaves all of them at the same moment. The <strong>Delay</strong> box on the Outputs page shows this
        per device. The solid bar is the device’s own delay, the light bar is how long Levels holds it back, and the label
        reads <strong>slowest</strong> or <strong>waits</strong> with the number of milliseconds.
      </p>
      <p>
        Each player reads from the buffer by the Mac’s absolute time. The crystals that clock audio devices run at
        slightly different speeds, tens of parts per million, which comes to a millisecond or two every ten minutes.
        Levels resamples to absorb that difference, so it never builds up into an echo.
      </p>
      <p>
        The latency of each device comes from macOS. It is the same figure audio workstations such as Ableton Live show.
        What macOS can’t see, like a TV’s sound processing over HDMI, you add once with that device’s slider.
      </p>

      <h2>What we measured</h2>
      <ul>
        <li>
          After setting the offset for a TV, we recorded it and the MacBook speakers with a microphone. The clicks from
          both arrived together, with a spread of 0.00 ms at the 0.1 ms resolution of the measurement.
        </li>
        <li>A Philips TV connected over HDMI played about 100 ms later than macOS reported. macOS listed its latency as about 2 ms.</li>
        <li>By ear, the MacBook speakers, the TV and a pair of headphones playing at once sounded like a single source.</li>
      </ul>

      <h2>Limits</h2>
      <ul>
        <li>It needs macOS 14.2 or later, the first version with process taps.</li>
        <li>
          All sound waits for the slowest output. With a TV that is around 170 ms, so video on the Mac’s screen runs ahead
          of the sound. On the TV’s own screen the gap is smaller, because the TV delays the picture too. For a film on
          the Mac, play on one output.
        </li>
        <li>AirPlay speakers are not part of synced playback. They buffer about two seconds of audio.</li>
        <li>A TV over HDMI is tuned by ear once and Levels keeps the setting. After you reconnect the cable it may need a small correction.</li>
        <li>Bluetooth headphones use the latency they report to macOS. If they report none, tune them by ear like a TV.</li>
        <li>An app that starts playing after you turn on several outputs plays only on the default output for about the first second.</li>
      </ul>

      <h2>Levels compared with a Multi-Output Device</h2>
      <div className="table-wrap">
        <table>
          <thead><tr><th></th><th>Levels</th><th>Multi-Output Device</th></tr></thead>
          <tbody>
            {rows.map(([k, a, b]) => <tr key={k}><th scope="row">{k}</th><td>{a}</td><td>{b}</td></tr>)}
          </tbody>
        </table>
      </div>
      <Note>
        Levels plays every app on all the ticked outputs. Sending one app to the TV and another to your headphones is not
        supported. If you need that, <Link href="/compare/soundsource">SoundSource</Link> can route each app to its own output.
      </Note>
    </ArticleShell>
  );
}

import type { Metadata } from "next";
import { ArticleShell, Note, Steps } from "@/components/ArticleShell";
import { page } from "@/lib/pages";
import { site } from "@/lib/site";

const info = page("/guides/two-audio-outputs-mac");

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
      lead={<p>A Mac can play the same sound through several outputs at once, for example the built-in speakers and a pair of headphones. The setting is hidden in Audio MIDI Setup, where you combine the outputs into a Multi-Output Device.</p>}
    >
      <h2>Create a Multi-Output Device</h2>
      <Steps>
        <li>Open <strong>Audio MIDI Setup</strong>. It is in Applications → Utilities, or you can find it with Spotlight.</li>
        <li>Click the <strong>+</strong> button at the bottom left and choose <strong>Create Multi-Output Device</strong>.</li>
        <li>Tick <strong>Use</strong> next to each output you want, for example MacBook Pro Speakers and your headphones.</li>
        <li>Set <strong>Primary Device</strong> to the wired or built-in output, and turn on <strong>Drift Correction</strong> for the others.</li>
        <li>Open System Settings → Sound and choose the new Multi-Output Device under Output.</li>
      </Steps>
      <p>To give the device a clearer name, double-click it in the sidebar of Audio MIDI Setup.</p>

      <h2>What to expect</h2>
      <h3>The volume keys stop working</h3>
      <p>
        macOS cannot change the volume of a Multi-Output Device with the keyboard or Control Center. Set the volume of each
        output before you switch to the combined device, or change it later in Audio MIDI Setup.
      </p>
      <h3>Bluetooth plays late</h3>
      <p>
        Bluetooth headphones and speakers usually play somewhere between 100 and 300 milliseconds behind wired outputs,
        and macOS does not line them up. If you can hear both at once, it sounds like an echo. When two people listen in
        different places, the delay is rarely a problem.
      </p>
      <h3>AirPlay plays later still</h3>
      <p>
        AirPlay speakers buffer about two seconds of audio, so they drift far apart from local outputs. To play music on
        several AirPlay speakers in sync with each other, use the AirPlay button in the Music app instead.
      </p>
      <h3>Silence or crackling on one device</h3>
      <p>
        Open Audio MIDI Setup and give every device in the group the same sample rate, usually 48,000 Hz. Drift
        Correction should be on for every device except the primary one.
      </p>

      <h2>Go back to one output</h2>
      <p>
        Choose your usual output again in System Settings → Sound. To delete the combined device, select it in Audio MIDI
        Setup and click the <strong>−</strong> button.
      </p>

      <Note>
        Levels cannot send sound to two outputs yet. We are building it: pick the outputs from the menu bar, set a volume
        for each, and let Levels delay the faster device so wired speakers and Bluetooth headphones play together. New
        versions appear on <a href={site.releases}>GitHub Releases</a>.
      </Note>
    </ArticleShell>
  );
}

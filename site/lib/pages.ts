export type PageInfo = {
  href: string;
  title: string; // <title> and h1
  short: string; // link text in nav, hub and footer
  description: string; // meta description, about 150 characters
  kind: "guide" | "compare" | "changelog";
  published: string; // ISO date
  updated: string; // ISO date
};

export const pages: PageInfo[] = [
  {
    href: "/guides/per-app-volume-mac",
    title: "How to change the volume of individual apps on a Mac",
    short: "Change the volume of one app",
    description: "macOS has one volume slider for everything. These are the ways to give each app its own volume, from built-in controls to a free menu bar app.",
    kind: "guide",
    published: "2026-11-14",
    updated: "2026-11-14",
  },
  {
    href: "/guides/mute-one-app-mac",
    title: "How to mute a single app on a Mac",
    short: "Mute a single app",
    description: "The mute key silences the whole Mac. Here is how to mute one app, a browser tab or an app's notification sounds while everything else keeps playing.",
    kind: "guide",
    published: "2026-11-14",
    updated: "2026-11-14",
  },
  {
    href: "/guides/two-audio-outputs-mac",
    title: "How to play sound through two outputs at once on a Mac",
    short: "Play sound on two outputs",
    description: "Send your Mac's sound to speakers and headphones at the same time with a Multi-Output Device, and what to expect from Bluetooth and AirPlay delay.",
    kind: "guide",
    published: "2026-11-14",
    updated: "2026-11-14",
  },
  {
    href: "/guides/sync-audio-outputs-mac",
    title: "How to play audio on multiple outputs in sync on a Mac",
    short: "Multiple outputs in sync",
    description: "Play a Mac’s sound on speakers, a TV and headphones at once without an echo. How Levels lines up outputs with different delays, and its limits.",
    kind: "guide",
    published: "2026-11-14",
    updated: "2026-11-14",
  },
  {
    href: "/compare/soundsource",
    title: "Levels vs SoundSource: per-app volume on Mac compared",
    short: "Levels vs SoundSource",
    description: "SoundSource is the most complete paid audio tool for the Mac. Levels is free and does less. A fair comparison of price, features and requirements.",
    kind: "compare",
    published: "2026-11-14",
    updated: "2026-11-14",
  },
  {
    href: "/compare/background-music",
    title: "Levels vs Background Music: free per-app volume apps for Mac",
    short: "Levels vs Background Music",
    description: "Both are free and open source. Background Music installs a virtual audio device, Levels uses Apple's process taps. How they differ and which to pick.",
    kind: "compare",
    published: "2026-11-14",
    updated: "2026-11-14",
  },
  {
    href: "/changelog",
    title: "Levels changelog",
    short: "Changelog",
    description: "Every Levels release with its date and what changed, from the first build to the current version.",
    kind: "changelog",
    published: "2026-11-14",
    updated: "2026-11-14",
  },
];

export const page = (href: string) => pages.find((p) => p.href === href)!;

export const site = {
  name: "Levels",
  url: "https://getlevels.app",
  // On a release: set the version here (the hero badge and the changelog entry follow it),
  // add the date in app/changelog/page.tsx, and update "Current version" in public/llms.txt
  // and the version list in public/llms-full.txt.
  version: "1.4",
  languages: ["English", "Español", "Deutsch", "Français", "Português", "Русский", "日本語", "简体中文", "한국어"],
  title: "Levels: per-app volume control for Mac",
  description:
    "Levels is a free, open source menu bar app that gives every Mac app its own volume slider and mute button. It installs no drivers. Get it with Homebrew.",
  github: "https://github.com/rafaelisdev/levels",
  releases: "https://github.com/rafaelisdev/levels/releases/latest",
  zip: "https://github.com/rafaelisdev/levels/releases/latest/download/Levels.zip",
  brew: "brew install rafaelisdev/tap/levels",
  curl: "curl -fsSL https://raw.githubusercontent.com/rafaelisdev/levels/main/install.sh | bash",
} as const;

/** Short feature list for JSON-LD (featureList). */
export const features = [
  "A volume slider and mute button for every app that plays sound",
  "Remembers each app's volume",
  "Output device volume and mute in the menu bar",
  "Plays on several outputs at once, lined up for each device's delay (Levels 1.4 and later)",
  "Launch at login",
  "Interface in 9 languages",
] as const;

export const faq = [
  {
    q: "Does Levels install a driver or kernel extension?",
    a: "No. Levels uses Core Audio process taps, which Apple added in macOS 14.2. Nothing is installed into the system, so removing the app leaves nothing behind.",
  },
  {
    q: "Which macOS versions are supported?",
    a: "Per-app volume needs macOS 14.2 or later. Levels itself runs on macOS 11 Big Sur and later, on Apple Silicon and Intel. On older systems it controls the output device volume only.",
  },
  {
    q: "Why does macOS ask for “System Audio Recording Only” access?",
    a: "macOS requires that permission before one app can change the sound of another. Levels processes audio in real time on your Mac and never records, stores or uploads it.",
  },
  {
    q: "What happens if Levels quits or crashes?",
    a: "Every app goes straight back to its normal volume. macOS only keeps an app routed through Levels while Levels is running.",
  },
  {
    q: "Can Levels play sound on several outputs at once?",
    a: "Yes, from Levels 1.4 on macOS 14.2 or later. Click the device name at the top of the panel and tick the outputs you want, for example the Mac’s speakers, a TV and headphones. Every app then plays on all of them, lined up so they sound at the same moment. AirPlay speakers are not included.",
  },
  {
    q: "Does playing on several outputs add delay?",
    a: "Yes. Each output takes a different time to play sound, so Levels holds the faster ones back until the slowest catches up. With a TV over HDMI that is around 170 ms, enough for video on the Mac’s screen to run ahead of the sound. On the TV’s own screen the gap is smaller, because the TV delays the picture too. For a film on the Mac, play on one output.",
  },
  {
    q: "How do I line up a TV or Bluetooth headphones?",
    a: "Levels takes each device’s delay from macOS. A TV adds sound processing that macOS doesn’t know about, so play something with a clear beat and move the TV’s slider under Sync until the echo is gone. Levels saves it for that device, and after you reconnect HDMI it may need a small correction. Bluetooth headphones that don’t report their delay are tuned the same way.",
  },
  {
    q: "Which languages does Levels speak?",
    a: "Levels follows your Mac’s language: English, Español, Deutsch, Français, Português, Русский, 日本語, 简体中文 and 한국어.",
  },
  {
    q: "Is Levels free?",
    a: "Yes. Levels is free and open source under the MIT license, and the code is on GitHub.",
  },
] as const;

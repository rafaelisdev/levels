export const site = {
  name: "Levels",
  url: "https://getlevels.app",
  version: "1.3",
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
    q: "Which languages does Levels speak?",
    a: "Levels follows your Mac’s language: English, Español, Deutsch, Français, Português, Русский, 日本語, 简体中文 and 한국어.",
  },
  {
    q: "Is Levels free?",
    a: "Yes. Levels is free and open source under the MIT license, and the code is on GitHub.",
  },
] as const;

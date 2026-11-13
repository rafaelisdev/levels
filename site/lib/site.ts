export const site = {
  name: "Levels",
  url: "https://getlevels.vercel.app",
  version: "1.3",
  languages: ["English", "Español", "Deutsch", "Français", "Português", "Русский", "日本語", "简体中文", "한국어"],
  title: "Levels — a volume slider for every Mac app",
  description:
    "Levels is a tiny macOS menu bar app that gives every app its own volume slider and mute. No drivers, no kernel extensions. Install with Homebrew.",
  github: "https://github.com/rafaelisdev/levels",
  releases: "https://github.com/rafaelisdev/levels/releases/latest",
  zip: "https://github.com/rafaelisdev/levels/releases/latest/download/Levels.zip",
  brew: "brew install rafaelisdev/tap/levels",
  curl: "curl -fsSL https://raw.githubusercontent.com/rafaelisdev/levels/main/install.sh | bash",
} as const;

export const faq = [
  {
    q: "Does Levels install a driver or kernel extension?",
    a: "No. Levels uses Core Audio process taps, an API Apple added in macOS 14.2. Nothing is installed into the system, so there is nothing to clean up when you remove the app.",
  },
  {
    q: "Which macOS versions are supported?",
    a: "Per-app volume needs macOS 14.2 or later. Levels itself runs on macOS 11 Big Sur and later, on Apple Silicon and Intel; on older systems it controls the output device volume.",
  },
  {
    q: "Why does macOS ask for “System Audio Recording Only” access?",
    a: "That permission is what lets an app take over another app’s sound to change its volume. Levels processes audio in real time on your Mac; it never records, stores or uploads anything.",
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
    a: "Yes. Levels is free, and its source code is on GitHub.",
  },
] as const;

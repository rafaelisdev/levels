# Template for Casks/levels.rb in the OWNER/homebrew-tap repo.
# scripts/publish.sh fills in __OWNER__, __VERSION__ and __SHA256__.
#   brew install __OWNER__/tap/levels
cask "levels" do
  version "__VERSION__"
  sha256 "__SHA256__"

  url "https://github.com/__OWNER__/levels/releases/download/v#{version}/Levels.zip"
  name "Levels"
  desc "Per-app volume control in the menu bar"
  homepage "https://github.com/__OWNER__/levels"

  depends_on macos: :big_sur

  app "Levels.app"

  # The app is not notarized; without this macOS refuses to open it on first launch.
  postflight_steps do
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "{{appdir}}/Levels.app"]
  end

  uninstall quit: "io.github.rafaelisdev.levels"

  zap trash: [
    "~/Library/Preferences/io.github.rafaelisdev.levels.plist",
    "~/Library/Preferences/local.volumemixer.plist",
  ]
end

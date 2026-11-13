# Template for Casks/volumemixer.rb in the OWNER/homebrew-tap repo.
# scripts/publish.sh fills in __OWNER__, __VERSION__ and __SHA256__.
#   brew install __OWNER__/tap/volumemixer
cask "volumemixer" do
  version "__VERSION__"
  sha256 "__SHA256__"

  url "https://github.com/__OWNER__/volumemixer/releases/download/v#{version}/VolumeMixer.zip"
  name "VolumeMixer"
  name "Микшер"
  desc "Per-app volume control in the menu bar"
  homepage "https://github.com/__OWNER__/volumemixer"

  depends_on macos: :big_sur

  app "VolumeMixer.app"

  # The app is not notarized; without this macOS refuses to open it on first launch.
  postflight_steps do
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "{{appdir}}/VolumeMixer.app"]
  end

  uninstall quit: "local.volumemixer"

  zap trash: "~/Library/Preferences/local.volumemixer.plist"
end

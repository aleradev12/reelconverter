# Source of the cask published in aleradev12/homebrew-tap.
# The current app is ad-hoc signed, not notarized; see the README before installing.
cask "reelconverter" do
  version "1.0.0"
  sha256 "a360cc3b0f7370ff958a539b6b3cc251db541c56d268405d188d252bac605e21"

  url "https://github.com/aleradev12/reelconverter/releases/download/v#{version}/ReelConverter-v#{version}-macos-arm64.zip"
  name "ReelConverter"
  desc "Native batch video converter using FFmpeg"
  homepage "https://github.com/aleradev12/reelconverter"

  depends_on macos: :ventura
  depends_on arch: :arm64
  depends_on formula: "ffmpeg"

  app "ReelConverter.app"
end

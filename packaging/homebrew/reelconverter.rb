# Source of the cask published in aleradev12/homebrew-tap.
# The current app is ad-hoc signed, not notarized; see the README before installing.
cask "reelconverter" do
  version "1.0.3"
  sha256 "9c0a77afb65f3a4190fd0652a0dc92910e7e497c51b60f85856f0960dbbb18b2"

  url "https://github.com/aleradev12/reelconverter/releases/download/v#{version}/ReelConverter-v#{version}-macos-arm64.zip"
  name "ReelConverter"
  desc "Native batch video converter using FFmpeg"
  homepage "https://github.com/aleradev12/reelconverter"

  depends_on macos: :ventura
  depends_on arch: :arm64
  app "ReelConverter.app"
end

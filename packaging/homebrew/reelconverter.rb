# Source of the cask published in aleradev12/homebrew-tap.
# The current app is ad-hoc signed, not notarized; see the README before installing.
cask "reelconverter" do
  version "1.0.2"
  sha256 "62d227649ee370a71030ef59cf9dd4cce4512309fed15d8542486a23c3837d09"

  url "https://github.com/aleradev12/reelconverter/releases/download/v#{version}/ReelConverter-v#{version}-macos-arm64.zip"
  name "ReelConverter"
  desc "Native batch video converter using FFmpeg"
  homepage "https://github.com/aleradev12/reelconverter"

  depends_on macos: :ventura
  depends_on arch: :arm64
  app "ReelConverter.app"
end

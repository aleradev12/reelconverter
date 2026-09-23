# Source of the cask published in aleradev12/homebrew-tap.
# The current app is ad-hoc signed, not notarized; see the README before installing.
cask "reelconverter" do
  version "1.0.1"
  sha256 "54c74df12050da08aa6f1e9ebea710047c25cccf5e355d4a87d44e15d3860bf8"

  url "https://github.com/aleradev12/reelconverter/releases/download/v#{version}/ReelConverter-v#{version}-macos-arm64.zip"
  name "ReelConverter"
  desc "Native batch video converter using FFmpeg"
  homepage "https://github.com/aleradev12/reelconverter"

  depends_on macos: :ventura
  depends_on arch: :arm64
  app "ReelConverter.app"
end

# Copy into Casks/reelconverter.rb in your homebrew-tap repository AFTER uploading
# and notarizing an arm64 release ZIP. Replace the SHA-256 below.
cask "reelconverter" do
  version "0.1.0"
  sha256 "REPLACE_WITH_RELEASE_ZIP_SHA256"

  url "https://github.com/aleradev12/reelconverter/releases/download/v#{version}/ReelConverter-v#{version}-macos-arm64.zip"
  name "ReelConverter"
  desc "Native batch video converter using FFmpeg"
  homepage "https://github.com/aleradev12/reelconverter"

  depends_on macos: ">= :ventura"
  depends_on arch: :arm64
  depends_on formula: "ffmpeg"

  app "ReelConverter.app"
end

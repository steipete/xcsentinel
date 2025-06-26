class Xcsentinel < Formula
  desc "Native macOS CLI tool to augment Xcode development workflow"
  homepage "https://github.com/yourusername/xcsentinel"
  url "https://github.com/yourusername/xcsentinel/archive/v1.0.0.tar.gz"
  sha256 "placeholder_sha256_will_be_updated_on_release"
  license "MIT"
  
  depends_on xcode: ["14.0", :build]
  depends_on macos: :sonoma
  
  def install
    system "swift", "build", "--disable-sandbox", "-c", "release"
    bin.install ".build/release/xcsentinel"
  end
  
  test do
    system "#{bin}/xcsentinel", "--version"
  end
end
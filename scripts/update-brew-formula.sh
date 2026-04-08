#!/usr/bin/env bash
# scripts/update-brew-formula.sh
# Updates the Homebrew formula in renatobardi/homebrew-hapai after a release.
# Called by .github/workflows/release.yml with HOMEBREW_TAP_TOKEN set.
#
# Usage: bash scripts/update-brew-formula.sh <version> <sha256> <tarball_url>

set -euo pipefail

VERSION="${1:-}"
SHA256="${2:-}"
URL="${3:-}"

[[ -z "$VERSION" || -z "$SHA256" || -z "$URL" ]] && {
  echo "Usage: $0 <version> <sha256> <tarball_url>" >&2
  exit 1
}

HOMEBREW_TAP_TOKEN="${HOMEBREW_TAP_TOKEN:-}"
TAP_REPO="renatobardi/homebrew-hapai"

if [[ -z "$HOMEBREW_TAP_TOKEN" ]]; then
  echo "HOMEBREW_TAP_TOKEN not set — skipping Homebrew formula update" >&2
  exit 0
fi

echo "Updating Homebrew formula for hapai ${VERSION}..."

# Clone the tap repo
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

git clone "https://x-access-token:${HOMEBREW_TAP_TOKEN}@github.com/${TAP_REPO}.git" "$tmp_dir/tap" \
  --depth 1 --quiet

formula_file="${tmp_dir}/tap/Formula/hapai.rb"

# Write updated formula
cat > "$formula_file" << RUBY
class Hapai < Formula
  desc "Deterministic guardrails for AI coding assistants"
  homepage "https://github.com/renatobardi/hapai"
  url "${URL}"
  sha256 "${SHA256}"
  license "MIT"
  version "${VERSION#v}"

  depends_on "jq"

  def install
    bin.install "bin/hapai"
    (prefix/"hooks").install Dir["hooks/*"]
    (prefix/"templates").install Dir["templates/*"]
    (prefix/"exporters").install Dir["exporters/*"] if Dir.exist?("exporters")
    prefix.install "hapai.defaults.yaml"
  end

  def post_install
    (var/"hapai").mkpath
    (var/"hapai/state").mkpath
    (var/"hapai/state/cooldown").mkpath
  end

  test do
    assert_match "hapai v", shell_output("#{bin}/hapai version")
  end
end
RUBY

# Commit and push
cd "$tmp_dir/tap"
git config user.name "hapai-bot"
git config user.email "hapai-bot@users.noreply.github.com"
git add Formula/hapai.rb
git commit -m "hapai ${VERSION}"
git push origin main --quiet

echo "Homebrew formula updated: ${VERSION}"

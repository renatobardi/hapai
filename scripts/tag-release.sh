#!/usr/bin/env bash
# hapai — Release Tagging Script
# Usage: bash scripts/tag-release.sh 1.0.1
#
# Creates a git tag for a new release and bumps version numbers consistently
# across bin/hapai and hooks/_lib.sh
#
# The tag is created locally; you must push manually:
#   git push origin main && git push origin v1.0.1

set -euo pipefail

VERSION="${1:-}"

# ─── Helpers ────────────────────────────────────────────────────────────────

log_info()  { echo -e "\033[0;36mℹ\033[0m $*"; }
log_ok()    { echo -e "\033[0;32m✓\033[0m $*"; }
log_error() { echo -e "\033[0;31m✗\033[0m $*" >&2; }
die()       { log_error "$*"; exit 1; }

# ─── Validation ──────────────────────────────────────────────────────────────

if [[ -z "$VERSION" ]]; then
  log_error "Usage: $0 <semver>  (e.g., $0 1.0.1)"
  exit 1
fi

# Validate semver format
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  die "Invalid semver format: $VERSION (expected: X.Y.Z)"
fi

# ─── Version Consistency Check ───────────────────────────────────────────────

log_info "Checking current version consistency..."

# Get versions from both files
BIN_VERSION=$(grep "^HAPAI_VERSION=" bin/hapai | sed 's/HAPAI_VERSION="\(.*\)"/\1/')
LIB_VERSION=$(grep "^HAPAI_VERSION=" hooks/_lib.sh | sed 's/HAPAI_VERSION="\(.*\)"/\1/')

if [[ "$BIN_VERSION" != "$LIB_VERSION" ]]; then
  log_error "Version mismatch detected:"
  log_error "  bin/hapai: $BIN_VERSION"
  log_error "  hooks/_lib.sh: $LIB_VERSION"
  die "Run git diff to sync versions manually before tagging"
fi

log_ok "Versions consistent: $BIN_VERSION"

# ─── Version Update ─────────────────────────────────────────────────────────

log_info "Bumping version to $VERSION..."

# Update bin/hapai
sed -i.bak "s/^HAPAI_VERSION=\"[^\"]*\"/HAPAI_VERSION=\"${VERSION}\"/" bin/hapai
rm -f bin/hapai.bak
log_ok "Updated bin/hapai"

# Update hooks/_lib.sh
sed -i.bak "s/^HAPAI_VERSION=\"[^\"]*\"/HAPAI_VERSION=\"${VERSION}\"/" hooks/_lib.sh
rm -f hooks/_lib.sh.bak
log_ok "Updated hooks/_lib.sh"

# ─── Git Commit & Tag ────────────────────────────────────────────────────────

log_info "Creating git commit and tag..."

git add bin/hapai hooks/_lib.sh
git commit -m "chore(release): bump version to ${VERSION}"
log_ok "Commit: chore(release): bump version to ${VERSION}"

git tag -a "v${VERSION}" -m "Release v${VERSION}"
log_ok "Tag created: v${VERSION}"

# ─── Summary ─────────────────────────────────────────────────────────────────

log_info ""
log_ok "Release v${VERSION} prepared!"
log_info ""
log_info "Next steps:"
log_info "  1. Review the commit: git log -1"
log_info "  2. Push to GitHub:"
log_info "     git push origin main"
log_info "     git push origin v${VERSION}"
log_info "  3. GitHub Actions will build a release with tarball + checksums"
log_info ""

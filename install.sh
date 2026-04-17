#!/usr/bin/env bash
# hapai — Universal Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/renatobardi/hapai/main/install.sh | bash
#
# Environment variables:
#   HAPAI_VERSION   — pin a specific version (default: latest)
#   HAPAI_HOME      — hapai state directory (default: ~/.hapai)
#   INSTALL_DIR     — where to install the hapai binary (default: ~/.local/bin)
#   HAPAI_DEV       — set to "1" to install from local source (for development)

set -euo pipefail

HAPAI_VERSION="${HAPAI_VERSION:-latest}"
HAPAI_HOME="${HAPAI_HOME:-$HOME/.hapai}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
HAPAI_REPO="renatobardi/hapai"
HAPAI_REPO_URL="https://github.com/${HAPAI_REPO}"
HAPAI_RAW_URL="https://raw.githubusercontent.com/${HAPAI_REPO}"
HAPAI_DEV="${HAPAI_DEV:-0}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[90m'
NC='\033[0m'

log_info()  { echo -e "${CYAN}ℹ${NC} $*"; }
log_ok()    { echo -e "${GREEN}✓${NC} $*"; }
log_warn()  { echo -e "${YELLOW}⚠${NC} $*"; }
log_error() { echo -e "${RED}✗${NC} $*" >&2; }
die()       { log_error "$*"; exit 1; }

# ─── PATH setup ─────────────────────────────────────────────────────────────

setup_path() {
  local dir="$1"
  [[ ":$PATH:" == *":$dir:"* ]] && return 0

  # ~/.profile is sourced by bash, zsh, sh, and dash as a login shell — no
  # shell-specific config needed
  local profile="$HOME/.profile"
  if ! grep -qF "$dir" "$profile" 2>/dev/null; then
    printf '\n# hapai — added by installer\nexport PATH="%s:$PATH"\n' "$dir" >> "$profile"
    log_ok "Added $dir to PATH in $profile"
  fi
}

# ─── Detect OS ──────────────────────────────────────────────────────────────

detect_os() {
  local os
  os="$(uname -s 2>/dev/null | tr '[:upper:]' '[:lower:]')"
  case "$os" in
    linux*)
      # Check for WSL
      if grep -qi microsoft /proc/version 2>/dev/null; then
        echo "wsl"
      else
        echo "linux"
      fi
      ;;
    darwin*) echo "darwin" ;;
    *)       echo "unknown" ;;
  esac
}

# ─── Check dependencies ──────────────────────────────────────────────────────

check_deps() {
  local missing=()

  command -v git  &>/dev/null || missing+=(git)
  command -v jq   &>/dev/null || missing+=(jq)
  command -v curl &>/dev/null || { command -v wget &>/dev/null || missing+=(curl); }

  if [[ ${#missing[@]} -gt 0 ]]; then
    log_error "Missing required dependencies: ${missing[*]}"
    local os
    os="$(detect_os)"
    case "$os" in
      darwin) log_info "Install with: brew install ${missing[*]}" ;;
      linux|wsl) log_info "Install with: apt-get install -y ${missing[*]}  (or your distro's package manager)" ;;
    esac
    exit 1
  fi

  log_ok "Dependencies: bash, git, jq — OK"
}

# ─── Resolve version ─────────────────────────────────────────────────────────

resolve_version() {
  if [[ "$HAPAI_VERSION" == "latest" ]]; then
    log_info "Resolving latest version..."
    local version
    version="$(curl -fsSL "https://api.github.com/repos/${HAPAI_REPO}/releases/latest" 2>/dev/null \
      | grep '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')" || true

    if [[ -z "$version" ]]; then
      log_warn "Could not resolve latest version from GitHub API. Using 'main' branch."
      HAPAI_VERSION="main"
    else
      HAPAI_VERSION="$version"
      log_ok "Latest version: $HAPAI_VERSION"
    fi
  else
    log_ok "Target version: $HAPAI_VERSION"
  fi
}

# ─── Download & install ──────────────────────────────────────────────────────

install_from_source() {
  local src_dir
  src_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  log_info "Installing from local source: $src_dir"

  mkdir -p "$HAPAI_HOME/hooks" 2>/dev/null || die "Cannot create $HAPAI_HOME/hooks"
  cp -r "$src_dir/hooks/"* "$HAPAI_HOME/hooks/"
  cp "$src_dir/hapai.defaults.yaml" "$HAPAI_HOME/"
  cp -r "$src_dir/templates" "$HAPAI_HOME/"
  cp -r "$src_dir/exporters" "$HAPAI_HOME/" 2>/dev/null || true

  # Install binary
  mkdir -p "$INSTALL_DIR"
  cp "$src_dir/bin/hapai" "$INSTALL_DIR/hapai"
  chmod +x "$INSTALL_DIR/hapai"
  setup_path "$INSTALL_DIR"
}

install_from_github() {
  log_info "Downloading hapai ${HAPAI_VERSION}..."

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT

  local tarball_url="${HAPAI_REPO_URL}/archive/${HAPAI_VERSION}.tar.gz"
  local tarball="${tmp_dir}/hapai.tar.gz"
  local checksums_url="${HAPAI_REPO_URL}/releases/download/${HAPAI_VERSION}/checksums.txt"

  if command -v curl &>/dev/null; then
    curl -fsSL "$tarball_url" -o "$tarball" || die "Download failed: $tarball_url"
  else
    wget -q "$tarball_url" -O "$tarball" || die "Download failed: $tarball_url"
  fi

  # Verify tarball integrity via SHA256 checksum (supply chain defense)
  # Try to download checksums.txt, if available verify; if not, warn but continue
  local expected_sha256=""
  if command -v curl &>/dev/null; then
    expected_sha256="$(curl -fsSL "$checksums_url" 2>/dev/null | grep "hapai-${HAPAI_VERSION}.tar.gz\$" | awk '{print $1}')"
  else
    expected_sha256="$(wget -q -O - "$checksums_url" 2>/dev/null | grep "hapai-${HAPAI_VERSION}.tar.gz\$" | awk '{print $1}')"
  fi

  if [[ -n "$expected_sha256" ]]; then
    # Compute actual SHA256
    local actual_sha256
    if command -v sha256sum &>/dev/null; then
      actual_sha256="$(sha256sum "$tarball" | awk '{print $1}')"
    elif command -v shasum &>/dev/null; then
      actual_sha256="$(shasum -a 256 "$tarball" | awk '{print $1}')"
    fi

    if [[ -n "$actual_sha256" && "$actual_sha256" != "$expected_sha256" ]]; then
      die "SHA256 checksum mismatch! Expected $expected_sha256, got $actual_sha256. Possible supply chain attack."
    fi
    log_ok "Tarball integrity verified"
  else
    log_warn "Could not verify checksum (checksums.txt not found). Proceeding anyway. Ensure download was from trusted source."
  fi

  tar -xzf "$tarball" -C "$tmp_dir" 2>/dev/null || die "Failed to extract archive"

  local extracted_dir
  extracted_dir="$(find "$tmp_dir" -maxdepth 1 -type d -name "hapai-*" | head -1)"
  [[ -z "$extracted_dir" ]] && die "Could not find extracted hapai directory"

  log_ok "Downloaded to $tmp_dir"

  # Copy to HAPAI_HOME
  mkdir -p "$HAPAI_HOME/hooks" 2>/dev/null || die "Cannot create $HAPAI_HOME/hooks"
  cp -r "$extracted_dir/hooks/"* "$HAPAI_HOME/hooks/"
  cp "$extracted_dir/hapai.defaults.yaml" "$HAPAI_HOME/"
  cp -r "$extracted_dir/templates" "$HAPAI_HOME/"
  cp -r "$extracted_dir/exporters" "$HAPAI_HOME/" 2>/dev/null || true

  # Install binary
  mkdir -p "$INSTALL_DIR"
  cp "$extracted_dir/bin/hapai" "$INSTALL_DIR/hapai"
  chmod +x "$INSTALL_DIR/hapai"
  setup_path "$INSTALL_DIR"
}

# ─── Post-install setup ──────────────────────────────────────────────────────

post_install() {
  # Make all hooks executable
  find "$HAPAI_HOME/hooks" -name "*.sh" -type f -exec chmod +x {} + 2>/dev/null || true

  # Initialize state directories and audit log
  mkdir -p "$HAPAI_HOME/state" "$HAPAI_HOME/state/cooldown" 2>/dev/null || true
  touch "$HAPAI_HOME/audit.jsonl" 2>/dev/null || true

  # Verify hooks were copied
  local hook_count
  hook_count="$(find "$HAPAI_HOME/hooks" -name "*.sh" -type f 2>/dev/null | wc -l | tr -d ' ')"
  if [[ "$hook_count" -eq 0 ]]; then
    die "Installation failed: no hooks found in $HAPAI_HOME/hooks — the download may be incomplete"
  fi
  log_ok "Hooks verified: $hook_count scripts installed"

  # Copy default config if not already present
  if [[ ! -f "$HAPAI_HOME/hapai.yaml" ]]; then
    cp "$HAPAI_HOME/hapai.defaults.yaml" "$HAPAI_HOME/hapai.yaml" 2>/dev/null || true
    log_ok "Default config: $HAPAI_HOME/hapai.yaml"
  else
    log_info "Config already exists: $HAPAI_HOME/hapai.yaml (kept)"
  fi
}

verify_install() {
  if command -v hapai &>/dev/null; then
    log_ok "hapai $(hapai version) installed at $(command -v hapai)"
  elif [[ -x "$INSTALL_DIR/hapai" ]]; then
    log_ok "hapai installed at $INSTALL_DIR/hapai"
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
      log_warn "Run: source ~/.profile  (or open a new terminal) to use hapai in this session"
    fi
  else
    log_warn "Could not verify installation. Check that $INSTALL_DIR is in PATH."
  fi
}

# ─── Main ────────────────────────────────────────────────────────────────────

main() {
  if [ -t 1 ]; then
    printf "\n"
    printf "${CYAN}─── │${NC}  ${BOLD}╦ ╦╔═╗╔═╗╔═╗╦${NC}\n"
    printf "${CYAN}──  │${NC}  ${BOLD}╠═╣╠═╣╠═╝╠═╣║${NC}\n"
    printf "${CYAN}─── │${NC}  ${BOLD}╩ ╩╩ ╩╩  ╩ ╩╩${NC}\n"
    printf "        ${DIM}guardrails for AI coding assistants${NC}\n"
    printf "\n"
  fi

  local os
  os="$(detect_os)"
  log_info "Platform: $os"

  check_deps

  if [[ "$HAPAI_DEV" == "1" ]]; then
    install_from_source
  else
    resolve_version
    install_from_github
  fi

  post_install
  verify_install

  echo ""
  log_ok "${BOLD}hapai installed successfully!${NC}"
  echo ""
  echo "  Next steps:"
  echo "    cd /your/project"
  echo "    hapai install --project   # activate hooks for this project"
  echo "    hapai install --global    # activate hooks for all projects"
  echo "    hapai validate            # verify everything is working"
  echo ""
}

main "$@"

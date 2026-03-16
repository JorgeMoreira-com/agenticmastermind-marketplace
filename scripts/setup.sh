#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────
# agenticmastermind.ai — Setup Script
#
# Reads DEPENDENCIES.json and checks/installs all required tools.
#
# Usage:
#   ./scripts/setup.sh --plugin google-workspace              # Check and install deps
#   ./scripts/setup.sh --plugin google-workspace --check      # Check only, don't install
# ──────────────────────────────────────────────────────────────────────

MARKETPLACE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# ── Load shell environment (nvm, brew, etc.) ─────────────────────────
# AI agents and non-interactive shells don't source .zshrc/.bashrc,
# so we load common tool managers explicitly.
eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null)" 2>/dev/null || true
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" 2>/dev/null || true

CHECK_ONLY=false
PLUGIN=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()     { echo -e "${GREEN}[setup]${NC} $*"; }
warn()    { echo -e "${YELLOW}[warn]${NC}  $*"; }
error()   { echo -e "${RED}[error]${NC} $*" >&2; }
success() { echo -e "  ${GREEN}✓${NC} $*"; }
fail()    { echo -e "  ${RED}✗${NC} $*"; }
info()    { echo -e "  ${CYAN}→${NC} $*"; }

# ── Detect OS ────────────────────────────────────────────────────────

detect_os() {
  case "$(uname -s)" in
    Darwin*) echo "macos" ;;
    Linux*)  echo "linux" ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *)       echo "unknown" ;;
  esac
}

OS=$(detect_os)

# ── Parse args ───────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)
      CHECK_ONLY=true
      shift
      ;;
    --plugin)
      PLUGIN="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage:"
      echo "  setup.sh --plugin google-workspace              Check and install all deps"
      echo "  setup.sh --plugin google-workspace --check      Check only, don't install"
      exit 0
      ;;
    *)
      error "Unknown option: $1"
      exit 1
      ;;
  esac
done

# ── Bootstrap: ensure jq is available ────────────────────────────────

ensure_jq() {
  if command -v jq &>/dev/null; then
    return 0
  fi

  if [[ "$CHECK_ONLY" == "true" ]]; then
    fail "jq is not installed (needed to parse DEPENDENCIES.json)"
    return 1
  fi

  warn "jq not found — installing it first (needed to parse DEPENDENCIES.json)..."
  case "$OS" in
    macos)   brew install jq 2>/dev/null || { error "brew not found. Install jq manually: https://jqlang.github.io/jq/download/"; exit 1; } ;;
    linux)   sudo apt-get install -y jq 2>/dev/null || sudo dnf install -y jq 2>/dev/null || { error "Could not auto-install jq"; exit 1; } ;;
    *)       error "Please install jq manually: https://jqlang.github.io/jq/download/"; exit 1 ;;
  esac
}

# ── Check a single dependency ────────────────────────────────────────

check_dep() {
  local name="$1" version="$2" description="$3" check_cmd="$4" install_cmd="$5" post_install="${6:-}"

  echo ""
  echo -e "  ${BOLD}$name${NC} ($version) — $description"

  # Run check command
  if eval "$check_cmd" &>/dev/null; then
    local actual_version
    actual_version=$(eval "$check_cmd" 2>/dev/null | head -1)
    success "Installed: $actual_version"
    return 0
  fi

  fail "Not found"

  if [[ "$CHECK_ONLY" == "true" ]]; then
    info "Install with: $install_cmd"
    return 1
  fi

  # Install
  info "Installing..."
  if eval "$install_cmd"; then
    success "Installed successfully"
    if [[ -n "$post_install" ]]; then
      warn "Post-install action required: ${CYAN}$post_install${NC}"
    fi
    return 0
  else
    fail "Installation failed. Try manually: $install_cmd"
    return 1
  fi
}

# ── Main ─────────────────────────────────────────────────────────────

main() {
  if [[ -z "$PLUGIN" ]]; then
    error "Plugin required. Usage: setup.sh --plugin google-workspace"
    echo "  Available plugins:"
    for d in "$MARKETPLACE_ROOT"/plugins/*/; do
      [[ -d "$d" ]] && echo "    $(basename "$d")"
    done
    exit 1
  fi

  local DEPS_FILE="$MARKETPLACE_ROOT/plugins/$PLUGIN/dependencies.json"
  if [[ ! -f "$DEPS_FILE" ]]; then
    error "No dependencies.json found for plugin '$PLUGIN'"
    exit 1
  fi

  echo ""
  echo -e "${BOLD}╔══════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║   agenticmastermind.ai — Environment Setup      ║${NC}"
  echo -e "${BOLD}╚══════════════════════════════════════════════════╝${NC}"
  echo ""

  ensure_jq

  local passed=0 failed=0 total=0

  # ── Core dependencies ──
  log "Checking core dependencies for ${CYAN}$PLUGIN${NC}..."

  local core_count
  core_count=$(jq '.dependencies.core | length' "$DEPS_FILE")

  for i in $(seq 0 $((core_count - 1))); do
    local name version description check_cmd install_cmd post_install
    name=$(jq -r ".dependencies.core[$i].name" "$DEPS_FILE")
    version=$(jq -r ".dependencies.core[$i].version" "$DEPS_FILE")
    description=$(jq -r ".dependencies.core[$i].description" "$DEPS_FILE")
    check_cmd=$(jq -r ".dependencies.core[$i].check" "$DEPS_FILE")

    install_cmd=$(jq -r ".dependencies.core[$i].install.$OS // .dependencies.core[$i].install.all // .dependencies.core[$i].install.note // \"see dependencies.json\"" "$DEPS_FILE")
    post_install=$(jq -r ".dependencies.core[$i].postInstall // empty" "$DEPS_FILE")

    total=$((total + 1))
    if check_dep "$name" "$version" "$description" "$check_cmd" "$install_cmd" "$post_install"; then
      passed=$((passed + 1))
    else
      failed=$((failed + 1))
    fi
  done

  # ── Plugin-specific dependencies ──
  local plugin_count
  plugin_count=$(jq --arg p "$PLUGIN" '.dependencies.plugins[$p] // [] | length' "$DEPS_FILE")

  if [[ "$plugin_count" -gt 0 ]]; then
    echo ""
    log "Checking plugin-specific dependencies..."

    for i in $(seq 0 $((plugin_count - 1))); do
      local name version description check_cmd install_cmd post_install
      name=$(jq -r --arg p "$PLUGIN" ".dependencies.plugins[\$p][$i].name" "$DEPS_FILE")
      version=$(jq -r --arg p "$PLUGIN" ".dependencies.plugins[\$p][$i].version" "$DEPS_FILE")
      description=$(jq -r --arg p "$PLUGIN" ".dependencies.plugins[\$p][$i].description" "$DEPS_FILE")
      check_cmd=$(jq -r --arg p "$PLUGIN" ".dependencies.plugins[\$p][$i].check" "$DEPS_FILE")
      install_cmd=$(jq -r --arg p "$PLUGIN" ".dependencies.plugins[\$p][$i].install.$OS // .dependencies.plugins[\$p][$i].install.all // \"see dependencies.json\"" "$DEPS_FILE")
      post_install=$(jq -r --arg p "$PLUGIN" ".dependencies.plugins[\$p][$i].postInstall // empty" "$DEPS_FILE")

      total=$((total + 1))
      if check_dep "$name" "$version" "$description" "$check_cmd" "$install_cmd" "$post_install"; then
        passed=$((passed + 1))
      else
        failed=$((failed + 1))
      fi
    done
  fi

  # ── Summary ──
  echo ""
  echo -e "  ─────────────────────────────────────"
  if [[ "$failed" -eq 0 ]]; then
    echo -e "  ${GREEN}${BOLD}All $total dependencies satisfied.${NC}"
  else
    echo -e "  ${GREEN}$passed passed${NC}, ${RED}$failed failed${NC} out of $total"
  fi
  echo ""

  return "$failed"
}

main

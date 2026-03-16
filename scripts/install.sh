#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────
# agenticmastermind.ai — Multi-Agent Skill Installer
#
# Installs marketplace skills into any supported AI agent's skill directory.
# SKILL.md is a cross-platform open standard supported by 39+ agents.
#
# Usage:
#   ./scripts/install.sh                          # Auto-detect agents, install all
#   ./scripts/install.sh --agent claude           # Install to Claude Code only
#   ./scripts/install.sh --agent codex            # Install to Codex only
#   ./scripts/install.sh --agent all              # Install to all detected agents
#   ./scripts/install.sh --plugin google-workspace
#   ./scripts/install.sh --skill gws-gmail --agent codex
#   ./scripts/install.sh --list-agents            # Show detected agents
#   ./scripts/install.sh --uninstall --agent codex --plugin google-workspace
# ──────────────────────────────────────────────────────────────────────

MARKETPLACE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# ── Load shell environment ───────────────────────────────────────────
eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null)" 2>/dev/null || true
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" 2>/dev/null || true

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()     { echo -e "${GREEN}[install]${NC} $*"; }
warn()    { echo -e "${YELLOW}[warn]${NC}    $*"; }
error()   { echo -e "${RED}[error]${NC}   $*" >&2; }
success() { echo -e "  ${GREEN}✓${NC} $*"; }

# ── Agent Registry (bash 3 compatible) ───────────────────────────────

ALL_AGENTS="claude codex gemini copilot cursor amp"

agent_display_name() {
  case "$1" in
    claude)  echo "Claude Code" ;;
    codex)   echo "Codex" ;;
    gemini)  echo "Gemini CLI" ;;
    copilot) echo "GitHub Copilot" ;;
    cursor)  echo "Cursor" ;;
    amp)     echo "Amp" ;;
    *)       echo "$1" ;;
  esac
}

agent_global_dir() {
  case "$1" in
    claude)  echo "$HOME/.claude/skills" ;;
    codex)   echo "${CODEX_HOME:-$HOME/.codex}/skills" ;;
    gemini)  echo "$HOME/.gemini/skills" ;;
    copilot) echo "$HOME/.copilot/skills" ;;
    cursor)  echo "$HOME/.cursor/skills" ;;
    amp)     echo "${XDG_CONFIG_HOME:-$HOME/.config}/agents/skills" ;;
  esac
}

agent_detect_dir() {
  case "$1" in
    claude)  echo "$HOME/.claude" ;;
    codex)   echo "$HOME/.codex" ;;
    gemini)  echo "$HOME/.gemini" ;;
    copilot) echo "$HOME/.copilot" ;;
    cursor)  echo "$HOME/.cursor" ;;
    amp)     echo "${XDG_CONFIG_HOME:-$HOME/.config}/amp" ;;
  esac
}

agent_is_detected() {
  local detect_dir
  detect_dir=$(agent_detect_dir "$1")
  [[ -d "$detect_dir" ]]
}

# ── Detect installed agents ──────────────────────────────────────────

detect_agents() {
  for agent in $ALL_AGENTS; do
    if agent_is_detected "$agent"; then
      echo "$agent"
    fi
  done
}

# ── Install skills to an agent ───────────────────────────────────────

install_skills() {
  local agent="$1" plugin_filter="${2:-}" skill_filter="${3:-}"
  local target_dir
  target_dir=$(agent_global_dir "$agent")
  local agent_name
  agent_name=$(agent_display_name "$agent")

  log "Installing to ${CYAN}$agent_name${NC} → $target_dir"

  local installed=0

  for plugin_dir in "$MARKETPLACE_ROOT"/plugins/*/; do
    [[ -d "$plugin_dir" ]] || continue
    local plugin_name
    plugin_name=$(basename "$plugin_dir")

    if [[ -n "$plugin_filter" && "$plugin_name" != "$plugin_filter" ]]; then
      continue
    fi

    local skills_dir="$plugin_dir/skills"
    [[ -d "$skills_dir" ]] || continue

    for skill_dir in "$skills_dir"/*/; do
      [[ -d "$skill_dir" ]] || continue
      local skill_name
      skill_name=$(basename "$skill_dir")

      if [[ -n "$skill_filter" && "$skill_name" != "$skill_filter" ]]; then
        continue
      fi

      local target_skill_dir="$target_dir/$skill_name"
      mkdir -p "$target_skill_dir"
      cp -r "$skill_dir"/* "$target_skill_dir/"
      installed=$((installed + 1))
    done
  done

  if [[ $installed -gt 0 ]]; then
    success "$installed skills installed to $agent_name"
  else
    warn "No skills matched the filter"
  fi
}

# ── Uninstall skills from an agent ───────────────────────────────────

uninstall_skills() {
  local agent="$1" plugin_filter="${2:-}" skill_filter="${3:-}"
  local target_dir
  target_dir=$(agent_global_dir "$agent")
  local agent_name
  agent_name=$(agent_display_name "$agent")
  local removed=0

  log "Uninstalling from ${CYAN}$agent_name${NC}"

  for plugin_dir in "$MARKETPLACE_ROOT"/plugins/*/; do
    [[ -d "$plugin_dir" ]] || continue
    local plugin_name
    plugin_name=$(basename "$plugin_dir")

    if [[ -n "$plugin_filter" && "$plugin_name" != "$plugin_filter" ]]; then
      continue
    fi

    local skills_dir="$plugin_dir/skills"
    [[ -d "$skills_dir" ]] || continue

    for skill_dir in "$skills_dir"/*/; do
      [[ -d "$skill_dir" ]] || continue
      local skill_name
      skill_name=$(basename "$skill_dir")

      if [[ -n "$skill_filter" && "$skill_name" != "$skill_filter" ]]; then
        continue
      fi

      local target_skill_dir="$target_dir/$skill_name"
      if [[ -d "$target_skill_dir" ]]; then
        rm -rf "$target_skill_dir"
        removed=$((removed + 1))
      fi
    done
  done

  success "$removed skills removed from $agent_name"
}

# ── List agents ──────────────────────────────────────────────────────

cmd_list_agents() {
  echo ""
  echo -e "${BOLD}Supported AI Agents${NC}"
  echo ""
  for agent in $ALL_AGENTS; do
    local status dir name
    dir=$(agent_detect_dir "$agent")
    name=$(agent_display_name "$agent")
    local gdir
    gdir=$(agent_global_dir "$agent")
    if [[ -d "$dir" ]]; then
      status="${GREEN}detected${NC}"
    else
      status="${YELLOW}not found${NC}"
    fi
    printf "  %-10s %-20s %b  (%s)\n" "$agent" "$name" "$status" "$gdir"
  done
  echo ""
}

# ── Main ─────────────────────────────────────────────────────────────

main() {
  local agent_filter="" plugin_filter="" skill_filter="" uninstall=false list_agents=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --agent)      agent_filter="$2"; shift 2 ;;
      --plugin)     plugin_filter="$2"; shift 2 ;;
      --skill)      skill_filter="$2"; shift 2 ;;
      --uninstall)  uninstall=true; shift ;;
      --list-agents) list_agents=true; shift ;;
      --help|-h)
        echo "Usage:"
        echo "  install.sh                                      Auto-detect agents, install all"
        echo "  install.sh --agent claude|codex|gemini|all      Target specific agent"
        echo "  install.sh --plugin google-workspace            Filter by plugin"
        echo "  install.sh --skill gws-gmail                    Filter by skill"
        echo "  install.sh --uninstall --agent codex            Remove skills"
        echo "  install.sh --list-agents                        Show detected agents"
        exit 0
        ;;
      *) error "Unknown option: $1"; exit 1 ;;
    esac
  done

  if [[ "$list_agents" == "true" ]]; then
    cmd_list_agents
    return 0
  fi

  echo ""
  echo -e "${BOLD}╔══════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║   agenticmastermind.ai — Skill Installer        ║${NC}"
  echo -e "${BOLD}╚══════════════════════════════════════════════════╝${NC}"
  echo ""

  # Determine target agents
  local agents=""
  if [[ "$agent_filter" == "all" ]]; then
    agents="$ALL_AGENTS"
  elif [[ -n "$agent_filter" ]]; then
    # Validate agent name
    local valid=false
    for a in $ALL_AGENTS; do
      if [[ "$a" == "$agent_filter" ]]; then valid=true; break; fi
    done
    if [[ "$valid" != "true" ]]; then
      error "Unknown agent: $agent_filter"
      echo "  Supported: $ALL_AGENTS"
      exit 1
    fi
    agents="$agent_filter"
  else
    # Auto-detect
    agents=$(detect_agents)
    if [[ -z "$agents" ]]; then
      warn "No AI agents detected. Use --agent to specify one, or --list-agents to see options."
      exit 1
    fi
    log "Auto-detected agents: $agents"
  fi

  # Execute
  for agent in $agents; do
    if [[ "$uninstall" == "true" ]]; then
      uninstall_skills "$agent" "$plugin_filter" "$skill_filter"
    else
      install_skills "$agent" "$plugin_filter" "$skill_filter"
    fi
  done

  echo ""
}

main "$@"

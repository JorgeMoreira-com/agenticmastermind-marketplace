#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────
# agenticmastermind.ai — Skill Sync Script
#
# Pulls upstream skills from source repos, respects local customizations,
# and tracks sync state in sources.json.
#
# Usage:
#   ./scripts/sync.sh                   # Sync all sources
#   ./scripts/sync.sh google-workspace  # Sync a specific source
#   ./scripts/sync.sh --status          # Show sync status
#   ./scripts/sync.sh --mark-custom <source> <skill>  # Mark a skill as customized
#   ./scripts/sync.sh --unmark-custom <source> <skill> # Unmark customization
#   ./scripts/sync.sh --diff <source> <skill>          # Show upstream vs local diff
# ──────────────────────────────────────────────────────────────────────

MARKETPLACE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCES_FILE="$MARKETPLACE_ROOT/sources.json"
CACHE_DIR="$MARKETPLACE_ROOT/.sync-cache"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()   { echo -e "${GREEN}[sync]${NC} $*"; }
warn()  { echo -e "${YELLOW}[warn]${NC} $*"; }
error() { echo -e "${RED}[error]${NC} $*" >&2; }
info()  { echo -e "${CYAN}[info]${NC} $*"; }

# ── Helpers ──────────────────────────────────────────────────────────

require_jq() {
  if ! command -v jq &>/dev/null; then
    error "jq is required. Install with: brew install jq"
    exit 1
  fi
}

get_source_field() {
  local source_name="$1" field="$2"
  jq -r --arg name "$source_name" '.sources[] | select(.name == $name) | .'"$field" "$SOURCES_FILE"
}

set_source_field() {
  local source_name="$1" field="$2" value="$3"
  local tmp
  tmp=$(mktemp)
  jq --arg name "$source_name" --arg field "$field" --arg val "$value" \
    '(.sources[] | select(.name == $name))[$field] = $val' "$SOURCES_FILE" > "$tmp"
  mv "$tmp" "$SOURCES_FILE"
}

is_customized() {
  local source_name="$1" skill_name="$2"
  jq -r --arg name "$source_name" --arg skill "$skill_name" \
    '.sources[] | select(.name == $name) | .customized | index($skill) != null' "$SOURCES_FILE"
}

# ── Commands ─────────────────────────────────────────────────────────

cmd_status() {
  require_jq
  log "Sync status for all sources:"
  echo ""
  jq -r '.sources[] | "  Source: \(.name)\n  Repo:   \(.repo)\n  Branch: \(.branch)\n  Plugin: \(.plugin)\n  Last synced: \(.lastSyncedAt // "never")\n  Commit: \(.lastSyncedCommit // "none")\n  Customized: \(.customized | if length == 0 then "none" else join(", ") end)\n"' "$SOURCES_FILE"
}

cmd_mark_custom() {
  require_jq
  local source_name="$1" skill_name="$2"
  local tmp
  tmp=$(mktemp)
  jq --arg name "$source_name" --arg skill "$skill_name" \
    '(.sources[] | select(.name == $name) | .customized) += [$skill] | (.sources[] | select(.name == $name) | .customized) |= unique' \
    "$SOURCES_FILE" > "$tmp"
  mv "$tmp" "$SOURCES_FILE"
  log "Marked ${CYAN}$skill_name${NC} as customized in source ${CYAN}$source_name${NC}"
}

cmd_unmark_custom() {
  require_jq
  local source_name="$1" skill_name="$2"
  local tmp
  tmp=$(mktemp)
  jq --arg name "$source_name" --arg skill "$skill_name" \
    '(.sources[] | select(.name == $name) | .customized) -= [$skill]' \
    "$SOURCES_FILE" > "$tmp"
  mv "$tmp" "$SOURCES_FILE"
  log "Unmarked ${CYAN}$skill_name${NC} — it will be overwritten on next sync"
}

cmd_diff() {
  require_jq
  local source_name="$1" skill_name="$2"
  local repo branch upstream_path plugin
  repo=$(get_source_field "$source_name" "repo")
  branch=$(get_source_field "$source_name" "branch")
  upstream_path=$(get_source_field "$source_name" "upstreamSkillsPath")
  plugin=$(get_source_field "$source_name" "plugin")

  local cache_repo="$CACHE_DIR/$source_name"
  local local_skill="$MARKETPLACE_ROOT/plugins/$plugin/skills/$skill_name/SKILL.md"
  local upstream_skill="$cache_repo/$upstream_path/$skill_name/SKILL.md"

  if [[ ! -d "$cache_repo" ]]; then
    log "Cloning $repo into cache..."
    git clone --depth 1 --branch "$branch" "$repo" "$cache_repo" 2>/dev/null
  else
    log "Updating cache..."
    git -C "$cache_repo" fetch origin "$branch" --depth 1 2>/dev/null
    git -C "$cache_repo" reset --hard "origin/$branch" 2>/dev/null
  fi

  if [[ ! -f "$upstream_skill" ]]; then
    error "Upstream skill $skill_name not found"
    return 1
  fi
  if [[ ! -f "$local_skill" ]]; then
    error "Local skill $skill_name not found"
    return 1
  fi

  info "Diff: local (left) vs upstream (right)"
  diff --color=always "$local_skill" "$upstream_skill" || true
}

cmd_sync() {
  require_jq
  local filter="${1:-}"
  mkdir -p "$CACHE_DIR"

  local source_count
  source_count=$(jq '.sources | length' "$SOURCES_FILE")

  for i in $(seq 0 $((source_count - 1))); do
    local name repo branch upstream_path plugin
    name=$(jq -r ".sources[$i].name" "$SOURCES_FILE")
    repo=$(jq -r ".sources[$i].repo" "$SOURCES_FILE")
    branch=$(jq -r ".sources[$i].branch" "$SOURCES_FILE")
    upstream_path=$(jq -r ".sources[$i].upstreamSkillsPath" "$SOURCES_FILE")
    plugin=$(jq -r ".sources[$i].plugin" "$SOURCES_FILE")

    # Filter to specific source if requested
    if [[ -n "$filter" && "$name" != "$filter" ]]; then
      continue
    fi

    log "Syncing source: ${CYAN}$name${NC} from $repo ($branch)"

    # Clone or update cache
    local cache_repo="$CACHE_DIR/$name"
    if [[ ! -d "$cache_repo" ]]; then
      log "Cloning $repo..."
      git clone --depth 1 --branch "$branch" "$repo" "$cache_repo" 2>/dev/null
    else
      log "Pulling latest..."
      git -C "$cache_repo" fetch origin "$branch" --depth 1 2>/dev/null
      git -C "$cache_repo" reset --hard "origin/$branch" 2>/dev/null
    fi

    local latest_commit
    latest_commit=$(git -C "$cache_repo" rev-parse HEAD)

    local upstream_skills_dir="$cache_repo/$upstream_path"
    local local_skills_dir="$MARKETPLACE_ROOT/plugins/$plugin/skills"
    mkdir -p "$local_skills_dir"

    # Track counts
    local added=0 updated=0 skipped=0 unchanged=0

    # Iterate upstream skills
    for skill_dir in "$upstream_skills_dir"/*/; do
      [[ -d "$skill_dir" ]] || continue
      local skill_name
      skill_name=$(basename "$skill_dir")
      local local_skill_dir="$local_skills_dir/$skill_name"

      # Check if customized
      if [[ $(is_customized "$name" "$skill_name") == "true" ]]; then
        warn "SKIP (customized): $skill_name"
        skipped=$((skipped + 1))
        continue
      fi

      if [[ ! -d "$local_skill_dir" ]]; then
        # New skill — copy it
        cp -r "$skill_dir" "$local_skill_dir"
        log "  ${GREEN}ADD${NC}: $skill_name"
        added=$((added + 1))
      else
        # Existing skill — check if changed
        if diff -rq "$skill_dir" "$local_skill_dir" &>/dev/null; then
          unchanged=$((unchanged + 1))
        else
          rm -rf "$local_skill_dir"
          cp -r "$skill_dir" "$local_skill_dir"
          log "  ${YELLOW}UPDATE${NC}: $skill_name"
          updated=$((updated + 1))
        fi
      fi
    done

    # Update sources.json with sync metadata
    local tmp now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    tmp=$(mktemp)
    jq --arg name "$name" --arg commit "$latest_commit" --arg ts "$now" \
      '(.sources[] | select(.name == $name)) |= (.lastSyncedCommit = $commit | .lastSyncedAt = $ts)' \
      "$SOURCES_FILE" > "$tmp"
    mv "$tmp" "$SOURCES_FILE"

    echo ""
    log "Done: ${GREEN}+$added${NC} added, ${YELLOW}~$updated${NC} updated, ${RED}!$skipped${NC} skipped (customized), $unchanged unchanged"
    log "Synced to commit: $latest_commit"
    echo ""
  done
}

# ── Main ─────────────────────────────────────────────────────────────

main() {
  require_jq

  case "${1:-}" in
    --status)
      cmd_status
      ;;
    --mark-custom)
      [[ $# -lt 3 ]] && { error "Usage: sync.sh --mark-custom <source> <skill>"; exit 1; }
      cmd_mark_custom "$2" "$3"
      ;;
    --unmark-custom)
      [[ $# -lt 3 ]] && { error "Usage: sync.sh --unmark-custom <source> <skill>"; exit 1; }
      cmd_unmark_custom "$2" "$3"
      ;;
    --diff)
      [[ $# -lt 3 ]] && { error "Usage: sync.sh --diff <source> <skill>"; exit 1; }
      cmd_diff "$2" "$3"
      ;;
    --help|-h)
      echo "Usage:"
      echo "  sync.sh                                  Sync all sources"
      echo "  sync.sh <source-name>                    Sync a specific source"
      echo "  sync.sh --status                         Show sync status"
      echo "  sync.sh --mark-custom <source> <skill>   Protect a skill from overwrites"
      echo "  sync.sh --unmark-custom <source> <skill> Allow a skill to be overwritten"
      echo "  sync.sh --diff <source> <skill>          Diff local vs upstream"
      ;;
    *)
      cmd_sync "${1:-}"
      ;;
  esac
}

main "$@"

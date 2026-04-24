#!/usr/bin/env bash
# Changelog generator skill
# Generates a changelog based on git commits since the last tag/release

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo '.')"
CHANGELOG_FILE="${CHANGELOG_FILE:-CHANGELOG.md}"
OUTPUT_FILE="${OUTPUT_FILE:-/tmp/changelog_draft.md}"
SINCE_TAG="${SINCE_TAG:-}"
NEW_VERSION="${NEW_VERSION:-}"
GROUP_BY_TYPE="${GROUP_BY_TYPE:-true}"

# Commit type labels
declare -A TYPE_LABELS=(
  [feat]="Features"
  [fix]="Bug Fixes"
  [docs]="Documentation"
  [style]="Styles"
  [refactor]="Refactoring"
  [perf]="Performance Improvements"
  [test]="Tests"
  [chore]="Chores"
  [ci]="CI/CD"
  [build]="Build System"
  [revert]="Reverts"
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log() { echo "[changelog-generator] $*"; }
err() { echo "[changelog-generator] ERROR: $*" >&2; }

get_latest_tag() {
  git describe --tags --abbrev=0 2>/dev/null || echo ""
}

get_commits_since() {
  local since="$1"
  if [[ -n "$since" ]]; then
    git log "${since}..HEAD" --pretty=format:"%H|%s|%an|%as" --no-merges
  else
    git log --pretty=format:"%H|%s|%an|%as" --no-merges -n 100
  fi
}

parse_conventional_commit() {
  local subject="$1"
  # Match: type(scope): description  OR  type: description
  if [[ "$subject" =~ ^([a-z]+)(\([^)]+\))?(!)?:[[:space:]](.+)$ ]]; then
    echo "${BASH_REMATCH[1]}|${BASH_REMATCH[2]}|${BASH_REMATCH[3]}|${BASH_REMATCH[4]}"
  else
    echo "other|||$subject"
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  cd "$REPO_ROOT"

  log "Starting changelog generation..."

  # Determine the base tag
  if [[ -z "$SINCE_TAG" ]]; then
    SINCE_TAG="$(get_latest_tag)"
    if [[ -n "$SINCE_TAG" ]]; then
      log "Using latest tag as base: $SINCE_TAG"
    else
      log "No tags found — including all commits (last 100)"
    fi
  else
    log "Using provided base tag: $SINCE_TAG"
  fi

  # Determine new version label
  if [[ -z "$NEW_VERSION" ]]; then
    NEW_VERSION="Unreleased"
  fi

  local today
  today="$(date +%Y-%m-%d)"

  # Collect commits
  local raw_commits
  raw_commits="$(get_commits_since "$SINCE_TAG")"

  if [[ -z "$raw_commits" ]]; then
    log "No commits found since ${SINCE_TAG:-beginning}. Nothing to generate."
    echo "## [$NEW_VERSION] - $today" > "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    echo "_No changes._" >> "$OUTPUT_FILE"
    cat "$OUTPUT_FILE"
    exit 0
  fi

  # Organise commits by type
  declare -A type_entries
  local breaking_entries=""

  while IFS='|' read -r hash subject author date; do
    [[ -z "$hash" ]] && continue
    local parsed type scope breaking description
    parsed="$(parse_conventional_commit "$subject")"
    IFS='|' read -r type scope breaking description <<< "$parsed"

    local short_hash="${hash:0:7}"
    local entry="- ${description} (${short_hash})"

    if [[ "$breaking" == "!" ]]; then
      breaking_entries+="${entry}"$'\n'
    fi

    type_entries["$type"]+="${entry}"$'\n'
  done <<< "$raw_commits"

  # Write changelog draft
  {
    echo "## [$NEW_VERSION] - $today"
    echo ""

    if [[ -n "$breaking_entries" ]]; then
      echo "### ⚠ Breaking Changes"
      echo ""
      printf "%s" "$breaking_entries"
      echo ""
    fi

    for type in feat fix perf refactor docs style test build ci chore revert other; do
      local entries="${type_entries[$type]:-}"
      [[ -z "$entries" ]] && continue
      local label="${TYPE_LABELS[$type]:-Other}"
      echo "### $label"
      echo ""
      printf "%s" "$entries"
      echo ""
    done
  } > "$OUTPUT_FILE"

  log "Changelog draft written to: $OUTPUT_FILE"
  echo "---"
  cat "$OUTPUT_FILE"

  # Optionally prepend to existing CHANGELOG.md
  if [[ "${PREPEND_TO_CHANGELOG:-false}" == "true" ]] && [[ -f "$CHANGELOG_FILE" ]]; then
    local tmp
    tmp="$(mktemp)"
    cat "$OUTPUT_FILE" "$CHANGELOG_FILE" > "$tmp"
    mv "$tmp" "$CHANGELOG_FILE"
    log "Prepended draft to $CHANGELOG_FILE"
  fi
}

main "$@"

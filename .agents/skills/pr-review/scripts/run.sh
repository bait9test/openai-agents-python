#!/usr/bin/env bash
# PR Review Skill - Automated pull request review script
# Analyzes code changes, checks for common issues, and posts review comments

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

PR_NUMBER="${PR_NUMBER:-}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-}"
REVIEW_LEVEL="${REVIEW_LEVEL:-standard}"  # minimal | standard | thorough
POST_REVIEW="${POST_REVIEW:-true}"

# ─── Helpers ──────────────────────────────────────────────────────────────────
log()  { echo "[pr-review] $*"; }
err()  { echo "[pr-review] ERROR: $*" >&2; }
die()  { err "$*"; exit 1; }

require_cmd() {
  command -v "$1" &>/dev/null || die "Required command not found: $1"
}

# ─── Validation ───────────────────────────────────────────────────────────────
validate_inputs() {
  [[ -n "$PR_NUMBER" ]]         || die "PR_NUMBER is required"
  [[ -n "$GITHUB_TOKEN" ]]      || die "GITHUB_TOKEN is required"
  [[ -n "$GITHUB_REPOSITORY" ]] || die "GITHUB_REPOSITORY is required"

  require_cmd curl
  require_cmd jq
  require_cmd git

  log "Reviewing PR #${PR_NUMBER} in ${GITHUB_REPOSITORY} (level: ${REVIEW_LEVEL})"
}

# ─── GitHub API helpers ───────────────────────────────────────────────────────
gh_api() {
  local method="$1"
  local path="$2"
  shift 2
  curl -fsSL \
    -X "$method" \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com${path}" \
    "$@"
}

fetch_pr_metadata() {
  log "Fetching PR metadata..."
  PR_DATA=$(gh_api GET "/repos/${GITHUB_REPOSITORY}/pulls/${PR_NUMBER}")
  PR_TITLE=$(echo "$PR_DATA" | jq -r '.title')
  PR_BODY=$(echo "$PR_DATA"  | jq -r '.body // ""')
  PR_BASE=$(echo "$PR_DATA"  | jq -r '.base.sha')
  PR_HEAD=$(echo "$PR_DATA"  | jq -r '.head.sha')
  PR_AUTHOR=$(echo "$PR_DATA" | jq -r '.user.login')
  log "PR: \"${PR_TITLE}\" by @${PR_AUTHOR}"
}

fetch_pr_files() {
  log "Fetching changed files..."
  PR_FILES=$(gh_api GET "/repos/${GITHUB_REPOSITORY}/pulls/${PR_NUMBER}/files")
  CHANGED_FILES=$(echo "$PR_FILES" | jq -r '.[].filename')
  FILE_COUNT=$(echo "$PR_FILES" | jq 'length')
  log "${FILE_COUNT} files changed"
}

# ─── Review checks ────────────────────────────────────────────────────────────
check_large_diff() {
  local additions deletions
  additions=$(echo "$PR_DATA" | jq '.additions')
  deletions=$(echo "$PR_DATA" | jq '.deletions')
  local total=$(( additions + deletions ))

  if (( total > 1000 )); then
    WARNINGS+=("Large diff detected (${total} lines changed). Consider splitting into smaller PRs.")
  fi
}

check_test_coverage() {
  local has_src_changes=false
  local has_test_changes=false

  while IFS= read -r file; do
    [[ "$file" == src/* || "$file" == *.py ]] && \
      [[ "$file" != *test* && "$file" != *spec* ]] && has_src_changes=true
    [[ "$file" == *test* || "$file" == *spec* ]] && has_test_changes=true
  done <<< "$CHANGED_FILES"

  if $has_src_changes && ! $has_test_changes; then
    WARNINGS+=("Source code changed but no test files were modified. Please add or update tests.")
  fi
}

check_changelog() {
  if [[ "$REVIEW_LEVEL" == "thorough" ]]; then
    local has_changelog=false
    while IFS= read -r file; do
      [[ "$file" == CHANGELOG* || "$file" == CHANGES* ]] && has_changelog=true
    done <<< "$CHANGED_FILES"

    if ! $has_changelog; then
      SUGGESTIONS+=("Consider updating the CHANGELOG for user-facing changes.")
    fi
  fi
}

check_pr_description() {
  if [[ -z "$PR_BODY" || "${#PR_BODY}" -lt 20 ]]; then
    WARNINGS+=("PR description is missing or too short. Please describe what this PR does and why.")
  fi
}

# ─── Build review body ────────────────────────────────────────────────────────
build_review_body() {
  local body="## Automated PR Review\n\n"

  body+="**Files changed:** ${FILE_COUNT}  \n"
  body+="**Review level:** ${REVIEW_LEVEL}\n\n"

  if (( ${#WARNINGS[@]} > 0 )); then
    body+="### ⚠️ Warnings\n"
    for w in "${WARNINGS[@]}"; do
      body+="- ${w}\n"
    done
    body+="\n"
  fi

  if (( ${#SUGGESTIONS[@]} > 0 )); then
    body+="### 💡 Suggestions\n"
    for s in "${SUGGESTIONS[@]}"; do
      body+="- ${s}\n"
    done
    body+="\n"
  fi

  if (( ${#WARNINGS[@]} == 0 && ${#SUGGESTIONS[@]} == 0 )); then
    body+="### ✅ No issues found\n\nLooks good to me!"
  fi

  REVIEW_BODY="$body"
}

post_review() {
  if [[ "$POST_REVIEW" != "true" ]]; then
    log "POST_REVIEW=false — skipping GitHub comment"
    echo -e "$REVIEW_BODY"
    return
  fi

  local event="COMMENT"
  (( ${#WARNINGS[@]} > 0 )) && event="REQUEST_CHANGES"

  local payload
  payload=$(jq -n \
    --arg body "$(echo -e "$REVIEW_BODY")" \
    --arg event "$event" \
    '{body: $body, event: $event}')

  gh_api POST "/repos/${GITHUB_REPOSITORY}/pulls/${PR_NUMBER}/reviews" \
    -H "Content-Type: application/json" \
    -d "$payload" > /dev/null

  log "Review posted (event: ${event})"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
  WARNINGS=()
  SUGGESTIONS=()

  validate_inputs
  fetch_pr_metadata
  fetch_pr_files

  check_pr_description
  check_large_diff
  check_test_coverage
  check_changelog

  build_review_body
  post_review

  log "Done."
}

main "$@"

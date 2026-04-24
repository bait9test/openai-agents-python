#!/bin/bash
# Issue Triage Script
# Automatically triages GitHub issues by analyzing content,
# applying labels, assigning priority, and routing to appropriate teams.

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
GH_REPO="${GH_REPO:-openai/openai-agents-python}"
ISSUE_NUMBER="${ISSUE_NUMBER:-}"
DRY_RUN="${DRY_RUN:-false}"
VERBOSE="${VERBOSE:-false}"

# Label definitions
LABEL_BUG="bug"
LABEL_FEATURE="enhancement"
LABEL_DOCS="documentation"
LABEL_QUESTION="question"
LABEL_DUPLICATE="duplicate"
LABEL_NEEDS_INFO="needs-more-information"
LABEL_PRIORITY_HIGH="priority: high"
LABEL_PRIORITY_MEDIUM="priority: medium"
LABEL_PRIORITY_LOW="priority: low"

# ── Helpers ───────────────────────────────────────────────────────────────────
log() { echo "[triage] $*"; }
debug() { [[ "$VERBOSE" == "true" ]] && echo "[triage:debug] $*" || true; }
err()  { echo "[triage:error] $*" >&2; }

require_cmd() {
  command -v "$1" &>/dev/null || { err "Required command not found: $1"; exit 1; }
}

# Apply a label to the issue (skip in dry-run mode)
apply_label() {
  local label="$1"
  if [[ "$DRY_RUN" == "true" ]]; then
    log "[dry-run] Would apply label: $label"
  else
    gh issue edit "$ISSUE_NUMBER" --add-label "$label" --repo "$GH_REPO" 2>/dev/null || \
      log "Warning: could not apply label '$label' (may not exist)"
  fi
}

# Post a comment on the issue
post_comment() {
  local body="$1"
  if [[ "$DRY_RUN" == "true" ]]; then
    log "[dry-run] Would post comment:"
    echo "$body"
  else
    gh issue comment "$ISSUE_NUMBER" --body "$body" --repo "$GH_REPO"
  fi
}

# ── Fetch issue data ──────────────────────────────────────────────────────────
fetch_issue() {
  log "Fetching issue #${ISSUE_NUMBER} from ${GH_REPO}..."
  gh issue view "$ISSUE_NUMBER" \
    --repo "$GH_REPO" \
    --json number,title,body,labels,author,createdAt,comments \
    2>/dev/null
}

# ── Classify issue type ───────────────────────────────────────────────────────
classify_issue() {
  local title="$1"
  local body="$2"
  local combined
  combined=$(echo "${title} ${body}" | tr '[:upper:]' '[:lower:]')

  # Bug indicators
  if echo "$combined" | grep -qE "(error|exception|traceback|crash|broken|fail|regression|unexpected|wrong result)"; then
    echo "bug"
    return
  fi

  # Documentation indicators
  if echo "$combined" | grep -qE "(docs|documentation|readme|example|tutorial|typo|unclear)"; then
    echo "docs"
    return
  fi

  # Feature request indicators
  if echo "$combined" | grep -qE "(feature|request|enhancement|add support|would be nice|suggestion|proposal)"; then
    echo "feature"
    return
  fi

  # Question indicators
  if echo "$combined" | grep -qE "(how to|how do|question|help|confused|not sure|wondering)"; then
    echo "question"
    return
  fi

  echo "unknown"
}

# ── Assess priority ───────────────────────────────────────────────────────────
assess_priority() {
  local type="$1"
  local title="$2"
  local body="$3"
  local combined
  combined=$(echo "${title} ${body}" | tr '[:upper:]' '[:lower:]')

  if [[ "$type" == "bug" ]]; then
    if echo "$combined" | grep -qE "(security|data loss|production|critical|blocker|breaking change)"; then
      echo "high"
    elif echo "$combined" | grep -qE "(regression|frequently|many users|common)"; then
      echo "medium"
    else
      echo "low"
    fi
  elif [[ "$type" == "feature" ]]; then
    echo "medium"
  else
    echo "low"
  fi
}

# ── Check for missing information ─────────────────────────────────────────────
needs_more_info() {
  local body="$1"
  # Flag if body is very short or missing reproduction steps for bugs
  local word_count
  word_count=$(echo "$body" | wc -w | tr -d ' ')
  [[ "$word_count" -lt 20 ]] && echo "true" || echo "false"
}

# ── Main triage logic ─────────────────────────────────────────────────────────
main() {
  require_cmd gh
  require_cmd jq

  if [[ -z "$ISSUE_NUMBER" ]]; then
    err "ISSUE_NUMBER environment variable is required."
    exit 1
  fi

  local issue_json
  issue_json=$(fetch_issue)

  local title body existing_labels
  title=$(echo "$issue_json" | jq -r '.title')
  body=$(echo "$issue_json"  | jq -r '.body // ""')
  existing_labels=$(echo "$issue_json" | jq -r '[.labels[].name] | join(",")')

  debug "Title: $title"
  debug "Existing labels: $existing_labels"

  # Skip if already triaged
  if echo "$existing_labels" | grep -qE "(triaged|bug|enhancement|documentation|question)"; then
    log "Issue #${ISSUE_NUMBER} already has type labels — skipping."
    exit 0
  fi

  local issue_type priority
  issue_type=$(classify_issue "$title" "$body")
  priority=$(assess_priority "$issue_type" "$title" "$body")
  local missing_info
  missing_info=$(needs_more_info "$body")

  log "Classified as: type=$issue_type priority=$priority needs_info=$missing_info"

  # Apply type label
  case "$issue_type" in
    bug)      apply_label "$LABEL_BUG" ;;
    feature)  apply_label "$LABEL_FEATURE" ;;
    docs)     apply_label "$LABEL_DOCS" ;;
    question) apply_label "$LABEL_QUESTION" ;;
    *)        log "Could not determine issue type; no type label applied." ;;
  esac

  # Apply priority label
  case "$priority" in
    high)   apply_label "$LABEL_PRIORITY_HIGH" ;;
    medium) apply_label "$LABEL_PRIORITY_MEDIUM" ;;
    low)    apply_label "$LABEL_PRIORITY_LOW" ;;
  esac

  # Request more info if needed
  if [[ "$missing_info" == "true" ]]; then
    apply_label "$LABEL_NEEDS_INFO"
    post_comment "Thanks for opening this issue! It looks like some details might be missing. Could you please provide more context, such as steps to reproduce, expected vs actual behavior, and your environment (Python version, SDK version)? This will help us address it faster. 🙏"
  fi

  log "Triage complete for issue #${ISSUE_NUMBER}."
}

main "$@"

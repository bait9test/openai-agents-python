#!/usr/bin/env bash
# Release Manager Script
# Automates the release process: version bumping, changelog generation,
# tagging, and publishing for openai-agents-python.

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
REPO_ROOT="$(git rev-parse --show-toplevel)"
PYPROJECT="$REPO_ROOT/pyproject.toml"
CHANGELOG="$REPO_ROOT/CHANGELOG.md"
DEFAULT_BRANCH="main"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { echo "[release-manager] $*"; }
err()  { echo "[release-manager] ERROR: $*" >&2; exit 1; }

require_cmd() {
  command -v "$1" &>/dev/null || err "Required command not found: $1"
}

current_version() {
  grep -E '^version\s*=' "$PYPROJECT" | head -1 | sed 's/.*=\s*"\(.*\)"/\1/'
}

bump_version() {
  local current="$1"
  local bump_type="$2"  # major | minor | patch

  IFS='.' read -r major minor patch <<< "$current"
  case "$bump_type" in
    major) major=$((major + 1)); minor=0; patch=0 ;;
    minor) minor=$((minor + 1)); patch=0 ;;
    patch) patch=$((patch + 1)) ;;
    *) err "Unknown bump type: $bump_type. Use major, minor, or patch." ;;
  esac

  echo "${major}.${minor}.${patch}"
}

update_pyproject_version() {
  local new_version="$1"
  sed -i.bak "s/^version = \".*\"/version = \"${new_version}\"/" "$PYPROJECT"
  rm -f "${PYPROJECT}.bak"
  log "Updated pyproject.toml version to $new_version"
}

prepend_changelog_entry() {
  local version="$1"
  local date
  date=$(date +%Y-%m-%d)
  local tmp
  tmp=$(mktemp)

  # Build a minimal changelog header for the new version
  {
    echo "## [$version] - $date"
    echo ""
    echo "### Changes"
    echo "- See commit history for details."
    echo ""
    cat "$CHANGELOG"
  } > "$tmp"

  mv "$tmp" "$CHANGELOG"
  log "Prepended changelog entry for $version"
}

create_git_tag() {
  local version="$1"
  local tag="v${version}"

  if git rev-parse "$tag" &>/dev/null; then
    log "Tag $tag already exists — skipping tag creation."
  else
    git tag -a "$tag" -m "Release $tag"
    log "Created git tag $tag"
  fi
}

push_release() {
  local version="$1"
  local tag="v${version}"

  git push origin "$DEFAULT_BRANCH"
  git push origin "$tag"
  log "Pushed branch and tag $tag to origin"
}

build_and_publish() {
  log "Building distribution packages..."
  python -m build --outdir dist/

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log "DRY_RUN=true — skipping PyPI publish."
  else
    log "Publishing to PyPI..."
    python -m twine upload dist/*
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  require_cmd git
  require_cmd python
  require_cmd sed

  local bump_type="${1:-patch}"

  log "Starting release process (bump: $bump_type)"

  # Ensure we are on the default branch and up to date
  local current_branch
  current_branch=$(git rev-parse --abbrev-ref HEAD)
  if [[ "$current_branch" != "$DEFAULT_BRANCH" ]]; then
    err "Must be on '$DEFAULT_BRANCH' branch to release. Currently on '$current_branch'."
  fi

  git pull origin "$DEFAULT_BRANCH"

  # Ensure working tree is clean
  if ! git diff --quiet || ! git diff --cached --quiet; then
    err "Working tree is not clean. Commit or stash changes before releasing."
  fi

  local old_version
  old_version=$(current_version)
  log "Current version: $old_version"

  local new_version
  new_version=$(bump_version "$old_version" "$bump_type")
  log "New version:     $new_version"

  update_pyproject_version "$new_version"
  prepend_changelog_entry "$new_version"

  git add "$PYPROJECT" "$CHANGELOG"
  git commit -m "chore: release v${new_version}"
  log "Committed version bump"

  create_git_tag "$new_version"

  if [[ "${DRY_RUN:-false}" != "true" ]]; then
    push_release "$new_version"
    build_and_publish "$new_version"
  else
    log "DRY_RUN=true — skipping push and publish."
  fi

  log "Release v${new_version} complete!"
}

main "$@"

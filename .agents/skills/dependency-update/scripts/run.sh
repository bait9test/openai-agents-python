#!/usr/bin/env bash
# Dependency update skill script
# Checks for outdated dependencies and creates a summary of available updates

set -euo pipefail

# ── helpers ──────────────────────────────────────────────────────────────────

log()  { echo "[dependency-update] $*"; }
err()  { echo "[dependency-update] ERROR: $*" >&2; }

require_cmd() {
  if ! command -v "$1" &>/dev/null; then
    err "Required command not found: $1"
    exit 1
  fi
}

# ── env / defaults ───────────────────────────────────────────────────────────

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
OUTPUT_FILE="${OUTPUT_FILE:-${REPO_ROOT}/.agents/skills/dependency-update/output/report.md}"
PYPROJECT="${REPO_ROOT}/pyproject.toml"
DRY_RUN="${DRY_RUN:-true}"

# ── checks ───────────────────────────────────────────────────────────────────

require_cmd python3
require_cmd pip

if [[ ! -f "${PYPROJECT}" ]]; then
  err "pyproject.toml not found at ${PYPROJECT}"
  exit 1
fi

mkdir -p "$(dirname "${OUTPUT_FILE}")"

# ── gather outdated packages ─────────────────────────────────────────────────

log "Checking for outdated packages..."

# pip list --outdated emits CSV-like output; capture it
OUTDATED_JSON=$(python3 -m pip list --outdated --format=json 2>/dev/null || echo '[]')

PACKAGE_COUNT=$(echo "${OUTDATED_JSON}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(len(data))
")

log "Found ${PACKAGE_COUNT} outdated package(s)."

# ── build markdown report ────────────────────────────────────────────────────

log "Writing report to ${OUTPUT_FILE}"

python3 - <<PYEOF
import json, datetime, os

outdated_json = '''${OUTDATED_JSON}'''
packages = json.loads(outdated_json)

lines = [
    "# Dependency Update Report",
    "",
    f"Generated: {datetime.datetime.utcnow().strftime('%Y-%m-%d %H:%M UTC')}",
    "",
]

if not packages:
    lines.append("All dependencies are up to date. ✅")
else:
    lines += [
        f"Found **{len(packages)}** outdated package(s):",
        "",
        "| Package | Current | Latest | Type |",
        "|---------|---------|--------|------|",
    ]
    for pkg in sorted(packages, key=lambda p: p["name"].lower()):
        name    = pkg.get("name", "")
        current = pkg.get("version", "")
        latest  = pkg.get("latest_version", "")
        kind    = pkg.get("latest_filetype", "wheel")
        lines.append(f"| {name} | {current} | {latest} | {kind} |")

    lines += [
        "",
        "## Recommended Actions",
        "",
        "Run the following to upgrade all listed packages:",
        "",
        "\`\`\`bash",
    ]
    pkg_names = " ".join(p["name"] for p in packages)
    lines.append(f"pip install --upgrade {pkg_names}")
    lines += [
        "\`\`\`",
        "",
        "> **Note:** Review each upgrade for breaking changes before merging.",
    ]

output_path = "${OUTPUT_FILE}"
os.makedirs(os.path.dirname(output_path), exist_ok=True)
with open(output_path, "w") as fh:
    fh.write("\n".join(lines) + "\n")

print(f"Report written to {output_path}")
PYEOF

# ── optional: apply updates ───────────────────────────────────────────────────

if [[ "${DRY_RUN}" == "false" ]]; then
  log "DRY_RUN=false — applying updates..."
  python3 -m pip install --upgrade \
    $(echo "${OUTDATED_JSON}" | python3 -c "
import json, sys
print(' '.join(p['name'] for p in json.load(sys.stdin)))
") || true
  log "Upgrade complete."
else
  log "DRY_RUN=true — skipping actual upgrades (set DRY_RUN=false to apply)."
fi

log "Done."

#!/bin/bash
# examples-auto-run skill: automatically discovers and runs example scripts,
# capturing output and reporting success/failure for each.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
EXAMPLES_DIR="${ROOT_DIR}/examples"
REPORT_FILE="${ROOT_DIR}/.agents/skills/examples-auto-run/run-report.md"
TIMEOUT_SECONDS="${EXAMPLES_TIMEOUT:-30}"
PYTHON_BIN="${PYTHON_BIN:-python}"

passed=0
failed=0
skipped=0
errors=()

log() {
  echo "[examples-auto-run] $*"
}

check_dependencies() {
  if ! command -v "$PYTHON_BIN" &>/dev/null; then
    log "ERROR: Python not found (tried '$PYTHON_BIN'). Set PYTHON_BIN to override."
    exit 1
  fi

  if [ ! -d "$EXAMPLES_DIR" ]; then
    log "ERROR: Examples directory not found at $EXAMPLES_DIR"
    exit 1
  fi
}

should_skip() {
  local file="$1"
  # Skip files that require interactive input or external secrets not available in CI
  if grep -qE '(input\(|getpass\.|SKIP_IN_CI)' "$file" 2>/dev/null; then
    return 0
  fi
  return 1
}

run_example() {
  local file="$1"
  local rel_path
  rel_path="$(realpath --relative-to="$ROOT_DIR" "$file")"

  if should_skip "$file"; then
    log "SKIP  $rel_path"
    ((skipped++)) || true
    echo "| \`$rel_path\` | ⏭ skipped | — |" >> "$REPORT_FILE"
    return
  fi

  log "RUN   $rel_path"
  local output
  local exit_code=0

  output=$(timeout "$TIMEOUT_SECONDS" "$PYTHON_BIN" "$file" 2>&1) || exit_code=$?

  if [ $exit_code -eq 124 ]; then
    log "TIMEOUT $rel_path (>${TIMEOUT_SECONDS}s)"
    ((failed++)) || true
    errors+=("$rel_path")
    echo "| \`$rel_path\` | ⏱ timeout | Exceeded ${TIMEOUT_SECONDS}s |" >> "$REPORT_FILE"
  elif [ $exit_code -ne 0 ]; then
    log "FAIL  $rel_path (exit $exit_code)"
    ((failed++)) || true
    errors+=("$rel_path")
    # Truncate output to first 5 lines for the report
    local short_output
    short_output=$(echo "$output" | head -5 | sed 's/|/\\|/g' | tr '\n' ' ')
    echo "| \`$rel_path\` | ❌ failed | \`$short_output\` |" >> "$REPORT_FILE"
  else
    log "PASS  $rel_path"
    ((passed++)) || true
    echo "| \`$rel_path\` | ✅ passed | — |" >> "$REPORT_FILE"
  fi
}

write_report_header() {
  mkdir -p "$(dirname "$REPORT_FILE")"
  cat > "$REPORT_FILE" <<EOF
# Examples Auto-Run Report

Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
Python: $($PYTHON_BIN --version 2>&1)
Timeout per example: ${TIMEOUT_SECONDS}s

| Example | Status | Notes |
|---------|--------|-------|
EOF
}

write_report_footer() {
  cat >> "$REPORT_FILE" <<EOF

## Summary

- ✅ Passed: $passed
- ❌ Failed: $failed
- ⏭ Skipped: $skipped
- **Total: $((passed + failed + skipped))**
EOF

  if [ ${#errors[@]} -gt 0 ]; then
    echo -e "\n## Failed Examples\n" >> "$REPORT_FILE"
    for e in "${errors[@]}"; do
      echo "- \`$e\`" >> "$REPORT_FILE"
    done
  fi
}

main() {
  log "Starting examples auto-run from $EXAMPLES_DIR"
  check_dependencies
  write_report_header

  # Find all top-level Python example files, sorted for deterministic order
  while IFS= read -r -d '' file; do
    run_example "$file"
  done < <(find "$EXAMPLES_DIR" -maxdepth 2 -name '*.py' ! -name '__*' -print0 | sort -z)

  write_report_footer

  log "Done. Passed=$passed Failed=$failed Skipped=$skipped"
  log "Report written to $REPORT_FILE"

  if [ $failed -gt 0 ]; then
    log "One or more examples failed. See report for details."
    exit 1
  fi
}

main "$@"

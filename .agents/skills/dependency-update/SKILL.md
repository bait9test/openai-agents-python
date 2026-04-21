# Dependency Update Skill

This skill automates checking for outdated dependencies and creating pull requests with updates.

## What it does

1. Scans `pyproject.toml` and `requirements*.txt` files for dependencies
2. Checks for newer versions on PyPI
3. Runs the test suite to verify updates don't break anything
4. Generates a summary report of available updates
5. Optionally applies safe (patch/minor) updates automatically

## When to use

- Scheduled weekly/monthly dependency maintenance
- Before a release to ensure dependencies are current
- After a security advisory to check for vulnerable packages

## Inputs

| Variable | Description | Default |
|----------|-------------|--------|
| `UPDATE_LEVEL` | Which updates to apply: `patch`, `minor`, `major`, or `none` (report only) | `patch` |
| `EXCLUDE_PACKAGES` | Comma-separated list of packages to skip | `""` |
| `RUN_TESTS` | Whether to run tests after updating | `true` |
| `FAIL_ON_MAJOR` | Exit with error if major updates are available | `false` |

## Outputs

- `dependency-report.md` — full report of current vs latest versions
- Modified `pyproject.toml` / `requirements*.txt` if updates were applied
- Exit code `0` on success, `1` if tests fail after update

## Example usage

```bash
UPDATE_LEVEL=minor RUN_TESTS=true bash .agents/skills/dependency-update/scripts/run.sh
```

## Notes

- Always review the generated report before merging changes
- Major version updates are never applied automatically — they require manual review
- The skill respects version pins (e.g., `==1.2.3`) and will not override them

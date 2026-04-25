# Release Manager Skill

Automates the release process for the openai-agents-python package, including version bumping, changelog finalization, tag creation, and PyPI publishing preparation.

## What it does

1. **Version Bump** — Updates version in `pyproject.toml` and `src/agents/__init__.py` based on semver rules (major/minor/patch)
2. **Changelog Finalization** — Moves unreleased changelog entries under the new version heading with today's date
3. **Release Commit** — Creates a release commit with the updated files
4. **Tag Creation** — Creates an annotated git tag for the release
5. **PyPI Prep** — Validates the package builds cleanly with `python -m build`
6. **GitHub Release Draft** — Opens a draft GitHub release with the changelog notes pre-filled

## Inputs

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `BUMP_TYPE` | Version bump type: `major`, `minor`, or `patch` | No | `patch` |
| `DRY_RUN` | If `true`, no commits/tags/releases are created | No | `false` |
| `GITHUB_TOKEN` | GitHub token for creating draft releases | Yes | — |

## Usage

```bash
export GITHUB_TOKEN="ghp_..."
export BUMP_TYPE="minor"
bash .agents/skills/release-manager/scripts/run.sh
```

## Dry Run

```bash
export DRY_RUN=true
bash .agents/skills/release-manager/scripts/run.sh
```

## Notes

- Requires `python -m build` and `twine` to be installed for package validation
- The script will abort if there are uncommitted changes in the working directory
- Changelog must have an `## [Unreleased]` section; if missing, the script warns but continues
- Tags follow the format `v{major}.{minor}.{patch}`

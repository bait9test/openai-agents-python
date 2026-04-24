# Changelog Generator Skill

Automatically generates or updates the CHANGELOG.md file based on merged pull requests and commits since the last release.

## What it does

1. Detects the latest git tag / release to determine the comparison base
2. Collects all merged PRs and commits since that tag
3. Categorises changes into: Features, Bug Fixes, Breaking Changes, Documentation, Chores
4. Writes a new changelog entry in [Keep a Changelog](https://keepachangelog.com) format
5. Opens a PR (or pushes directly to the current branch) with the updated `CHANGELOG.md`

## Inputs

| Variable | Required | Default | Description |
|---|---|---|---|
| `GITHUB_TOKEN` | yes | — | Token used to query the GitHub API and create PRs |
| `REPO` | yes | — | `owner/repo` slug |
| `BASE_TAG` | no | latest tag | Override the comparison base tag |
| `TARGET_VERSION` | no | `Unreleased` | Version string for the new section header |
| `CREATE_PR` | no | `true` | Set to `false` to commit directly to the current branch |
| `DRY_RUN` | no | `false` | Print the generated entry without writing any files |

## Outputs

- Updated `CHANGELOG.md` at the repository root
- (Optional) A pull-request titled `chore: update changelog for <TARGET_VERSION>`

## Usage

```yaml
- uses: .agents/skills/changelog-generator
  with:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    REPO: openai/openai-agents-python
    TARGET_VERSION: "1.2.0"
```

## Category labels → changelog sections

| PR label | Changelog section |
|---|---|
| `breaking-change` | Breaking Changes |
| `enhancement`, `feature` | Features |
| `bug`, `fix` | Bug Fixes |
| `documentation`, `docs` | Documentation |
| `chore`, `ci`, `deps` | Chores |
| *(unlabelled)* | Other |

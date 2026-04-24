# PR Review Skill

Automatically reviews pull requests for code quality, style consistency, potential bugs, and adherence to project conventions.

## What it does

- Analyzes changed files in a pull request
- Checks for common Python anti-patterns and bugs
- Validates that tests are included for new functionality
- Ensures docstrings and type hints are present
- Verifies imports are clean and organized
- Checks for hardcoded secrets or credentials
- Reviews for performance concerns
- Summarizes findings as a structured review comment

## Inputs

| Name | Description | Required |
|------|-------------|----------|
| `pr_number` | The pull request number to review | Yes |
| `repo` | The repository in `owner/repo` format | Yes |
| `github_token` | GitHub token with PR read/write access | Yes |
| `strict_mode` | Fail on warnings in addition to errors | No (default: false) |
| `skip_tests_check` | Skip validation that tests exist for new code | No (default: false) |

## Outputs

- Posts a structured review comment on the PR
- Returns exit code 0 if no blocking issues found
- Returns exit code 1 if blocking issues are detected

## Usage

```yaml
- uses: .agents/skills/pr-review
  with:
    pr_number: ${{ github.event.pull_request.number }}
    repo: ${{ github.repository }}
    github_token: ${{ secrets.GITHUB_TOKEN }}
    strict_mode: false
```

## Review Checks

### Blocking (exit code 1)
- Hardcoded secrets or API keys
- Syntax errors in Python files
- Missing `__init__.py` in new packages
- Broken imports referencing non-existent modules

### Warnings (blocking only in strict mode)
- Missing type hints on public functions
- Missing docstrings on public classes/functions
- Test coverage for new modules
- Overly complex functions (cyclomatic complexity > 10)

### Informational
- Suggested refactors
- Style inconsistencies
- Dependency additions without version pinning

## Notes

- Requires `gh` CLI to be installed and authenticated
- Requires `python3` with `ast` module (stdlib)
- Works with both draft and ready-for-review PRs
- Review comments are updated (not duplicated) on re-runs

# Test Runner Skill

Automatically runs the project's test suite, reports results, and identifies failing tests with actionable summaries.

## Overview

This skill executes the full test suite (or a targeted subset) for the `openai-agents-python` project, captures output, and produces a structured summary of pass/fail counts, error messages, and suggested fixes.

## Trigger Conditions

- A pull request is opened or updated
- A commit is pushed to a tracked branch
- Manually triggered via workflow dispatch
- After dependency updates to verify nothing is broken

## Behavior

1. **Setup** — Install dependencies from `pyproject.toml` / `requirements.txt` using the appropriate Python version.
2. **Run Tests** — Execute `pytest` (or the configured test runner) with coverage enabled.
3. **Parse Results** — Collect exit code, pass/fail/skip counts, and any error tracebacks.
4. **Summarize** — Post a comment on the PR or print a structured report to stdout.
5. **Fail Fast** — Exit with a non-zero code if any tests fail, so CI pipelines can gate merges.

## Inputs

| Variable | Description | Default |
|---|---|---|
| `TEST_PATH` | Directory or file to test | `tests/` |
| `PYTHON_VERSION` | Python version to use | `3.11` |
| `COVERAGE_THRESHOLD` | Minimum coverage % required | `80` |
| `EXTRA_PYTEST_ARGS` | Additional args passed to pytest | `` |
| `GITHUB_TOKEN` | Token for posting PR comments | *(required for PR comments)* |
| `PR_NUMBER` | Pull request number | *(optional)* |

## Outputs

- Console report with pass/fail/skip counts
- Coverage summary
- PR comment (if `PR_NUMBER` and `GITHUB_TOKEN` are set)
- Exit code `0` on success, `1` on failure

## Example Usage

```bash
TEST_PATH=tests/ PYTHON_VERSION=3.11 bash .agents/skills/test-runner/scripts/run.sh
```

## Notes

- Requires `pytest` and `pytest-cov` to be available in the environment.
- If running in a GitHub Actions context, the script will automatically detect `GITHUB_ACTIONS=true` and adjust output formatting.
- Coverage reports are written to `.coverage` and `coverage.xml` for downstream consumers.

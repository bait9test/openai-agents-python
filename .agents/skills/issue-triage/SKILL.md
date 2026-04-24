# Issue Triage Skill

Automatically triages new GitHub issues by analyzing content, applying labels, assigning priority, and routing to appropriate team members.

## What it does

- Reads newly opened or updated GitHub issues
- Classifies issue type (bug, feature request, question, docs, etc.)
- Applies relevant labels based on content analysis
- Assigns priority level (P0-P3) based on severity signals
- Identifies affected components (agents, tracing, tools, streaming, etc.)
- Posts a structured triage comment summarizing findings
- Requests additional information when the issue is incomplete
- Flags duplicates by searching existing issues

## Inputs

| Variable | Description |
|---|---|
| `GITHUB_TOKEN` | GitHub token with issues read/write permissions |
| `ISSUE_NUMBER` | The issue number to triage |
| `REPO` | Repository in `owner/repo` format (default: current repo) |

## Outputs

- Labels applied to the issue
- Priority comment posted
- Duplicate links if found
- Triage summary in structured format

## Trigger

Typically triggered on `issues.opened` and `issues.edited` GitHub events.

## Label taxonomy

### Type labels
- `bug` — Something isn't working as expected
- `enhancement` — New feature or improvement request
- `question` — Usage question or clarification needed
- `documentation` — Docs gap or inaccuracy
- `performance` — Performance regression or concern

### Priority labels
- `priority: P0` — Critical, blocking production use
- `priority: P1` — High, significant impact
- `priority: P2` — Medium, normal priority
- `priority: P3` — Low, nice to have

### Component labels
- `component: agents` — Core agent runner
- `component: tracing` — Tracing and observability
- `component: tools` — Tool definitions and execution
- `component: streaming` — Streaming responses
- `component: handoffs` — Agent handoff logic
- `component: guardrails` — Input/output guardrails
- `component: models` — Model provider integrations

## Example triage comment

```
## 🏷️ Issue Triage

**Type:** Bug  
**Priority:** P1  
**Component:** component: streaming  

**Summary:** Streaming responses appear to drop tokens intermittently when using the `Runner.run_streamed()` method with tool calls enabled.

**Next steps:**
- [ ] Reproduce with minimal example
- [ ] Check if issue is model-specific
- [ ] Review streaming buffer handling in `src/agents/stream_events.py`

*Triaged automatically — please update labels if classification is incorrect.*
```

## Notes

- Duplicate detection uses semantic similarity against the last 200 closed issues
- If the issue body is under 50 characters, a request-for-info comment is posted automatically
- Triage can be re-run by adding the `needs-triage` label

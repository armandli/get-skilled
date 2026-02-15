# Plan File Format Specification

## Overview

A plan file is a markdown document with YAML frontmatter. It describes a body of work decomposed into step blocks with explicit dependencies, enabling concurrent execution by multiple agents.

## YAML Frontmatter

```yaml
---
title: "Short descriptive title"
goal: "One sentence describing what this plan achieves"
status: draft        # draft | active | completed | abandoned
created: YYYY-MM-DD
modified: YYYY-MM-DD
---
```

All fields are required. `status` starts as `draft` and is updated as work progresses.

## Body Sections

The body contains these sections in order:

### Goal

Restate the goal with any additional context not captured in the frontmatter one-liner.

### Scope

Two subsections:
- **Included** — what this plan covers
- **Excluded** — what is explicitly out of scope

### Constraints

Bullet list of technical, time, resource, or organizational limits.

### Step Blocks

The core of the plan. Each step block follows the format below.

### Dependency Graph

A text diagram showing the execution flow. See the SKILL.md for the diagram format.

### Execution Summary

A table summarizing plan metrics:

```markdown
| Metric             | Value |
|--------------------|-------|
| Total steps        | N     |
| Entry points       | N     |
| Critical path      | N     |
| Max parallelism    | N     |
```

## Step Block Format

Each step block is an `###` heading with the following structure:

```markdown
### `step-id` -- Step Title

| Field        | Value                                    |
|--------------|------------------------------------------|
| Status       | pending                                  |
| Depends on   | `dep-1`, `dep-2` or none                 |
| Effort       | S                                        |
| Assigned to  |                                          |

**Description:** What this step accomplishes and why it matters.

**Expected inputs:**
- From `dep-id`: What this step needs from that dependency

**Procedures:**
1. First concrete action
2. Second concrete action
3. Third concrete action

**Outcomes:**
- **Success:** Verifiable criteria that prove the step is done
- **Failure -- [name]:** What went wrong and how to recover
```

### Field Rules

- **`step-id`**: Kebab-case, unique within the plan. Examples: `setup-environment`, `design-api-contracts`
- **Status**: One of `pending`, `in-progress`, `done`, `blocked`, `skipped`
- **Depends on**: Comma-separated list of step IDs in backticks, or `none` for entry points
- **Effort**: One of `S` (< 1 hour), `M` (1-4 hours), `L` (4-8 hours), `XL` (multi-day)
- **Assigned to**: Agent name or blank. Acts as a cooperative lock — only one agent should claim a step at a time
- **Expected inputs**: Required if the step has dependencies. Describes what each dependency produces that this step consumes.
- **Procedures**: Numbered list of concrete, actionable steps. No vague instructions.
- **Outcomes**: Must include at least one **Success** outcome. Include **Failure** outcomes for foreseeable risks with recovery instructions.

## Concurrent Execution Rules

These rules govern how agents pick up and execute steps:

1. A step is **ready** when all its dependencies have status `done` and its own status is `pending`
2. An agent claims a step by writing its name in the `Assigned to` field and setting status to `in-progress`
3. Multiple ready steps can be executed in parallel by different agents
4. When a step finishes, the agent sets its status to `done` (or `blocked`/`skipped` with a reason)
5. After completing a step, re-scan all pending steps — new steps may now be ready

### Execution Loop

```
repeat:
  scan all steps where status = pending
  filter to steps where all dependencies have status = done
  if no ready steps and pending steps remain → deadlock (circular dependency)
  if no pending steps remain → plan complete
  for each ready step:
    claim it (set assigned-to, set status = in-progress)
    execute procedures
    set status = done | blocked | skipped
```

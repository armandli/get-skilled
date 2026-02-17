---
name: get-planted
description: Creates structured development plans as markdown files with step blocks, dependencies, and concurrent execution support. Use when user asks to "create a plan", "make a development plan", "plan out this project", or "build an execution plan". Do NOT use for simple to-do lists, task tracking, or questions about what a development plan is.
argument-hint: "[path/to/plan.md]"
---

## Critical: Read This First

You are creating (or modifying) a structured development plan. A plan is a markdown file with YAML frontmatter and step blocks that support concurrent execution by multiple agents. Each step block declares its dependencies, expected inputs, and defined outcomes so an execution engine (or team of agents) can run independent steps in parallel.

Read the full plan format specification at [references/plan-format.md](references/plan-format.md) before writing any plan content.

The `plan-planter` subagent handles plan validation when available (Step 5). It subsumes the scrutiny checklist and adds dependency optimization and flaw analysis.

## Workflow

Follow these steps in order. Do not skip steps.

### Step 1: Determine Mode

The plan file path comes from `$ARGUMENTS`. If no path is given, ask the user for one.

- **File exists** → Modification mode. Load and parse the plan. Present a summary: title, goal, status, total steps, how many are done/pending/blocked. Ask the user what they want to change.
- **File does not exist** → Creation mode. Proceed to Step 2.
- **File exists but is malformed** → Warn the user. Offer two choices: start fresh or attempt to salvage valid step blocks from the existing content.

### Step 2: Gather Goals

Have an interactive conversation to establish:

1. **Primary goal** — one sentence describing what the plan achieves
2. **Scope** — what is included and what is explicitly excluded
3. **Constraints** — technical, time, resource, or organizational limits
4. **Known risks** — anything that could derail execution

**Gate:** Do not proceed to Step 3 until you have at least a clear goal and scope. If the user is vague, ask clarifying questions.

### Step 3: Decompose into Step Blocks

Break the work into step blocks. For each block, define all required fields from the plan format spec. Present the blocks to the user and iterate until they approve.

Guidelines for decomposition:
- Each step should be completable by a single agent in one focused session
- Prefer many small steps over few large ones — this maximizes parallelism
- If a step has the word "and" in its title, consider splitting it
- If you reach 30+ steps, suggest splitting into multiple plan files with cross-references

### Step 4: Map Dependencies

After step blocks are approved, analyze and present the dependency structure:

1. **Entry points** — steps with no dependencies (these can start immediately)
2. **Critical path** — the longest chain of sequential dependencies
3. **Parallel lanes** — groups of steps that can execute concurrently

Present the dependency graph as an indented text diagram. Example:

```
Entry: setup-environment, gather-requirements
  setup-environment → build-database-schema → seed-test-data
  gather-requirements → design-api-contracts → implement-endpoints
  build-database-schema + design-api-contracts → integration-tests
  implement-endpoints + seed-test-data → integration-tests
  integration-tests → write-documentation → final-review
```

Ask the user to confirm the dependency structure is correct.

### Step 5: Scrutiny Review

**If the `plan-planter` subagent is available**, delegate validation to it. Pass the plan content (step blocks, dependencies, and goal) to the subagent. It runs a 5-phase validation: structural integrity, dependency optimization (transitive reduction for maximum parallelism), detail sufficiency, plan flaw analysis, and a summary report. It will interact with the user directly to resolve any issues found. Wait for the subagent to complete before proceeding to Step 6.

**Fallback (if the subagent is unavailable):** Run through every item in the scrutiny checklist at [references/scrutiny-checklist.md](references/scrutiny-checklist.md) manually.

For every issue found (whether via subagent or manual review):
- State the problem clearly
- Propose a specific fix
- Apply the fix after user approval

Do not proceed to Step 6 if any circular dependencies remain unresolved.

### Step 6: Write Plan File

1. Assemble the full plan following the format in [references/plan-format.md](references/plan-format.md)
2. Write it to the target path. If the directory doesn't exist, create it.
3. After writing, verify:
   - All step IDs are unique
   - All dependency references point to existing step IDs
   - All required fields are present in every step block
4. Report a summary to the user:
   - Total steps
   - Entry points (can start immediately)
   - Critical path length
   - Maximum parallelism (most steps that can run at the same time)

## Error Handling

- **File not writable** → Attempt to create the parent directory. If that fails, suggest an alternative path.
- **Circular dependencies detected** → List the cycle. Must be resolved before saving.
- **User abandons mid-workflow** → Offer to save current progress with `status: draft` in the frontmatter.
- **30+ steps** → Suggest splitting into multiple plan files. Each file should be a coherent sub-plan with clear entry and exit points.

---
name: agent-memory-v2
description: Sets up and manages diagram-driven project memory in docs/memory/. Scaffolds directories (docs/memory, docs/plans), creates memory files (kanban.md, architecture.md, adr.md, config.md, bug.md), and writes CLAUDE.md to guide future sessions. Diagrams in docs/memory drive source code changes. Use when the user asks to "set up agent memory v2", "scaffold project structure", "initialize memory", "add an ADR", "log a bug fix", "update config memory", "update kanban", "create kanban item", "move item to in progress", "complete a kanban item", "sync code from diagram", "update source from architecture", "reflect diagram changes in code", or "update memory files". Also triggered by command-style invocations: "agent-memory-v2 create-item", "agent-memory-v2 progress", "agent-memory-v2 complete". Depends on mermaid-diagram-guide for diagram syntax. Do NOT use for committing or pushing changes, and do NOT use the old agent-memory skill for v2 projects.
argument-hint: "[create-item <name> \"details\" | progress <name> | complete <name>]"
---

# agent-memory-v2 Skill

## Detect Intent

### Command-Style Invocation (check first)

If `$ARGUMENTS` is present, parse it as a kanban command and go directly to **Path B-Kanban**:

| Invocation | Action |
|-----------|--------|
| `create-item <name> "details"` | Create new item in the `open` column with the given name and details |
| `progress <name>` | Move item matching `<name>` from `open` → `inprogress` |
| `complete <name>` | Move item matching `<name>` from any column → `complete` |

Item name matching is case-insensitive and partial — match the closest item if exact match not found. If ambiguous (multiple partial matches), list them and ask the user to clarify.

### Natural Language Invocation

If no `$ARGUMENTS`, determine the path from the user's message:

- **Setup / Scaffold** — initialize project structure, create dirs, memory files, CLAUDE.md. → **Path A**
- **Memory Operations** — read/write kanban, ADR, config, or bug files. → **Path B**
- **Diagram-Driven Development** — user modified a diagram in `docs/memory/` and wants source code updated to reflect it, or asks to sync code from a diagram. → **Path C**

---

## Path A — Setup / Scaffold

### Step A1 — Verify Working Directory

Run `pwd` and `git rev-parse --show-toplevel 2>/dev/null`.

If the git root differs from `pwd`, warn the user and stop. All paths must be relative to the repo root.

---

### Step A2 — Create Directories

```bash
mkdir -p docs/memory docs/plans
```

Both created with `-p` (no error if already present).

---

### Step A3 — Create Memory Files

Use Glob to check which files already exist under `docs/memory/*.md`.

For each file **not** already present, create it using the Write tool with the initial content specified in [references/initial-content.md](references/initial-content.md). Files to create:

- `docs/memory/kanban.md`
- `docs/memory/architecture.md`
- `docs/memory/adr.md`
- `docs/memory/config.md`
- `docs/memory/bug.md`

Skip any file that already exists — never overwrite existing memory.

---

### Step A4 — Create or Update `.claude/CLAUDE.md`

Use Glob to check whether `.claude/CLAUDE.md` exists at the repo root.

- If `.claude/` does not exist, create it first with `mkdir -p .claude`.
- If `.claude/CLAUDE.md` **does not exist**: use the Write tool to create it with the content in [references/claude-md-content.md](references/claude-md-content.md).
- If `.claude/CLAUDE.md` **already exists**: read it first, then use the Edit tool to append the agent-memory-v2 section if it is not already present. Never remove existing content.

---

### Step A5 — Report

Print a summary:
- Directories created or already existed
- Each memory file: created or skipped
- `.claude/CLAUDE.md`: created, updated, or skipped

---

## Path B-Kanban — Kanban Command Operations

This path handles both command-style (`$ARGUMENTS`) and natural-language kanban requests.

### Step BK1 — Read Kanban File

Read `docs/memory/kanban.md`. Parse the mermaid `kanban` block to extract the current items and their columns.

### Step BK2 — Execute the Operation

**`create-item <name> "details"`** (or natural language equivalent: "add kanban item", "create task"):
- Generate a unique item ID: slugify the name (lowercase, hyphens, max 30 chars), e.g. `fix-auth-bug`
- If an item with the same ID already exists, append a short suffix (`-2`, `-3`, etc.)
- Add the new item under the `open` column:
  ```
  open[Open]
      fix-auth-bug[Fix auth bug — details here]
  ```
- The label should be: `name — details` (em dash separator). If no details provided, use just the name.

**`progress <name>`** (or "move to in progress", "start working on"):
- Find the item in the `open` column whose label best matches `<name>`
- Move it: remove from `open`, add under `inprogress`
- Preserve all other items exactly

**`complete <name>`** (or "complete item", "mark done", "finish"):
- Find the item in any column whose label best matches `<name>`
- Move it: remove from current column, add under `complete`
- Preserve all other items exactly

### Step BK3 — Write Back

Use the Edit tool to update the mermaid `kanban` block in `docs/memory/kanban.md`. Replace only the fenced code block — preserve the heading and any surrounding text.

### Step BK4 — Report

State: which item was affected, what operation was performed, and which column it now lives in.

---

### Step B1 — Identify Target File(s)

Read all target files before editing.

| Intent | Target file(s) |
|--------|---------------|
| Add/move kanban item | `docs/memory/kanban.md` |
| Add architectural decision | `docs/memory/adr.md` |
| Add/update config entry | `docs/memory/config.md` |
| Add bug fix record | `docs/memory/bug.md` |

---

### Step B2 — Apply File-Specific Schema

See [references/memory-schemas.md](references/memory-schemas.md) for the exact schema and rules for each file.

---

### Step B3 — Write Back

Use the Edit tool (not Write) to make targeted updates — preserve all existing content.

- For `kanban.md`: edit the mermaid diagram block — move items between columns or add new items. Keep the fenced code block intact.
- For `adr.md` and `bug.md`: append new rows at the bottom of the table.
- For `config.md`: append under the relevant section heading, or add a new section.
- Never truncate or overwrite content not part of the requested change.
- If a table header row is missing, add it before appending data rows.

---

### Step B4 — Report

Confirm which file(s) were updated and what changed. If any forbidden config content was omitted, state what and why.

---

## Path C — Diagram-Driven Development

This path is triggered when the user has edited a diagram in `docs/memory/` and wants the source code updated to match it, or explicitly asks to "sync code from diagram" / "update source from architecture".

See [references/diagram-driven-dev.md](references/diagram-driven-dev.md) for the full workflow.

### Step C1 — Identify the Diagram

Ask the user which diagram changed (if not already stated). Supported diagrams:

| File | Diagram type | Drives |
|------|-------------|--------|
| `docs/memory/architecture.md` | Class diagram | Class/struct/interface definitions, relationships, method signatures |
| `docs/memory/*.md` (sequence) | Sequence diagram | Function/method call flows, API contracts, inter-service protocols |
| `docs/memory/*.md` (state) | State diagram | State machine implementations, lifecycle enums, transition handlers |

### Step C2 — Read the Diagram

Read the target file. Parse the mermaid diagram to understand the intended structure or behavior. Refer to the mermaid-diagram-guide skill for syntax — load the relevant reference file from that skill if needed.

### Step C3 — Diff Against Current Source

Explore the source code to find the corresponding implementation:
- For architecture diagrams: find class/struct/interface definitions
- For sequence diagrams: find the relevant functions or API handlers
- For state diagrams: find the state machine or lifecycle logic

Identify what is missing, renamed, or structurally different.

### Step C4 — Apply Changes

Make the minimum set of source changes needed to bring the code in line with the diagram:
- Add missing classes, methods, fields, or relationships
- Rename entities to match the diagram
- Add missing state transitions or sequence steps

Do not add features, docstrings, or refactors beyond what the diagram specifies.

### Step C5 — Report

List each source change made (file, what changed, which diagram element drove it).

---

## Safety Rules

- Never write secrets or credentials to any memory file
- Never delete rows from `adr.md` or `bug.md` (append-only)
- Never delete kanban items — move them to the `complete` column instead
- Always read before writing — do not overwrite content blindly
- Never remove or overwrite existing `CLAUDE.md` content
- ADR entries must only capture decisions NOT already expressible as a diagram change — if a decision is structural, encode it in `architecture.md` instead

---

## Final Step — Record Usage

After the skill's primary task completes, run:

```bash
python3 ${PWD}/.claude/skills/skill-stat/scripts/record-stat.py "agent-memory-v2"
```

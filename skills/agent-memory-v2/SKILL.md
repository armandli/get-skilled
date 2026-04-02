---
name: agent-memory-v2
description: Sets up and manages diagram-driven project memory in docs/memory/. Scaffolds directories (docs/memory, docs/plans), creates memory files (kanban.md, architecture.md, adr.md, config.md, bug.md), and writes CLAUDE.md to guide future sessions. Diagrams in docs/memory drive source code changes. Use when the user asks to "set up agent memory v2", "scaffold project structure", "initialize memory", "add an ADR", "log a bug fix", "update config memory", "update kanban", "sync code from diagram", "update source from architecture", "reflect diagram changes in code", or "update memory files". Depends on mermaid-diagram-guide for diagram syntax. Do NOT use for committing or pushing changes, and do NOT use the old agent-memory skill for v2 projects.
---

# agent-memory-v2 Skill

## Detect Intent

Determine which path to follow:

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

### Step A4 — Create or Update Root `CLAUDE.md`

Use Glob to check whether `CLAUDE.md` exists at the repo root.

- If it **does not exist**: use the Write tool to create it with the content in [references/claude-md-content.md](references/claude-md-content.md).
- If it **already exists**: read it first, then use the Edit tool to append the agent-memory-v2 section if it is not already present. Never remove existing content.

---

### Step A5 — Report

Print a summary:
- Directories created or already existed
- Each memory file: created or skipped
- `CLAUDE.md`: created, updated, or skipped

---

## Path B — Memory Operations

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

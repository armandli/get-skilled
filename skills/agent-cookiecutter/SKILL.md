---
name: agent-cookiecutter
description: Scaffolds an agent-friendly project structure by creating docs/memory and
  docs/plan directories, four memory markdown files (adr.md, config.md, bug.md,
  issue.md), and a .claude/CLAUDE.md that instructs the agent how to use them. Skips
  any files or directories that already exist. Use when the user asks to "set up agent
  memory", "scaffold agent project structure", "initialize agent cookiecutter", or
  "run agent-cookiecutter". Do NOT use for pulling, committing, or modifying existing
  project files.
disable-model-invocation: true
---

## Step 1 — Verify Working Directory

Run `pwd` and `git rev-parse --show-toplevel 2>/dev/null`.

- If the git root differs from `pwd`, warn the user and stop. All paths must be relative to the repo root.

---

## Step 2 — Create Directories

Run:
```
mkdir -p docs/memory docs/plan
```

Both are created with `-p` (no error if already present).

---

## Step 3 — Create Memory Files

Use Glob to check which files already exist: `docs/memory/*.md`.

For each file not already present, use the Write tool to create it:

- `docs/memory/adr.md` — content: `# Architectural Decision Records`
- `docs/memory/config.md` — content: `# Project Configuration`
- `docs/memory/bug.md` — content: `# Bug Fix History`
- `docs/memory/issue.md` — content: `# Open Issues`

Skip any file that already exists.

---

## Step 4 — Create `.claude/CLAUDE.md`

Use Glob to check whether `.claude/CLAUDE.md` already exists.

Only if it does not exist:

1. Run `mkdir -p .claude` to ensure the directory is present.
2. Use the Write tool to create `.claude/CLAUDE.md` with this exact content:

```markdown
# Agent Memory

This project uses structured memory files to maintain context across sessions.

## Architecture Decisions

When making changes to project architecture or significant design decisions, read and update `docs/memory/adr.md` to record the decision, rationale, and consequences.

## Configuration and Settings

When changing project configurations or settings, read and update `docs/memory/config.md` to reflect the current configuration state.

## Bug Tracking

When fixing bugs:
- Check `docs/memory/bug.md` for historical bug fixes that may be relevant.
- After fixing a bug, record the fix and its root cause in `docs/memory/bug.md`.
- Check `docs/memory/issue.md` for currently open issues.
- When resolving an open issue, move it from `docs/memory/issue.md` to `docs/memory/bug.md`.
```

If `.claude/CLAUDE.md` already exists, skip creation.

---

## Step 5 — Report

Print a summary listing:
- Directories created (or already existed)
- Each memory file: created or already present
- `.claude/CLAUDE.md`: created or skipped (already exists)

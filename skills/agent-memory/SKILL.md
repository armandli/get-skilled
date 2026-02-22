---
name: agent-memory
description: Defines the schema and lifecycle rules for the four agent memory files
  created by agent-cookiecutter (adr.md, config.md, bug.md, issue.md). Enforces table
  formats, safe/forbidden config fields, and the issue-to-bug promotion workflow. Use
  when the user asks to "add an ADR", "record an architectural decision", "log a bug
  fix", "add a bug", "add an issue", "update config memory", "resolve an issue",
  "move issue to bug", or "update memory files". Do NOT use for scaffolding the
  directory structure (use agent-cookiecutter) or for committing/pushing changes.
---

# agent-memory Skill

This skill governs how you read and write the four agent memory files in `docs/memory/`. Follow all five steps in order for every operation.

---

## Step 1 — Identify Intent and Read Target File(s)

Determine which operation is requested from the table below, then read all target files before making any edits.

| Intent | Target file(s) |
|---|---|
| Add architectural decision | `docs/memory/adr.md` |
| Add/update config entry | `docs/memory/config.md` |
| Add bug fix record | `docs/memory/bug.md` |
| Add open issue | `docs/memory/issue.md` |
| Resolve issue (move to bug) | `docs/memory/issue.md` + `docs/memory/bug.md` |

---

## Step 2 — Apply File-Specific Schema

### `adr.md` — Architectural Decision Records

Maintain as a Markdown table with exactly these 5 columns in order:

| ID/Name | Context | Decision | Alternative | Consequence |
|---|---|---|---|---|

- **ID/Name**: a short unique identifier (e.g., `ADR-001`) and/or a descriptive name.
- **Context**: why this decision is needed — the problem or constraint driving it.
- **Decision**: what was chosen.
- **Alternative**: other options that were considered but not chosen.
- **Consequence**: trade-offs, risks, or downstream effects of the decision.

Append new rows; never delete existing rows.

---

### `config.md` — Project Configuration

Free-form Markdown organized by service or category. Each entry should document one of:

- Hostnames or URLs
- Port numbers
- Service account email addresses
- Environment names (e.g., `staging`, `prod`)
- Public API endpoints
- Non-secret configuration values (feature flags, timeouts, limits)

**NEVER record in this file:**
- Authentication credentials or passwords
- Service account private keys or JSON key files
- OAuth client secrets or tokens
- Database connection strings with credentials
- Infrastructure secrets (API keys, certificates, private keys)

If the user attempts to write forbidden content, stop, warn them, and omit the secret.

---

### `bug.md` — Bug Fix History

Maintain as a Markdown table with exactly these 5 columns in order:

| Date | Issue | Cause | Solution | Prevention |
|---|---|---|---|---|

- **Date**: ISO 8601 date the bug was found (`YYYY-MM-DD`).
- **Issue**: nature or symptom of the bug.
- **Cause**: root cause — why it happened.
- **Solution**: how it was fixed.
- **Prevention**: how to avoid recurrence (can be left as `—` if not applicable).

Append new rows; never delete existing rows.

---

### `issue.md` — Open Issues

Maintain as a Markdown table with exactly these 2 columns in order:

| Date | Issue |
|---|---|

- **Date**: ISO 8601 date the issue was found (`YYYY-MM-DD`).
- **Issue**: nature or description of the problem.

Append new rows for new issues.

---

## Step 3 — Issue Resolution Lifecycle

When an issue is resolved (user says the bug is fixed, issue is closed, etc.):

1. Read `docs/memory/issue.md` and identify the matching row.
2. Read `docs/memory/bug.md`.
3. Remove the resolved row from `issue.md`.
4. Append a new row to `bug.md` using:
   - **Date**: the date from `issue.md` (date found), not today's date.
   - **Issue**: the issue description from `issue.md`.
   - **Cause**: provided by the user or inferred from context.
   - **Solution**: provided by the user or inferred from context.
   - **Prevention**: provided by the user or `—` if not given.
5. Write both files.

If cause or solution is unknown, ask the user before writing.

---

## Step 4 — Write Back

Use the Edit tool (not Write) to make targeted updates so existing content is preserved.

- For table files (`adr.md`, `bug.md`, `issue.md`): append new rows at the bottom of the table.
- For `config.md`: append under the relevant section heading, or create a new section.
- Never truncate or overwrite content that was not part of the requested change.
- If a table header row is missing from a file, add it before appending data rows.

---

## Step 5 — Report

After every operation, confirm:
- Which file(s) were updated
- What was added or removed (one-line summary per change)
- If any forbidden config content was omitted, name what was excluded and why

---

## Safety Rules

- Never write secrets or credentials to any memory file
- Never delete rows from `adr.md` or `bug.md` (append-only)
- Never delete rows from `issue.md` except when promoting to `bug.md`
- Always read before writing — do not overwrite content blindly
- If a table header row is missing from a file, add it before appending data rows

# Memory File Schemas

## `kanban.md` — Task Board

Contains a single mermaid `kanban` diagram with exactly three columns: `open`, `inprogress`, `complete`.

```
kanban
    open[Open]
        item1[Task description]@{ ticket: X, priority: High }
    inprogress[In Progress]
        item2[Another task]@{ assigned: alice }
    complete[Complete]
        item3[Finished task]
```

**Rules:**
- Column IDs must stay as `open`, `inprogress`, `complete` (case-sensitive)
- Item IDs must be unique within the diagram
- Move items between columns using the Edit tool — never delete them
- Metadata (`@{ assigned, ticket, priority }`) is optional but encouraged
- Priority values: `Very High`, `High`, `Low`, `Very Low`
- When adding a new task, place it in the `open` column unless the user specifies otherwise

---

## `architecture.md` — Architecture Diagram

Contains a mermaid `classDiagram` as the primary structural reference for the project.

**What to capture:**
- Classes, structs, interfaces, abstract classes
- Attributes with types and visibility
- Methods with signatures and visibility
- Relationships: inheritance (`<|--`), composition (`*--`), aggregation (`o--`), association (`-->`)
- Multiplicity / cardinality labels

**What NOT to capture:**
- Runtime behavior (use sequence diagrams for that)
- State transitions (use state diagrams for that)
- Infrastructure (use mermaid architecture diagrams for that)

When editing `architecture.md`, preserve the heading and explanatory text. Edit only the fenced mermaid code block.

Other diagram files in `docs/memory/` (sequence, state, etc.) follow the same convention: one diagram per file, with a heading and brief explanation.

---

## `adr.md` — Architectural Decision Records

Markdown table with exactly these 5 columns:

| ID | Context | Decision | Alternative | Consequence |
|----|---------|----------|-------------|-------------|

- **ID**: short unique identifier (e.g., `ADR-001`) or descriptive slug
- **Context**: the problem, constraint, or motivation for the decision
- **Decision**: what was chosen
- **Alternative**: other options considered but not chosen
- **Consequence**: trade-offs, risks, or downstream effects

**Scope rule**: only record decisions not already expressible as a diagram change. If a decision is about adding a class or relationship, encode it in `architecture.md` and note the diagram was updated instead. ADRs are for "why" decisions — technology picks, conventions, strategic trade-offs — not "what" decisions that diagrams already capture.

Append new rows — never delete existing rows.

---

## `config.md` — Project Configuration

Free-form Markdown organized by service or category. Each entry documents one of:

- Hostnames or URLs
- Port numbers
- Service account email addresses (non-secret)
- Environment names (`staging`, `prod`, etc.)
- Public API endpoints
- Feature flags, timeouts, limits, quotas

**NEVER record:**
- Authentication credentials or passwords
- Private keys or certificates
- OAuth client secrets or tokens
- Database connection strings with credentials
- Any infrastructure secrets or API keys

If the user attempts to write forbidden content, stop, warn them, and omit the secret.

---

## `bug.md` — Bug Fix History

Markdown table with exactly these 5 columns:

| Date | Issue | Cause | Solution | Prevention |
|------|-------|-------|----------|------------|

- **Date**: ISO 8601 date the bug was found (`YYYY-MM-DD`)
- **Issue**: symptom or nature of the bug
- **Cause**: root cause — why it happened
- **Solution**: how it was fixed
- **Prevention**: how to avoid recurrence (`—` if not applicable)

Append new rows — never delete existing rows.

If cause or solution is unknown, ask the user before writing.

# CLAUDE.md Content

This is the content to write into the root `CLAUDE.md` when creating it fresh (Path A, Step A4).

When the file already exists, append only the section below that is not already present.

---

## Content to write / append

```markdown
# Development Guidance

This project uses diagram-driven development. Structured memory files in `docs/memory/` maintain
architecture, decisions, tasks, and history across sessions.

## Architecture

`docs/memory/architecture.md` contains a mermaid class diagram that is the authoritative description
of the project's structure. Before making structural changes (new classes, interfaces, methods,
relationships), read this file. After making structural changes, update the diagram to match.

Additional diagrams may exist in `docs/memory/` as separate `.md` files:
- **Sequence diagrams** describe inter-component call flows and API contracts
- **State diagrams** describe state machine logic and lifecycle transitions

When a diagram in `docs/memory/` is changed, use the agent-memory-v2 skill (Path C) to apply
the corresponding source code changes.

## Task Tracking

`docs/memory/kanban.md` tracks work items as a mermaid kanban board with three columns:
- **Open** — not yet started
- **In Progress** — actively being worked on
- **Complete** — done

When starting a task, move it to In Progress. When finished, move it to Complete.
Never delete kanban items — only move them forward.

## Architectural Decisions

`docs/memory/adr.md` records decisions that are NOT already captured by a diagram.
Use it for: technology choices, library selections, deployment strategies, data format decisions,
cross-cutting conventions, and decisions whose rationale is not self-evident from the diagrams.
Do NOT duplicate information already described by `architecture.md` or other diagram files.

## Configuration

`docs/memory/config.md` records non-secret configuration values: hostnames, ports, environment names,
public endpoints, feature flags, timeouts, and limits.
Never write passwords, private keys, tokens, or credentials here.

## Bug History

`docs/memory/bug.md` records resolved bugs. When fixing a bug:
- Check this file for similar past issues before starting
- After fixing, append a row with the date, symptom, root cause, solution, and prevention note

## Plans

`docs/plans/` stores planning documents and implementation plans for larger features.
```

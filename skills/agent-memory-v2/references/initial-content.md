# Initial File Content

Use this content when creating each memory file for the first time during Path A setup. Never use this to overwrite an existing file.

---

## `docs/memory/kanban.md`

```markdown
# Kanban

```mermaid
kanban
    open[Open]
    inprogress[In Progress]
    complete[Complete]
```
```

---

## `docs/memory/architecture.md`

```markdown
# Architecture

This file contains the mermaid class diagram describing the architecture of this project.
Update this diagram when making structural changes (new classes, interfaces, relationships, method signatures).
Changes here drive source code updates via the agent-memory-v2 skill (Path C).

```mermaid
classDiagram
    %% Define your project's classes, interfaces, and relationships here.
    %% Example:
    %% class ServiceA {
    %%     +methodA() void
    %% }
    %% class ServiceB {
    %%     +methodB() string
    %% }
    %% ServiceA --> ServiceB : uses
```
```

---

## `docs/memory/adr.md`

```markdown
# Architectural Decision Records

Record decisions that are NOT already captured by diagrams in `docs/memory/`.
Structural decisions (classes, interfaces, relationships, state machines, call flows) should be encoded
in `architecture.md` or the relevant diagram file instead of here.

Use ADRs for: technology choices, library selections, deployment strategies, data format decisions,
cross-cutting conventions, and decisions where the "why" is not evident from the diagram.

| ID | Context | Decision | Alternative | Consequence |
|----|---------|----------|-------------|-------------|
```

---

## `docs/memory/config.md`

```markdown
# Project Configuration

Record non-secret configuration values: hostnames, ports, environment names, public API endpoints,
feature flags, timeouts, and limits.

**Never record**: passwords, private keys, OAuth secrets, connection strings with credentials,
or any authentication tokens.
```

---

## `docs/memory/bug.md`

```markdown
# Bug Fix History

| Date | Issue | Cause | Solution | Prevention |
|------|-------|-------|----------|------------|
```

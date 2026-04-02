# Diagram-Driven Development

## Overview

Diagrams in `docs/memory/` are the authoritative source of truth for project structure and behavior.
When a diagram changes, the source code must be updated to match — not the other way around.

This workflow (Path C) applies when:
- The user edits a diagram and asks to sync or reflect it in code
- The user says "update source from the architecture diagram"
- The user modifies a sequence/state diagram and wants the implementation updated

---

## Diagram-to-Code Mapping

### Class Diagram → Source Structure

File: `docs/memory/architecture.md`

| Diagram element | Source code target |
|----------------|-------------------|
| `class Foo { }` | Class or struct definition named `Foo` |
| `<<interface>>` annotation | Interface/abstract class/protocol |
| `+method() ReturnType` | Public method with matching signature |
| `-field Type` | Private member variable |
| `A <\|-- B` | B inherits/extends A |
| `A *-- B` | A owns B (composition field) |
| `A --> B` | A holds a reference/pointer to B |
| `A "1" --> "0..*" B` | A has a collection of B |
| `<<abstract>>` | Abstract class modifier |
| `method()$` | Static method |
| `method()*` | Abstract method |

**Workflow:**
1. Read `docs/memory/architecture.md`
2. Parse the classDiagram — list all classes, their members, and relationships
3. Search the source tree for each class by name (use Grep and Glob)
4. For each class in the diagram:
   - If missing from source: create the class file/definition with the correct members
   - If present but mismatched: edit to add missing members or fix signatures
   - If a relationship is missing: add the corresponding field or inheritance declaration
5. Do not remove source code elements not mentioned in the diagram — only add or update

---

### Sequence Diagram → Call Flow

File: any `docs/memory/*.md` containing a `sequenceDiagram` or `zenuml` block

| Diagram element | Source code target |
|----------------|-------------------|
| `A->>B: methodName(args)` | A calls B.methodName(args) |
| `B-->>A: result` | Return value from B to A |
| `loop` block | Loop or iteration in implementation |
| `alt`/`else` block | Conditional branch (if/else) |
| `par` block | Concurrent calls (goroutines, async/await, threads) |
| `opt` block | Optional code path (guarded by condition) |
| `critical` block | Mutex/lock-protected section |

**Workflow:**
1. Read the sequence diagram file
2. Identify which components (services, classes, modules) are participants
3. Locate the entry-point function in source — the one that initiates the first message
4. Trace the call chain through the source and compare to the diagram
5. Add missing calls, return handling, loops, conditionals, or concurrency as specified
6. Do not restructure working code that already matches — only add what is missing

---

### State Diagram → State Machine

File: any `docs/memory/*.md` containing a `stateDiagram-v2` block

| Diagram element | Source code target |
|----------------|-------------------|
| State node | Enum value or named constant |
| `[*] --> StateA` | Initial state assignment |
| `A --> B : event` | Transition function: on event `event`, move from A to B |
| Composite state | Nested state machine or sub-state enum |
| `<<fork>>` / `<<join>>` | Parallel state entry/exit logic |
| `--` concurrent region | Concurrent state variables |
| `note` | Comment in transition handler |

**Workflow:**
1. Read the state diagram file
2. Extract all states, transitions, and guards
3. Find the state machine implementation in source (search for state enum or state variable)
4. For each state in the diagram:
   - If the enum/constant is missing: add it
   - If the transition handler is missing: add it
5. Ensure the initial state matches `[*] -->` declaration
6. Do not remove existing transitions not in the diagram

---

## Staying in Sync

After any source code change that adds classes, methods, or behavioral logic, check whether `docs/memory/` diagrams need updating in the reverse direction (code → diagram). If the user made source changes outside this skill:

1. Ask: "Should I update the diagrams in `docs/memory/` to reflect these source changes?"
2. If yes: read the relevant source, parse the structure, and update the mermaid diagram using the Edit tool
3. Preserve all existing diagram content — only add or modify the specific elements that changed

---

## Referring to mermaid-diagram-guide

When parsing or writing any mermaid diagram during Path C, load the relevant reference from the `mermaid-diagram-guide` skill:

- For class diagrams: `mermaid-diagram-guide/references/class-diagram.md`
- For sequence diagrams: `mermaid-diagram-guide/references/sequence-diagram.md`
- For state diagrams: `mermaid-diagram-guide/references/state-diagram.md`
- For ZenUML: `mermaid-diagram-guide/references/zenuml.md`
- For architecture diagrams: `mermaid-diagram-guide/references/architecture.md`

Path in skills directory: `.claude/skills/mermaid-diagram-guide/references/<file>`

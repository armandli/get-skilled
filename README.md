# get-skilled

A collection of reusable skills for [Claude Code](https://docs.anthropic.com/en/docs/claude-code), Anthropic's CLI for Claude.

## What's Inside

### Skills

#### `create-skill`

A meta-skill that teaches Claude Code how to create new skills. It provides:

- A **step-by-step workflow** for building skills — from gathering use cases to validation
- **Five design patterns** for structuring skills:
  1. Sequential Workflow Orchestration (ordered, dependent steps)
  2. Multi-MCP Coordination (cross-server tool orchestration)
  3. Iterative Refinement (generate-validate-refine loops)
  4. Context-Aware Tool Selection (decision-tree branching)
  5. Domain-Specific Intelligence (specialized knowledge encoding)
- A **validation checklist** covering naming, structure, description clarity, trigger testing, and functional testing

#### `advent-cookiecutter`

Generates a starter C++ file for a new Advent of Code problem, pre-loaded with type aliases, optional 2D/3D coordinate structs, and an input parsing template inferred from an example input file. Accepts an output path, an example input file, and an optional coordinate specifier (`p2`, `pd2`, `pdpd2`, `p3`, `pd3`, `pdpd3`).

#### `cpp-cookiecutter`

Sets up a standard C++ project repo structure with `src/`, `test/`, and `bin/` directories, plus a root `CMakeLists.txt`, `src/CMakeLists.txt`, and `test/CMakeLists.txt` with FetchContent GTest integration. Requires a project name argument.

#### `python-cookiecutter`

Sets up a standard Python package development repo structure with `bin/`, `etc/`, `notebooks/`, `source/` (Python source), `src/` (C++ source), and `test/` directories, plus a templated `setup.py` and `pyproject.toml` for local dev and pybind11 C++ bindings. Requires a package name argument.

#### `format-cpp`

Formats C++ code according to 20 specific style rules covering whitespace, braces, preprocessor directives, namespaces, types, formatting, and semantic transformations. Includes a namespace aliases reference and formatting examples.

#### `plant-plan`

Copies a plan file from `~/.claude/plans/` into the local repo's `docs/plans/` directory. Accepts optional arguments to select a specific plan by name pattern or rename the output file.

#### `marimo-notebook`

Writes and edits [marimo](https://marimo.io) reactive Python notebooks with correct cell structure, setup cells, reactivity patterns, and Typer CLI argument support. Includes reference guides for Polars, Altair, NumPy, SciPy, PyTorch, SQL, and marimo UI components.

#### `optimize-python`

Reviews Python code and applies performance optimizations drawn from a 23-pattern reference covering data structures, loops, strings, memory, and profiling. Safe mechanical changes are applied directly; structural changes are reported as suggestions.

#### `refactor-python`

Scans a Python codebase for duplicate or near-duplicate logic, then extracts repeated patterns into typed utility classes in a shared module. Groups helpers by the type they operate on (strings, numbers, dates, collections, etc.).

#### `refactor-cpp`

Scans a C++ codebase for duplicate or near-duplicate logic across `.cpp` and `.h` files, then extracts them into reusable utility functions in a `utils/` directory. Template functions are placed in `.h` headers only; non-template utilities get a `.h` declaration and a `.cpp` definition. Groups helpers by operand type (strings, numbers, containers, etc.) and outputs a structured refactor report.

#### `jupyter-to-marimo`

Converts a Jupyter notebook (`.ipynb`) to a marimo notebook (`.py`) by running `marimo convert`, then auditing and fixing the output for magic commands, IPython display calls, anti-patterns, import consolidation into the setup cell, and missing PEP 723 metadata. Validates the result with `marimo check` and leaves `# REVIEW:` comments for patterns that cannot be automatically resolved.

#### `mermaid-diagram-guide`

Reference guide for Mermaid diagram syntax covering all major diagram types used in software engineering: flowchart, sequence, class, ER, state, Gantt, requirement, C4, ZenUML, mindmap, architecture, kanban, block, packet, treemap, and treeview. Auto-validates diagrams via a `PostToolUse` hook (`mmdc`) when `@mermaid-js/mermaid-cli` is installed.

#### `marimo-anywidget`

Creates custom interactive widgets in marimo notebooks using `anywidget`, combining Python `traitlets` state with vanilla JavaScript ESM front-ends. Covers the full widget lifecycle: Python `AnyWidget` subclass, JS `render`/`initialize` functions, CSS scoping, `mo.ui.anywidget()` integration, and reactive downstream cells.

#### `async-python`

Converts one or more named Python functions from synchronous to asynchronous using `asyncio`. Locates the functions in the repo, builds a call graph and inter-function communication map, then applies `async`/`await` syntax and replaces sync I/O libraries with async equivalents (`requests` → `aiohttp`, `pika` → `aio-pika`, `boto3` → `aiobotocore`, `kafka-python` → `aiokafka`, `queue.Queue` → `asyncio.Queue`). Flags helper functions and threading-boundary queues for manual review.

#### `agent-memory`

Sets up an agent memory project structure and manages the four agent memory files (`adr.md`, `config.md`, `bug.md`, `issue.md`). Handles both scaffolding (creating `docs/memory/`, `docs/plan/`, memory files, and `.claude/CLAUDE.md`) and memory operations (adding ADRs, logging bug fixes, tracking open issues, updating config). Enforces table schemas, blocks recording secrets or credentials, and handles the full issue-to-bug promotion lifecycle.

#### `agent-memory-v2`

Sets up and manages diagram-driven project memory in `docs/memory/`. Scaffolds directories (`docs/memory/`, `docs/plans/`) and five memory files (`kanban.md`, `architecture.md`, `adr.md`, `config.md`, `bug.md`), and writes `.claude/CLAUDE.md` to guide future sessions. Supports three paths: scaffold setup, memory operations (kanban CRUD, ADR/config/bug writes), and diagram-driven development (syncing source code from edited Mermaid diagrams). Accepts command-style invocations (`create-item`, `progress`, `complete`) for quick kanban management. Depends on `mermaid-diagram-guide` for diagram syntax.

#### `create-hook`

Interactive wizard that creates and installs Claude Code hooks in `settings.json`. Guides the user through lifecycle event selection (`PreToolUse`, `PostToolUse`, `Stop`, `SessionStart`, etc.), hook type (`command`, `prompt`, `agent`, or `http`), optional matcher regex, and installation target (global, project, or project-local). Generates or writes helper scripts for complex commands and verifies the written configuration.

#### `curate`

Acquires a skill from a local directory or GitHub URL into this repo's `skills/`, or merges features from an external skill version into an existing local skill. Analyzes the source for security concerns, preferential bias, and destructive operations before writing anything. Resolves flagged issues interactively. Optimizes acquired skills to meet `create-skill` quality standards and creates the `.claude/skills/` symlink.

#### `commit-push`

Commits all current changes and pushes to the remote `origin` on the current branch. Stages everything, generates a context-aware commit message by analyzing the diff and recent commit style, creates the commit, and pushes. Stops cleanly if there are no changes.

#### `commit-push-pr`

Creates a new branch named after the changes, stages all current changes, commits them, and pushes to `upstream` (falls back to `origin` if absent). Derives both the branch name and commit message from the staged diff and recent commit log.

#### `pull`

Syncs the local `main` branch with the default remote. Switches to `main` first (warning about and discarding uncommitted changes if needed), runs `git pull`, and resolves merge conflicts by reverting local changes in favor of remote. Reports branch, sync status, and recent commits when done.

#### `update-readme`

Updates a project `README.md` with a description, build instructions, test instructions, and a Mermaid architecture diagram. Emphasizes interfaces, protocols, and extension points in the diagram — not concrete implementations.

#### `current-time`

Retrieves the current date and time in a configured timezone. Can be invoked directly or used internally by other skills that require timestamps. With a timezone argument, validates and persists the new default timezone.

#### `revert`

Reverts all git changes in the working directory: staged changes, unstaged modifications, and new untracked files. Shows a summary of what will be lost and asks for confirmation before running `git reset --hard HEAD` and `git clean -fd`. Does not touch ignored files.

#### `skill-stat`

Records skill usage statistics and issue reports into `.claude/skill-stats.md`. Increments the Uses count for a skill name and optionally logs an issue report that increments the Issues count and appends a row to the Issue Reports table.

### Subagents

#### `advent-hacker`

Solves open-ended coding problems (e.g. Advent of Code) in Python. Reads problem descriptions, writes Python solutions, and runs them against input files.

## Repository Structure

```
skills/
├── advent-cookiecutter/
│   ├── SKILL.md
│   └── references/
│       ├── parsing-templates.md
│       └── struct-templates.md
├── agent-memory/
│   └── SKILL.md
├── agent-memory-v2/
│   ├── SKILL.md
│   └── references/
│       ├── claude-md-content.md
│       ├── diagram-driven-dev.md
│       ├── initial-content.md
│       └── memory-schemas.md
├── async-python/
│   ├── SKILL.md
│   └── references/
│       ├── asyncio-patterns.md
│       ├── concurrency-patterns.md
│       └── library-conversions.md
├── commit-push/
│   └── SKILL.md
├── commit-push-pr/
│   └── SKILL.md
├── create-hook/
│   ├── SKILL.md
│   └── references/
│       └── events-reference.md
├── curate/
│   ├── SKILL.md
│   └── references/
│       ├── github-url-formats.md
│       └── security-flags.md
├── cpp-cookiecutter/
│   └── SKILL.md
├── create-skill/
│   ├── SKILL.md
│   └── references/
│       ├── checklist.md
│       ├── hooks-best-practices.md
│       └── patterns.md
├── current-time/
│   └── SKILL.md
├── format-cpp/
│   ├── SKILL.md
│   └── references/
│       ├── examples.md
│       └── namespace-aliases.md
├── plant-plan/
│   └── SKILL.md
├── jupyter-to-marimo/
│   ├── SKILL.md
│   └── references/
│       └── CONVERSION-PATTERNS.md
├── marimo-anywidget/
│   ├── SKILL.md
│   └── references/
│       └── JS-PATTERNS.md
├── marimo-notebook/
│   ├── SKILL.md
│   └── references/
│       ├── ALTAIR.md
│       ├── NUMPY.md
│       ├── POLARS.md
│       ├── PYTEST.md
│       ├── PYTORCH.md
│       ├── SCIPY.md
│       ├── SQL.md
│       ├── TOP-LEVEL-IMPORTS.md
│       ├── TYPER.md
│       └── UI.md
├── mermaid-diagram-guide/
│   ├── SKILL.md
│   └── references/
│       ├── architecture.md
│       ├── block-diagram.md
│       ├── c4-diagram.md
│       ├── class-diagram.md
│       ├── er-diagram.md
│       ├── flowchart.md
│       ├── gantt.md
│       ├── kanban.md
│       ├── mindmap.md
│       ├── packet.md
│       ├── requirement-diagram.md
│       ├── sequence-diagram.md
│       ├── state-diagram.md
│       ├── treemap.md
│       ├── treeview.md
│       └── zenuml.md
├── optimize-python/
│   ├── SKILL.md
│   └── references/
│       └── optimization-patterns.md
├── pull/
│   └── SKILL.md
├── python-cookiecutter/
│   └── SKILL.md
├── refactor-cpp/
│   ├── SKILL.md
│   └── references/
│       └── refactor-patterns.md
├── refactor-python/
│   ├── SKILL.md
│   └── references/
│       └── refactor-patterns.md
├── revert/
│   └── SKILL.md
├── skill-stat/
│   └── SKILL.md
└── update-readme/
    └── SKILL.md
agents/
└── advent-hacker.md
```

## Usage

Clone this repo and point Claude Code at it. Then invoke any skill by name.

```sh
git clone https://github.com/armandli/get-skilled.git
cd get-skilled
claude
```

Example commands:
- `/create-skill` — scaffold a new skill
- `/advent-cookiecutter day01.cpp input.txt pd2` — generate a C++ AoC starter
- `/agent-memory` — set up agent memory structure, or add an ADR, log a bug fix, or resolve an open issue
- `/agent-memory-v2` — set up diagram-driven project memory; `/agent-memory-v2 create-item "fix login bug" "details"`, `progress`, or `complete` for kanban ops
- `/create-hook` — interactive wizard to create and install a Claude Code hook
- `/curate https://github.com/user/repo/tree/main/skills/my-skill` — acquire a skill from GitHub; `/curate my-skill <source>` to merge features
- `/mermaid-diagram-guide` — look up Mermaid syntax; `/mermaid-diagram-guide sequence` for a specific diagram type
- `/async-python fetch_data process_results` — convert named functions to async
- `/commit-push` — stage, commit, and push current changes
- `/commit-push-pr` — create a branch, commit, and push to upstream
- `/cpp-cookiecutter myproject` — scaffold a C++ project with CMake and GTest
- `/current-time` — get current date/time; `/current-time America/New_York` to set timezone
- `/format-cpp src/main.cpp` — format C++ files
- `/plant-plan` — copy the most recent plan from `~/.claude/plans/` into `docs/plans/`
- `/jupyter-to-marimo notebook.ipynb` — convert a Jupyter notebook to marimo
- `/marimo-anywidget slider "a range slider synced to Python"` — create a custom marimo widget
- `/marimo-notebook analysis.py` — create or edit a marimo notebook
- `/optimize-python src/` — apply Python performance optimizations
- `/pull` — sync local main branch with remote
- `/revert` — discard all staged and unstaged changes in the working directory
- `/python-cookiecutter mypackage` — scaffold a Python package with pybind11 support
- `/refactor-cpp src/` — extract duplicate C++ logic into shared utilities
- `/refactor-python src/` — extract duplicate Python logic into utilities
- `/skill-stat agent-memory` — record a skill usage stat
- `/update-readme` — generate or refresh the project README

## Adding New Skills

Use the `create-skill` skill itself to generate new skills, or manually add a directory under `skills/` following the conventions documented in `skills/create-skill/SKILL.md`.

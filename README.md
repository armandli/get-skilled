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

#### `cpp-formatter`

Formats C++ code according to 20 specific style rules covering whitespace, braces, preprocessor directives, namespaces, types, formatting, and semantic transformations. Includes a namespace aliases reference and formatting examples.

#### `get-planted`

Creates structured development plans as markdown files with step blocks, dependencies, and concurrent execution support. Plans use YAML frontmatter and step blocks that declare dependencies, expected inputs, and defined outcomes — enabling parallel execution by multiple agents.

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

#### `marimo-anywidget`

Creates custom interactive widgets in marimo notebooks using `anywidget`, combining Python `traitlets` state with vanilla JavaScript ESM front-ends. Covers the full widget lifecycle: Python `AnyWidget` subclass, JS `render`/`initialize` functions, CSS scoping, `mo.ui.anywidget()` integration, and reactive downstream cells.

#### `async-python`

Converts one or more named Python functions from synchronous to asynchronous using `asyncio`. Locates the functions in the repo, builds a call graph and inter-function communication map, then applies `async`/`await` syntax and replaces sync I/O libraries with async equivalents (`requests` → `aiohttp`, `pika` → `aio-pika`, `boto3` → `aiobotocore`, `kafka-python` → `aiokafka`, `queue.Queue` → `asyncio.Queue`). Flags helper functions and threading-boundary queues for manual review.

#### `agent-cookiecutter`

Scaffolds an agent-friendly project structure by creating `docs/memory/` and `docs/plan/` directories, four memory markdown files (`adr.md`, `config.md`, `bug.md`, `issue.md`), and a `.claude/CLAUDE.md` that instructs the agent how to use them. Skips any files or directories that already exist.

#### `agent-memory`

Manages the four agent memory files created by `agent-cookiecutter`. Enforces table schemas for `adr.md` (architectural decisions), `bug.md` (bug fix history), and `issue.md` (open issues), and free-form sections for `config.md`. Handles the full issue-to-bug promotion lifecycle and blocks recording of secrets or credentials.

#### `commit-push`

Commits all current changes and pushes to the remote `origin` on the current branch. Stages everything, generates a context-aware commit message by analyzing the diff and recent commit style, creates the commit, and pushes. Stops cleanly if there are no changes.

#### `commit-push-pr`

Creates a new branch named after the changes, stages all current changes, commits them, and pushes to `upstream` (falls back to `origin` if absent). Derives both the branch name and commit message from the staged diff and recent commit log.

#### `pull`

Syncs the local `main` branch with the default remote. Switches to `main` first (warning about and discarding uncommitted changes if needed), runs `git pull`, and resolves merge conflicts by reverting local changes in favor of remote. Reports branch, sync status, and recent commits when done.

### Subagents

#### `plan-planter`

Validates and optimizes development plans created by `get-planted`. Checks DAG integrity, minimizes redundant dependencies for maximum concurrency, verifies step detail sufficiency, and interactively resolves gaps with the user.

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
├── agent-cookiecutter/
│   └── SKILL.md
├── agent-memory/
│   └── SKILL.md
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
├── cpp-formatter/
│   ├── SKILL.md
│   └── references/
│       ├── examples.md
│       └── namespace-aliases.md
├── create-skill/
│   ├── SKILL.md
│   └── references/
│       ├── checklist.md
│       ├── hooks-best-practices.md
│       └── patterns.md
├── get-planted/
│   ├── SKILL.md
│   └── references/
│       ├── plan-format.md
│       └── scrutiny-checklist.md
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
├── optimize-python/
│   ├── SKILL.md
│   └── references/
│       └── optimization-patterns.md
├── pull/
│   └── SKILL.md
├── refactor-cpp/
│   ├── SKILL.md
│   └── references/
│       └── refactor-patterns.md
└── refactor-python/
    ├── SKILL.md
    └── references/
        └── refactor-patterns.md
subagents/
├── advent-hacker.md
└── plan-planter.md
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
- `/agent-cookiecutter` — scaffold agent memory structure for a project
- `/agent-memory` — add an ADR, log a bug fix, or resolve an open issue
- `/async-python fetch_data process_results` — convert named functions to async
- `/commit-push` — stage, commit, and push current changes
- `/commit-push-pr` — create a branch, commit, and push to upstream
- `/cpp-formatter src/main.cpp` — format C++ files
- `/get-planted plan.md` — create a structured development plan
- `/jupyter-to-marimo notebook.ipynb` — convert a Jupyter notebook to marimo
- `/marimo-anywidget slider "a range slider synced to Python"` — create a custom marimo widget
- `/marimo-notebook analysis.py` — create or edit a marimo notebook
- `/optimize-python src/` — apply Python performance optimizations
- `/pull` — sync local main branch with remote
- `/refactor-cpp src/` — extract duplicate C++ logic into shared utilities
- `/refactor-python src/` — extract duplicate Python logic into utilities

## Adding New Skills

Use the `create-skill` skill itself to generate new skills, or manually add a directory under `skills/` following the conventions documented in `skills/create-skill/SKILL.md`.

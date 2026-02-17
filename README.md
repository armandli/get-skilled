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

#### `cpp-formatter`

Formats C++ code according to 20 specific style rules covering whitespace, braces, preprocessor directives, namespaces, types, formatting, and semantic transformations. Includes a namespace aliases reference and formatting examples.

#### `get-planted`

Creates structured development plans as markdown files with step blocks, dependencies, and concurrent execution support. Plans use YAML frontmatter and step blocks that declare dependencies, expected inputs, and defined outcomes — enabling parallel execution by multiple agents.

### Subagents

#### `plan-planter`

Validates and optimizes development plans created by `get-planted`. Checks DAG integrity, minimizes redundant dependencies for maximum concurrency, verifies step detail sufficiency, and interactively resolves gaps with the user.

#### `advent-hacker`

Solves open-ended coding problems (e.g. Advent of Code) in Python. Reads problem descriptions, writes Python solutions, and runs them against input files.

## Repository Structure

```
skills/
├── create-skill/
│   ├── SKILL.md
│   └── references/
│       ├── checklist.md
│       ├── hooks-best-practices.md
│       └── patterns.md
├── cpp-formatter/
│   ├── SKILL.md
│   └── references/
│       ├── examples.md
│       └── namespace-aliases.md
└── get-planted/
    ├── SKILL.md
    └── references/
        ├── plan-format.md
        └── scrutiny-checklist.md
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
- `/cpp-formatter src/main.cpp` — format C++ files
- `/get-planted plan.md` — create a structured development plan

## Adding New Skills

Use the `create-skill` skill itself to generate new skills, or manually add a directory under `skills/` following the conventions documented in `skills/create-skill/SKILL.md`.

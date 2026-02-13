# get-skilled

A collection of reusable skills for [Claude Code](https://docs.anthropic.com/en/docs/claude-code), Anthropic's CLI for Claude.

## What's Inside

### `create-skill`

A meta-skill that teaches Claude Code how to create new skills. It provides:

- A **step-by-step workflow** for building skills — from gathering use cases to validation
- **Five design patterns** for structuring skills:
  1. Sequential Workflow Orchestration (ordered, dependent steps)
  2. Multi-MCP Coordination (cross-server tool orchestration)
  3. Iterative Refinement (generate-validate-refine loops)
  4. Context-Aware Tool Selection (decision-tree branching)
  5. Domain-Specific Intelligence (specialized knowledge encoding)
- A **validation checklist** covering naming, structure, description clarity, trigger testing, and functional testing

## Repository Structure

```
skills/
└── create-skill/
    ├── SKILL.md              # Main skill instructions
    └── references/
        ├── checklist.md      # Validation checklist
        └── patterns.md       # Design patterns reference
```

## Usage

Clone this repo and point Claude Code at it. Then ask Claude to "create a skill" and it will follow the `create-skill` workflow to scaffold a new skill with best-practice structure.

```sh
git clone https://github.com/armandli/get-skilled.git
cd get-skilled
claude
```

Then in Claude Code:

> create a skill for deploying to AWS

## Adding New Skills

Use the `create-skill` skill itself to generate new skills, or manually add a directory under `skills/` following the conventions documented in `skills/create-skill/SKILL.md`.

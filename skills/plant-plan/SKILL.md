---
name: plant-plan
description: Copies a plan file from ~/.claude/plans/ into the local repo's docs/planss/ directory. Use when the user says "plant the plan", "save the plan to the repo", "move the plan", or "/plant-plan". Accepts optional arguments to select a specific plan or rename the output. Do NOT use for creating plans (use plan mode) or reading plan content.
argument-hint: "[output-filename.md | partial-plan-name [output-filename.md]]"
disable-model-invocation: true
---

## Step 1 — Parse Arguments

Parse `$ARGUMENTS` by splitting on whitespace:

- **0 tokens** → `SOURCE_PATTERN=""`, `OUTPUT_NAME=""`
- **1 token ending in `.md`** → `SOURCE_PATTERN=""`, `OUTPUT_NAME=$1`
- **1 token not ending in `.md`** → `SOURCE_PATTERN=$1`, `OUTPUT_NAME=""`
- **2 tokens** → `SOURCE_PATTERN=$1`, `OUTPUT_NAME=$2`
- **3+ tokens** → print usage and stop:
  ```
  Usage:
    /plant-plan                              # plant most recent plan, keep original name
    /plant-plan output.md                    # plant most recent plan, rename to output.md
    /plant-plan <partial-name>               # plant a specific plan by name search
    /plant-plan <partial-name> output.md     # plant a specific plan, rename to output.md
  ```

---

## Step 2 — Find Source Plan

Run:
```bash
ls ~/.claude/plans/ 2>/dev/null
```

If the directory is empty or does not exist, report and stop:
```
No plan files found in ~/.claude/plans/
```

**If `SOURCE_PATTERN` is set:**
- Search the listing for filenames containing `SOURCE_PATTERN` (case-insensitive).
- If zero matches: report `No plan matching "<SOURCE_PATTERN>" found in ~/.claude/plans/` and stop.
- If multiple matches: list them and report `Multiple plans match "<SOURCE_PATTERN>". Specify a more unique pattern.` and stop.
- Set `SOURCE_FILE=<matched filename>`.

**If `SOURCE_PATTERN` is empty:**
- Run `ls -t ~/.claude/plans/` and take the first (most recently modified) file.
- Set `SOURCE_FILE=<first result>`.

Set `SOURCE_PATH=~/.claude/plans/$SOURCE_FILE`.

---

## Step 3 — Determine Destination

```
DEST_DIR={PWD}/docs/plans
DEST_FILE = OUTPUT_NAME if set, else SOURCE_FILE
DEST_PATH = $DEST_DIR/$DEST_FILE
```

---

## Step 4 — Preflight Check

If `$DEST_PATH` already exists:
- Warn the user: `docs/plans/$DEST_FILE already exists.`
- Ask to confirm overwrite before continuing. Stop if not confirmed.

---

## Step 5 — Copy the Plan

```bash
mkdir -p {PWD}/docs/plans
cp "$SOURCE_PATH" "$DEST_PATH"
```

---

## Step 6 — Report

Print a concise summary:
```
Planted: ~/.claude/plans/<SOURCE_FILE> → docs/plans/<DEST_FILE>
```

---

## Final Step — Record Usage

```bash
python3 ${PWD}/.claude/skills/skill-stat/scripts/record-stat.py "plant-plan"
```

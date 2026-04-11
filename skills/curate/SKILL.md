---
name: curate
description: Acquires a skill from a local directory or GitHub URL into this repo's skills/, or merges features from an external skill version into an existing local skill. Analyzes the source for security concerns, preferential bias, and destructive operations before writing anything. Also optimizes acquired skills to meet create-skill quality standards. Use when the user asks to "curate a skill", "import a skill from GitHub", "add a skill from a URL", "install a skill", "merge skill features", or "bring in an external skill". Do NOT use for creating new skills from scratch (use create-skill) or for enabling already-local skills.
argument-hint: "<source> | <local-skill-name> <source>"
disable-model-invocation: true
---

## Critical: Determine Mode from Arguments

Parse `$ARGUMENTS` by splitting on whitespace:

- **0 or 3+ tokens** → Stop and print:
  ```
  Usage:
    /curate <source>                    # acquire a skill from a local path or URL
    /curate <local-skill-name> <source> # merge remote skill features into a local skill
  ```
- **1 token** → **Acquire mode**. Set `SOURCE=$1`.
- **2 tokens** → **Merge mode**. Set `LOCAL_SKILL_NAME=$1`, `SOURCE=$2`.

---

## Step 1 — Resolve Source

Determine source type: SOURCE is a URL if it contains `://` or starts with `github.com/`.

### URL sources

Normalize to a fetchable form — see [references/github-url-formats.md](references/github-url-formats.md) for full conversion rules:
- Web directory URL (`/tree/`) → GitHub Contents API URL
- Web file URL (`/blob/`) → raw.githubusercontent.com URL
- `github.com/` shorthand (no scheme) → prepend `https://`

**If the normalized URL is a GitHub Contents API URL (directory):**
Use WebFetch to fetch it. Parse the JSON array response:
- Find the entry with `"name": "SKILL.md"` — use its `"download_url"` to WebFetch the raw SKILL.md text.
- Record any entry with `"type": "dir"` and `"name": "references"` — store its `"url"` as `REFS_DIR_URL` for later.

**If the normalized URL points directly to a SKILL.md file (raw or blob):**
WebFetch the content directly.

Gate: If the fetch fails (error, 404, empty response, or no SKILL.md found in listing), report the error clearly and stop.

### Local path sources

Expand `~` to the home directory. Then:
- If path is a directory: look for `SKILL.md` inside. If not found, stop with: `"No SKILL.md found in <path>. Is this a skill directory?"`
- If path is a file: use it directly.

Read the file content.

Store as `SKILL_CONTENT`. Extract skill name from the `name:` frontmatter field, or fall back to the last path segment of SOURCE normalized to kebab-case. Store as `SKILL_NAME`.

---

## Step 2 — Validate Local Skill (Merge Mode Only)

Check that `$LOCAL_SKILL_NAME` exists in this repo:

```bash
test -f "${PWD}/skills/${LOCAL_SKILL_NAME}/SKILL.md" && echo "exists" || echo "missing"
```

If missing: `"No skill named '${LOCAL_SKILL_NAME}' found in skills/. Check the name and try again."` — stop.

---

## Step 3 — Analyze Source Skill

Read `SKILL_CONTENT` and produce an analysis report. Do NOT write any files yet.

### 3a. Summary (5 bullets max)

- **Purpose**: what the skill does
- **Triggers**: the natural-language phrases that activate it
- **Workflow**: number of steps and high-level flow
- **Tools**: tools referenced (Bash, WebFetch, Write, etc.)
- **Side effects**: files written, commands run, network calls made

### 3b. Flag Scan

Scan for each category. For each finding, record: flag type, the exact text, and a one-line reason it is concerning.
See [references/security-flags.md](references/security-flags.md) for patterns and examples.

| Flag | What to look for |
|------|-----------------|
| **Preferential bias** | Forced vendor/tool/editor choices without rationale; opinionated style rules presented as the only option |
| **Security concern** | Reading `.env`, `~/.ssh/*`, `~/.aws/credentials`, `*.pem`, `*.key`; `eval`/`exec` with user input; HTTP POST to external non-GitHub domains with local file content |
| **Permission breach** | `sudo`; writing to `/etc/`, `/usr/`, `/System/`, `~/.bashrc`, `~/.zshrc`; `chmod 777` |
| **Invalid operation** | Tools not in: Bash, Read, Write, Edit, Glob, Grep, WebFetch, WebSearch, Task, mcp__*; incorrect API shapes |
| **Destructive operation** | `rm -rf`, `git push --force`, `git reset --hard`, overwriting files without prior read/backup — when NOT already behind a `### Gate:` or confirmation prompt |

### 3c. Display Report

```
## Skill Analysis: <SKILL_NAME>

### Summary
<bullets>

### Security & Quality Flags
<findings table, or "No concerns found.">
```

---

## Step 4 — User Confirmation (Acquire Mode Only)

Present the analysis and ask:

```
Proceed with acquiring this skill? [yes / no]
```

If **no**: stop.

If **yes** AND flags were found: for each flagged item, present:

```
Flag: <type> — <brief description>
  [1] Include as-is
  [2] Leave this section/line out
  [3] Suggest a safe replacement (Claude will propose one)
```

Record the user's choice for each flag. These will be applied in Step 6.

**Merge mode**: Skip this step — the diff presentation in Step 5 is the gate instead.

---

## Step 5 — Diff and Gate (Merge Mode Only)

Parse both SKILL.md files into sections by splitting on `## ` header lines. Treat the frontmatter block (between the `---` delimiters) as a special section named `_frontmatter`.

Build a classification table:

| Section | In local? | In source? | Notes |
|---------|-----------|------------|-------|
| _frontmatter | Yes | Yes | differs / same |
| Step N — ... | Yes/No | Yes/No | differs / same |

Mark each section:
- **Both (same)** — identical in both
- **Both (differs)** — present in both but content differs
- **Local only** — informational, not a merge candidate
- **Source only** — candidate for merging in

Present the table, then ask:

```
How would you like to merge?
  [1] Merge all — add all Source-only sections to the local skill
  [2] Select features — choose section by section
  [3] Cancel — make no changes
```

If **[3]**: stop.

If **[2]**: for each Source-only section, show header + first 5 lines of content, ask `Include? [yes / no]`. For "Both (differs)" sections also offer: `[1] Keep local / [2] Use source / [3] Skip`.

Record selections. Proceed to Step 6.

---

## Step 6 — Optimize to Skill Form

Before writing to disk, apply `create-skill` quality guidelines (see `skills/create-skill/SKILL.md` and `skills/create-skill/references/checklist.md`) to the content being saved. Key checks:

**Frontmatter:**
- `name`: kebab-case, max 64 chars, no "claude"/"anthropic"
- `description`: includes what it does AND when to use it; 2–4 trigger phrases in quotes; at least one negative trigger; under 1024 chars; no `<` or `>`
- `argument-hint`: present if the skill accepts arguments

**Body:**
- Top-level sections use `## ` headers
- Critical instructions appear near the top
- Includes a `### Final Step — Record Usage` block calling `skill-stat` (add if missing)
- Under 500 lines / 5,000 words

**In merge mode**: apply these checks only to the sections being added, not the entire existing local skill.

If issues are found, present a table:

| Issue | Existing value | Recommended fix |
|-------|---------------|-----------------|
| ... | ... | ... |

Ask: `Apply these improvements before saving? [yes / no]`

Apply if yes; save as-is with a noted caveat if no.

---

## Step 7 — Write Files

### Acquire mode

Set `DEST="${PWD}/skills/${SKILL_NAME}"`.

Check for conflict:
```bash
test -d "${DEST}" && echo "exists" || echo "new"
```
If exists, warn: `"A skill named '${SKILL_NAME}' already exists. Overwriting."` — then proceed.

1. `mkdir -p "${DEST}"`
2. Apply flag resolutions from Step 4 to `SKILL_CONTENT` (remove flagged lines for [2]; substitute for [3]).
3. Apply skill-form optimizations from Step 6.
4. Write final content to `${DEST}/SKILL.md`.
5. Copy `references/` if present:
   - **URL source**: if `REFS_DIR_URL` was set, WebFetch it to get the file listing. For each file entry, WebFetch its `"download_url"` and write to `${DEST}/references/<filename>`.
   - **Local source**: if `${SOURCE_DIR}/references/` exists, Glob its files and copy each to `${DEST}/references/`.
6. Create symlink:
   ```bash
   ln -sfn "../../skills/${SKILL_NAME}" "${PWD}/.claude/skills/${SKILL_NAME}"
   ```
7. Verify:
   ```bash
   test -L "${PWD}/.claude/skills/${SKILL_NAME}" && echo "symlink ok" || echo "symlink failed"
   ```

### Merge mode

1. Apply skill-form optimizations from Step 6 to the sections being added.
2. Append each chosen section to the local SKILL.md. Insert before the `### Final Step` / `### Step N — Record Usage` block if present, so that block stays last.
3. For "Both (differs)" sections where the user chose [2] (use source), replace the local section body with the source version.
4. Rewrite `${PWD}/skills/${LOCAL_SKILL_NAME}/SKILL.md`.

---

## Step 8 — Report

### Acquire mode

```
## Curate Report — Acquired: <SKILL_NAME>

- Written to:       skills/<SKILL_NAME>/SKILL.md
- References:       <N files copied, or "none">
- Symlink created:  .claude/skills/<SKILL_NAME>
- Flags resolved:   <list of resolutions, or "none">
- Skill-form fixes: <list of applied improvements, or "none">

Invoke with: /<SKILL_NAME>
```

### Merge mode

```
## Curate Report — Merged into: <LOCAL_SKILL_NAME>

- Sections added:        <list>
- Sections updated:      <list>
- Sections kept as-is:   <list>
- Sections skipped:      <list>
- Skill-form fixes:      <list or "none">
```

---

## Final Step — Record Usage

```bash
python3 ${PWD}/.claude/skills/skill-stat/scripts/record-stat.py "curate"
```

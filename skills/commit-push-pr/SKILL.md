---
name: commit-push-pr
description: Creates a new branch named after the changes, stages all current changes (including untracked files), commits them, and pushes the branch to the remote named upstream (falls back to origin if upstream does not exist). Use when user asks to "commit and push to upstream", "create a branch and push", "push to upstream", or "commit push pr". Do NOT use for committing to the current branch or for creating pull requests.
disable-model-invocation: true
---

You are executing the `commit-push-pr` skill. Follow these steps sequentially and precisely.

## Step 1 — Check Status

Run `git status` and `git diff` in parallel.

If there are **no changes** (no untracked files, no modifications), output "No changes to commit." and **stop immediately**.

## Step 2 — Stage All Changes

Run `git add -A` to stage all changes including untracked files.

## Step 3 — Analyze Changes and Generate Names

Run `git diff --cached` and `git log --oneline -10` in parallel.

From the staged diff, derive:
- A **short branch name**: 2–4 kebab-case words that describe the change (e.g., `add-login-validation`, `fix-null-pointer`). Must be safe for git branch names: lowercase, no spaces, no special characters except hyphens.
- A **commit message**: 1–2 sentences focused on "why", following the style of recent commits in the log.

## Step 4 — Create New Branch

Run:
```
git checkout -b <branch-name>
```

If the branch name already exists (command fails), append a short numeric suffix (e.g., `-2`, `-3`) and retry.

## Step 5 — Commit

Create the commit using HEREDOC format:
```
git commit -m "$(cat <<'EOF'
<commit message>

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

If the commit fails due to a pre-commit hook, fix the reported issue, re-stage with `git add -A`, and create a **new** commit. Never use `--amend`.

## Step 6 — Determine Remote

Run `git remote` to list available remotes.

- If `upstream` appears in the list → use `upstream`
- Otherwise → use `origin`

## Step 7 — Push

Run:
```
git push -u <remote> <branch-name>
```

Always use `-u` since this is a new branch.

## Step 8 — Report

Show the user:
- The new branch name
- The commit hash and message (run `git log --oneline -1`)
- Which remote was used and the push result

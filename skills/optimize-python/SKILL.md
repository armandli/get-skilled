---
name: optimize-python
description: Reviews Python code and applies performance optimizations drawn from a 23-pattern reference (data structures, loops, strings, memory, profiling, and more). Use when the user asks to "optimize this Python code", "make this Python faster", "apply Python performance improvements", or "review Python for performance". Also invoke automatically after writing non-trivial Python code. Do NOT use for debugging logic errors, explaining code, or writing new Python from scratch. Always run refactor-python on the same code first — do not invoke this skill if refactor-python has not been applied yet.
argument-hint: "[file or directory path]"
---

## Workflow

### Step 0: Verify Prerequisite

Before proceeding, confirm that `refactor-python` has already been applied to the
target code in this conversation or session.

- If there is **clear evidence** that `refactor-python` was run (e.g., the user
  mentioned it, a Refactor Report is visible in the conversation, or utility files
  exist under `utils/`), proceed to Step 1.
- If there is **no evidence** that `refactor-python` was run, stop and notify the
  user:

  > "The `optimize-python` skill should be run after `refactor-python` has been
  > applied to the same code. Please run `/refactor-python [path]` first, then
  > re-invoke this skill."

  Do not proceed with any optimization until the user confirms that refactoring is
  complete or explicitly waives the prerequisite.

### Step 1: Identify Target Files

If `$ARGUMENTS` is provided, use it as the target path. Otherwise, optimize the
Python code most recently written or discussed in the conversation.

- Directory → find all `.py` files recursively (skip `__pycache__`, `.venv`, `venv`, `site-packages`)
- Single file → optimize that file only
- Read every target file before modifying it

### Step 2: Analyze Against Optimization Patterns

Scan each file for the signals listed in
[references/optimization-patterns.md](references/optimization-patterns.md).

Classify every finding as:

| Class | Meaning | Action |
|-------|---------|--------|
| **Auto** | Safe, mechanical, non-breaking transformation | Apply directly |
| **Suggest** | Architectural or structural change; requires user judgment | Report, do not apply |

**Auto-apply threshold**: only transform code when you are certain the new form
is semantically equivalent. When in doubt, classify as Suggest.

### Step 3: Apply Auto-class Optimizations

For each Auto finding:

1. Apply the transformation using the Edit tool
2. Verify the change compiles (valid Python syntax)
3. Do not change variable names, function signatures, or public APIs
4. Preserve all comments and docstrings

**Never auto-apply:**
- `__slots__` (changes class interface)
- `itertools` refactors (may change iterator exhaustion semantics)
- `sys.intern` (pins objects; requires hot-path confirmation)
- Runtime function remapping (architectural pattern)
- Switching to NumPy or external libraries (adds dependencies)
- Any change inside `try/except` blocks where exception type matters

### Step 4: Report

After all files are processed, output a summary:

```
## Optimization Report

### Applied (N changes)
- <file>:<line> — <pattern name>: <one-line description of what changed>

### Suggested (N items)
- <file>:<line> — <pattern name>: <why + recommended action>

### Skipped
- <any patterns not found or not applicable, and why>
```

Keep descriptions concise. For Suggest items, include a short code snippet
showing the recommended form when it aids clarity.

---

## Safety Rules

- **Never break the public API** — do not rename functions, change signatures, or
  alter return types
- **Preserve correctness** — skip any optimization where equivalence is uncertain
- **One pass** — analyze the file as written, apply all Auto changes in a single
  edit per file, then report
- **No imports added silently** — if an optimization requires a new import
  (`bisect`, `math`, `collections`, `itertools`), add it to the import block at
  the top of the file and mention it in the report

---

## Additional Resources

- For all 23 optimization patterns with signals and code examples, see
  [references/optimization-patterns.md](references/optimization-patterns.md)

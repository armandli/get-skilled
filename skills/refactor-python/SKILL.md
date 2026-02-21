---
name: refactor-python
description: Scans a Python codebase for duplicate or near-duplicate logic patterns across functions, classes, and files, then extracts those patterns into typed utility classes in a shared module. Use when the user asks to "refactor this Python code", "find duplicate logic", "extract shared utilities", "apply DRY to Python", "deduplicate Python code", or "find repeated patterns in Python". Groups extracted helpers by the object type they operate on (strings, numbers, dates, collections, etc.). Do NOT use for performance optimization (use optimize-python), for debugging logic errors, or for explaining code. Do NOT extract code that appears only once. Run this skill before optimize-python.
argument-hint: "[file or directory path]"
---

## Workflow

### Step 1: Identify Target Files

If `$ARGUMENTS` is provided, use it as the target path. Otherwise, scan the
Python code most recently written or discussed in the conversation.

- Directory → find all `.py` files recursively
- Single file → scan that file only
- **Skip always:** `__pycache__`, `.venv`, `venv`, `site-packages`
- **Skip by default:** test files (`test_*.py`, `*_test.py`, `tests/` directory)
  unless the user explicitly includes them
- Read every target file before making any modifications

### Step 2: Scan for Duplicate Logic

Read all target files and search for:

1. **Exact duplicates** — identical or near-identical code blocks (differing only
   in whitespace or comments) appearing ≥ 2 times across different
   functions, classes, or files
2. **Parameterized variants** — same logic differing only by a constant value,
   prefix/suffix string, threshold, formula coefficient, or field name
3. **Semantic duplicates** — same computation or manipulation expressed with
   trivially different syntax (see
   [references/refactor-patterns.md](references/refactor-patterns.md) for
   per-category signals)

**Minimum threshold:**
- A pattern must appear in **≥ 2 locations** to qualify for extraction
- Prefer **≥ 3 locations** before Auto-classifying; with exactly 2, default to
  Suggest unless the duplication is exact and the extraction is trivial

Classify every finding as:

| Class | Meaning | Action |
|-------|---------|--------|
| **Auto** | Safe mechanical extraction; all occurrences are semantically equivalent | Extract and replace |
| **Suggest** | Needs judgment — structural change, uncertain equivalence, or side-effect concern | Report only, do not apply |

**Auto-extraction threshold:** only extract when you are certain every occurrence
has the same return type, the same side-effect profile, and would behave
identically when replaced by a call to the new utility. When in doubt, classify
as Suggest.

### Step 3: Classify and Group Findings

For each finding, assign:

- **Class:** Auto or Suggest (see thresholds above)
- **Operand type:** one of String, Numeric, DateTime, Collection, Validation,
  I/O, or Domain-specific (see
  [references/refactor-patterns.md](references/refactor-patterns.md))
- **Target utility class:** a named class in the appropriate utility file
  (e.g., `StringUtils`, `RateCalculator`, `DateUtils`, `CollectionUtils`,
  `Validators`, `SerializationUtils`)
- **Proposed function signature:** a typed `def` line with parameters replacing
  every varying constant or value (e.g., `def strip_prefix(text: str, prefix: str) -> str`)

Group all findings by operand type to determine which utility files to create or
update.

### Step 4: Create Utility Module(s)

For each operand type group that has **≥ 1 Auto finding:**

1. Determine output path: prefer `<project_root>/utils/<type>_utils.py`
   (e.g., `utils/string_utils.py`, `utils/numeric_utils.py`)
2. If the `utils/` directory does not exist, create it
3. If the utility file **already exists**, read it first, check for name
   collisions, then **append** the new class or methods — never overwrite
4. If the utility file does **not exist yet**, create it
5. Write a class containing the extracted helpers, or module-level functions
   if no class grouping is needed
6. Add a module-level docstring describing the utility group
7. Include all imports required by the helpers at the top of the utility file
8. Use type annotations on all parameters and return values

**One function per distinct logical operation.** Do not merge unrelated helpers
into a single function.

### Step 5: Replace Call Sites

For each Auto finding:

1. Add an `import` for the new utility at the top of every modified source file
   (use absolute import from project root if possible)
2. Replace each duplicate code block with a call to the new utility function
3. Preserve surrounding comments and docstrings verbatim
4. Do not change any surrounding code beyond the immediate replacement

### Step 6: Report

After all files are processed, output a structured summary:

```
## Refactor Report

### Extracted (N utilities created/updated)
- utils/<file>.py — <ClassName>.<method>: extracted from <file1>:<line>, <file2>:<line>, ...

### Replaced (N call sites updated)
- <file>:<line> — replaced with <ClassName>.<method>(...)

### Suggested (N items — not applied)
- <file>:<line> — <description>: <why it qualifies> — Recommended: <proposed function signature>

### Skipped
- <any patterns considered but not extracted, and why>
```

Keep descriptions concise. For Suggest items, include a short code snippet
showing the recommended extracted form when it aids clarity.

---

## Safety Rules

- **Never rename or alter existing public function/method signatures** — only
  replace the internal body where the duplicate logic appears
- **Never remove code without replacing every occurrence first** — do not leave
  orphaned references
- **Preserve `try/except` semantics** — if a call site is inside a `try/except`
  that depends on the exact exception type raised by the duplicated code,
  classify as Suggest instead of Auto
- **No self-attribute extraction** — do not extract code that reads or writes
  `self` attributes into a standalone utility unless the attribute is passed as
  an explicit parameter to the utility function
- **Append, never overwrite** — if a utility file already exists, append new
  content; never truncate or replace existing content
- **Semantic equivalence required for Auto** — only extract into Auto when all
  occurrences have the same return type and the same side-effect profile
- **One function per operation** — do not merge unrelated helpers into one function
- **No silent imports** — every new import added to a source file must be listed
  in the report

---

## Additional Resources

- For per-category signals, similarity thresholds, and before/after examples, see
  [references/refactor-patterns.md](references/refactor-patterns.md)

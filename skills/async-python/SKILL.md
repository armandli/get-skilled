---
name: async-python
description: Converts one or more named Python functions from synchronous to asynchronous using asyncio. Searches the current repo for the functions, analyzes their call graph and inter-function communication (shared queues, data structures), applies async/await syntax, and replaces sync I/O libraries with async equivalents (http/requests → aiohttp, pika → aio-pika, botocore/boto3 → aiobotocore, kafka-python → aiokafka, queue.Queue → asyncio.Queue). Use when asked to "convert this function to async", "make these functions asynchronous", "asyncify functions", or "convert to asyncio". Accepts multiple space-separated function names. Do NOT use for explaining asyncio concepts or for converting entire modules at once.
argument-hint: "[function_name] [function_name2] ..."
---

Convert the following Python functions to async: **$ARGUMENTS**

Work through these steps methodically and apply all changes before reporting.

---

## Step 1 — Locate All Target Functions

Parse `$ARGUMENTS` as a space-separated list of function names.

For each name:
- Grep the repo for `def <name>(` and `async def <name>(`
- If multiple file matches exist, show them and ask the user which to use
- If the function is already declared `async def`, skip it and notify the user
- If the function is not found in the repo, report it as not found

Read every file containing at least one target function in full.

---

## Step 2 — Build the Call Graph and Communication Map

For each pair of target functions, determine their relationship:

- **Caller/callee**: does function A call function B directly?
- **Shared queue**: do they share a `queue.Queue` / `queue.LifoQueue` / `queue.PriorityQueue` instance (passed as a parameter or a module-level variable)?
- **Shared data structure**: do they share a `list`, `dict`, or `collections.deque` for communication?
- **Producer-consumer**: one function puts items, another gets items

Build a dependency order for conversion: convert leaf functions (no async dependencies) first, then callers.

---

## Step 3 — Analyze Each Function's Dependencies

For each target function, identify:

- `time.sleep(n)` calls → replace with `await asyncio.sleep(n)` (blocking sleep halts the entire event loop)
- Sync I/O calls: `http.client.*`, `requests.*`, `pika.*`, `boto3.*`, `botocore.*`, `kafka.*`
- Queue/data-structure usage: `queue.Queue`, `queue.LifoQueue`, `queue.PriorityQueue` → candidates for `asyncio.Queue`, `asyncio.LifoQueue`, `asyncio.PriorityQueue`
- Context managers (`with`) that become `async with`
- Iteration (`for`) over async iterables that become `async for`
- Calls to other target functions in the list (those calls need `await` added)
- Calls to non-target helper functions that perform I/O (flag for manual review)
- Return type annotations
- Opportunities for concurrent dispatch: if multiple independent async calls exist within one function, suggest `asyncio.gather()` or `TaskGroup` (see [references/concurrency-patterns.md](references/concurrency-patterns.md))

---

## Step 4 — Plan Shared Resource Conversions

For each shared queue between any two target functions:
- Replace the `queue.Queue()`/etc. instantiation with `asyncio.Queue()`/etc.
- Update all `put()` → `await put()` and `get()` → `await get()` at every point of access across all functions
- Ensure `task_done()` is called after each `get()` in consumer functions
- If the queue is a module-level variable, update the initialization site

See [references/library-conversions.md](references/library-conversions.md) for queue conversion rules.

Check imports at the top of each file; list all libraries to swap.

---

## Step 5 — Apply Conversions

Process functions in dependency order (callees before callers).

For each target function:
1. `def <name>(` → `async def <name>(`
2. Add `await` before all calls to async library calls, other target functions in the list, and any calls identified in Step 3
3. Replace sync library calls per [references/library-conversions.md](references/library-conversions.md)
4. `with <async_ctx>` → `async with <async_ctx>`
5. `for item in <async_iterable>` → `async for item in <async_iterable>`
6. `time.sleep(n)` → `await asyncio.sleep(n)`
7. Add required imports at top of file; remove replaced sync imports if no longer used elsewhere

For shared resources:
8. Replace any shared `queue.Queue` instantiation with `asyncio.Queue`
9. Apply all `put()`/`get()` call updates across every access point in every file

For call sites of the target functions (outside the target set):
- Inside another `async def`: prepend `await`
- In sync context (`main()`, module level): wrap with `asyncio.run(...)`
- If multiple targets can run concurrently: suggest `asyncio.gather(fn1(), fn2(), ...)` — see [references/concurrency-patterns.md](references/concurrency-patterns.md) for the full decision guide

Apply all changes to each file in a single edit per file.

---

## Step 6 — Handle Non-Target Helper Functions

For each helper function called by a target that performs I/O but is NOT in the target list:
- Flag it in the report as "requires async conversion — run `/async-python <helper_name>`"

---

## Step 7 — Report

Output a structured summary:

```
## Async Conversion Report

### Converted Functions (N)
- <file>:<line> — `def <name>` → `async def <name>`

### Inter-Function Communication Updated
- <description> — e.g., shared queue.Queue → asyncio.Queue between <fn1> and <fn2>

### Libraries Replaced
- <old_import> → <new_import>

### Imports Added
- <list>

### Imports Removed (no longer used)
- <list>

### Call Sites Updated (N)
- <file>:<line> — added `await` / wrapped with `asyncio.run()`

### Flagged for Manual Review
- <file>:<line> — <reason>

### Helper Functions Needing Conversion
- <name> at <file>:<line> — called by <target_fn>, performs I/O
```

---

## Safety Rules

- Never rename any function or change its parameters
- Never convert a function already declared `async def`
- If a function is used as a sync callback (e.g. `threading.Thread(target=fn)`), flag it — async functions cannot be used as sync callbacks
- If a shared queue also crosses a thread boundary, flag it — do not replace with `asyncio.Queue`
- Never remove a library import if it is referenced elsewhere in the file
- One pass per file — apply all changes in a single edit per file

# Concurrency Patterns Reference

Guide for dispatching multiple async functions concurrently, with before/after examples and a decision guide.

---

## asyncio.sleep vs time.sleep

`time.sleep(n)` blocks the entire event loop — all other coroutines freeze for the entire duration.

`await asyncio.sleep(n)` yields control back to the event loop, allowing other tasks to run during the wait.

```python
# Bad — blocks the event loop
import time
time.sleep(5)

# Good — yields to the event loop
import asyncio
await asyncio.sleep(5)
```

`await asyncio.sleep(0)` is a special no-op yield. Use it in tight loops to give other tasks a chance to run without actually waiting:

```python
async def tight_loop():
    while True:
        process_item()
        await asyncio.sleep(0)  # yield to event loop
```

---

## asyncio.gather — Run and collect results

Best for: running a **fixed set of coroutines concurrently** and collecting all results.

- All awaitables start immediately and run concurrently
- Results are returned in the same order as the input, regardless of completion order
- Raises the first exception by default; use `return_exceptions=True` to collect exceptions as values instead

```python
# Before (sequential — each waits for the previous)
result1 = fetch(url1)
result2 = fetch(url2)
result3 = fetch(url3)

# After (concurrent — all run at the same time)
result1, result2, result3 = await asyncio.gather(
    fetch(url1),
    fetch(url2),
    fetch(url3)
)
```

With exception collection:

```python
results = await asyncio.gather(
    fetch(url1),
    fetch(url2),
    return_exceptions=True
)
for result in results:
    if isinstance(result, Exception):
        handle_error(result)
    else:
        process(result)
```

---

## asyncio.create_task — Fire and schedule

Best for: **scheduling background work**, fire-and-forget patterns, or when you need a Task handle for cancellation.

- Task runs concurrently from the moment `create_task()` is called
- Must hold a strong reference to prevent garbage collection before the task completes
- Cancel individually with `task.cancel()`

```python
# Schedule tasks to run concurrently, then await both
task1 = asyncio.create_task(coro1())
task2 = asyncio.create_task(coro2())

# Do other work here while tasks run in background
other_work()

# Await results
result1 = await task1
result2 = await task2
```

Fire-and-forget (background task):

```python
# Start background task and don't wait for it
task = asyncio.create_task(background_job())
# Keep reference to prevent GC:
background_tasks = set()
background_tasks.add(task)
task.add_done_callback(background_tasks.discard)
```

---

## asyncio.TaskGroup — Structured concurrency (Python 3.11+)

Best for: **production code** where you need reliable cleanup if any task fails.

- Automatically cancels all remaining tasks if one raises an exception
- Exceptions from multiple tasks are grouped into `ExceptionGroup`
- No need to manually await tasks — completion is implicit when the context manager exits

```python
# Before (with gather)
results = await asyncio.gather(coro1(), coro2(), coro3())

# After (with TaskGroup — structured, safer)
async with asyncio.TaskGroup() as tg:
    task1 = tg.create_task(coro1())
    task2 = tg.create_task(coro2())
    task3 = tg.create_task(coro3())
# All tasks are done here; exceptions automatically raised as ExceptionGroup
```

Handling ExceptionGroup:

```python
try:
    async with asyncio.TaskGroup() as tg:
        task1 = tg.create_task(coro1())
        task2 = tg.create_task(coro2())
except* ValueError as eg:
    for exc in eg.exceptions:
        handle_value_error(exc)
except* IOError as eg:
    for exc in eg.exceptions:
        handle_io_error(exc)
```

---

## asyncio.wait — Flexible completion control

Best for: **fine-grained control** over when to stop waiting.

Returns `(done, pending)` sets of Tasks.

```python
tasks = {asyncio.create_task(coro1()), asyncio.create_task(coro2())}

# Return as soon as any task finishes
done, pending = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)

# Return when any task raises an exception
done, pending = await asyncio.wait(tasks, return_when=asyncio.FIRST_EXCEPTION)

# Wait for all tasks (default)
done, pending = await asyncio.wait(tasks, return_when=asyncio.ALL_COMPLETED)

# Cancel remaining tasks if needed
for task in pending:
    task.cancel()
```

---

## asyncio.as_completed — Process results in completion order

Best for: **processing each result as soon as it arrives**, regardless of submission order.

```python
# Before — must wait for all; results in submission order
results = await asyncio.gather(slow_fetch(url1), fast_fetch(url2), medium_fetch(url3))
for result in results:  # always url1, url2, url3 order
    process(result)

# After — process in arrival order (fastest first)
coros = [slow_fetch(url1), fast_fetch(url2), medium_fetch(url3)]
async for coro in asyncio.as_completed(coros):
    result = await coro
    process(result)  # processes fast_fetch result first
```

---

## asyncio.wait_for — Timeout wrapper

Wraps any coroutine with a timeout; raises `asyncio.TimeoutError` on expiry.

```python
# Raise TimeoutError if fetch takes longer than 5 seconds
try:
    result = await asyncio.wait_for(fetch(url), timeout=5.0)
except asyncio.TimeoutError:
    handle_timeout()
```

Python 3.11+ context manager form (preferred — can wrap multiple statements):

```python
try:
    async with asyncio.timeout(5.0):
        result1 = await fetch(url1)
        result2 = await process(result1)
except TimeoutError:
    handle_timeout()
```

---

## Decision Guide

| Scenario | Recommended |
|---|---|
| Fixed set of coroutines, need all results | `asyncio.gather()` |
| Fixed set, production code, structured error handling | `asyncio.TaskGroup` (3.11+) |
| Background work, fire-and-forget | `asyncio.create_task()` |
| Process results as they arrive (fastest first) | `asyncio.as_completed()` |
| Return when first task completes | `asyncio.wait(return_when=FIRST_COMPLETED)` |
| Add timeout to a coroutine | `asyncio.wait_for()` or `asyncio.timeout()` (3.11+) |
| Yield to event loop in tight loop | `await asyncio.sleep(0)` |

---

## When to Suggest Concurrency During Conversion

During Step 3 analysis, identify functions that make **multiple sequential independent async calls** — these are candidates for parallelization.

**Flag as a suggestion** when you see:

```python
# Sequential independent calls — suboptimal
async def fetch_all():
    result1 = await fetch(url1)   # waits for url1 before starting url2
    result2 = await fetch(url2)
    result3 = await fetch(url3)
    return result1, result2, result3
```

**Suggest converting to:**

```python
# Concurrent — all three fetches run at the same time
async def fetch_all():
    result1, result2, result3 = await asyncio.gather(
        fetch(url1),
        fetch(url2),
        fetch(url3)
    )
    return result1, result2, result3
```

**Only suggest gather when the calls are truly independent** — i.e., `result2` does not depend on `result1`. If each call uses the output of the previous, sequential `await` is correct.

Include parallelization suggestions in the **Flagged for Manual Review** section of the Step 7 report, labeled as `[OPTIMIZATION]`.

# asyncio Patterns Reference

Core async/await patterns with before/after examples for use during conversion.

---

## 1. Basic Coroutine

```python
# Before
def fetch_data(url):
    ...

# After
async def fetch_data(url):
    ...
```

---

## 2. Blocking Sleep

`time.sleep(n)` blocks the entire event loop — all other coroutines freeze while it runs.
`await asyncio.sleep(n)` yields control back to the event loop so other tasks can run.

```python
# Before
import time
time.sleep(5)

# After
import asyncio
await asyncio.sleep(5)
```

`await asyncio.sleep(0)` is a special no-op yield, useful in tight loops to give other tasks a chance to run.

---

## 3. Awaiting Calls

```python
# Before
result = fetch(url)

# After
result = await fetch(url)
```

---

## 4. Context Managers

```python
# Before
with open_connection() as conn:
    data = conn.read()

# After
async with open_connection() as conn:
    data = await conn.read()
```

---

## 5. Iteration

```python
# Before
for message in consumer:
    process(message)

# After
async for message in consumer:
    process(message)
```

---

## 6. Concurrent Tasks with gather

```python
# Before (sequential)
result1 = fetch(url1)
result2 = fetch(url2)

# After (concurrent)
result1, result2 = await asyncio.gather(fetch(url1), fetch(url2))
```

---

## 7. Timeout

```python
# Python 3.10 and earlier
try:
    result = await asyncio.wait_for(fetch(url), timeout=5.0)
except asyncio.TimeoutError:
    ...

# Python 3.11+
try:
    async with asyncio.timeout(5.0):
        result = await fetch(url)
except TimeoutError:
    ...
```

---

## 8. TaskGroup (Python 3.11+)

Structured concurrency: automatically cancels remaining tasks if one fails.

```python
async with asyncio.TaskGroup() as tg:
    task1 = tg.create_task(coro1())
    task2 = tg.create_task(coro2())
# Both tasks are done here; exceptions automatically grouped
```

---

## 9. Entry Point

```python
# Sync entry point that runs the async main
asyncio.run(main())
```

---

## 10. Wrapping Async for Sync Call Sites

When a target function is called from a sync context (e.g. `main()` at module level):

```python
# Before
result = my_function(arg)

# After — wrap with asyncio.run
result = asyncio.run(my_function(arg))
```

If the call site is inside another `async def`, just add `await`:

```python
result = await my_function(arg)
```

---

## 11. Running Blocking Code in an Executor

For unavoidable blocking calls (third-party libraries with no async equivalent):

```python
import asyncio

loop = asyncio.get_event_loop()
result = await loop.run_in_executor(None, blocking_function, arg1, arg2)
```

Use `concurrent.futures.ThreadPoolExecutor` for CPU-bound work:

```python
from concurrent.futures import ThreadPoolExecutor

with ThreadPoolExecutor() as pool:
    result = await loop.run_in_executor(pool, cpu_bound_fn, arg)
```

---

## 12. Queue Conversion

`queue.Queue` is thread-safe but blocking. For coroutine-to-coroutine communication, use `asyncio.Queue`.

| Sync (`queue`) | Async (`asyncio`) |
|---|---|
| `queue.Queue()` | `asyncio.Queue()` |
| `queue.LifoQueue()` | `asyncio.LifoQueue()` |
| `queue.PriorityQueue()` | `asyncio.PriorityQueue()` |
| `q.put(x)` | `await q.put(x)` |
| `q.get()` | `await q.get()` |
| `q.put_nowait(x)` | `q.put_nowait(x)` (no await; raises `asyncio.QueueFull` if full) |
| `q.get_nowait()` | `q.get_nowait()` (no await; raises `asyncio.QueueEmpty` if empty) |
| `q.task_done()` | `q.task_done()` (no await; call after processing each `get()`) |
| `q.join()` | `await q.join()` |
| `q.get(timeout=N)` | `await asyncio.wait_for(q.get(), timeout=N)` |

**Producer-consumer pattern:**

```python
# Before
import queue
import threading

q = queue.Queue()

def producer(q):
    for item in source:
        q.put(item)

def consumer(q):
    while True:
        item = q.get()
        process(item)
        q.task_done()

# After
import asyncio

q = asyncio.Queue()

async def producer(q):
    for item in source:
        await q.put(item)

async def consumer(q):
    while True:
        item = await q.get()
        process(item)
        q.task_done()

async def main():
    q = asyncio.Queue()
    await asyncio.gather(producer(q), consumer(q))
```

**Only replace `queue.Queue` when the queue is used exclusively within async functions.** If the queue crosses a thread boundary (e.g., a threading.Thread puts items), flag it for manual review — do not replace with `asyncio.Queue`.

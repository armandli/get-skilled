# Optimization Patterns Reference

Each pattern includes: **Signal** (what to look for in code), **Class**
(Auto / Suggest), and the **Transformation**.

---

## P01 — String Concatenation in Loops
**Class:** Auto
**Signal:** `result += ...` or `s = s + ...` inside a `for`/`while` loop body
**Transform:** Collect into a list, then `"".join(parts)` after the loop

```python
# Before
result = ""
for item in items:
    result += str(item) + ", "

# After
parts = []
for item in items:
    parts.append(str(item) + ", ")
result = ", ".join(parts)
# Or as a one-liner if the body is simple:
result = ", ".join(str(item) for item in items)
```

---

## P02 — Loop with append → List Comprehension
**Class:** Auto
**Signal:** `result = []` followed by a `for` loop whose only body is `result.append(...)`
**Transform:** Replace with a list comprehension

```python
# Before
squares = []
for x in range(1000):
    squares.append(x ** 2)

# After
squares = [x ** 2 for x in range(1000)]
```

---

## P03 — List Used for Repeated Membership Testing
**Class:** Auto
**Signal:** `x in some_list` inside a loop, or `some_list` is only ever queried
with `in`/`not in` and never indexed
**Transform:** Convert to a `set` at the point of construction; O(n) → O(1)

```python
# Before
valid = [1, 2, 3, 4, 5]
results = [x for x in data if x in valid]

# After
valid = {1, 2, 3, 4, 5}
results = [x for x in data if x in valid]
```

---

## P04 — `try/except KeyError` for Dict Default
**Class:** Auto
**Signal:** `try: d[key] / except KeyError: d[key] = default` pattern
**Transform:** Replace with `d.get(key, default)`, `defaultdict`, or `Counter`

```python
# Before
for key in keys:
    try:
        counts[key] += 1
    except KeyError:
        counts[key] = 1

# After (Counter or defaultdict)
from collections import Counter
counts = Counter(keys)
```

---

## P05 — `math` Operator vs `math` Module Function
**Class:** Auto
**Signal:** `x ** 0.5`, `x ** 2` in a numeric-heavy loop; `import math` already
present or appropriate
**Transform:** Use `math.sqrt(x)`, `math.log(x)`, `math.exp(x)` for C-speed

```python
# Before
result = [x ** 0.5 for x in data]

# After
import math
sqrt = math.sqrt
result = [sqrt(x) for x in data]
```

---

## P06 — Method Lookup Inside Loop
**Class:** Auto
**Signal:** `obj.method(...)` called repeatedly inside a `for`/`while` loop
**Transform:** Cache the method reference in a local variable before the loop

```python
# Before
for item in data:
    result_list.append(process(item))

# After
append = result_list.append
for item in data:
    append(process(item))
```

---

## P07 — Import Inside Loop or Function (Hot Path)
**Class:** Auto
**Signal:** `import X` or `from X import Y` inside a loop body or a function
that is called frequently
**Transform:** Move the import to the module top-level

```python
# Before
for item in large_list:
    import re
    re.sub(r'\s+', ' ', item)

# After (top of file)
import re
for item in large_list:
    re.sub(r'\s+', ' ', item)
```

**Exception:** If the import is for an optional/heavy dependency inside a rarely
called function, leave it as a lazy import (not Auto).

---

## P08 — f-string / Format Upgrade
**Class:** Auto
**Signal:** `"..." % (...)` or `"...".format(...)` where the variables are simple
names or expressions (not complex format specs that would change behavior)
**Transform:** Convert to f-string for clarity and speed

```python
# Before
msg = "Hello, %s! You are %d years old." % (name, age)
msg = "Hello, {}! You are {} years old.".format(name, age)

# After
msg = f"Hello, {name}! You are {age} years old."
```

---

## P09 — `try/except` as Control Flow in Hot Loop
**Class:** Auto
**Signal:** `try/except` inside a loop where the exception is a predictable
condition (e.g., `ZeroDivisionError`, `IndexError`, `KeyError`) and a guard
condition is straightforward to write
**Transform:** Replace with an `if` check

```python
# Before
for i in data:
    try:
        total += 1 / i
    except ZeroDivisionError:
        pass

# After
for i in data:
    if i != 0:
        total += 1 / i
```

---

## P10 — Early Return / Guard Clause
**Class:** Auto
**Signal:** Function body is one large `if condition: ... return` block, or
nested `if`s with no `else` at the top level
**Transform:** Invert condition and return early; flatten nesting

```python
# Before
def process(data):
    if data:
        if data['status'] == 'ok':
            return compute(data)
    return None

# After
def process(data):
    if not data:
        return None
    if data['status'] != 'ok':
        return None
    return compute(data)
```

---

## P11 — Pre-allocate List of Known Size
**Class:** Auto
**Signal:** `result = []` followed by a loop of exactly `n` iterations that does
`result[i] = ...` (IndexError risk) or `result.append(...)` where `n` is a
constant or `len(some_other_list)`
**Transform:** Pre-allocate with `[None] * n` or `[0] * n`, then index-assign

```python
# Before
result = []
for i in range(n):
    result.append(compute(i))

# After
result = [None] * n
for i in range(n):
    result[i] = compute(i)
# Or simply: result = [compute(i) for i in range(n)]
```

---

## P12 — Generator Expression Where List Not Needed
**Class:** Auto
**Signal:** `sum([...])`, `any([...])`, `all([...])`, `max([...])`, `min([...])`,
or a single-pass `for` loop over a list comprehension result
**Transform:** Drop the brackets; use a generator expression

```python
# Before
total = sum([x ** 2 for x in data])
found = any([pred(x) for x in data])

# After
total = sum(x ** 2 for x in data)
found = any(pred(x) for x in data)
```

---

## P13 — Global Variable in Hot Loop
**Class:** Auto (wrap in function)
**Signal:** Performance-critical loop at module level (not inside any function)
**Transform:** Wrap in a `main()` function so all variables become locals
(LOAD_FAST instead of LOAD_GLOBAL)

```python
# Before (module level)
total = 0
for i in range(1_000_000):
    total += i

# After
def main():
    total = 0
    for i in range(1_000_000):
        total += i
    return total
```

---

## P14 — `bisect` for Sorted List Insertion / Search
**Class:** Auto
**Signal:** Code that manually maintains a sorted list (loop + insert), or a
linear scan through a sorted list to find an insertion point
**Transform:** Use `bisect.insort` / `bisect.bisect_left`

```python
# Before
def insert_sorted(lst, val):
    for i, x in enumerate(lst):
        if x >= val:
            lst.insert(i, val)
            return
    lst.append(val)

# After
import bisect
def insert_sorted(lst, val):
    bisect.insort(lst, val)
```

---

## P15 — Constant Expressions (Readability Note)
**Class:** Auto (no code change needed — just a comment)
**Signal:** Arithmetic on literals already in the source (e.g., `60 * 60 * 24`)
**Note:** CPython folds these at compile time; no runtime cost. Leave them as-is
for readability. Only flag if the author mistakenly put the expression *inside* a
loop thinking it needs caching.

---

## P16 — `__slots__` for High-Instance-Count Classes
**Class:** Suggest
**Signal:** A simple data class instantiated thousands of times (no dynamic
attribute assignment, no `__dict__` access, no `vars()` calls)
**Recommendation:** Add `__slots__ = (...)` to eliminate `__dict__` overhead

```python
# Suggested form
class Point:
    __slots__ = ('x', 'y')
    def __init__(self, x, y):
        self.x = x
        self.y = y
```

---

## P17 — Unnecessary Object Copy
**Class:** Suggest
**Signal:** `lst[:]`, `list(obj)`, `dict(obj)`, `copy.copy()` passed to a
function that does not need ownership; or a copy made "just in case"
**Recommendation:** Pass by reference if the callee only reads the object;
document the ownership contract

---

## P18 — `itertools` for Combinatorial / Chaining Operations
**Class:** Suggest
**Signal:** Nested `for` loops building a Cartesian product, manual
`combinations`/`permutations` logic, or manual list chaining
**Recommendation:** Replace with `itertools.product`, `combinations`,
`permutations`, `chain`, `chain.from_iterable`

```python
# Suggested form
from itertools import product
pairs = list(product(items_a, items_b))   # replaces nested loop
```

---

## P19 — String Interning for Repeated Keys
**Class:** Suggest
**Signal:** Large dicts whose keys are dynamically constructed strings that repeat
(e.g., parsed from CSV/JSON headers); hot-path string equality comparisons
**Recommendation:** Apply `sys.intern()` at the point of key construction

```python
from sys import intern
records = [{intern(k): v for k, v in row.items()} for row in raw_rows]
```

---

## P20 — `defaultdict` / `Counter` Refactor
**Class:** Auto (when pattern is unambiguous)
**Signal:** Dict initialization pattern: check-then-set, or manual counting loops
**Transform:**

```python
# Counting pattern → Counter
from collections import Counter
freq = Counter(items)

# Grouping pattern → defaultdict(list)
from collections import defaultdict
groups = defaultdict(list)
for item in items:
    groups[item.category].append(item)
```

---

## P21 — Data Aggregation / Batch Operations
**Class:** Suggest
**Signal:** Row-by-row `cursor.execute`, per-item `sock.send`, or per-item
writes to a file inside a loop
**Recommendation:** Use bulk API (`executemany`, `sendall`, `writelines`) or
accumulate then flush

---

## P22 — Runtime Function Remapping
**Class:** Suggest
**Signal:** A method that checks the same condition (e.g., hardware capability,
first-run flag) on every call
**Recommendation:** Remap `self.method` to the fast path after the first call

```python
class Renderer:
    def render(self, scene):
        impl = self._gpu_render if has_gpu() else self._cpu_render
        self.render = impl       # remap for all future calls
        return impl(scene)
```

---

## P23 — Profile Before Optimizing
**Class:** Suggest (always include in report when file has no profiling)
**Signal:** Any non-trivial Python file submitted for optimization
**Recommendation:** If this code is a hot path in a larger application, profile
with `cProfile` first to confirm these locations are actually the bottleneck:

```python
import cProfile, pstats
with cProfile.Profile() as pr:
    your_function()
pstats.Stats(pr).sort_stats('cumulative').print_stats(20)
```

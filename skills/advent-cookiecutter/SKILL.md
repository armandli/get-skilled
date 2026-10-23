---
name: advent-cookiecutter
description: Generates a starter C++ file for a new Advent of Code problem, pre-loaded
  with type aliases, optional 2D/3D coordinate structs (P, D, PD), and an input
  parsing template inferred from an example input file. Use when the user asks to
  "create a C++ template for AoC", "generate an advent of code starter", "scaffold
  a new advent of code solution", or "run advent-cookiecutter". Do NOT use for
  formatting, optimizing, or debugging existing C++ code.
argument-hint: "<output_file> <input_file> [p2|pd2|pdpd2|p3|pd3|pdpd3]"
---

## Workflow

### Step 1 — Parse Arguments

Split `$ARGUMENTS` on whitespace:
- **Token 1** = output `.cpp` filename (required)
- **Token 2** = example input filename to analyze (required)
- **Token 3** = coordinate specifier (optional)

Valid specifiers: `p2`, `pd2`, `pdpd2`, `p3`, `pd3`, `pdpd3`, `none`

If token 1 or 2 is missing, stop and ask the user.
If token 3 is present and not in the valid list, stop and ask the user.

---

### Step 2 — Classify the Example Input

Read token 2 with the Read tool. Examine all lines, then pick one classification:

| Signal | Classification |
|---|---|
| All lines same length, only printable ASCII, no digit-only lines | `grid` |
| Lines contain only digits, spaces, minus signs | `int-tokens` |
| Any line contains a comma | `comma-separated` |
| Lines match a repeated template like `"key: val"` or `"p=%d,%d v=%d,%d"` | `structured-sscanf` |
| Blank lines divide the file into distinct groups of lines | `multi-group` |
| Lines contain a mix of words and integers | `space-separated` |
| Unrecognized or file unreadable | `stub` |

If the file cannot be read, use `stub` and warn the user.

---

### Step 3 — Determine Struct Sections

Look up the exact code in [references/struct-templates.md](references/struct-templates.md).
Paste each listed section in order when assembling the file.
**D must always be emitted before P when both are present** (P-2D-full / P-3D-full use D inline).

| Specifier | Sections to include (in order) |
|---|---|
| `p2` | `P-2D-simple`, `Comparators-2D`, `hash-P-2D` |
| `pd2` | `D-2D`, `P-2D-full`, `Comparators-2D`, `Free-Operators-2D`, `hash-P-2D`, `Direction-Constants-2D`, `hashing-turn-helpers` |
| `pdpd2` | All of `pd2` + `PD-2D`, `hash-PD-2D` |
| `p3` | `P-3D-simple`, `Comparators-3D`, `hash-P-3D` |
| `pd3` | `D-3D`, `P-3D-full`, `Comparators-3D`, `Free-Operators-3D`, `hash-P-3D`, `Direction-Constants-3D` |
| `pdpd3` | All of `pd3` + `PD-3D`, `hash-PD-3D` |
| absent / `none` | (nothing) |

---

### Step 4 — Assemble the Output File

Construct the file text in this exact order:

**1. Includes** (always emit these):
```cpp
#include <iostream>
#include <vector>
#include <string>
#include <cassert>
#include <array>
#include <unordered_set>
#include <unordered_map>
#include <algorithm>
#include <numeric>
```
Add extra includes based on classification:
- `comma-separated`, `space-separated` → also add `#include <sstream>`
- `int-tokens` with multiple values per line → also add `#include <sstream>`
- `structured-sscanf` → also add `#include <cstdio>`

**2. Type aliases** (always):
```cpp
using namespace std;
using ll   = long long;
using ull  = unsigned long long;
using uint = unsigned;
template <typename T>             using uset = unordered_set<T>;
template <typename K, typename V> using umap = unordered_map<K, V>;
```

**3. Coordinate structs** — paste the sections from `references/struct-templates.md`
identified in Step 3. Separate each section with one blank line.

**4. Parsing function** — paste the matching section from
[references/parsing-templates.md](references/parsing-templates.md):

| Classification | Section to paste |
|---|---|
| `grid` | **Grid** |
| `int-tokens` | **Integer-Tokens** |
| `comma-separated` | **Comma-Separated** |
| `space-separated` | **Space-Separated** |
| `structured-sscanf` | **Structured-sscanf** |
| `multi-group` | **Multi-Group** |
| `stub` | **Stub** |

**5. main()** (always):
```cpp
int main(){
  auto input = parse();
  // Part 1
  cout << 0 << endl;
  // Part 2
  cout << 0 << endl;
}
```

---

### Step 5 — Write and Report

Use the Write tool to create the file at the exact path from token 1.

Then report:
- Output file path written
- Structs included (or "none")
- Parsing pattern detected

---

## Additional Resources

- Coordinate struct code → [references/struct-templates.md](references/struct-templates.md)
- Parsing template code → [references/parsing-templates.md](references/parsing-templates.md)

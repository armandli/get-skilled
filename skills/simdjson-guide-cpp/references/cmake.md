# simdjson Build Integration

simdjson is **not header-only**. Either link the CMake target or compile `simdjson.cpp` from the
amalgamation into your build. Options and targets below were read from the v5.3.0 `CMakeLists.txt`.

## Contents

1. [FetchContent](#1-fetchcontent)
2. [find_package](#2-find_package)
3. [Amalgamation](#3-amalgamation)
4. [Exported targets](#4-exported-targets)
5. [CMake options](#5-cmake-options)
6. [Compiler and flags](#6-compiler-and-flags)
7. [Runtime kernel selection](#7-runtime-kernel-selection)
8. [Troubleshooting](#8-troubleshooting)

## 1. FetchContent

```cmake
cmake_minimum_required(VERSION 3.14)
include(FetchContent)

set(SIMDJSON_BUILD_STATIC_LIB ON CACHE INTERNAL "")   # options go BEFORE MakeAvailable
FetchContent_Declare(
  simdjson
  GIT_REPOSITORY https://github.com/simdjson/simdjson.git
  GIT_TAG        v5.3.0
  GIT_SHALLOW    TRUE
)
FetchContent_MakeAvailable(simdjson)

target_link_libraries(my_app PRIVATE simdjson::simdjson)
```

If the project already declares simdjson in its top-level `CMakeLists.txt`, reuse that declaration
rather than adding a second one.

## 2. find_package

```cmake
find_package(simdjson CONFIG REQUIRED)
target_link_libraries(my_app PRIVATE simdjson::simdjson)
```

Sources: vcpkg (`vcpkg install simdjson`), Conan, Homebrew (`brew install simdjson`), and most Linux
distributions. Distro packages often lag several major versions — check the version before relying
on builder or 5.x APIs.

## 3. Amalgamation

Copy `singleheader/simdjson.h` and `singleheader/simdjson.cpp` from the release into the tree:

```cmake
add_executable(my_app main.cpp third_party/simdjson/simdjson.cpp)
target_include_directories(my_app PRIVATE third_party/simdjson)
```

```bash
c++ -std=c++20 -O3 -DNDEBUG main.cpp simdjson.cpp -o my_app
```

## 4. Exported targets

| Target | Meaning |
|--------|---------|
| `simdjson::simdjson` | Primary library (alias of `simdjson`; shared or static per `BUILD_SHARED_LIBS`) |
| `simdjson::simdjson_static` | Extra static library, present when `SIMDJSON_BUILD_STATIC_LIB=ON` |

Prefer the namespaced name: a typo in it is a configure error, while a typo in a bare name is
silently treated as a linker flag.

## 5. CMake options

| Option | Default | Purpose |
|--------|---------|---------|
| `BUILD_SHARED_LIBS` | OFF | Build simdjson as a shared library |
| `SIMDJSON_BUILD_STATIC_LIB` | OFF | Also build `simdjson_static` |
| `SIMDJSON_EXCEPTIONS` | ON | OFF defines `SIMDJSON_EXCEPTIONS=0` publicly: error-code API only |
| `SIMDJSON_DEVELOPMENT_CHECKS` | OFF | Force the expensive misuse checks on (they are already automatic in unoptimized builds without `NDEBUG`) |
| `SIMDJSON_ENABLE_NAN_INF` | OFF | Accept `NaN` / `Infinity` literals (non-standard) |
| `SIMDJSON_ALLOW_TRAILING_COMMAS` | OFF | Accept `[1,2,]` / `{"a":1,}` in On-Demand; DOM stays strict |
| `SIMDJSON_MINUS_ZERO_AS_FLOAT` | OFF | Treat `-0` as a floating-point value |
| `SIMDJSON_STATIC_REFLECTION_MODE` | AUTO | C++26 reflection: `AUTO` (use if the compiler supports it), `ON` (adds `-std=c++26 -freflection`), `OFF`. Replaces the deprecated boolean `SIMDJSON_STATIC_REFLECTION`. |
| `SIMDJSON_ENABLE_THREADS` | ON | Thread support for `iterate_many`/`parse_many` background parsing |
| `SIMDJSON_DISABLE_DEPRECATED_API` | OFF | Make deprecated APIs a compile error |
| `SIMDJSON_ENABLE_MEMORY_FILE_MAPPING_ON_WINDOWS` | OFF | `padded_memory_map` on Windows |
| `SIMDJSON_DEVELOPER_MODE` | OFF | simdjson's own tests/benchmarks; leave OFF as a subproject |
| `SIMDJSON_AVX512_ALLOWED` | ON | Developer-mode option; as a consumer define the macro `SIMDJSON_AVX512_ALLOWED=0` to skip AVX-512 kernels |

Most of these are also plain macros: defining e.g. `SIMDJSON_ALLOW_TRAILING_COMMAS 1` before
`#include "simdjson.h"` works with the amalgamation. Define them identically in every TU.

## 6. Compiler and flags

- **Language standard**: C++11 minimum. C++17 for `padded_input` and structured bindings; C++20
  (concepts) for the builder, `tag_invoke` and template keys; C++26 for reflection.
- **Release**: define `NDEBUG` and optimize (`-O2`/`-O3`, `/O2` on MSVC). Without `NDEBUG` in an
  unoptimized build, development checks switch on automatically.
- **Never `-march=native`** on code shipped to other machines. simdjson dispatches to the best SIMD
  kernel at runtime; `-march=native` defeats that and can crash older CPUs.
- **Identical flags across TUs.** On-Demand types are header-inlined into every TU. TUs compiled with
  different `-O`, `-std`, or `NDEBUG` emit different inline copies and the linker keeps one
  arbitrarily — an ODR violation. See troubleshooting.

## 7. Runtime kernel selection

```cpp
#include <iostream>
#include "simdjson.h"
int main() {
  std::cout << "simdjson " << SIMDJSON_VERSION << " kernel: "
            << simdjson::get_active_implementation()->name() << "\n";   // e.g. haswell, arm64
}
```

Running this proves the build links and dispatches. To force a kernel (benchmarking, reproducing a
CPU-specific bug):

```cpp
simdjson::get_active_implementation() = simdjson::get_available_implementations()["fallback"];
```

## 8. Troubleshooting

| Symptom | Cause and fix |
|---------|---------------|
| `undefined reference to simdjson::...` | Not linked. Add `simdjson::simdjson` to `target_link_libraries`, or add `simdjson.cpp` to the sources. |
| `simdjson.h: No such file or directory` | `FetchContent_MakeAvailable` missing, or include paths added by hand — link the target instead. |
| `simdjson::builder` / `to_json` not found | Pinned tag predates the builder (v4). Bump `GIT_TAG`. |
| `to_json_string(obj)`, `extract_from`, `sb << obj` do not compile | Reflection-only. Use `tag_invoke` + `to_json(obj, out)`; see [serialization.md](serialization.md). |
| `Illegal instruction` at runtime | Built with `-march=native` on a different machine. |
| Field lookups return wrong values, and the behaviour changes with link order or build type | **Mixed compile flags across TUs** (ODR violation, §6). Build every TU that includes `simdjson.h` with one CMake configuration. Bites hardest when an ad-hoc `g++` command links a CMake-built archive. |
| Garbage values or `UTF8_ERROR` on valid JSON | Input not padded. Use `padded_string` / `padded_input`. |
| FetchContent re-clones every configure | Use `GIT_SHALLOW TRUE` and an immutable tag. |

---
name: cpp-cookiecutter
description: Sets up a standard C++ project repo structure with src (C++ source), test
  (GTest unit tests), and bin (scripts) directories, plus root CMakeLists.txt,
  src/CMakeLists.txt, and test/CMakeLists.txt with FetchContent GTest integration.
  Use when the user asks to "set up cpp project structure", "scaffold a cpp project",
  "initialize a c++ repo", or "run cpp-cookiecutter". Do NOT use for formatting,
  refactoring, or building existing C++ code.
argument-hint: "<project_name>"
disable-model-invocation: true
---

## Step 1 — Parse Arguments

Read `$ARGUMENTS` and extract `project_name` (the first word/token).

- If `$ARGUMENTS` is empty or missing, stop and ask the user: "Please provide a project name, e.g. `/cpp-cookiecutter myproject`."

---

## Step 2 — Verify Working Directory

Run `pwd` and `git rev-parse --show-toplevel 2>/dev/null`.

- If the git root differs from `pwd`, warn the user and stop. All paths must be relative to the repo root.

---

## Step 3 — Create Directories

Run:
```
mkdir -p src test bin
```

All three directories are created with `-p` (no error if already present).

---

## Step 4 — Create `CMakeLists.txt` (root)

Use Glob to check whether `CMakeLists.txt` already exists.

Only if it does not exist, use the Write tool to create `CMakeLists.txt` with this exact content, replacing `<project_name>` with the value from Step 1:

```cmake
cmake_minimum_required(VERSION 3.14)
project(<project_name>)
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED True)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
enable_testing()
add_subdirectory(src)
add_subdirectory(test)
```

---

## Step 5 — Create `src/CMakeLists.txt`

Use Glob to check whether `src/CMakeLists.txt` already exists.

Only if it does not exist, use the Write tool to create `src/CMakeLists.txt` with this exact content, replacing `<project_name>` with the value from Step 1:

```cmake
# add_library(<project_name> STATIC
#   <project_name>.cpp
# )
# target_include_directories(<project_name> PUBLIC ${CMAKE_SOURCE_DIR}/src)
```

---

## Step 6 — Create `test/CMakeLists.txt`

Use Glob to check whether `test/CMakeLists.txt` already exists.

Only if it does not exist, use the Write tool to create `test/CMakeLists.txt` with this exact content, replacing `<project_name>` with the value from Step 1:

```cmake
include(FetchContent)
FetchContent_Declare(
  googletest
  URL https://github.com/google/googletest/archive/refs/tags/v1.14.0.zip
)
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(googletest)

# add_executable(<project_name>_test <project_name>_test.cpp)
# target_link_libraries(<project_name>_test GTest::gtest_main)
# add_test(NAME <project_name>_test COMMAND <project_name>_test)
```

---

## Step 7 — Create `src/<project_name>.cpp`

Use Glob to check whether `src/<project_name>.cpp` already exists (substitute the actual project name).

Only if it does not exist, use the Write tool to create `src/<project_name>.cpp` with this exact content:

```cpp
// <project_name> source
```

---

## Step 8 — Create `test/<project_name>_test.cpp`

Use Glob to check whether `test/<project_name>_test.cpp` already exists (substitute the actual project name).

Only if it does not exist, use the Write tool to create `test/<project_name>_test.cpp` with this exact content, replacing `<project_name>` with the value from Step 1:

```cpp
#include <gtest/gtest.h>
TEST(<project_name>, Placeholder) { EXPECT_TRUE(true); }
```

---

## Step 9 — Report

Print a summary listing each item and whether it was created or skipped (already exists):

- `src/` — created (always, idempotent with `-p`)
- `test/` — created (always, idempotent with `-p`)
- `bin/` — created (always, idempotent with `-p`)
- `CMakeLists.txt`: created or skipped (already exists)
- `src/CMakeLists.txt`: created or skipped (already exists)
- `test/CMakeLists.txt`: created or skipped (already exists)
- `src/<project_name>.cpp`: created or skipped (already exists)
- `test/<project_name>_test.cpp`: created or skipped (already exists)

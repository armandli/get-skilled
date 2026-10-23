---
name: python-cookiecutter
description: Sets up a standard Python package development repo structure with bin,
  etc, notebooks, source (Python source), src (C++ source), and test directories,
  plus a templated setup.py and pyproject.toml for local dev and pybind11 C++ bindings.
  Use when the user asks to "set up python project structure", "scaffold a python
  package", "initialize python repo structure", or "run python-cookiecutter". Do NOT
  use for installing packages, running tests, or modifying existing project code.
argument-hint: "<package_name>"
disable-model-invocation: true
---

## Step 1 — Parse Arguments

Read `$ARGUMENTS` and extract `package_name` (the first word/token).

- If `$ARGUMENTS` is empty or missing, stop and ask the user: "Please provide a package name, e.g. `/python-cookiecutter myproject`."

---

## Step 2 — Verify Working Directory

Run `pwd` and `git rev-parse --show-toplevel 2>/dev/null`.

- If the git root differs from `pwd`, warn the user and stop. All paths must be relative to the repo root.

---

## Step 3 — Create Directories

Run:
```
mkdir -p bin etc notebooks source src test
```

All six directories are created with `-p` (no error if already present).

---

## Step 4 — Create `source/__init__.py`

Use Glob to check whether `source/__init__.py` already exists.

Only if it does not exist, use the Write tool to create `source/__init__.py` with empty content (just a newline).

---

## Step 5 — Create `setup.py`

Use Glob to check whether `setup.py` already exists.

Only if it does not exist, use the Write tool to create `setup.py` with this exact content, replacing `<package_name>` with the value from Step 1:

```python
from glob import glob
from setuptools import setup, find_packages
from pybind11.setup_helpers import Pybind11Extension, build_ext, ParallelCompile, naive_recompile

ParallelCompile("NPY_NUM_BUILD_JOBS", needs_recompile=naive_recompile).install()

__version__ = '0.0.1'

ext_modules = [
    Pybind11Extension(
        "cppext",
        sorted(glob("src/*.cpp")) + sorted(glob("src/*.cc")),
        cxx_std=17,
    ),
]

setup(
  name='<package_name>',
  version=__version__,
  description='',
  author='',
  author_email='',
  url='',
  packages=find_packages(exclude=['']),
  package_data={},
  data_files={},
  install_requires=[
      'pybind11',
      'marimo',
      'typer',
      'polars',
      'altair',
      'tqdm',
      'anywidget',
  ],
  entry_points={
    'console_scripts': []
  },
  scripts=[],
  cmdclass={"build_ext": build_ext},
  ext_modules=ext_modules,
  zip_safe=False,
)
```

Substitute the literal string `<package_name>` in `name='<package_name>'` with the actual package name from Step 1.

---

## Step 6 — Create `pyproject.toml`

Use Glob to check whether `pyproject.toml` already exists.

Only if it does not exist, use the Write tool to create `pyproject.toml` with this exact content:

```toml
[build-system]
requires = ["setuptools>=42", "pybind11~=2.6.1"]
build-backend = "setuptools.build_meta"
```

---

## Step 7 — Report

Print a summary listing:
- Directories created (all six are always created idempotently with `-p`)
- `source/__init__.py`: created or skipped (already exists)
- `setup.py`: created or skipped (already exists)
- `pyproject.toml`: created or skipped (already exists)

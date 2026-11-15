#!/usr/bin/env bash
# Push skills from this repo into other repos' .claude/skills/ that already have them.
#
# Scans a root directory (default: $HOME) for <repo>/.claude/skills/<name>/ dirs and,
# for every <name> that also exists under ./skills/, copies over changed/new files.
# Dry run by default; pass -a to actually copy.

set -euo pipefail

# Resolve symlinks (e.g. ~/bin/sync-skills.sh -> <repo>/bin/sync-skills.sh) so the
# repo is found no matter where the script is invoked from.
script="${BASH_SOURCE[0]}"
while [[ -L "$script" ]]; do
  link="$(readlink "$script")"
  [[ "$link" == /* ]] || link="$(dirname "$script")/$link"
  script="$link"
done
# This script lives in <repo>/bin/, so the repo root is one level up.
SRC_ROOT="$(cd "$(dirname "$script")/.." && pwd -P)"
SRC_SKILLS="$SRC_ROOT/skills"

SCAN_ROOT="$HOME"
MAX_DEPTH=2
APPLY=0
DELETE=0
FORCE=0
VERBOSE=0
ONLY_SKILLS=()

usage() {
  cat <<EOF
Usage: $(basename "$0") [options] [skill ...]

Copy skills from $SRC_SKILLS into any <repo>/.claude/skills/<skill>/
found under the scan root, but only where that skill already exists.

Options:
  -a, --apply        Actually copy files (default is a dry run)
  -r, --root DIR     Directory to scan for repos (default: \$HOME)
  -d, --depth N      How many levels below the root repos can be (default: $MAX_DEPTH;
                     1 means <root>/<repo>/.claude/skills)
  -D, --delete       Also delete files in the target that no longer exist here
  -f, --force        Overwrite targets even when they look locally edited (drift)
  -v, --verbose      Show unified diffs for changed files
  -h, --help         Show this help

Positional skill names limit the sync to those skills.

A target is flagged as DRIFT when one of its differing files is newer than
the copy here, meaning it was probably edited in place. Drifted targets are
skipped on --apply unless --force is given; fold those edits back first.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -a|--apply)   APPLY=1 ;;
    -r|--root)    SCAN_ROOT="$2"; shift ;;
    -d|--depth)   MAX_DEPTH="$2"; shift ;;
    -D|--delete)  DELETE=1 ;;
    -f|--force)   FORCE=1 ;;
    -v|--verbose) VERBOSE=1 ;;
    -h|--help)    usage; exit 0 ;;
    -*)           echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
    *)            ONLY_SKILLS+=("$1") ;;
  esac
  shift
done

if [[ -t 1 ]]; then
  C_RED=$'\e[31m'; C_GRN=$'\e[32m'; C_YEL=$'\e[33m'; C_DIM=$'\e[2m'; C_BLD=$'\e[1m'; C_OFF=$'\e[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_DIM=""; C_BLD=""; C_OFF=""
fi

wanted() {
  local name="$1" s
  [[ ${#ONLY_SKILLS[@]} -eq 0 ]] && return 0
  for s in "${ONLY_SKILLS[@]}"; do [[ "$s" == "$name" ]] && return 0; done
  return 1
}

# Relative file list of a skill dir, ignoring macOS junk.
list_files() {
  (cd "$1" && find . -type f ! -name .DS_Store | sed 's|^\./||' | sort)
}

n_synced=0; n_updated=0; n_drift=0; n_pending=0; n_dirs=0

# Locate every .claude/skills dir under the scan root, skipping heavy/irrelevant trees.
while IFS= read -r target_skills; do
  target_skills="$(cd "$target_skills" && pwd -P)"
  # Never sync into ourselves.
  [[ "$target_skills" == "$SRC_ROOT/.claude/skills" ]] && continue
  n_dirs=$((n_dirs + 1))
  repo="${target_skills%/.claude/skills}"

  for target in "$target_skills"/*/; do
    target="${target%/}"
    name="$(basename "$target")"
    src="$SRC_SKILLS/$name"
    [[ -d "$src" ]] || continue
    wanted "$name" || continue
    # A symlinked skill already tracks its source.
    [[ -L "$target" ]] && continue

    changed=(); added=(); extra=(); drift=0
    while IFS= read -r rel; do
      if [[ ! -e "$target/$rel" ]]; then
        added+=("$rel")
      elif ! cmp -s "$src/$rel" "$target/$rel"; then
        changed+=("$rel")
        [[ "$target/$rel" -nt "$src/$rel" ]] && drift=1
      fi
    done < <(list_files "$src")
    while IFS= read -r rel; do
      [[ -e "$src/$rel" ]] || extra+=("$rel")
    done < <(list_files "$target")

    if [[ ${#changed[@]} -eq 0 && ${#added[@]} -eq 0 && ( $DELETE -eq 0 || ${#extra[@]} -eq 0 ) ]]; then
      n_synced=$((n_synced + 1))
      continue
    fi

    label="${repo/#$HOME/~} :: $name"
    if [[ $drift -eq 1 ]]; then
      echo "${C_BLD}${C_RED}[DRIFT]${C_OFF} ${C_BLD}$label${C_OFF}"
    else
      echo "${C_BLD}${C_YEL}[UPDATE]${C_OFF} ${C_BLD}$label${C_OFF}"
    fi
    for f in ${changed[@]+"${changed[@]}"}; do
      if [[ "$target/$f" -nt "$src/$f" ]]; then
        echo "  ${C_RED}M $f (target is newer)${C_OFF}"
      else
        echo "  ${C_YEL}M${C_OFF} $f"
      fi
      if [[ $VERBOSE -eq 1 ]]; then
        diff -u "$target/$f" "$src/$f" | sed 's/^/      /' || true
      fi
    done
    for f in ${added[@]+"${added[@]}"}; do echo "  ${C_GRN}A${C_OFF} $f"; done
    for f in ${extra[@]+"${extra[@]}"}; do
      if [[ $DELETE -eq 1 ]]; then
        echo "  ${C_RED}D${C_OFF} $f"
      else
        echo "  ${C_DIM}? $f (only in target, kept)${C_OFF}"
      fi
    done

    if [[ $drift -eq 1 && $FORCE -eq 0 ]]; then
      n_drift=$((n_drift + 1))
      [[ $APPLY -eq 1 ]] && echo "  ${C_DIM}skipped: target has newer edits (use --force to overwrite)${C_OFF}"
      continue
    fi

    if [[ $APPLY -eq 0 ]]; then
      n_pending=$((n_pending + 1))
      continue
    fi

    for f in ${changed[@]+"${changed[@]}"} ${added[@]+"${added[@]}"}; do
      mkdir -p "$(dirname "$target/$f")"
      # -p keeps the source mtime so the target isn't mistaken for drift next run.
      cp -p "$src/$f" "$target/$f"
    done
    if [[ $DELETE -eq 1 ]]; then
      for f in ${extra[@]+"${extra[@]}"}; do rm -f "$target/$f"; done
      find "$target" -type d -empty -delete
    fi
    n_updated=$((n_updated + 1))
    echo "  ${C_GRN}synced${C_OFF}"
  done
done < <(
  # Repo depth N puts .claude/skills at find depth N+2.
  find "$SCAN_ROOT" -maxdepth "$((MAX_DEPTH + 2))" \
    \( -name node_modules -o -name Library -o -name .Trash -o -name .git -o -name .venv \) -prune \
    -o -type d -path '*/.claude/skills' -print 2>/dev/null
)

if [[ $n_dirs -eq 0 ]]; then
  echo "${C_YEL}No .claude/skills dirs found under $SCAN_ROOT within depth $MAX_DEPTH.${C_OFF}" >&2
fi
echo
echo "${C_BLD}Summary${C_OFF}: $n_synced in sync, $n_updated updated, $n_pending pending, $n_drift drifted"
if [[ $APPLY -eq 0 && $n_pending -gt 0 ]]; then
  echo "Dry run. Re-run with --apply to copy changes."
fi

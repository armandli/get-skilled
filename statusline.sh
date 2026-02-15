#!/usr/bin/env bash

# Claude Code status line: context usage bar + git status
# Reads JSON from stdin, outputs a single-line status

CACHE_FILE="/tmp/claude-statusline-git-cache"
CACHE_TTL=5

# Read stdin JSON
INPUT=$(cat)

# --- Segment 1: Context Usage Bar ---
USED=$(printf '%s' "$INPUT" | jq -r '.context_window.used_percentage // 0' 2>/dev/null)
USED=${USED%.*}  # truncate to integer

FILLED=$((USED / 10))
EMPTY=$((10 - FILLED))

BAR=""
for ((i = 0; i < FILLED; i++)); do BAR+="▓"; done
for ((i = 0; i < EMPTY; i++)); do BAR+="░"; done

if [ "$USED" -le 50 ]; then
  COLOR="\033[32m"  # green
else
  COLOR="\033[31m"  # red
fi
RESET="\033[0m"

SEGMENT1="${COLOR}[${BAR}] ${USED}%${RESET}"

# --- Segment 2: Git Status ---
WORKDIR=$(printf '%s' "$INPUT" | jq -r '.workspace.current_dir // empty' 2>/dev/null)

if [ -z "$WORKDIR" ] || [ ! -d "$WORKDIR" ]; then
  printf '%b\n' "${SEGMENT1}"
  exit 0
fi

# Cache logic
NOW=$(date +%s)
CACHE_VALID=false
if [ -f "$CACHE_FILE" ]; then
  CACHE_AGE=$(( NOW - $(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0) ))
  CACHE_DIR=$(head -1 "$CACHE_FILE")
  if [ "$CACHE_AGE" -lt "$CACHE_TTL" ] && [ "$CACHE_DIR" = "$WORKDIR" ]; then
    CACHE_VALID=true
  fi
fi

if $CACHE_VALID; then
  GIT_SEGMENT=$(tail -n +2 "$CACHE_FILE")
else
  BRANCH=$(git -C "$WORKDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [ -z "$BRANCH" ]; then
    printf '%b\n' "${SEGMENT1}"
    exit 0
  fi

  PORCELAIN=$(git -C "$WORKDIR" status --porcelain 2>/dev/null)
  if [ -n "$PORCELAIN" ]; then
    MODIFIED=$(printf '%s\n' "$PORCELAIN" | grep -c '^ M\|^M \|^MM\|^AM\|^ D\|^D \|^R ')
    UNTRACKED=$(printf '%s\n' "$PORCELAIN" | grep -c '^??')
  else
    MODIFIED=0
    UNTRACKED=0
  fi

  AHEAD=0
  UPSTREAM=$(git -C "$WORKDIR" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null)
  if [ -n "$UPSTREAM" ]; then
    AHEAD=$(git -C "$WORKDIR" rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo 0)
  fi

  YELLOW="\033[33m"
  GREEN="\033[32m"

  INDICATORS=""
  if [ "$MODIFIED" -gt 0 ]; then INDICATORS+=" ${YELLOW}M:${MODIFIED}${RESET}"; fi
  if [ "$UNTRACKED" -gt 0 ]; then INDICATORS+=" ${YELLOW}?:${UNTRACKED}${RESET}"; fi
  if [ "$AHEAD" -gt 0 ]; then INDICATORS+=" ${YELLOW}↑:${AHEAD}${RESET}"; fi

  if [ -z "$INDICATORS" ]; then
    GIT_SEGMENT="${GREEN}${BRANCH} ✓ clean${RESET}"
  else
    GIT_SEGMENT="${BRANCH}${INDICATORS}"
  fi

  # Write cache
  printf '%s\n%s' "$WORKDIR" "$GIT_SEGMENT" > "$CACHE_FILE"
fi

printf '%b  |  %b\n' "${SEGMENT1}" "${GIT_SEGMENT}"

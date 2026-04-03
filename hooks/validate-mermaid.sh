#!/usr/bin/env bash
# PostToolUse hook: validates .mmd files with mmdc after Write or Edit.
# Exit 2 sends stderr as feedback to Claude so it can fix syntax errors.

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only act on .mmd files
[[ "$FILE" == *.mmd ]] || exit 0

# Skip if mmdc not installed
if ! command -v mmdc &>/dev/null; then
  exit 0
fi

TMPOUT=$(mktemp /tmp/mmd_validate_XXXXXX.svg)
if ! ERRMSG=$(mmdc -i "$FILE" -o "$TMPOUT" 2>&1); then
  rm -f "$TMPOUT"
  echo "Mermaid syntax error in $FILE:" >&2
  echo "$ERRMSG" >&2
  exit 2
fi

rm -f "$TMPOUT"
exit 0

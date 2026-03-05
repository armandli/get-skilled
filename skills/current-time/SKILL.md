---
name: current-time
description: >
  Retrieve the current date and time in the configured timezone. Automatically
  invoked whenever any skill or task requires the current date, time, or
  timestamp. Use when user asks what time it is, needs today's date, needs a
  timestamp, or when logging/journaling skills need date context. Triggers on:
  "current time", "what time", "what date", "now", or when another skill
  imports this for date/time context. With an argument, validates and sets the
  default timezone.
argument-hint: "[timezone-name]"
allowed-tools: Bash
---

Execute the current-time script to get or configure the current date/time.

**When `$ARGUMENTS` is non-empty** (user provided a timezone name):
- Run: `bash ${PWD}/.claude/skills/current-time/scripts/get-time.sh "$ARGUMENTS"`
- Display output (timezone confirmed + current time), or show error if invalid

**When `$ARGUMENTS` is empty** (just getting current time):
- Run: `bash ${PWD}/.claude/skills/current-time/scripts/get-time.sh`
- Display current date/time in the stored timezone (UTC if none configured)

Timezone preference is persisted at `~/.claude/current-timezone`.

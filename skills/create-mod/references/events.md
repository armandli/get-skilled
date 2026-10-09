# Claude Code Mod Events — Complete Reference

All events a mod can handle, organized by category. For each event `e.field` denotes the event's input fields. The return column uses shorthand: `next(e)` passes unchanged; `next({...e, field})` passes a modified copy; an object `{ key: value }` answers without calling next.

## Hook Signature

```javascript
on('event.name', [matcher], async ($, e, next) => {
  // observe: return next(e)
  // rewrite: return next({ ...e, field: newValue })
  // answer:  return { resultField: value }  // don't call next
})
```

`turn.step` and `process.spawn` hooks are **async generators** — use `yield*` instead of `return next(e)`:
```javascript
on('turn.step', async function* ($, e, next) {
  const result = yield* next(e)   // streams response, evaluates to finished result
  return result
})
```

---

## Tool Events

### `tool.call`
Fires before each tool runs (including MCP tools, subagent tools).

| Field | Type | Description |
|---|---|---|
| `e.tool` | string | Tool name (e.g., `'Bash'`, `'Read'`, `'mcp__github__list_issues'`) |
| `e.command` | string | Bash: the shell command |
| `e.file_path` | string | Read/Edit/Write: the file path |
| `e.input` | object | All tool arguments |

Returns: `next(e)` | `{ deny: reason }` | `{ result: text }`

```javascript
// Guard risky Bash commands
on('tool.call', { tool: 'Bash' }, async ($, e, next) => {
  if (/git push.*--force/.test(e.command)) {
    return { deny: 'Force pushes blocked. Push to a branch.' }
  }
  return next(e)
})

// Log after tool runs (await next first)
on('tool.call', async ($, e, next) => {
  const result = await next(e)
  if (!result.deny && !result.isError) $.ui.log(e.tool + ' finished')
  return result
})

// Ask user before risky command
on('tool.call', { tool: 'Bash' }, async ($, e, next) => {
  if (!/rm -rf/.test(e.command)) return next(e)
  let answer = 'Refuse'
  try {
    answer = await $.ui.ask('Run: ' + e.command, ['Run it', 'Refuse'])
  } catch {}
  if (answer !== 'Run it') return { deny: 'User declined.' }
  return next(e)
})
```

### `tool.check`
Fires after `tool.call` and `PreToolUse` settings hooks have run. `next(e)` resolves to the permission decision.

| Field | Type | Description |
|---|---|---|
| `e.tool` | string | Tool name |
| `e.input` | object | Tool arguments |

Returns: `{ decision: 'allow' | 'ask' | 'deny', reason?: string }`

```javascript
// Block git push on main branch
on('tool.check', { tool: 'Bash' }, async ($, e, next) => {
  const decided = await next(e)
  if (!e.input.command.includes('git push')) return decided
  const branch = await $.process.run(['git', 'branch', '--show-current'])
  if (branch.stdout.trim() !== 'main') return decided
  return { decision: 'deny', reason: 'Push from a branch, not main' }
})
```

### `tool.describe`
Fires once per tool when its description is first sent to Claude.

Returns: `{ description: string }` optionally with `isDeferred: true` (tool search) or `false` (load upfront).

---

## Prompt and System Prompt Events

### `prompt.submit`
Fires before each user prompt is sent to start a turn.

| Field | Type | Description |
|---|---|---|
| `e.text` | string | The prompt text |
| `e.context` | string[] | Extra context lines added by previous hooks |

Returns: `next({...e, text: newText})` | `next({...e, context: [...e.context, extra]})` | `{ drop: reason }`

```javascript
// Add git branch when PR is mentioned
on('prompt.submit', async ($, e, next) => {
  if (!/\bPR\b|pull request/i.test(e.text)) return next(e)
  const git = await $.process.run(['git', 'branch', '--show-current'])
  if (git.exitCode !== 0) return next(e)
  return next({ ...e, context: [...(e.context ?? []), 'Current branch: ' + git.stdout.trim()] })
})
```

### `prompt.compose`
Fires when Claude Code renders a system prompt.

Returns: `{ sections: Array<{ id, text, scope }> }` — reorder or replace sections.

### `prompt.section`
Fires once for each named section of the system prompt.

| Field | Type | Description |
|---|---|---|
| `e.name` | string | Section id |
| `e.text` | string | Section text |

Returns: `{ text: string }` | `{ text: null }` (omit section)

### `prompt.context`
Fires once per conversation for the context sent with the first message.

Returns: `{ blocks: [...] }`

### `prompt.fill` / `prompt.suggest`
Fires when text is placed into the prompt box as a draft or dim suggestion.

Returns: `next({...e, text: newText})`

### `prompt.edit`
Fires on each keystroke as the user edits the prompt box. **Time limit: 50ms.**

Returns: `next(e)` (observe only in most cases due to time limit)

### `prompt.attachment`
Fires when Claude Code adds a reminder or attachment message.

| Field | Type | Description |
|---|---|---|
| `e.type` | string | Kind of attachment |
| `e.detail` | object | Facts the message was built from |

Returns: `{ text: string }` | `{ text: null }` (omit it)

### `skill.prompt`
Fires when a skill's text is being expanded for Claude.

Returns: `{ text: string }`

### `attribution.text`
Fires when commit/PR attribution text is composed.

Returns: `{ text: string }`

---

## Turn Events

### `turn.start`
Fires when a turn begins. `e.turnId` identifies the turn.

Returns: `next(e)`

### `turn.step` (async generator)
Fires for each model request within a turn. A turn with tool calls has several steps.

| Field | Type | Description |
|---|---|---|
| `e.turnId` | string | Turn identifier |
| `e.agentId` | string? | Set for subagent requests |
| `e.model` | string | Model being used |

Returns: `yield* next(e)` | `next({...e, model: 'different-model'})` | `next({...e, effort: level})`

```javascript
// Log cache usage per request
on('turn.step', async function* ($, e, next) {
  const result = yield* next(e)
  if (result.usage) {
    $.ui.log('cache read ' + result.usage.cache_read_input_tokens +
             ' · wrote ' + result.usage.cache_creation_input_tokens)
  }
  return result
})
```

### `turn.complete`
Fires when a turn ends (including user-interrupted turns where `e.isAborted` is true).

| Field | Type | Description |
|---|---|---|
| `e.turnId` | string | Turn identifier |
| `e.answer` | string | Claude's final text |
| `e.durationMs` | number | How long the turn took |
| `e.usage` | object | Token totals for the turn |
| `e.isAborted` | boolean | True if user interrupted |
| `e.agentId` | string? | Set for subagent turns |

Returns: `next(e)` | `{ text: string }` (shows a line under the answer)

```javascript
on('turn.complete', async ($, e, next) => {
  return { text: 'Done in ' + Math.round(e.durationMs / 1000) + 's' }
})
```

---

## Session Events

### `session.start`
Fires before the first prompt, and again each time this mod reloads. Does NOT fire after `/clear`, `/resume`, or `/branch`.

**Register commands, tools, and load saved state here.**

```javascript
on('session.start', async ($, e, next) => {
  await $.command.register({ name: 'tally', description: 'Show count' })
  const saved = await $.store.get('count')
  if (typeof saved === 'number') count = saved
  return next(e)
})
```

### `session.end`
Fires when the session ends, or when `/clear`, `/resume`, or `/branch` runs.

| Field | Type | Description |
|---|---|---|
| `e.reason` | string | `'clear'`, `'resume'`, `'logout'`, `'prompt_input_exit'`, `'other'`. `/branch` reports `'resume'`. |

### `session.compact`
Fires before the conversation is compacted.

Returns: `{ skip: reason }` to prevent compaction, or `next(e)`.

### `session.receive`
Fires when a message arrives from another session or agent.

| Field | Type | Description |
|---|---|---|
| `e.text` | string | Message text |
| `e.origin.kind` | string | `'peer'`, `'task-notification'`, `'scheduled-trigger'`, etc. |

Returns: `{ consumed: reason }` to keep it from Claude, or `next(e)`.

### `session.send`
Fires when a message is about to leave this session.

Returns: `{ isDelivered: false, reason }` to block, or `next(e)`.

### `session.append`
Fires for each row stored in the conversation (prompt, response, tool result, notice).

Returns: `next({...e, message: newMessage})` to rewrite content.

### `session.measure`
Fires after each turn and when plan limits change. Useful for context window monitoring.

### `classic.SessionStart`
Fires at startup AND after `/clear`, `/resume`, `/branch`, and compaction. Use with filter `{ source: ['clear', 'resume', 'fork'] }` to reload `$.state` from `$.store` after resets.

```javascript
on('classic.SessionStart', { source: ['clear', 'resume', 'fork'] }, async ($, e, next) => {
  const saved = await $.store.get('myValue')
  // restore $.state from $.store
  return next(e)
})
```

---

## Command and Configuration Events

### `command.run`
Fires when a user runs a `/command`. Always use a matcher.

| Field | Type | Description |
|---|---|---|
| `e.command` | string | Command name (without `/`) |
| `e.args` | string | Text typed after command name, or `''` |

Returns: `{ text: string }` (printed in transcript, Claude reads it) | `{}` (no output) | `next(e)` (pass to other handlers)

```javascript
on('command.run', { command: 'standup' }, async ($, e) => {
  const days = e.args || '1'
  return { text: 'Summary for last ' + days + ' day(s)...' }
})
```

### `command.describe`
Fires once per command for the command list.

Returns: `{ description, argumentHint, isHidden }`

### `config.set`
Fires when a `/config` row is about to change.

Returns: `next({...e, value: newValue})` | `{ deny: reason }`

### `config.describe`
Fires once per `/config` row.

Returns: `{ label, description, isHidden }`

---

## Interface Events

### `ui.render`
Fires when a render site is about to be drawn. See [ui-and-drawing.md](ui-and-drawing.md) for full details.

| Field | Type | Description |
|---|---|---|
| `e.component` | string | Render site name: `'Pane'`, `'AbovePrompt'`, `'Spinner'`, etc. |
| `e.requestId` | string | For `Pane`: the `id` you opened it with |
| `e.props` | object | Site-specific props |
| `e.surface` | string | `'terminal'` or `'desktop'` |
| `e.viewport` | object | `{ columns, rows, isFullscreen }` |

Returns: element tree | `next(e)` (use Claude Code's own drawing)

### `ui.press` / `ui.input` / `ui.select`
Fires when a Button, Input, or Select drawn by your mod is used.

| Field | Type | Description |
|---|---|---|
| `e.element` | string | The control's `key` |

### `ui.close`
Fires when a pane is about to close.

| Field | Type | Description |
|---|---|---|
| `e.id` | string | Pane id |
| `e.origin.kind` | string | `'plugin'`, `'person'`, or `'unload'` |

### `ui.message`
Fires when a `Client` element posts data to its mod.

### `ui.fault`
Fires when a `Client` element fails (load, render, or run phase). Requires v2.1.289+.

| Field | Type | Description |
|---|---|---|
| `e.phase` | string | `'load'`, `'render'`, or `'run'` |
| `e.reason` | string | Error message |

---

## Agent and Subagent Events

### `agent.offer`
Fires when a subagent type is offered to Claude.

Returns: `{ isOffered: false }` to withhold it, or `next(e)`.

### `agent.spawn`
Fires when a subagent or agent-team teammate is about to start.

| Field | Type | Description |
|---|---|---|
| `e.isTeammate` | boolean | True for agent-team teammates |

Returns: `next({...e, model: 'different-model'})` | `{ deny: reason }`

---

## Mod Management Events

### `plugin.register`
Fires when a hooks module is about to load.

| Field | Type | Description |
|---|---|---|
| `e.uses` | object | Lists events, API calls, env vars, and state the mod uses (same as `claude plugin validate` output) |

Returns: `{ refuse: reason }` to block the mod, or `next(e)`.

### `engine.create`
Fires when the mods API is being built for a mod. Allows adding or withholding API namespaces.

---

## Settings Hook Events (`classic.*`)

Every settings hook event type is available as `classic.<EventName>`:

| Mod event | Settings hook equivalent |
|---|---|
| `classic.Stop` | `Stop` — Claude finishes responding |
| `classic.PostToolUse` | `PostToolUse` — after a tool runs |
| `classic.PreToolUse` | `PreToolUse` — before a tool runs |
| `classic.Notification` | `Notification` — Claude needs user input |
| `classic.SessionStart` | `SessionStart` — session starts, or after `/clear` etc. |

`e` has the same fields a settings hook receives on stdin, including `transcript_path`.

```javascript
on('classic.Stop', async ($, e, next) => {
  $.ui.log('Transcript at: ' + e.transcript_path)
  return next(e)
})
```

Use `'classic.*'` as a wildcard to match all settings hook events.

---

## mods API Events

Every mods API call is also an event: `fs.read`, `model.complete`, `ui.open`, etc. An earlier mod in the chain can intercept calls from later mods. This enables policy enforcement.

```javascript
// An org policy mod can block all file writes from user-installed mods
on('fs.write', async ($, e, next) => {
  if (next.origin.tier === 'user') {
    return { deny: 'File writes blocked by policy' }
  }
  return next(e)
})
```

---

## Telemetry Events

```javascript
// Must include the { to: 'collector' } filter — validation fails without it
on('telemetry.log', { to: 'collector' }, async ($, e, next) => {
  // e has the telemetry record
  return next(e)
})
```

`'*'` wildcard does NOT match telemetry events.

---

## Event Order

Mods form a middleware chain. Order for a tool call:
1. Managed `prependPlugins` mods (including `sec-default@builtin`)
2. User-installed mods
3. `appendPlugins` mods
4. Built-in Claude Code mods
5. Claude Code's own behavior

`PreToolUse` settings hooks from managed settings run **before** step 1.
`PreToolUse` hooks from user settings run **after** step 4, as part of Claude Code's behavior.

---
name: create-mod
description: Creates Claude Code mods — JavaScript/TypeScript event-handler plugins that run inside Claude Code to intercept tool calls, draw UI panes, add commands, guard prompts, and call models. Use when user says "create a mod", "make a mod", "build a mod", "write a mod", "create a plugin with hooks", or is editing register.js, hooks.json, plugin.json files. Covers file structure, all events, mods API, UI elements, state management, static analysis compliance rules, and the --plugin-dir dev loop. Do NOT use for MCP servers, settings hooks (settings.json), or skills (SKILL.md files).
argument-hint: "[mod-name] [description]"
---

# Claude Code Mod Creation

A mod is a plugin with JavaScript/TypeScript event handlers that run **inside** Claude Code. Unlike settings hooks (shell scripts), a mod can: draw UI panes and bands, intercept and rewrite any event, add slash commands and tools, call models for sub-tasks, and share state between hooks. Mods require Claude Code v2.1.287+.

## Required File Structure

```
my-mod/
├── .claude-plugin/
│   └── plugin.json      # Plugin manifest (required)
└── hooks/
    ├── hooks.json       # Points to hooks module (required)
    └── register.js      # Your code entry point (required)
```

### plugin.json
```json
{
  "name": "my-mod",
  "version": "0.1.0",
  "description": "What this mod does",
  "author": { "name": "Your Name" }
}
```
Name rules: lowercase, hyphens OK, max 64 chars, no `claude-` prefix (Anthropic reserved).

### hooks.json
```json
{
  "description": "My mod hooks module",
  "modules": ["./register.js"]
}
```

### register.js — Entry Point
```javascript
// Module-level shared state
let calls = 0

// Claude Code calls register() once when the mod loads
export function register(on) {
  on('session.start', async ($, e, next) => {
    await $.command.register({ name: 'tally', description: 'Show tool call count' })
    return next(e)
  })

  on('tool.call', async ($, e, next) => {
    calls += 1
    $.ui.invalidate('ui.render')
    return next(e)
  })

  on('command.run', { command: 'tally' }, async ($, e) => {
    return { text: 'Tool calls: ' + calls }
  })
}
```

## The Three Hook Behaviors

Every hook receives `($, e, next)`:
- `$` — mods API (all side effects go through this)
- `e` — event data (deeply frozen; copy with `{...e}` to modify)
- `next` — calls subsequent handlers and Claude Code's own behavior

### 1. Observe — watch, pass through unchanged
```javascript
on('tool.call', async ($, e, next) => {
  $.ui.log('Tool: ' + e.tool)    // dim transcript line
  return next(e)                  // pass unchanged
})
```

### 2. Rewrite — modify the event before it continues
```javascript
on('prompt.submit', async ($, e, next) => {
  return next({ ...e, text: e.text.trim() })  // trimmed copy
})
```

### 3. Answer — handle it yourself, bypass Claude Code
```javascript
on('tool.call', { tool: 'Bash' }, async ($, e, next) => {
  if (/rm -rf/.test(e.command)) {
    return { deny: 'Blocked. Use safer alternatives.' }  // no next() call
  }
  return next(e)
})
```

## Matchers (Event Filters)

Pass as the second argument to `on` to narrow which events trigger your hook:

```javascript
on('tool.call', { tool: 'Bash' }, hook)                  // exact string
on('tool.call', { tool: ['Edit', 'Write'] }, hook)        // any in array
on('tool.call', { tool: /^mcp__github__/ }, hook)         // regex
on('command.run', { command: 'tally' }, hook)
on('ui.render', { component: 'Spinner' }, hook)
on('classic.*', handler)                                   // wildcard: all settings-hook events
```

## CRITICAL: Static Analysis Rules

Violations of these rules cause **silent load failures** or validation errors.

**Event names must be string literals:**
```javascript
on('tool.call', handler)           // CORRECT
const ev = 'tool.call'
on(ev, handler)                    // WRONG — variable name fails
```

**mods API must use full dot-path — no destructuring or aliasing:**
```javascript
$.ui.log('hello')                  // CORRECT
$.fs.read('file.txt')              // CORRECT
const { log } = $.ui               // WRONG — "$.ui is used as a value"
const ui = $.ui                    // WRONG
$.ui['log']('hello')               // WRONG — computed property
```

**No dynamic imports:**
```javascript
import { atom } from 'claude-code'          // CORRECT
const m = await import('claude-code')       // WRONG
```

**Import only from plugin-relative paths or `claude-code`:**
```javascript
import { atom, read, update } from 'claude-code'   // CORRECT (only bare import allowed)
import helper from './utils.js'                     // CORRECT (relative)
import _ from 'lodash'                              // WRONG (external package)
```

**No duplicate event names without different matchers:**
```javascript
on('session.start', handlerA)
on('session.start', handlerB)       // WRONG — "registered twice without a matcher"
// Combine into one hook, or add distinct matchers
```

**Don't shadow `on` inside register:**
```javascript
export function register(on) {
  function helper(on) { ... }       // WRONG — '"on" is declared again'
}
```

**You can pass `$` to a top-level function (not a method or nested function):**
```javascript
async function loadData($) {
  return $.fs.read('data.json')     // CORRECT — top-level function
}
on('session.start', async ($, e, next) => {
  await loadData($)                 // CORRECT
  return next(e)
})
```

## Key Events Quick Reference

| Event | Fires when | Hook can return |
|---|---|---|
| `session.start` | Before first prompt, after each reload | `next(e)` |
| `tool.call` | Before each tool runs | `next(e)`, `{ deny: reason }`, `{ result }` |
| `tool.check` | After permission rules decide | `{ decision: 'allow'/'ask'/'deny' }` |
| `prompt.submit` | Before prompt sent to model | `next({...e, text})`, `next({...e, context})`, `{ drop: reason }` |
| `turn.start` | Turn begins | `next(e)` |
| `turn.step` | Each model request (async generator) | `yield* next(e)`, `next({...e, model})` |
| `turn.complete` | Turn ends | `next(e)`, `{ text }` (line under answer) |
| `command.run` | User types a `/command` | `{ text }`, `{}` (no output) |
| `ui.render` | Render site is being drawn | element tree or `next(e)` |
| `session.end` | Session ends or `/clear` | `next(e)` |
| `classic.Stop` | Claude finishes responding | same as settings Stop hook |

For the complete event catalog with all fields and return shapes, see [references/events.md](references/events.md).

## mods API Namespaces

| `$` namespace | Key methods | Purpose |
|---|---|---|
| `$.ui` | `log`, `toast`, `status`, `open`, `close`, `invalidate`, `ask`, `resolve` | UI, notifications, dialogs |
| `$.command` | `register`, `run`, `list` | Slash commands |
| `$.tool` | `register`, `call`, `check` | Tools for Claude |
| `$.model` | `complete`, `fork` | Sub-task model calls |
| `$.fs` | `read`, `write`, `list`, `exists`, `stat` | File system |
| `$.store` | `get`, `set`, `delete`, `keys` | Persistent cross-session storage (JSON, 4 MiB) |
| `$.state` | `get`, `set` (via `atom`/`read`/`update`) | Reactive session state, survives reloads |
| `$.clock` | `every`, `after`, `now`, `sleep` | Background timers |
| `$.http` | `fetch` | Network (resolves to `{ status, ok, text, headers }`) |
| `$.process` | `run`, `spawn` | Shell commands (no shell expansion; pass arg array) |
| `$.session` | `messages`, `cwd`, `usage`, `id`, `send` | Session info, inter-session messaging |
| `$.prompt` | `submit`, `fill`, `suggest` | Submit prompts programmatically |
| `$.env` | `get`, `set` | Environment variables |
| `$.settings` | `read` | Read settings files |
| `$.audio` | `play`, `speak` | Audio output |
| `$.plugin` | `name`, `root` | This plugin's name and directory path |

For full signatures and examples, see [references/api-methods.md](references/api-methods.md).

## State: Three Tiers

| Tier | Syntax | Survives reload? | Survives session end? |
|---|---|---|---|
| Module variable | `let count = 0` | No (resets to 0) | No |
| `$.state` atom | `atom(...)` + `read`/`update` | **Yes** | No |
| `$.store` | `$.store.get/set(key)` | Yes | **Yes** (persists to disk) |

Load `$.store` values in `session.start`. After `/clear`, `/resume`, or `/branch`, `$.state` resets — reload from `$.store` in a `classic.SessionStart` hook too.

## Drawing UI

Open a pane from a command or `session.start`, then draw in `ui.render`. For complete UI coverage (bands, elements, state, keyboard, raster grids), see [references/ui-and-drawing.md](references/ui-and-drawing.md).

```javascript
// Open pane
on('command.run', { command: 'show' }, async ($) => {
  await $.ui.open({ id: 'my-pane', title: 'My Pane', focus: true, closeOnEscape: true })
  return {}
})

// Draw in it
on('ui.render', { component: 'Pane' }, async ($, e, next) => {
  if (e.requestId !== 'my-pane') return next(e)
  const { Box, Text, Button } = $.ui.resolve(e)
  let count = 0
  const redraw = () => $.ui.invalidate('ui.render')
  return Box({
    flexDirection: 'row', columnGap: 2,
    children: [
      Button({ key: 'add', label: 'Add', onPress: () => { count++; redraw() } }),
      Text({ children: ['Count: ' + count] }),
    ],
  })
})
```

## Development Workflow

```bash
# 1. Load for one session with hot reload on save
claude --plugin-dir ./my-mod

# 2. Validate (no session needed) — checks manifest + static analysis
claude plugin validate ./my-mod

# 3. Run automated tests (no session, no network)
claude plugin test ./my-mod

# 4. Inside a session: reload after changes
/reload-plugins
```

TypeScript declarations for your exact Claude Code version are auto-written to `my-mod/.claude-plugin/types/` when using `--plugin-dir`. Check `claude-code/index.d.ts` there — it is the authoritative reference for your installed version.

**Add TypeScript support** (optional): rename `register.js` to `register.ts`, update `hooks.json` modules path. No build step needed — Claude Code loads `.ts` directly.

## Time Limits

| Context | Limit |
|---|---|
| Most hook own-execution time | 10 seconds (time inside `next()` or `$.` calls doesn't count) |
| `prompt.edit` hook | 50 milliseconds |
| `.catch` error handler | 1 second |
| `$.process.run` default | 30 seconds (max 10 minutes with `timeoutMs`) |
| `$.model.complete` default maxTokens | 1024 (max 64,000) |

## Error Handling on Hooks

```javascript
// Without .catch: a hook that fails BEFORE calling next() is skipped (tool runs anyway)
// With .catch: you control the fallback
on('tool.call', { tool: 'Bash' }, guardHook)
  .catch(async ($, e, next) => {
    // next.error.kind is 'throw' or 'timeout'
    return { deny: 'Guard failed (' + next.error.kind + '). Command blocked for safety.' }
  })
```

## Limits Reference

| Limit | Value |
|---|---|
| `$.fs.read`/`write` per file | 4 MiB |
| `$.store` total | 4 MiB JSON |
| `$.session.messages()` | Newest 4,096 entries |
| `$.model.complete` maxTokens | 1,024 default, 64,000 max |
| Text element string child | 10,000 characters |
| Pane/command/tool names | Letters, digits, `_`, `-`, max 64 chars |
| `$.ui.invalidate` rate | 10/sec (30/sec for visible terminal pane) |

## Complete Examples

See [references/examples.md](references/examples.md) for:
1. **first-mod** — full tool call counter with `/tally` command and spinner label
2. **Tool guard with dialog** — hold risky `rm -rf` commands, ask user to confirm
3. **Prompt context injector** — auto-add git branch when PR mentioned
4. **PR checks status bar** — background timer with `$.ui.status`
5. **Notes pane** — pane with `Input` field and list with delete buttons

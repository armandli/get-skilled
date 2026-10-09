# Claude Code mods API — Method Reference

The mods API is the `$` argument every hook receives. All side effects must go through `$` — the hooks module has no Node.js globals, no `setTimeout`/`setInterval`, no direct `fetch`, and no `fs`. Every method listed here is also an interceptable event (see events.md).

**Write every call in full: `$.namespace.method(...)`**. Destructuring or aliasing fails static analysis.

---

## `$.ui` — Interface and Notifications

### Draw and invalidate
```javascript
$.ui.invalidate('ui.render')        // ask Claude Code to run ui.render hooks again
                                    // throttled: 10/sec (30/sec for visible terminal pane)

$.ui.resolve(e)                     // returns the elements this surface supports
                                    // call inside a ui.render hook, pass the event e
                                    // destructure: const { Box, Text, Button } = $.ui.resolve(e)
```

### Pane management
```javascript
await $.ui.open({
  id: 'my-pane',           // required; your ui.render hook checks e.requestId === id
  title: 'My Pane',        // tab label when multiple panes are open
  focus: true,             // request keyboard focus (granted only when prompt is empty)
  closeOnEscape: true,     // Esc closes the pane
  holdToasts: true,        // hold toasts until pane closes
  rows: 20,                // height when pane is above prompt (default: 1/3 of space)
  columns: 60,             // width when pane is beside transcript
})
// Returns: { isPlaced: true } or { isPlaced: false, reason }
// A pane opened without user action only appears at 144+ columns (110 after first user open)

await $.ui.close({ id: 'my-pane' })

const panes = await $.ui.panes()    // list of open pane ids

await $.ui.focus({ id: 'my-pane' }) // give keyboard focus to pane

await $.ui.scroll({ id: 'my-pane', to: 'bottom' })  // scroll pane

await $.ui.blit({                   // repaint one Raster element without re-running ui.render
  requestId: 'my-pane',
  key: 'grid',
  columns: 3, rows: 2,
  cells: base64cells,
})
```

### Notifications
```javascript
$.ui.log('message')                 // dim transcript line (● my-mod: message); Claude doesn't read it

$.ui.status('checks: passing')      // persistent line under prompt (⚠ my-mod: checks: passing)
                                    // call again to update; call with '' to clear

$.ui.toast('Build complete!')       // toast notification, disappears after 4s
$.ui.toast('msg', { timeoutMs: 8000 })

$.ui.notice('Important notice')     // persistent notice in transcript
```

### Dialogs
```javascript
const answer = await $.ui.ask('Run this command?', ['Run it', 'Cancel'])
// Shows options in Claude's question dialog; resolves to the label picked
// Throws when user dismisses or in claude -p (nobody to ask)
// After Chat about this option, throws; your catch block should default to the safe answer

// Good pattern:
let answer = 'Cancel'   // safe default
try {
  answer = await $.ui.ask('Delete all?', ['Delete', 'Cancel'])
} catch {}
```

### Clipboard and selection
```javascript
await $.ui.copy('text to clipboard')

const sel = await $.ui.selection()  // returns selected text in the terminal
```

---

## `$.command` — Slash Commands

```javascript
// Register in session.start
await $.command.register({
  name: 'standup',                  // becomes /standup
  description: 'Show recent changes',
  argumentHint: '[days]',           // shown in prompt after typing /standup<space>
  immediate: true,                  // allow while Claude is working (default: false)
})
// Throws if name conflicts with a built-in command; wrap in try/catch

await $.command.run({ command: 'standup', args: '3' })  // run programmatically

const cmds = await $.command.list()  // list registered commands
```

Handle in `command.run`:
```javascript
on('command.run', { command: 'standup' }, async ($, e) => {
  // e.args: text after the command name
  return { text: 'Summary...' }     // printed in transcript, Claude reads it
  // return {} for no output
})
```

---

## `$.tool` — Tools for Claude

```javascript
// Register in session.start
await $.tool.register({
  name: 'ticket',                   // full name: mcp__<plugin-name>__ticket
  description: 'Look up a ticket',  // Claude uses this to decide when to call it
  inputSchema: {
    type: 'object',
    properties: { id: { type: 'string', description: 'Ticket ID' } },
    required: ['id'],
  },
})

await $.tool.call({ tool: 'Bash', command: 'ls' })   // call a tool from your mod
                                                      // useful in tests and background jobs

const decision = await $.tool.check({ tool: 'Bash', input: { command: 'ls' } })
// Returns 'allow', 'ask', or 'deny'

const tools = await $.tool.list()   // list available tools
```

Handle calls:
```javascript
// Tool full name is: mcp__ + plugin name + __ + registered name
on('tool.call', { tool: 'mcp__my-mod__ticket' }, async ($, e) => {
  // e.id is the argument defined in inputSchema
  const r = await $.http.fetch('https://api.example.com/tickets/' + encodeURIComponent(e.id))
  return { result: r.ok ? await r.text : 'Error ' + r.status }
})
```

---

## `$.model` — Model Calls

```javascript
const r = await $.model.complete({
  model: 'haiku',           // 'haiku', 'sonnet', 'opus', or a full model id
  system: 'Reply with one word: bug, feature, or question.',
  prompt: 'The export button does nothing',
  maxTokens: 20,            // default: 1024, max: 64000
  timeoutMs: 15000,         // optional timeout
  effort: 'low',            // 'low', 'medium', 'high' for extended thinking
})
// r.isAnswered: true when model replied
// r.text: the reply (only when r.isAnswered)
// r.reason: why it didn't answer (when r.isAnswered is false)

if (r.isAnswered) {
  const label = r.text.trim()
} else {
  // API failure, timeout, or blocked model
  console.error(r.reason)
}

// Fork: sends one question over current conversation history
const fork = await $.model.fork({ prompt: 'Summarize what you just did in one sentence' })

// Classify: efficient classification call (returns a category)
const cat = await $.model.classify({ prompt: text, labels: ['bug', 'feature', 'question'] })
```

Uses the user's plan or API key. A rejected call (blocked model, org policy) throws immediately.

---

## `$.fs` — File System

```javascript
const text = await $.fs.read('/absolute/path/to/file.txt')
// Or relative to session cwd:
const text = await $.fs.read('README.md')
// Limit: 4 MiB per file

await $.fs.write('output.txt', 'content here')
// NOT atomic; another process can read a partially written file
// For multi-session shared data, use $.store instead

const exists = await $.fs.exists('file.txt')   // boolean

const stat = await $.fs.stat('file.txt')
// Returns: { size, kind: 'file'|'directory'|'symlink', isLink }

const entries = await $.fs.list('.')
// Returns: Array<{ name, kind, size, isLink }> — NOT recursive, one directory only

const ancestors = await $.fs.ancestors('/path/to/file')
// Returns: array of ancestor directory paths
```

---

## `$.store` — Persistent Key-Value Storage

Cross-session, per-plugin, stored as JSON at `~/.claude/plugins/store/`. Cleaned up after `cleanupPeriodDays` of inactivity.

```javascript
await $.store.set('count', 42)          // any JSON value
const val = await $.store.get('count')  // undefined if not set
await $.store.delete('count')
const keys = await $.store.keys()       // array of all keys for this plugin

// Total limit: 4 MiB JSON
// Prefer individual keys per item over one large object (avoids write races)
// Multi-session pattern: read immediately before write
const saved = Number((await $.store.get('count')) ?? 0)
await $.store.set('count', saved + 1)
```

---

## `$.state` — Reactive Session State

Survives module reloads (unlike module variables). Resets on session end, `/clear`, `/resume`, `/branch`. A `ui.render` hook that reads a value auto-redraws when that value changes.

Requires declaration in `types/index.d.ts` and `types` in `plugin.json`.

```javascript
// In types/index.d.ts:
declare module 'claude-code' {
  interface PluginState {
    'my-mod': {
      count: number
      tab: 'one' | 'two'
    }
  }
}

// In register.js:
import { atom, read, update } from 'claude-code'

const count = atom({ plugin: 'my-mod', key: 'count' }, 0)  // name + default
// plugin and key MUST be string literals

// In ui.render hook:
const n = await read($, count)        // subscribe to this value, auto-redraw on change

// In a callback (onPress, onSubmit, or other event hook):
await update($, count, (v) => v + 1)  // atomic update; triggers redraw of subscribed sites

// Manual write:
await $.state.set({ plugin: 'my-mod', key: 'count' }, 42)
const v = await $.state.get({ plugin: 'my-mod', key: 'count' })
```

**Restore after `/clear`**: `$.state` resets to defaults on `/clear`, `/resume`, `/branch`. Use `classic.SessionStart` with `{ source: ['clear', 'resume', 'fork'] }` to reload from `$.store`.

---

## `$.clock` — Timers

```javascript
const timer = $.clock.every(60_000, async () => {
  // runs every 60 seconds; callback runs outside any event
  $.ui.status('last check: ' + new Date().toLocaleTimeString())
})
timer.cancel()   // stop the timer

const oneShot = $.clock.after(5000, async () => {
  // runs once after 5 seconds
})
oneShot.cancel()

const now = await $.clock.now()      // current time in milliseconds

await $.clock.sleep(1000)            // pause for 1 second (counts against hook time limit)
```

Timers stop when the module reloads. Start new ones in `session.start`. Callback errors go to the debug log; the timer keeps running.

**For operations inside a hook** where you need to wait without using the time limit, use mods API calls (they don't count against the limit). `$.clock.sleep` DOES count against the limit.

---

## `$.http` — Network Requests

```javascript
const r = await $.http.fetch('https://api.example.com/data')
const r = await $.http.fetch('https://api.example.com/data', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token },
  body: JSON.stringify({ key: 'value' }),
})
// r.status: HTTP status code
// r.ok: true when status 200-299
// r.text: response body as string (already read)
// r.headers: response headers object
```

---

## `$.process` — Shell Commands

```javascript
const r = await $.process.run(['git', 'branch', '--show-current'])
// Takes an array (no shell, no globbing, no pipes)
// r.exitCode: number
// r.stdout: string
// r.stderr: string
// Resolves regardless of exit code; rejects only if program can't start or times out

// With options:
const r = await $.process.run(['npm', 'test'], {
  cwd: '/path/to/project',    // working directory (default: session cwd)
  timeoutMs: 60000,           // default: 30s, max: 600s
  env: { NODE_ENV: 'test' },  // additional env vars
})

// Stream a long-running command:
const proc = await $.process.spawn(['tail', '-f', 'logs/app.log'])
for await (const chunk of proc.stdout) {
  $.ui.log(chunk)
}
```

Wrap in try/catch: `run` throws if program can't start or times out.

---

## `$.session` — Session Information

```javascript
const id = await $.session.id()        // current session ID
const cwd = await $.session.cwd()      // working directory
const model = await $.session.model()  // current model name
const root = await $.session.root()    // project root (where CLAUDE.md is)

const usage = await $.session.usage()
// Returns:
// {
//   startedAt: number,
//   context: { tokens: number, window: number, percent: number },
//   rateLimits: Array<{ kind, percentUsed, resetsAt }>,
//   cost: number
// }

const turns = await $.session.turns()  // turn count

const msgs = await $.session.messages()
// Returns newest 4096 entries: Array<{ role: 'user'|'assistant', text, toolUses }>

// Send message to another session
const result = await $.session.send({
  to: { sessionId: 'abc-123' },   // or { agentId: 'xyz' } for subagent
  text: 'Status? One line.',
})
// result.isDelivered: boolean
// result.reason: why it wasn't delivered (when isDelivered is false)

await $.session.compact()   // trigger conversation compaction

await $.session.append({ role: 'user', content: '...' })  // append to conversation

const surfaces = await $.session.surfaces()  // list of connected apps
const repo = await $.session.repo()          // git repo info
const version = await $.session.version()   // Claude Code version

await $.session.authorize({ tool: 'Bash', command: 'npm test' })  // pre-approve a tool call
```

---

## `$.prompt` — Submit Prompts

```javascript
// Submit text from a background job (waits until session is idle)
await $.prompt.submit({ text: 'Check if the tests pass now' })
// Claude reads: "[my-mod] Check if the tests pass now"

// As user's own words (no attribution prefix):
await $.prompt.submit({ text: 'Run the tests', asUser: true })

// Fill the prompt box with text (doesn't submit):
await $.prompt.fill({ text: 'npm test' })

// Suggest (dim preview text in prompt box):
await $.prompt.suggest({ text: 'suggested command' })

// Read current prompt box text:
const current = await $.prompt.read()
```

---

## `$.env` — Environment Variables

```javascript
const token = await $.env.get('MY_API_TOKEN')   // key MUST be a string literal
await $.env.set('MY_SETTING', 'value')           // key MUST be a string literal
```

Static analysis requires string literal keys — no variable key names.

---

## `$.settings` — Read Settings

```javascript
const settings = await $.settings.read()
// Returns merged settings from all settings files and managed policy
```

---

## `$.agent` — Subagents

```javascript
await $.agent.register({
  name: 'reviewer',
  description: 'Reviews code changes',
  // ...
})

const agent = await $.agent.spawn({ name: 'reviewer', prompt: 'Review this PR' })

const agents = await $.agent.list()   // list active subagents
```

---

## `$.mcp` — MCP Server Calls

```javascript
// Call a tool on a connected MCP server (must be listed in your plugin's manifest dependencies)
const result = await $.mcp.call({ server: 'my-server', tool: 'list_files', input: { path: '.' } })

// Connect an MCP server your plugin's manifest declares
await $.mcp.connect('my-server-name')
```

---

## `$.audio` — Audio

```javascript
await $.audio.speak('Hello from my mod')          // text-to-speech
await $.audio.play('/path/to/sound.mp3')          // play audio file
```

---

## `$.plugin` — Plugin Info

```javascript
const name = $.plugin.name    // your plugin's name from plugin.json
const root = $.plugin.root    // absolute path to the plugin's directory
```

---

## `$.telemetry` — Telemetry (Built-in Only)

```javascript
$.telemetry.log({ event: 'my_event', properties: { key: 'value' } })
$.telemetry.mark('feature_used')
```

Only records when called by Claude Code itself or built-in mods. User-installed mods' telemetry calls are ignored.

---

## `next` — Handler Chain Control

```javascript
// Standard: pass event through
return next(e)

// With modification:
return next({ ...e, text: newText })

// Check abort signal for long operations:
if (next.signal.aborted) return { deny: 'Abandoned' }

// Check time remaining:
const ms = next.budget.remainingMs

// Skip to a later tier (only for prependPlugins/appendPlugins mods):
return next.to(e, 'append')    // skip user-installed mods
return next.to(e, 'core')      // skip all mods

// In .catch handler:
next.error.kind     // 'throw' or 'timeout'
next.error.message  // error text
next.called         // true if the failed hook had called next
```

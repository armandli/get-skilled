# Claude Code Mod Examples

Complete, working mod examples. Each is a full plugin directory you can load with `claude --plugin-dir ./mod-name`.

---

## Example 1: first-mod — Tool Call Counter

Counts tool calls, shows count beside the spinner, adds `/tally` and `/tally-reset` commands.

### File structure
```
first-mod/
├── .claude-plugin/
│   └── plugin.json
└── hooks/
    ├── hooks.json
    └── register.js
```

### `.claude-plugin/plugin.json`
```json
{
  "name": "first-mod",
  "version": "0.1.0",
  "description": "Counts tool calls, shows beside spinner, /tally command",
  "author": { "name": "Your Name" }
}
```

### `hooks/hooks.json`
```json
{
  "description": "first-mod hooks module",
  "modules": ["./register.js"]
}
```

### `hooks/register.js`
```javascript
let calls = 0

export function register(on) {
  on('session.start', async ($, e, next) => {
    await $.command.register({ name: 'tally', description: 'Show tool call count' })
    await $.command.register({ name: 'tally-reset', description: 'Reset the tool call count' })
    return next(e)
  })

  on('tool.call', async ($, e, next) => {
    calls += 1
    $.ui.invalidate('ui.render')
    return next(e)
  })

  on('command.run', { command: 'tally' }, async ($, e) => {
    return { text: 'Claude has made ' + calls + ' tool calls since this mod loaded' }
  })

  on('command.run', { command: 'tally-reset' }, async ($, e) => {
    calls = 0
    $.ui.invalidate('ui.render')
    return { text: 'Tool call count reset to 0' }
  })

  on('ui.render', { component: 'Spinner' }, async ($, e, next) => {
    if (calls === 0) return next(e)
    return next({ ...e, props: { ...e.props, suffix: ' · tools: ' + calls + '…' } })
  })
}
```

### Test
```typescript
// hooks/tests/first-mod.test.ts
import { expect, test } from 'claude-code/testing'

test('/tally reports tool calls', async ($, on) => {
  on('tool.call', () => ({ result: 'ok' }))
  await $.tool.call({ tool: 'Bash', command: 'ls' })
  await $.tool.call({ tool: 'Read', file_path: 'README.md' })
  const answer = await $.command.run({ command: 'tally', args: '' })
  expect(answer.text).toBe('Claude has made 2 tool calls since this mod loaded')
})

test('/tally-reset resets count', async ($, on) => {
  on('tool.call', () => ({ result: 'ok' }))
  await $.tool.call({ tool: 'Bash', command: 'ls' })
  await $.command.run({ command: 'tally-reset', args: '' })
  const answer = await $.command.run({ command: 'tally', args: '' })
  expect(answer.text).toBe('Claude has made 0 tool calls since this mod loaded')
})
```

---

## Example 2: blast-radius — Tool Guard with User Confirmation

Holds risky Bash commands (rm -rf, git reset --hard, force push) and asks the user before running.

### `hooks/register.js`
```javascript
const RISKY = /\brm\s+-rf?\b|\bgit\s+reset\s+--hard\b|\bgit\s+push\b.*?--force/

export function register(on) {
  on('tool.call', { tool: 'Bash' }, async ($, e, next) => {
    if (!RISKY.test(e.command)) return next(e)

    // Preview what the command would affect
    let preview = ''
    try {
      if (/rm -rf?/.test(e.command)) {
        const targets = e.command.replace(/rm\s+-rf?\s+/, '').trim()
        const ls = await $.process.run(['ls', '-la', ...targets.split(' ')])
        preview = ls.exitCode === 0 ? '\n\nWould remove:\n' + ls.stdout : ''
      }
    } catch {}

    let answer = 'Refuse'
    try {
      answer = await $.ui.ask(
        'Risky command detected:' + preview + '\n\n' + e.command,
        ['Run it', 'Refuse']
      )
    } catch {
      // Dismissed or claude -p session: default to refusing
    }

    if (answer !== 'Run it') {
      return { deny: 'User declined the risky command. Suggest a safer alternative.' }
    }
    return next(e)
  })

  // Fail closed: if the guard throws or times out, refuse the command
  on('tool.call', { tool: 'Bash' }, async ($, e, next) => next(e))
    .catch(async ($, e, next) => {
      return { deny: 'Safety guard failed (' + next.error.kind + '). Command blocked.' }
    })
}
```

---

## Example 3: git-context — Auto-inject Git Branch in Prompts

Adds the current git branch to any prompt that mentions a PR or pull request.

### `hooks/register.js`
```javascript
export function register(on) {
  on('prompt.submit', async ($, e, next) => {
    // Only augment prompts that mention PRs
    if (!/\bPR\b|\bpull request\b|\bpull-request\b/i.test(e.text)) {
      return next(e)
    }

    // Get current branch
    const git = await $.process.run(['git', 'branch', '--show-current'])
    if (git.exitCode !== 0) return next(e)   // not in a git repo

    const branch = git.stdout.trim()
    if (!branch) return next(e)

    // Add branch as hidden context (Claude reads it, user doesn't see it in transcript)
    return next({
      ...e,
      context: [...(e.context ?? []), 'Current git branch: ' + branch],
    })
  })
}
```

---

## Example 4: pr-checks — Background Status Bar

Polls GitHub PR checks every 60 seconds and shows status under the prompt.

### `hooks/register.js`
```javascript
function summarize(json) {
  try {
    const checks = JSON.parse(json)
    const counts = { success: 0, failure: 0, pending: 0 }
    for (const c of checks) {
      if (c.state === 'success') counts.success++
      else if (c.state === 'failure' || c.state === 'error') counts.failure++
      else counts.pending++
    }
    const parts = []
    if (counts.success > 0) parts.push(counts.success + ' passing')
    if (counts.failure > 0) parts.push(counts.failure + ' failing')
    if (counts.pending > 0) parts.push(counts.pending + ' pending')
    return parts.join(', ') || 'no checks'
  } catch {
    return 'could not parse'
  }
}

export function register(on) {
  on('session.start', async ($, e, next) => {
    $.clock.every(60_000, async () => {
      try {
        const result = await $.process.run(['gh', 'pr', 'checks', '--json', 'state,name'])
        if (result.exitCode === 0) {
          $.ui.status('PR checks: ' + summarize(result.stdout))
        } else {
          $.ui.status('')    // clear if no PR
        }
      } catch {
        $.ui.status('PR checks: gh not found')
      }
    })
    return next(e)
  })
}
```

---

## Example 5: notes-pane — Persistent Notes with UI

A `/notes` command opens a pane with a text field. Notes persist across sessions.

### `hooks/register.js`
```javascript
import { atom, read, update } from 'claude-code'

const PANE = 'notes-pane'

// Module-level (ephemeral): what's shown in the input field while typing
let inputValue = ''

export function register(on) {
  // Load saved notes on start
  on('session.start', async ($, e, next) => {
    await $.command.register({ name: 'notes', description: 'Open the notes pane' })
    return next(e)
  })

  // Open pane on /notes
  on('command.run', { command: 'notes' }, async ($, e) => {
    await $.ui.open({ id: PANE, title: 'Notes', focus: true, closeOnEscape: true })
    return {}
  })

  // Draw the pane
  on('ui.render', { component: 'Pane' }, async ($, e, next) => {
    if (e.requestId !== PANE) return next(e)

    const { Box, Text, Button, Input } = $.ui.resolve(e)
    const redraw = () => $.ui.invalidate('ui.render')

    // Load notes from store
    const notes = (await $.store.get('notes')) ?? []

    return Box({
      flexDirection: 'column',
      children: [
        Input({
          key: 'note-input',
          label: 'New note',
          placeholder: 'Type a note and press Enter',
          value: inputValue,
          submitLabel: 'add',
          autoFocus: true,
          onInput: (v) => { inputValue = v },
          onSubmit: async (value) => {
            if (!value.trim()) return
            const updated = [...notes, { text: value.trim(), ts: Date.now() }]
            await $.store.set('notes', updated)
            inputValue = ''
            redraw()
          },
        }),
        notes.length === 0
          ? Text({ dimColor: true, children: ['No notes yet.'] })
          : Box({
              flexDirection: 'column',
              children: notes.map((note, i) =>
                Box({
                  key: 'note-' + i,
                  flexDirection: 'row',
                  columnGap: 1,
                  children: [
                    Button({
                      key: 'del-' + i,
                      label: 'x',
                      plain: true,
                      onPress: async () => {
                        const updated = notes.filter((_, j) => j !== i)
                        await $.store.set('notes', updated)
                        redraw()
                      },
                    }),
                    Text({ children: [note.text] }),
                  ],
                })
              ),
            }),
      ],
    })
  })
}
```

---

## Example 6: context-monitor — Context Window Band

Shows a live context window bar above the prompt, colored by usage level.

### `hooks/register.js`
```javascript
export function register(on) {
  // Refresh every 2 seconds
  on('session.start', async ($, e, next) => {
    $.clock.every(2000, () => $.ui.invalidate('ui.render'))
    return next(e)
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    // Only show when there's usage data
    const usage = await $.session.usage()
    const { tokens, window, percent } = usage.context
    if (!tokens) return next(e)

    const { Box, Text } = $.ui.resolve(e)
    const cols = e.props.bodyColumns
    const filled = Math.round((percent / 100) * (cols - 20))
    const empty = Math.max(0, cols - 20 - filled)

    // Color: green < 50%, yellow 50-80%, red > 80%
    const color = percent > 80 ? 'red' : percent > 50 ? 'yellow' : 'green'

    return Box({
      flexDirection: 'row',
      columnGap: 1,
      children: [
        Text({ dimColor: true, children: ['ctx'] }),
        Text({ color, children: ['█'.repeat(filled) + '░'.repeat(empty)] }),
        Text({ dimColor: true, children: [percent + '%'] }),
      ],
    })
  })
}
```

---

## Example 7: model-router — Send Long Tasks to Opus

Intercepts turns and routes requests that mention "think deeply" or "analyze carefully" to Opus.

### `hooks/register.js`
```javascript
const POWER_PATTERNS = /\b(think deeply|analyze carefully|complex analysis|thorough review)\b/i

export function register(on) {
  on('turn.step', async function* ($, e, next) {
    // Check the current prompt for power-user patterns
    const msgs = await $.session.messages()
    const lastMsg = msgs[msgs.length - 1]
    const isFirstStep = !e.agentId   // only for main conversation, not subagents

    if (isFirstStep && lastMsg?.role === 'user' && POWER_PATTERNS.test(lastMsg.text)) {
      $.ui.log('Routing to Opus for complex task…')
      const result = yield* next({ ...e, model: 'opus' })
      return result
    }

    return yield* next(e)
  })
}
```

---

## Example 8: org-policy-mod — Enforce Organization Policy

An org-managed mod that refuses certain tool patterns and logs all tool usage.

### `hooks/register.js`
```javascript
const FORBIDDEN_PATHS = ['/etc', '/root', '/usr/bin', '/system']
const FORBIDDEN_COMMANDS = /\bcurl\b.*\|.*\bbash\b|\bwget\b.*\|.*\bsh\b/

export function register(on) {
  // Log every tool call to a file for audit
  on('tool.call', async ($, e, next) => {
    const entry = JSON.stringify({
      ts: new Date().toISOString(),
      tool: e.tool,
      args: e.input ?? {},
      sessionId: await $.session.id(),
    })
    try {
      const existing = await $.fs.read('/var/log/claude-audit.jsonl').catch(() => '')
      await $.fs.write('/var/log/claude-audit.jsonl', existing + entry + '\n')
    } catch {}
    return next(e)
  })

  // Block access to forbidden paths
  on('tool.call', { tool: ['Read', 'Write', 'Edit', 'Bash'] }, async ($, e, next) => {
    const path = e.file_path || e.command || ''
    const forbidden = FORBIDDEN_PATHS.some(p => path.startsWith(p))
    if (forbidden) {
      return { deny: 'Access to system paths is not allowed in this organization.' }
    }
    return next(e)
  })

  // Block pipe-to-shell patterns
  on('tool.call', { tool: 'Bash' }, async ($, e, next) => {
    if (FORBIDDEN_COMMANDS.test(e.command)) {
      return { deny: 'Piping download output directly to a shell is blocked. Download first, inspect, then execute.' }
    }
    return next(e)
  })
}
```

---

## Development Patterns Reference

### Pattern: register command + handle it
```javascript
// Always in session.start
on('session.start', async ($, e, next) => {
  await $.command.register({ name: 'cmd', description: '...' })
  return next(e)
})

on('command.run', { command: 'cmd' }, async ($, e) => {
  return { text: 'result' }
})
```

### Pattern: pane with state
```javascript
let state = { tab: 'home', items: [] }

on('command.run', { command: 'show' }, async ($) => {
  await $.ui.open({ id: 'my-pane', focus: true, closeOnEscape: true })
  return {}
})

on('ui.render', { component: 'Pane' }, async ($, e, next) => {
  if (e.requestId !== 'my-pane') return next(e)
  const { Box, Text } = $.ui.resolve(e)
  const redraw = () => $.ui.invalidate('ui.render')
  // build tree from state...
  return Box({ children: [Text({ children: [state.tab] })] })
})
```

### Pattern: background job → prompt
```javascript
on('session.start', async ($, e, next) => {
  $.clock.every(300_000, async () => {  // every 5 minutes
    const result = await $.process.run(['npm', 'test', '--silent'])
    if (result.exitCode !== 0) {
      // Start a turn only when session is idle
      await $.prompt.submit({ text: 'Tests are failing:\n' + result.stderr })
    }
  })
  return next(e)
})
```

### Pattern: tool for Claude + handler
```javascript
on('session.start', async ($, e, next) => {
  await $.tool.register({
    name: 'lookup',
    description: 'Look up a value in the company database',
    inputSchema: {
      type: 'object',
      properties: { id: { type: 'string' } },
      required: ['id'],
    },
  })
  return next(e)
})

// Full tool name = mcp__ + plugin name + __ + registered name
on('tool.call', { tool: 'mcp__my-mod__lookup' }, async ($, e) => {
  try {
    const r = await $.http.fetch('https://internal.api/lookup/' + e.id)
    return { result: r.ok ? r.text : 'Not found' }
  } catch (err) {
    return { result: 'Error: ' + err.message }
  }
})
```

### Pattern: intercept model request for turn.step
```javascript
on('turn.step', async function* ($, e, next) {
  // MUST be an async generator (function*)
  // Use yield* to forward the stream
  const result = yield* next(e)

  // result.usage has token counts after streaming completes
  if (result.usage) {
    const { input_tokens, output_tokens, cache_read_input_tokens } = result.usage
    $.ui.log('tokens: ' + input_tokens + ' in, ' + output_tokens + ' out, ' +
             cache_read_input_tokens + ' from cache')
  }
  return result
})
```

### Pattern: TypeScript with $.state
```typescript
// register.ts
import { atom, read, update } from 'claude-code'
import type { ModHooksContext } from 'claude-code'

// In types/index.d.ts:
// declare module 'claude-code' {
//   interface PluginState { 'my-mod': { count: number } }
// }

const count = atom({ plugin: 'my-mod', key: 'count' }, 0)

export function register(on: ModHooksContext['on']) {
  on('ui.render', { component: 'Pane' }, async ($, e, next) => {
    if (e.requestId !== 'counter') return next(e)
    const { Box, Text, Button } = $.ui.resolve(e)
    const n = await read($, count)   // auto-subscribes; auto-redraws on change
    return Box({
      flexDirection: 'row', columnGap: 2,
      children: [
        Button({ key: 'add', label: '+1', onPress: () => update($, count, v => v + 1) }),
        Text({ children: [String(n)] }),
      ],
    })
  })
}
```

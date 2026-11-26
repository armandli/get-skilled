# Claude Code mods — UI and Drawing Reference

## Where a Mod Can Draw

A mod's interface lives in **render sites** — named extension points Claude Code fires `ui.render` events for. The main sites:

| Site | Where in the UI | Surface |
|---|---|---|
| `Pane` | Sidebar (wide terminal) or framed region above prompt (narrow) | Terminal, Desktop |
| `AbovePrompt` | Band directly above the prompt input | Terminal, Desktop |
| `Spinner` | The animated line while Claude works | Terminal, Desktop |
| `UserMessage` | A message the user sent | Terminal, Desktop |
| `AssistantMessage` | Claude's reply | Terminal, Desktop |
| `ToolUse`, `ToolResult`, `ToolGroup` | Tool call rows in transcript | Terminal, Desktop |
| `AskUserQuestion` | Claude's question dialog | Terminal, Desktop |
| `TurnDuration` | The line that closes a turn | Terminal only |
| `Spinner`, `ToolProgress` | Status lines during a turn | Terminal, Desktop |
| `PromptHint` | Hint line under the prompt | Terminal, Desktop |
| `InfoNotice` | Status lines under the logo | Terminal only |
| `SessionMode` | Dim mode labels at the right of the prompt footer (`e.props.modes`); add or filter modes | Terminal, Desktop |
| `CommandOutput` | Output of a slash command | Terminal, Desktop |

The **permission prompt** is not a render site — a mod cannot change it.

---

## Opening and Drawing a Pane

### Open
```javascript
// From a command, button press, or session.start
await $.ui.open({
  id: 'my-pane',            // unique id; your ui.render hook checks e.requestId
  title: 'My Pane',         // tab label when multiple panes open
  focus: true,              // request keyboard focus (only granted when prompt is empty)
  closeOnEscape: true,      // Esc closes and returns focus to prompt
  rows: 20,                 // height when pane is above prompt (default: 1/3)
  columns: 60,              // width when pane is beside transcript
})
// Returns { isPlaced: true } or { isPlaced: false, reason }
```

**Placement rules:**
- Wide terminal (≥144 cols): pane appears beside transcript
- Narrow terminal: pane appears above prompt
- A pane opened without user action only appears at ≥144 cols; after user has opened it once, 110 cols is enough

### Draw
```javascript
on('ui.render', { component: 'Pane' }, async ($, e, next) => {
  // Skip panes that belong to other mods
  if (e.requestId !== 'my-pane') return next(e)

  const { Box, Text, Button } = $.ui.resolve(e)

  // e.props.bodyColumns: available width
  // e.props.bodyRows: available height (when placement is 'dock')
  // e.props.placement: 'dock' (beside transcript) or 'inline' (above prompt)
  // e.surface: 'terminal' or 'desktop'

  return Box({
    flexDirection: 'column',
    children: [
      Text({ children: ['Hello from my pane!'] }),
    ],
  })
})
```

### Close
```javascript
await $.ui.close({ id: 'my-pane' })
```

---

## Drawing in the Band (AbovePrompt)

The band is always present. Every mod shares it. Return a tree to draw there, or `next(e)` for nothing. A returned tree replaces what later mods draw, so **share it**: when you have nothing to show, `return next(e)`; when you do, `const below = await next(e)` and return `Box({ flexDirection: 'column', children: [mine, below] })`. Yield (`return next(e)`) while `e.props.hasSurvey` is true. Fit your rows inside `e.props.maxRows` so the band never scrolls. See [ui-recipes.md](ui-recipes.md) §1.

```javascript
on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
  const { Box, Text } = $.ui.resolve(e)
  const usage = await $.session.usage()
  const pct = usage.context.percent

  // e.props.bodyColumns: available width
  // e.props.maxRows: max rows the band can use
  // e.props.isWorking: true while Claude is working

  // Example: context window percentage bar
  const filled = Math.round(pct * e.props.bodyColumns / 100)
  const bar = '█'.repeat(filled) + '░'.repeat(e.props.bodyColumns - filled)
  return Text({ dimColor: true, children: [bar + ' ' + pct + '%'] })
})
```

---

## Modifying Claude Code's Own Interface

At built-in render sites, `next(e)` returns a reference to Claude Code's drawing. You can:

### Change a detail (pass modified props to next)
```javascript
on('ui.render', { component: 'Spinner' }, async ($, e, next) => {
  // e.props: { word, message, suffix, mode }
  return next({ ...e, props: { ...e.props, suffix: ' · ' + myCount + ' calls…' } })
})
```

### Replace the drawing entirely (return tree, don't call next)
```javascript
on('ui.render', { component: 'Spinner' }, async ($, e) => {
  const { Text } = $.ui.resolve(e)
  return Text({ children: ['Working… (' + myCount + ' tool calls)'] })
})
```

### Wrap the original drawing in your tree
```javascript
on('ui.render', { component: 'Spinner' }, async ($, e, next) => {
  const { Box, Text } = $.ui.resolve(e)
  const theirs = await next(e)   // returns { type: 'engine', ref }
  return Box({
    flexDirection: 'column',
    children: [theirs, Text({ children: ['extra line'] })],
  })
})
```

The `AskUserQuestion` site must include the reference exactly once for Claude Code to draw the dialog correctly.

---

## Elements

Get elements from `$.ui.resolve(e)` inside a `ui.render` hook:
```javascript
const { Box, Text, Button, Input, Select, Markdown, Link, Code, Raster } = $.ui.resolve(e)
```

If your file is `.tsx` or `.jsx`, you can write JSX after destructuring.

**Which surface has which element:**

| Element | terminal | desktop / vscode | mobile |
|---|---|---|---|
| `Box`, `Text`, `Button`, `Link`, `Code`, `Markdown` | ✓ | ✓ | ✓ |
| `Input`, `Select` | ✓ | ✓ | ✗ |
| `Client` | ✓ | desktop ✓, vscode ✗ | ✗ |
| `Raster`, `Image` | ✓ | ✗ | ✗ |
| `Svg` | ✗ | ✓ | ✓ |

Feature-detect optional elements: `const el = $.ui.resolve(e); const Svg = 'Svg' in el ? el.Svg : undefined`. On an unknown surface, an element it doesn't know renders as a fragment.

**Tree limits:** 20,000 nodes, 32 levels deep, 100,000 serialized characters. Over that, the tree is refused and Claude Code draws its own.

### `Box` — Flex container
```javascript
Box({
  flexDirection: 'column',    // or 'row'
  columnGap: 2,               // gap between row children
  rowGap: 1,                  // gap between column children
  padding: 1,                 // or { top, right, bottom, left }
  margin: 1,
  width: 40,                  // or '50%'
  height: 10,
  borderStyle: 'single',      // 'single', 'double', 'round', 'bold', 'classic'
  backgroundColor: 'blue',    // theme key or color name
  position: 'absolute',       // for overlapping elements
  hover: { backgroundColor: 'gray' },
  children: [...],
})
```

### `Text` — Styled text
```javascript
Text({
  color: 'green',             // theme key, color name, or hex '#ff0000'
  backgroundColor: 'black',
  bold: true,
  italic: true,
  underline: true,
  dimColor: true,
  inverse: true,
  strikethrough: true,
  wrap: 'wrap',               // 'wrap', 'truncate', 'truncate-start', 'truncate-middle', 'truncate-end'
  // Desktop/VS Code typography (the terminal ignores these, so they are safe everywhere):
  size: 'footnote',           // 'caption' | 'footnote' | 'body' | 'heading' | 'title'
  weight: 'semibold',         // 'regular' | 'medium' | 'semibold' | 'bold' (bold: true = semibold)
  mono: true,                 // monospace face, for glyph art and code columns
  tabular: true,              // fixed-width digits, for counters and number columns
  hover: { color: 'suggestion' },   // needs an enclosing keyed Box, or hover.scope
  children: ['Hello, world!'],  // max 10,000 chars per string
})
```

Colors can be a **theme key** that follows the user's Claude theme: `'text'`, `'subtle'`, `'inactive'`, `'suggestion'`, `'success'`, `'error'`, `'warning'`, `'claude'`, `'permission'`, `'diffAdded'`, `'diffRemoved'` and others. They can also be raw: `'#rrggbb'`, `'#rrggbbaa'`, `'ansi256(n)'` or a named color.

### `Box` hover and overlays
```javascript
Box({
  key: 'row-1',                               // a keyed Box is a hover scope
  hover: { backgroundColor: 'gray' },         // applied by the surface; no hook runs
  position: 'relative',
  children: [
    Text({ children: ['ⓘ'] }),
    Box({ position: 'absolute', top: -2, left: 2, display: 'none',
          hover: { display: 'flex' }, borderStyle: 'round', children: [Text({ children: ['tooltip'] })] }),
  ],
})
```
`hover.scope: 'name'` links elements across sites so they light together. Space props also accept `'xs' | 'sm' | 'md' | 'lg' | 'xl'`. See [building-great-ui.md](building-great-ui.md) §6.

### `Button` — Pressable control
```javascript
Button({
  key: 'submit-btn',          // required for tests; unique within the drawing
  label: 'Submit',
  hotkey: 's',                // one digit or lowercase letter
  plain: true,                // no brackets; terminal shows "s: Submit"
  dimColor: true,             // dim when inactive (e.g., for tab buttons)
  autoFocus: true,            // gets keyboard focus when pane opens (true only)
  action: 'Accept',           // Claude Code keybinding action (user's keybinding presses it)
  onPress: async (e) => {     // e.surface: 'terminal' or 'desktop'
    count += 1
    $.ui.invalidate('ui.render')
  },
})
```

When two buttons share a `hotkey`, the later one gets it. `autoFocus: false` throws — omit the prop instead.

### `Input` — Text field
```javascript
Input({
  key: 'search-input',
  label: 'Search',            // text before the field; terminal draws ": " after
  placeholder: 'Type here…',
  value: '',                  // always draw with '' to clear after submit
  submitLabel: 'go',          // word after ⏎ symbol
  autoFocus: true,
  onSubmit: async (value) => {
    // runs when user presses Enter
    notes.push(value)
    $.ui.invalidate('ui.render')
    await $.store.set('notes', notes)
  },
  onInput: async (value) => {
    // runs on every keystroke
    filtered = allItems.filter(i => i.includes(value))
    $.ui.invalidate('ui.render')
  },
})
```

Submitting an Input does NOT start a Claude turn unless you call `$.prompt.submit`.

### `Select` — Dropdown
```javascript
Select({
  key: 'size-select',
  label: 'Size',
  options: [
    { value: 'sm', label: 'Small' },
    { value: 'md', label: 'Medium' },
    { value: 'lg', label: 'Large' },
  ],
  value: 'md',                // currently selected value
  autoFocus: true,
  onSelect: async (value) => {
    selectedSize = value
    $.ui.invalidate('ui.render')
  },
})
```

### `Markdown` — Formatted text
```javascript
Markdown({
  key: 'content',
  text: '# Hello\n\nThis is **markdown** content.',  // max 10,000 chars
  dimColor: true,
  pressableLinks: ['https://x.invalid/open/1'],      // string[] of hrefs this element answers
  onLinkPress: (link, e) => { open(link.href) },     // link is a PressedLink; key is required with it
})
```
A trick for progressive disclosure: make each closed section a link to a made-up href (`https://x.invalid/open/N`) and expand it in `onLinkPress`.

### `Link`
```javascript
Link({ href: 'https://example.com', label: 'Open Docs' })
```

### `Code` — Code block (engine highlighter)
```javascript
Code({ source: 'const x = 42', language: 'ts' })             // or path: 'a.ts' to infer language
Code({ source: text, path: file, startLine: 40, wrap: 'truncate-end' })  // dim line-number gutter
Code({ source: unifiedDiffHunks, format: 'diff' })           // +/- coloring and gutters
```
`source` is the prop, not children; the limit is 100,000 characters per drawing. Colors are the engine's own.

### `Svg` — Vector graphics (Desktop, VS Code, mobile; not terminal)
```javascript
Svg({ key: 'icon', source: '<svg xmlns="http://www.w3.org/2000/svg" ...>...</svg>', alt: 'folder', width: 16, height: 16 })
```
`source` is at most 131,072 chars; `width`/`height` are CSS pixels; `alt` is required. Without `isInteractive` it is drawn as a static image. `isInteractive: true` draws it in a script-less sandbox where SMIL animation, CSS `:hover` and `<title>` tooltips work. Svg is isolated from the app's fonts: embed a base64 `@font-face` in `<style>` if text matters. It has no `onPress`: put a `Client` hit layer over it. See [building-great-ui.md](building-great-ui.md) §3.

### `Raster` — Grid of colored cells (terminal only)
```javascript
const DEFAULT_COLOR = 0x01000000   // use terminal's default color

function cellsOf(rows) {
  // rows: Array<Array<[char: string, color: number]>>
  const numbers = rows.flat().flatMap(([char, color]) => [
    char.codePointAt(0),   // character code point
    color,                  // 24-bit RGB, e.g. 0xff0000 = red
    DEFAULT_COLOR,          // background color
  ])
  return new Uint8Array(Uint32Array.from(numbers).buffer).toBase64()
}

Raster({
  key: 'heat-grid',
  columns: 10,      // max 512
  rows: 5,          // max 256
  cells: cellsOf([
    [['█', 0x2e7d32], ['█', 0xf9a825], ['█', 0xc62828]],  // row 1
    [['█', 0x66bb6a], ['█', 0x2e7d32], ['█', 0xf9a825]],  // row 2
  ]),
})

// Animate without re-running ui.render:
await $.ui.blit({ requestId: 'my-pane', key: 'heat-grid', columns: 10, rows: 5, cells: newCells })
```

Check `e.surface !== 'terminal'` and show a fallback for Desktop.

### `Image` (terminal only: kitty, Ghostty; iTerm2 3.5+ in fullscreen for `png`/`rgba` only)
```javascript
Image({ key: 'chart', source: { png: base64Png }, columns: 40, rows: 10, alt: 'chart of X' })
Image({ source: { rgba: base64Rgba, width: 64, height: 64 }, columns: 16, rows: 8, alt: 'pie chart' })
Image({ source: { file: '/abs/frame.png', format: 'png', generation: 3 }, columns: 80, rows: 25, alt: 'preview' })
// swap the picture without re-rendering:
await $.ui.blit({ requestId: 'my-pane', key: 'chart', source: { png: nextPng } })
```
`columns`/`rows` must be 1–255. `alt` is required and is what other terminals show. Decoded bytes are at most 2 MiB, and `rgba` is at most 2048 px per side. `file` and `shm` sources are read by the terminal directly. You can compute RGBA pixels yourself, with no library needed; see [building-great-ui.md](building-great-ui.md) §4.

### `Client` — Interactive component on the drawing thread
A second module (a `ClientModule`) with local state, a mouse and key listener, and a timer, and no `$`. Use it for instant hover, clicks on arbitrary cells, drag, animation and keyboard navigation.
```javascript
Client({ key: 'rows', module: './rows.tsx', props: { rows, active }, width: '100%', height: 20 })
// module must be a string literal; props must be plain JSON (≤100,000 chars)

// rows.tsx
const Rows = (props, surface) => {
  // surface.elements, surface.state / setState, surface.columns / rows,
  // surface.every(ms, fn), surface.onPointer(fn), surface.onKey(fn), surface.post(data)
  return surface.elements.Text({ children: [String(props.rows.length)] })
}
export default Rows

// hooks: on('ui.message', ...) with e.requestId, e.element (the Client key) and e.data
```
There's no `Client`, `Raster` or `Image` inside a Client. Start timers and listeners once (while `state` is undefined). Three `setState` calls in a row with no input between them unmount it. Full pattern: [building-great-ui.md](building-great-ui.md) §5.

---

## Redrawing

Claude Code redraws a site when:
- Site props change (e.g., terminal resize)
- `$.ui.invalidate('ui.render')` is called
- A `$.state` value is written (for hooks that read it)

**Manual redraw pattern:**
```javascript
const redraw = () => $.ui.invalidate('ui.render')
// Call from onPress, onSubmit, timer callbacks, or event hooks
```

**Timer-based redraw (clock):**
```javascript
on('session.start', async ($, e, next) => {
  $.clock.every(1000, () => $.ui.invalidate('ui.render'))  // redraw every second
  return next(e)
})
```

**Throttle limits:** 10 redraws/sec globally; 30/sec for the visible terminal pane. Excess calls are coalesced.

---

## State Management

| Method | When to use | Lifetime |
|---|---|---|
| Module variable `let x = 0` | Ephemeral display state | Until module reloads |
| `$.state` atom | State that survives reloads AND triggers auto-redraw | Session lifetime |
| `$.store` | Settings, history, anything persistent | Across sessions |

### Using `$.state` (reactive atoms)

**Step 1 — Declare in `types/index.d.ts`:**
```typescript
declare module 'claude-code' {
  interface PluginState {
    'my-mod': {
      count: number
      tab: 'one' | 'two'
    }
  }
}
```

**Step 2 — Add `types` to `plugin.json`:**
```json
{
  "name": "my-mod",
  "types": "./types/index.d.ts"
}
```

**Step 3 — Use in register.js:**
```javascript
import { atom, read, update } from 'claude-code'

// plugin and key MUST be string literals (static analysis requirement)
const count = atom({ plugin: 'my-mod', key: 'count' }, 0)

// In ui.render hook — read subscribes this hook to the atom
const n = await read($, count)
// Hook now auto-redraws when count changes; no $.ui.invalidate needed

// In onPress/onSubmit callbacks — update triggers redraw
onPress: () => update($, count, (v) => v + 1)
```

### Loading `$.store` into `$.state` after resets

`/clear`, `/resume`, `/branch` reset `$.state` to defaults. Reload from `$.store`:

```javascript
async function loadCount($) {
  const saved = Number((await $.store.get('count')) ?? 0)
  await update($, count, () => saved)
}

on('session.start', async ($, e, next) => {
  await loadCount($)
  return next(e)
})

// classic.SessionStart fires after /clear, /resume, /branch (and at startup + compaction)
on('classic.SessionStart', { source: ['clear', 'resume', 'fork'] }, async ($, e, next) => {
  await loadCount($)
  return next(e)
})
```

---

## Keyboard Focus

Your pane gets keyboard focus when:
- Opened with `focus: true` from a user action (command, button press)
- User presses Ctrl+X then Tab
- User clicks the pane

While focused:
| Key | Effect |
|---|---|
| Tab | Next control |
| Up/Down | Previous/next control; scrolls if content overflows |
| Enter | Press focused Button, submit Input, select in Select |
| Digit/letter hotkey | Press matching Button |
| Page Up/Down, Home, End | Scroll pane |
| Ctrl+X + arrow | Resize pane |
| Ctrl+X + X | Close pane |
| Esc | Return focus to prompt (closes pane if `closeOnEscape: true`) |

Tab and arrow keys can't be rebound. Use letter/digit hotkeys for game controls.

Keyboard focus rules:
- `focus: true` from a command or press: granted if prompt is empty, nothing else focused
- `focus: true` from a timer or `turn.start`: not granted (prevents stealing keystrokes)

---

## Debugging Drawings

In a `--plugin-dir` session, when a tree fails validation (unknown element, bad prop, misplaced child), a transcript line reports it:
```
ui.render (Pane) refused: Text prop "bogusProp" is not allowed; the engine drew its own
```

Debug log path: `~/.claude/logs/` — check for `ui.render (Pane): a hook returned a tree that does not validate`.

Common causes:
- Using an element the surface doesn't support (e.g., `Raster` on Desktop, `Svg` in the terminal)
- `Code` given `children` instead of `source`; `Image`/`Svg` missing the required `alt`
- A `Text` with `hover` that is neither inside a keyed `Box` nor given a `hover.scope`
- A prop set to `false` when it only accepts `true` (e.g., `autoFocus: false`)
- Typo in an element name or prop name
- Child string exceeding 10,000 characters
- Two `autoFocus: true` controls in one drawing

---

## Render Site Props Reference

### `Pane`
```
e.props: {
  title: string,
  isFocused: boolean,
  bodyColumns: number,      // usable width
  placement: 'dock'|'inline',
  scroll: { bodyRows: number, offset: number },
  view: object,
}
e.requestId: string         // the id you opened with
e.surface: 'terminal'|'desktop'
e.viewport: { columns, rows, isFullscreen }
```

### `AbovePrompt`
```
e.props: {
  hasSurvey: boolean,
  isWorking: boolean,       // true while Claude is active
  maxRows: number,
  bodyColumns: number,
  scroll: object,
  view: object,
}
```

### `Spinner`
```
e.props: {
  word: string,             // e.g., 'Thinking'
  message: string,          // full message text
  suffix: string,           // text after word (add to this)
  mode: string,
}
```

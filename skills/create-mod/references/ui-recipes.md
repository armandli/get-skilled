# UI Recipes from Popular Mods

These are concrete, proven patterns for specific kinds of mod UI. They come from studying the most popular mods on [claudemod.com](https://www.claudemod.com/browse?category=mod):
- the official Anthropic examples in `anthropics/claude-code-playground` (Token Weather, Replay Theater, Blast Radius)
- Ribbon, Claude Image View, Claude Flightdeck, Lot Map, Terminal Browser, Agent Standup, TextFold, CC Stretch, CC Intelligent UI and Claude Skins

Every API named here was checked against the engine's `index.d.ts`. Your installed version may differ, so grep `.claude-plugin/types/claude-code/index.d.ts` before relying on a prop. Read [building-great-ui.md](building-great-ui.md) first for the fundamentals.

## 1. The band (`AbovePrompt`)

The band is one shared strip above the prompt. Good band mods are guests: small, quiet when idle, and never hiding other mods.

```tsx
on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
  if (e.props.hasSurvey || !hasSomethingToSay()) return next(e)   // yield to surveys, idle = no rows
  const below = await next(e)                                      // keep other mods' bands
  const { Box, Text } = $.ui.resolve(e)
  return <Box flexDirection="column">{myRows(e.props.bodyColumns, e.props.maxRows - 1)}{below}</Box>
})
```

- **Fit `e.props.maxRows`.** Subtract your chrome (a border and a label take about 3 rows) and shrink content until it fits. If not even the minimum fits, `return next(e)`. A band that scrolls is broken.
- **Width tiers.** Design three layouts:
  - wide (≥ about 78 columns): everything on one row
  - stacked (each meter becomes a small column block)
  - tight (< about 42 columns): secondary widgets move to their own row or disappear
  Hide extras such as sparklines below about 60 columns.
- **Top 3 plus "and N more".** Each row is `<Text wrap="truncate-end">` with a nested `<Text dimColor>` for the secondary part. A footer names the command that shows everything.
- **"Hide until something new."** A dismiss `Button` stores the set of keys shown at that moment (`id:what`). The band stays hidden until a key appears that isn't in the set, and keys that vanish are pruned. This dismisses without muting.
- **Default fold state from severity.** Store `{ mode, open }` and default to open only in the alarming state (for example, a cold cache). Reset the user's choice when the state changes.
- **Pane with a band fallback.** `const { isPlaced } = await $.ui.open({...})`. If it's `false` (narrow terminal, not fullscreen), draw the same view in the band, sized to `maxRows`. The official Blast Radius and Replay Theater mods do this.
- **Focus handoff from the band to a pane.** Call `$.ui.invalidate('ui.render')`, then `await $.clock.sleep(200)`, then `$.ui.open({ id, focus: true })`, so the band releases the keyboard first.

## 2. Meters, status and forecasts

- **Push, don't poll.** `on('session.measure', …)` fires after each turn and whenever a rate-limit window moves a whole point. It carries context, rate limits, cost and a `changed` list. `$.session.usage({ breakdown: 'summary' })` is a local estimate that sends no request. After a resume, `classic.SessionStart` gives `context_tokens` and `seconds_since_last_response` to restore a meter immediately.
- **Threshold tables.** A forecast is a sorted list of `{ upTo, symbol, word, color }`. Use single-width symbols (`☀ ☁ ☂ ☇ ↯`), not emoji, because emoji widths vary between terminals. Show an absolute % next to a sparkline scaled to the busiest reading, plus a delta (`▲ +98k last turn`).
- **Gauge glyphs.** Use `●●●·· ` dots or `▰▰▰▱▱` bars, and a bold `LOW` once a meter crosses a threshold.
- **Dedupe status updates.** Keep the last `$.ui.status` text and skip identical calls, and only `invalidate` when the JSON of your data changed. `$.ui.status(undefined)` clears the line.
- **Strip control characters** (`/[\u0000-\u001f\u007f]+/g`) from any external text before it reaches a one-line status or band row. One newline breaks the layout.

## 3. Rewriting the transcript (replies, tools, commands)

- **Fold by rewriting the text, not by redrawing.** `return next({ ...e, props: { ...e.props, text: folded } })` keeps Claude Code's own markdown, links and selection. Add a dim line under it (`Points · 17 of 89 words · press 1 to unfold`). Skip folding replies under about 80 words, or where the fold would hide less than 25%.
- **State per message with `memberOf`.** One atom becomes a family keyed by `e.requestId`, so each reply or tool row has its own open state, and a toggle redraws only that row:

```tsx
import { atom, memberOf, read, update } from 'claude-code'
const openRows = atom({ plugin: 'my-mod', key: 'open' }, false)
// inside ui.render:
const open = memberOf(openRows, e)
const isOpen = await read($, open)
<Button key="toggle" plain label={isOpen ? '▾' : '▸'} onPress={() => update($, open, v => !v)} />
```

- **`AssistantMessage` props to respect:**
  - `isSummary`: always `return next(e)`, because changing it is refused.
  - `isFirstOfReply`: draw the `⏺` bullet yourself when you replace the drawing.
  - `onScreen`: `null` means the row is off-screen, so skip or postpone expensive work.
- **Fullscreen matters.** When `e.viewport.isFullscreen === false`, replies are printed into terminal scrollback and can't change, so presses inside them never arrive. Draw everything expanded there, and only offer toggles in fullscreen.
- **Filter streaming text.** `classic.MessageDisplay` fires per batch of completed lines (`message_id`, `index`, `delta`, `final`). Return `displayContent` to hide raw markup while it streams. Chain each flush after the previous one, because several can be in flight.
- **Placeholder until final.** In a `turn.step` async generator, a new `chunk.index` or a non-text chunk means the previous text block is complete. Only then run the expensive render (math, charts), and draw a dim placeholder before that. Close the inner stream in `finally`, and also handle `turn.abort`.
- **Match on props.** `on('ui.render', { component: 'ToolUse', props: { tool: 'Read' } }, …)`. Other sites worth restyling:
  - `ToolGroup`: rewrite `isExpanded` to force groups open.
  - `ToolUse`/`ToolResult`: add your own chevron. When the open `ToolUse` already shows the output, return an empty `<Box/>` from `ToolResult`.
  - `CommandOutput`: restyle slash-command output.
  - `TurnDuration`: a footer with turn stats.
  - `SessionMode`: add or filter the mode labels at the right of the prompt footer.
- **Ask for a shape that folds well instead of calling a model.** Popular folding mods don't call `$.model`. They add a session-scoped section in `prompt.compose` that asks Claude to put the point first, then the detail. Gate it on `e.surfaces.length`, and skip when `e.traits` includes `bare` or `print`. **Caveat:** in some versions the built-in `sec-default` plugin skips `prompt.compose`, `prompt.section` and `prompt.context` for installed (user-tier) plugins. If so, add model-only guidance via `prompt.submit` context, and verify in a `claude --debug` session.
- **Keyboard toggles inside replies.** A `Button` with `action: 'app:…'` reuses a chord the user already has. For single-letter toggles, while your overlay is visible, a `prompt.edit` hook consumes the letter and returns `{ text: e.text, cursor: e.cursor }`, so the key isn't typed. Pass each toggle request to a `Client` as a prop with an increasing counter, so it runs once.
- **Desktop disclosure through links.** Render closed sections as Markdown links to made-up hrefs (`https://x.invalid/open/3`). Set `pressableLinks` to those hrefs and expand in `onLinkPress(link)` (read `link.href`; `key` is required).
- **Tell Claude what the reader opened.** In `prompt.submit`, add context naming the sections the user expanded, because that's a strong signal of interest.
- **Memo per message, swap on resize as an "epoch".** Cache each rendered tree by `requestId` plus a stamp (text, columns, theme). On resize, keep showing the old drawings until all the new ones are ready, then swap them together. This avoids a flicker of half-updated replies.

## 4. Dashboards of agents and sessions

**Where the data comes from:**

| Event | Gives you |
|---|---|
| `agent.spawn` | `e.description`, `e.subagentType`; `await next(e)` returns `{ agentId, model }` |
| `turn.step` with `e.agentId` | per-step usage and stop reason for that agent |
| `turn.start` / `turn.complete` | busy/idle; `e.reason` (`answer`, `aborted`, …) gives the card status; `e.agentId` marks subagents |
| `tool.call` (wrap `next`) | the tool ran, succeeded, failed (`isError`) or was blocked (`deny`) |
| `tool.check` | permission decisions (show a strip when Claude is waiting on you) |
| `prompt.submit` (`e.origin.kind`) | user prompt vs task notification |
| `session.compact`, `skill.prompt` | timeline markers |
| `e.props.view.agentId` (Pane) | which agent the user is viewing, so you can highlight it |

- **Layout:** cards (about 20 columns each) switch to swimlanes once they no longer fit. Hide empty panels. When `e.props.placement === 'inline'`, show a summary of at most 8 rows.
- **A live elapsed clock with no hook traffic:** a `Client` takes `props.startedAt` and `props.now`, ticks locally with `surface.every(1000, …)`, and resyncs whenever `props.now` changes.
- **Animate connectors only while active.** Stop the timer when the agent is idle.
- **Other Claude Code sessions (unofficial).** Each session writes `~/.claude/sessions/<pid>.json` (or under `CLAUDE_CONFIG_DIR`), with `status` (`busy`, `idle`, `waiting`), `waitingFor`, `cwd`, `name` and `entrypoint`. List the folder with `$.fs.list`, exclude your own `$.session.id()` (re-read it on every pass, because `/clear` changes it), and check PIDs are alive. This is an observed format, not an API, so treat it as unstable.
- **Toast on transitions, never on the first look.** For example, toast `busy→idle` ("finished, your turn") and `→waiting`. Skip the first poll so the user isn't flooded at startup.
- **Drop stale poll results.** Give each poll a sequence number (`const mine = ++seq`) and throw away results older than the last one applied, so the UI never goes back in time.
- **Cap history** (for example, 80 rows) but always keep running items. Redact secrets before displaying tool input.

## 5. Live pixels and animation

- **Schedule frames by when the picture next changes.** Compute `nextChangeIn(scene, t)`; if nothing animates, schedule nothing. Use `$.clock.after` (cancel the previous timer) and subtract the time the paint took. Give endless loops frames only while work is running, then slow to every few seconds.
- **Respect terminal bandwidth.** Measured in Lot Map: kitty stops showing animation above about 530 KB/s of base64. Cap at about 450 KB/s and ≥ 200 ms per frame. Returning the **same `source`** as last time sends nothing, so it's a free "no change".
- **Probe picture support by trying.** About 100 ms after the first frame, `$.ui.blit(...)`. If the result is `deny` and mentions `alt`, the terminal doesn't draw pictures, so switch to the glyph view. This beats guessing from environment variables.
- **Known bad terminal: iTerm2 before 3.7.8** keeps every animated frame in memory (gigabytes in minutes). Check `TERM_PROGRAM_VERSION` (or `LC_TERMINAL_VERSION` under ssh or tmux) and show a static picture or a notice.
- **Streaming another process's frames (browser, video, emulator).**
  - The helper writes each frame to a **new** POSIX shm object, and the mod passes only its name: `source: { shm: '/x-17', format: 'rgb', width, height }`.
  - The terminal unlinks each object after reading it. Names are at most 30 chars on macOS. Raw `file`/`shm` sources go up to 4096 px a side and work on kitty and Ghostty only.
  - Use `generation` when a file name is reused.
- **Blit only when the size still matches.** `$.ui.blit` is refused unless `columns`/`rows` equal the mounted Image's size. On a mismatch or repeated `deny`, call `$.ui.invalidate`, rate-limited to about once per 500 ms.
- **Long-poll instead of a timer.** A loop started with `void watch($)` calls `$.http.fetch(url + '?version=' + v)`, and the helper holds the request until something changes. A `watcher` counter stops old loops after a restart. `$.http.fetch` has no timeout, so race it against a `$.clock.after(ms)` promise and cancel that in `finally`. Back off (5 s up to 30 s) when the helper is down.
- **Forward input into rendered content.**
  - A full-size `Client` over the `Image` queues pointer and key events and flushes them every 20 ms as one `post` batch, because a later post replaces an undelivered one.
  - It also reports `surface.columns`/`rows` so the helper renders at the right size.
  - Forward the wheel with `on('ui.scroll', { requestId }, …)`, using `e.by` and `e.pointer.{column,row}`, and return `{}`.
- **Force a fresh `Client`** (reset its state and focus) by changing its `key`.
- **One SVG for every surface.** Lot Map writes its scene once as SVG with SMIL motion and shows it on Desktop via `Svg`. In the terminal it rasterizes a single moment of that SVG to RGBA (or PNG, whichever is smaller) for `Image`. Its braille-in-`Raster` third mode animates with `blit({ cells })`.
- **Negative SMIL `begin`** (`begin="-1.4s"`, the element's age) makes a redraw resume an animation instead of restarting it.
- **Entrance animation only once.** Animate a card the first time it draws, then bump an atom so later draws use a "settled" SVG. Otherwise scrolling replays the animation.
- **SVG pixel art as one `<path>`** of `M x y h1 v1 h-1 z` squares, not one `<rect>` per pixel, which leaves seams at fractional sizes.
- **Svg text needs its font embedded.** The Svg is isolated from the app's fonts, so put a base64 woff2 `@font-face` in `<style>`. You can't measure text inside it, so pre-compute widths.
- **Thumbnails without image support.** Draw a `Raster` of `▀` cells where the foreground is the top pixel and the background is the bottom pixel. That's two pixels per cell, in every terminal. Read the file with `$.fs.read(path, { as: 'bytes' })`.
- **Graph layout that reads well:** nodes on an ellipse at `(i + shift) · 2π / n`, edges as quadratic curves bent toward the centre, and parallel pulses offset sideways.
- **Offer `motion: full | reduced`.** Reduced replaces movement with fades.
- **Offer a `cellShape` option** (cell height ÷ width, default about 2) so circles stay round on unusual fonts. Detect a light terminal from `COLORFGBG` (the last field 7 or 9–15 means light).

## 6. Desktop and VS Code specifics

- **The text font is proportional** unless you pass `mono`. Nested `Text` pieces wrap separately, and runs of spaces collapse. For aligned rows, put each piece in a fixed-width `Box` and drop pieces from the end when they don't fit. Don't use spaces for alignment.
- **Prefer theme keys.** Use `color="text"` for body text, because a light terminal profile on a dark pane otherwise gives black on black. Use `'ide'` rather than `'claude'` for "running" (`'claude'` looks like the error color on light themes). Use `'suggestion'` for accents.
- **VS Code's pane can't grow** and has no `Client`. Add zoom (fixed `Svg` widths) and fold buttons there. Elsewhere, omit `Svg` `width`/`height` so it scales to the slot, or size it from columns (about `(cols + 5) * 12` px).
- In a docked Desktop pane, fill `bodyRows` with `flexShrink: 1, minHeight: 0, overflow: 'hidden'` on the list.
- Make `alt` a **live description** of the state ("3 agents running, 1 waiting"), not a static label.
- Narrow `e` per surface with `RenderInputOf<'Pane', 'desktop'>` for typed props.

## 7. Robustness

- **Draw an error card, not a blank pane:**

```tsx
on('ui.render', { component: 'Pane', requestId: 'dash' }, drawDash)
  .catch(async ($, e, next) => {
    const { Text } = $.ui.resolve(e)
    return <Text color="error">dash failed to draw ({next.error.kind}). /reload-plugins to retry</Text>
  })
```

(`next.error.kind` is `throw` or `timeout`.)

- **`ui.fault`** tells you a `Client` module crashed. Remember which `surface:module` faulted and redraw without it.
- **Wrap every observer in a `quietly()` try/catch,** so a UI failure never reaches the tool call or turn it observes.
- **Version-gate new props.** `$.session.version()` returns `{ version, base }`. Spread a prop only when it's supported, `{...(hasMono ? { mono: true } : {})}`, and never pass `false` for a true-only prop.
- **No surface, no UI.** If `(await $.session.surfaces()).length === 0` (print mode or SDK), skip drawing and polling. Desktop may report no surface at launch, so open your pane later from a `session.attach` hook.
- **Version persisted state.** `atom(ref, init, { shape: 'board-4' })` makes values stored by an older shape read as absent, which avoids crashes after a schema change. Or normalize on read.
- **Holding a tool call behind your own confirmation pane:**
  - Wait in short `$.process.run(['sleep', '0.25'])` steps, because time inside `$` calls doesn't count against the hook limit.
  - Honour `next.signal.aborted`.
  - Bind buttons to the held request object, not a global.
  - `autoFocus` the safe choice (Cancel).
  - Word the deny so the model doesn't retry.
- **Rewrite what gets copied.** The `ui.copy` hook lets you turn image cells into text for a native copy. `$.ui.selection()` reads the current selection.
- **Use `$.clock.now()` in hooks,** not `Date.now()`, so test clocks work.

## 8. Sharing a renderer with other mods

Add a noun to `$` in an `engine.create` hook. Other mods can then call `$.mymod.markdown({...})` to draw in your style:

```ts
on('engine.create', async (_$, e, next) => ({ ...(await next(e)), mymod: { markdown: async () => undefined } }))
on('mymod.markdown', async ($, e) => ({ value: drawMarkdown($, e) }))   // answer with { value } or { deny }
```

Declare the noun with `declare module 'claude-code' { interface EngineInterface { mymod: {...} } }` in a `.d.ts` you ship. Consumers call it in a `try` and fall back when your mod isn't installed.

## 9. Testing patterns

- **Stub any `$` op by hooking its name.** For example `on('session.usage', () => ({ value: {...} }))`, and likewise `fs.list`, `process.run`, `prompt.read`, `session.id` and `ui.blit`. Return `{ deny: 'ENOENT' }` to simulate failure, and sleep on the test clock inside a stub to simulate a hang.
- **Capture side effects:** `on('ui.toast', ($, e) => { toasts.push(e.text); return { value: undefined } })`, and count `state.set` calls to catch redraw churn.
- **Stand in for the engine's drawing** with `on('ui.render', () => <Text>engine band</Text>)`, then assert your band still shows "engine band" below yours.
- **Drive events directly:** `$.agent.spawn(...)`, `$.turn.start(...)`, `$.session.attach(...)`, `$.prompt.compose(...)` (assert the sections), `ui.press({ key: 'level-3' })`, then assert the message site redrew.
- **Races:** hold a stubbed promise open, resolve a newer poll first, and assert the older result is ignored.
- **Benchmarks:** time `$.ui.mount` over transcripts of 1k and 5k rows.
- **Pixel regression:** a Node script imports your pure drawing modules, renders each option to PNG, and compares against committed screenshots with `--check`.
- **Surface inventory:** keep a generated list of every hook and `$` call the mod makes, so a new capability shows up in review.

## 10. Packaging and docs conventions

- `userConfig` fields can be `string` (with `options` for a picker), `number` or `boolean`. An ordered set of panels can be one comma-list string (`"agents,tools,usage"`).
- Add `keywords` to `plugin.json`, and ship `.claude-plugin/marketplace.json` so `claude plugin marketplace add owner/repo` works.
- Gitignore `.claude-plugin/types/`; it's generated per engine version.
- CI: run `claude plugin validate` and `claude plugin test` on the **oldest supported and newest** Claude Code. Generate the types by starting a session once, then run `tsc`.
- **README sections that build trust**, as used by the best mods and the official template:
  - What this shows, with a GIF
  - Where it runs (terminal, Desktop, VS Code)
  - What it can reach (a table mapping each event to what it sees)
  - What is inferred vs measured
  - Options, with a screenshot for each look
  - Install steps "for agents"
  - Limitations

## Bugs in the official examples (don't copy them)

- Token Weather and Replay Theater read `e.hasSurvey`, `e.maxRows` and `e.bodyColumns` at the top level. They live under **`e.props`**.
- Replay Theater checks `e.requestId` on `ui.close`. The field is **`e.id`**.
- `AbovePrompt` is raised on both terminal and Desktop, not terminal only.

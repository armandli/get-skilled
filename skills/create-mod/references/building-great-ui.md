# Building Great Mod UI

Read [ui-and-drawing.md](ui-and-drawing.md) first. It covers the element API. This file covers the craft: drawing charts, shapes and lines; interactive panes with mouse, hover and animation; one look across terminal and Desktop; theming; speed; testing.

Patterns come from two production mods:
- [prismantis](https://github.com/NahumLitvin/prismantis): redraws replies with themed tables, charts, pies and mermaid diagrams.
- [claude-code-filetree](https://github.com/data-goblin/claude-code-filetree): an IDE-style file-tree pane with mouse, hover, shimmer animation, SVG icons on Desktop and a pixel treemap in the terminal.

The code here is written for this guide, not copied from either repo. For recipes for specific kinds of UI (bands, meters, reply folding, agent dashboards, streamed pixels), see [ui-recipes.md](ui-recipes.md). **The authority is your engine's types.** `claude --plugin-dir ./my-mod` writes them to `.claude-plugin/types/claude-code/index.d.ts`. Grep that file before trusting any prop named here. filetree vendors a copy under `types/engine/` and type-checks against it in CI.

## Do I need an external package to draw shapes and lines?

**No.** Mods cannot import npm packages. The only bare import allowed is `claude-code`. Hooks run without Node: no `require`, no bare imports, no dynamic `import()`. Every visual is built from elements Claude Code provides, plus your own math:

| Tool | What it draws | Surfaces |
|---|---|---|
| `Text` runs with `color` | Shapes made of Unicode glyphs: lines, boxes, bars, sparklines, pies, plots | All |
| `Box` (`borderStyle`, `backgroundColor`, sizes, `position="absolute"`) | Frames, cards, filled bars, overlays, hairlines (fractional sizes on Desktop) | All |
| **`Svg`** | Real vector graphics from an SVG string you write: icons, lines, curves, guides, animated spinners | **Desktop, VS Code, mobile only** (not terminal) |
| `Raster` | A colored cell grid, repainted in place with `$.ui.blit` | **Terminal only** |
| `Image` | Real pixels: PNG or raw RGBA you compute yourself, or a file / shared-memory frame | **Terminal only** (kitty, Ghostty; iTerm2 3.5+ in fullscreen for `png`/`rgba`); others show `alt` |
| `Client` | Your own interactive component: local state, mouse, keys, timers | Terminal, Desktop |

So the rule of thumb is: **glyphs and `Raster`/`Image` in the terminal, `Svg` on Desktop.** Both are plain strings or bytes your TypeScript produces.

Detect elements rather than assuming them:

```tsx
const el = $.ui.resolve(e)
const Svg = 'Svg' in el ? el.Svg : undefined        // Desktop, VS Code, mobile
const Image = 'Image' in el ? el.Image : undefined  // terminal
```

If you really need a library (a diagram layout engine, a syntax highlighter), **vendor it**: bundle it at build time into one ESM file under `hooks/vendor/`, import it by relative path, and check that its license is MIT-compatible. prismantis does this for mermaid and Prism.

## 1. Architecture

```
hooks/
├── register.tsx   # hooks only: wires events to the functions below
├── look.tsx       # (e, $) → view model: surface flags, colors, element table
├── canvas.ts      # pure: grid, paint, line
├── chart.ts       # pure: data → canvas / svg string
├── rows.tsx       # Client module: an interactive list drawn on the UI thread
└── vendor/        # generated single-file libraries
```

- **Keep geometry and layout pure.** They take data and return data, element trees or SVG strings, which makes them unit-testable.
- **Passing `$` to helpers:** current engines accept exported top-level `function` declarations typed `$: EngineInterface` in other modules. filetree does this in more than 30 files. Older engines refused it, and prismantis keeps every `$` user in `register.tsx` for that reason. If `claude plugin test` reports "hooks module did not load", move those functions into `register.tsx`. Never destructure or alias `$`.
- **Build a view model in stages.** filetree's pane render is a pipeline: `look → layout → toolbar → grid → columns → rows → footer`. Each stage spreads the previous object and adds fields. Each stage is small, and the final JSX just reads fields:

```tsx
export async function renderPane($: EngineInterface, e: PaneEvent) {
  const v = await lookOf($, e)          // surface, elements, theme, colors
  const l = { ...v, ...layoutOf(v) }    // widths, rows available
  const r = { ...l, ...rowsOf(l) }      // row specs
  return <v.Box flexDirection="column">{header(r)}{body(r)}{footer(r)}</v.Box>
}
```

## 2. Glyph canvas: shapes in any terminal

Paint characters and a color index into a 2D grid, then turn each row into `Text` runs.

```ts
export type Canvas = { chars: string[][]; ink: number[][] }   // ink -1 = default color
export const blank = (rows: number, cols: number): Canvas => ({
  chars: Array.from({ length: rows }, () => Array(cols).fill(' ')),
  ink: Array.from({ length: rows }, () => Array(cols).fill(-1)),
})
export const put = (c: Canvas, row: number, col: number, text: string, ink: number) =>
  [...text].forEach((ch, k) => {
    if (c.chars[row]?.[col + k] === undefined) return
    c.chars[row]![col + k] = ch
    c.ink[row]![col + k] = ink
  })
```

**Merge same-color runs.** One `Text` per cell blows the node budget:

```tsx
export const canvasElement = ({ Box, Text }: ElementTable, c: Canvas, palette: string[]) => (
  <Box flexDirection="column">
    {c.chars.map((row, r) => {
      const parts = []
      for (let at = 0; at < row.length; ) {
        const ink = c.ink[r]![at]!
        let end = at + 1
        while (end < row.length && c.ink[r]![end] === ink) end++
        parts.push(<Text key={`${at}`} color={ink < 0 ? undefined : palette[ink]}>{row.slice(at, end).join('')}</Text>)
        at = end
      }
      return <Text key={`r${r}`} mono>{parts}</Text>
    })}
  </Box>
)
```

Store palette **indexes** in the grid and resolve them to colors at render time, so a theme change doesn't recompute geometry. `mono` keeps the art aligned on Desktop; the terminal ignores it.

### Glyph toolkit

| Need | Glyphs | Resolution per cell |
|---|---|---|
| Lines and frames | `─ │ ┌ ┐ └ ┘ ├ ┤ ┬ ┴ ┼`, heavy `━ ┃`, round `╭ ╮ ╰ ╯`, double `═ ║` | 1×1 |
| Tree guides, chevrons | `│ ├─ └─`, `▸ ▾` | 1×1 |
| Horizontal bars | `▏▎▍▌▋▊▉█` | 8 steps across |
| Vertical bars, sparklines | `▁▂▃▄▅▆▇█` | 8 steps up |
| Two colors per cell | `▀ ▄` with `color` + `backgroundColor` | 1×2 |
| Filled shapes, pies | quadrants `▘▝▀▖▌▞▛▗▚▐▜▄▙▟█` | 2×2 |
| Line plots, curves | Braille `U+2800`–`U+28FF` | 2×4 |
| Scrollbar | `┃` thumb over a `│` track | 1×1 |
| Spinner | `⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏` | animation |

**Cells are about twice as tall as they are wide.** Scale x by about 2 or circles come out as ovals.

**Quadrant shapes:** sample four points per cell, build a bitmask, and pick the glyph:

```ts
const QUADS = ' ▘▝▀▖▌▞▛▗▚▐▜▄▙▟█'   // bit 1 TL, 2 TR, 4 BL, 8 BR
const quadCell = (inside: (x: number, y: number) => boolean, col: number, row: number) =>
  QUADS[(inside(col + .25, row * 2 + .5) ? 1 : 0) | (inside(col + .75, row * 2 + .5) ? 2 : 0)
      | (inside(col + .25, row * 2 + 1.5) ? 4 : 0) | (inside(col + .75, row * 2 + 1.5) ? 8 : 0)]
```

**Braille plots** have the best line resolution:

```ts
const DOT = [[0x01, 0x08], [0x02, 0x10], [0x04, 0x20], [0x40, 0x80]]   // [dy][dx]
export const braille = (points: [number, number][], cols: number, rows: number): string[] => {
  const bits = Array.from({ length: rows }, () => Array(cols).fill(0))
  for (const [x, y] of points) {                    // x in [0, cols*2), y in [0, rows*4)
    const c = Math.floor(x / 2), r = Math.floor(y / 4)
    if (bits[r]?.[c] !== undefined) bits[r]![c] |= DOT[Math.floor(y) % 4]![Math.floor(x) % 2]!
  }
  return bits.map(row => row.map(b => String.fromCharCode(0x2800 + b)).join(''))
}
```

**Bars with fractional ends:**

```ts
const EIGHTHS = ' ▏▎▍▌▋▊▉█'
export const bar = (value: number, max: number, width: number) => {
  const e = Math.round((value / max) * width * 8)
  return '█'.repeat(Math.floor(e / 8)) + (e % 8 ? EIGHTHS[e % 8] : '')
}
```

**Axis-aligned layouts** (cards, tables, lists, kanban) need no canvas. Use `Box` flex with `borderStyle`. Use a canvas only when lines cross or connect.

**Icon fonts with a fallback.** Nerd Font icons look great but show as boxes without the font. filetree probes for a Nerd Font, uses it only when present (never on Desktop or over SSH), and offers a `glyphs: auto | plain | text` option. Always keep a plain-Unicode fallback (`▸ ▾ ● ○ × §`).

**Emoji are risky in terminals.** Their width varies between terminals. Measure them as 2 cells, or replace them with narrow glyphs on the terminal surface.

## 3. Vector graphics on Desktop: `Svg`

On Desktop, VS Code and mobile, the `Svg` element draws an SVG string (at most 131,072 characters) as an image. That gives you crisp icons, tree guide lines, chevrons, charts and curves, with no library.

```tsx
const NS = 'http://www.w3.org/2000/svg'
const icon = (d: string, color: string, size = 16) =>
  `<svg xmlns="${NS}" width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="${color}" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"><path d="${d}"/></svg>`

{Svg ? <Svg key="folder" source={icon(FOLDER_PATH, accent)} alt="folder" width={16} height={16} /> : <Text>▸</Text>}
```

- `alt` is required, and it's what screen readers and surfaces without `Svg` get.
- `width` and `height` are **CSS pixels**, not cells.
- **Animate with SMIL** (reliable only with `isInteractive: true`; without it the SVG is an image). A spinning refresh icon is `<g>…<animateTransform attributeName="transform" type="rotate" from="0 12 12" to="360 12 12" dur="900ms" repeatCount="indefinite"/></g>`. Change the element's `key` when you switch between spinning and still, so the image reloads.
- `isInteractive: true` draws the SVG in a sandboxed frame, so CSS `:hover`, `<title>` tooltips and SMIL triggers work. Scripts never run. Handle presses on an enclosing element (see §5).
- **Row graphics:** filetree draws each tree row's indent guides, chevron and file icon as one small SVG strip (`depth * 16 + 38` px wide, 24 px tall), then the name as `Text`. That gives IDE-quality rows with text that stays selectable.
- A 2 px-wide SVG `<rect>` makes a crisp cursor bar; position it with `position="absolute" left={0} top={0} bottom={0}`.
- Build charts the same way. A line chart is a `<polyline points="...">` computed from your data, and a pie is `<path d="M cx cy L ... A r r 0 large 1 ...">` arcs.

## 4. Real pixels in the terminal: `Image`

```tsx
<Image key="map" source={{ rgba: pixels.toBase64(), width: w, height: h }} columns={40} rows={12} alt="disk usage treemap" />
<Image source={{ png: pngBase64 }} columns={40} rows={12} alt="chart" />
<Image source={{ file: '/tmp/frame.png', format: 'png', generation: n }} columns={80} rows={25} alt="preview" />
```

- `columns`/`rows` (1–255) are the cell box, `alt` is required, and decoded bytes are at most 2 MiB (each side at most 2048 px for `rgba`). `file` and `shm` sources let the terminal read the pixels directly, so nothing passes through `$`.
- **Compute pixels yourself.** filetree paints a squarified treemap into a `Uint32Array`, with labels drawn from a tiny embedded bitmap font (glyph bits stored as base64 in a `.ts` file). prismantis anti-aliases pie edges by averaging 4×4 sub-samples per edge pixel.
- **Size to the real cell.** filetree probes the cell pixel size (a short `python3 -I` call reading the tty's `TIOCGWINSZ` via `$.process.run`) so pixels map 1:1 to cells. Without a probe, assume about 8×16 px.
- **Detect support** before choosing pixels: kitty (`KITTY_WINDOW_ID`), Ghostty (`TERM_PROGRAM=ghostty`), not inside tmux. Expose an option (`treemap: auto | image | text`) and always keep a glyph fallback.
- **Animate with `$.ui.blit({ requestId, key, source })`.** It swaps the picture at frame rate without rerunning `ui.render`. `Raster` works the same way with `cells`. In practice, keep frames ≥ 200 ms apart and under about 450 KB/s of base64 (kitty drops animation above that), avoid animating on iTerm2 before 3.7.8 (it leaks memory), and probe support by checking whether a `blit` is denied. See [ui-recipes.md](ui-recipes.md) §5.

## 5. Interactive components: `Client`

A `Client` is a second module, a `ClientModule`, that runs **on the drawing thread** with its own local state. Use it for anything that must react instantly: hover highlights, mouse clicks on arbitrary cells, drag scrollbars, per-character animation, keyboard navigation. Without it, every interaction is a round trip through a hook.

```tsx
// register.tsx / pane.tsx: mount it (module must be a string literal)
<Client key="rows" module="./rows.tsx" props={{ rows, active: cursorId, activeBg, hoverBg } satisfies RowsProps} />

// rows.tsx: no $ here. Plain props in, surface.post(...) out.
import type { ClientModule } from 'claude-code'
export type RowsProps = { rows: { id: string; text: string }[]; active: string; activeBg: string; hoverBg: string }
type Local = { hover: number; phase: number; ref: { stop?: () => void } }

const Rows: ClientModule<RowsProps, Local> = (props, surface) => {
  const { Box, Text } = surface.elements
  let s = surface.state
  if (s === undefined) {                                    // first call: init once
    s = { hover: -1, phase: 0, ref: {} }
    surface.setState(s)
    s.ref.stop = surface.every(90, () => {                  // local animation clock
      const cur = surface.state
      if (cur) surface.setState({ ...cur, phase: cur.phase + 1 })
    })
  }
  surface.onPointer(ev => {                                 // cells relative to this region
    const cur = surface.state ?? s
    if (ev.type === 'leave') return surface.setState({ ...cur, hover: -1 })
    if (ev.type === 'move' && !ev.button && ev.y !== cur.hover) surface.setState({ ...cur, hover: ev.y })
    const row = props.rows[ev.y]
    if (ev.type === 'down' && ev.button === 'right' && row) surface.post({ copy: row.id })
    else if (ev.type === 'down' && (ev.button ?? 'left') === 'left' && row) surface.post({ press: row.id, shift: Boolean(ev.shift) })
  })
  surface.onKey(k => surface.post({ key: k.key, ctrl: Boolean(k.ctrl) }))
  return (
    <Box flexDirection="column">
      {props.rows.map((r, i) => (
        <Box key={r.id} height={1} overflow="hidden"
             backgroundColor={r.id === props.active ? props.activeBg : i === s.hover ? props.hoverBg : undefined}>
          <Text wrap="truncate-end">{r.text}</Text>
        </Box>
      ))}
    </Box>
  )
}
export default Rows
```

Handle posts in the hooks module:

```tsx
on('ui.message', async ($, e, next) => {
  if (e.requestId !== 'my-pane' || e.element !== 'rows') return next(e)
  const d = e.data as { press?: string; copy?: string; key?: string }
  if (d.press) await select($, d.press)
  else if (d.copy) await $.ui.copy({ text: d.copy })
  return {}            // or { props: {...} } to hand the instance new props directly
})
```

Rules from the engine types:
- **Props are plain JSON** (at most 100,000 characters), not closures. New props reach the running instance with its state kept. Keep the same `key` to keep the instance.
- **Start timers and listeners once**, while `state` is still `undefined`. A `setState` on three renders in a row with no input between them is a render loop, and the instance unmounts.
- `onPointer` events have `type` (`down`/`move`/`up`/`enter`/`leave`), cell `x`/`y`, `button`, modifier keys, and `fine.{x,y}` sub-cell positions on kitty, Ghostty, iTerm2, WezTerm and foot. After a `down`, the instance captures the pointer until `up`, which makes drag scrollbars easy: `post({ scrollTo: y / (rows - 1) })`.
- `onKey` only fires after a click gives the instance focus, and Escape returns focus to the prompt.
- `post` sends at most one message per frame; a later post replaces an undelivered one. Client trees have the same limits as hook trees, and `Client`, `Raster` and `Image` are unavailable inside one.
- **Budget the tree yourself.** filetree's row client stops at about 1,500 rows or 70 KB of serialized tree and prints `… N more rows, use search`.
- **Animated shimmer:** color each character by its distance from a moving band (`band = phase * 1.6 % (len + 8) - 4`), stepping through a 4-tone palette. Run the timer only while something is lit, and stop it when nothing is.

### Hit-layer pattern (clickable anything)

`Svg`, `Image` and `Raster` take no `onPress`. To make an icon, a treemap tile or a whole row clickable on any surface, lay a transparent `Client` over it:

```tsx
<Box key={`row:${id}`} position="relative" flexDirection="row" hover={{ backgroundColor: hoverBg }}>
  {Svg ? <Svg source={rowSvg(depth, icon)} alt={name} width={w} height={24} /> : null}
  <Text>{name}</Text>
  <Box position="absolute" top={0} left={0} right={0} bottom={0}>
    <Client key={`hit:${id}`} module="./hit.tsx" props={{ id }} width="100%" height="100%" />
  </Box>
</Box>
```

`hit.tsx` returns `<Box width="100%" height="100%" />` and posts `{ press: id }` on a left `up` and `{ copy: id }` on a right `down`. For a treemap, one `Client` can cover the whole image and map `fine.x`/`fine.y` to the tile under the pointer from a list of tile rectangles passed as props.

## 6. Hover without any hook

`Box` and `Text` take a `hover` prop the surface applies by itself, with no hook call and no `Client`:

```tsx
<Box key="row-1" hover={{ backgroundColor: hoverBg }}>          {/* row highlight */}
  <Text hover={{ color: accent, underline: true }}>open</Text>
</Box>
```

- `hover` applies while the pointer is over the **nearest keyed `Box`**. A `Text` hover outside a keyed `Box` must name a `scope`.
- **Hover groups:** elements with the same `hover.scope` (1–64 chars) light together across sites. For example, a mark in a transcript message and a row in your pane can highlight each other.
- **Reveal on hover:** draw a `Box` with `display="none"` and `hover={{ display: 'flex' }}`. Combine it with `position="absolute"` for a tooltip or preview card that doesn't reflow anything:

```tsx
<Box key="tip-host"><Text>ⓘ</Text>
  <Box position="absolute" top={-2} left={2} display="none" hover={{ display: 'flex' }} borderStyle="round" paddingX={1}>
    <Text>details here</Text>
  </Box>
</Box>
```

- A hover can only change styles that don't move siblings: colors, border style, `display` on absolute boxes, and offsets of absolute boxes.
- For hover-driven text elsewhere (a header hint naming the hovered button), have a `Client` post `{ over: true }` and redraw the header from a hook.

## 7. Measure width correctly

`string.length` is wrong for CJK, emoji and combining marks. Measure **terminal cells**:

```ts
const segmenter = new Intl.Segmenter()
const WIDE = /[ᄀ-ᅟ⺀-꓏가-힣豈-﫿︰-﹏＀-｠￠-￦]|\p{Extended_Pictographic}/u
const ZERO = /^[\p{M}\p{Default_Ignorable_Code_Point}]+$/u
export const cellWidth = (s: string) =>
  /^[ -~]*$/.test(s) ? s.length
  : [...segmenter.segment(s)].reduce((w, { segment: g }) => w + (ZERO.test(g) ? 0 : WIDE.test(g) ? 2 : 1), 0)
```

- Lay out to `e.props.bodyColumns` (Pane, AbovePrompt) or `e.viewport.columns` (transcript sites), minus padding, with a floor of about 20 columns.
- Truncate by grapheme with `…`, or let the engine do it with `<Text wrap="truncate-end">` (also `truncate-start` for paths and `truncate-middle`) inside a `Box` that has `flexShrink={1}` and `overflow="hidden"`.
- Right-align trailing info with a spacer: `left parts`, `<Box flexGrow={1} />`, then `right parts`.

## 8. One drawing, every surface

`e.surface` is `'terminal'`, `'desktop'`, `'vscode'` or `'mobile'`.

| | Terminal | Desktop / VS Code |
|---|---|---|
| Elements | `Raster`, `Image`, `Client`, `Input`, `Select` | `Svg`, `Input`, `Select`; `Client` on Desktop only (not VS Code); mobile has no `Input`/`Select`/`Client` |
| Text | Monospace cells, one size | `size` (`caption`, `footnote`, `body`, `heading`, `title`), `weight` (`regular`…`bold`), `mono`, `tabular` digits |
| Sizes | Integer cells | Fractional `height`/`width` (e.g. `height={0.06}` hairline); `Svg` sizes in CSS px |
| Lines | `'─'.repeat(n)` | Thin `Box` with `backgroundColor`, or `Svg` |
| Scrolling | Your own (`ui.scroll` hook, scrollbar glyphs) | Native scroll works; let it |
| Colors | Palette indices follow the terminal theme | Theme keys follow Claude's theme |

- **Decide the surface once** in your view model (`desk`, `grid`, `images` flags). Pure drawing code branches on those flags.
- **Desktop gets real typography.** Use `size="footnote"` for metadata, `weight="semibold"` for names, and `tabular` for counts and line numbers that change or stack. The terminal ignores all of these, so they cost nothing.
- **Pane placement:** in the terminal a pane docks beside the transcript only in the fullscreen layout and at 110 columns or more. Otherwise it's `placement: 'inline'` above the prompt. Check `e.props.placement` and draw a compact version, or tell the user what's needed (filetree's `/filetree` replies "needs /tui fullscreen" or "widen to 110 columns"). `$.ui.panes()` lists panes with `isShown` and `isPlaced`, which makes a toggle command easy.
- Fill the pane: give the root `Box` `minHeight={e.props.scroll.bodyRows}`, and add a `<Box flexGrow={1} />` before the footer so it sticks to the bottom.

## 9. Theming and color

- **Semantic tokens, not raw hex.** Drawing code asks for `theme.accent`, `theme.muted` or `theme.urgent`. Presets fill the tokens, and options override them.
- **Let the user's theme own the colors.** These are the best defaults:
  - Terminal: palette indices like `'ansi256(2)'` (green) and `'ansi256(1)'` (red), plus `dimColor` for muted text. They follow whatever terminal theme the user runs.
  - Desktop: **theme keys** as colors: `'suggestion'` (accent), `'error'`, `'success'`, `'warning'`, `'subtle'`, `'inactive'`, `'diffAdded'`, `'diffRemoved'`, `'claude'`, `'permission'`. They follow Claude's light or dark theme automatically.
  - Use hard-coded hex only for what you paint yourself: SVG fills, pixel images, shimmer tones.
- **Alpha hex** works for subtle tints: `${accentHex}1f` (about 12%) for a cursor-row background.
- **Contrast gate in CI.** filetree runs a script that checks every hex color it picks against several dark (`#000`, `#1e1e1e`, `#282c34`) and light (`#fff`, `#fafafa`) backgrounds, including tints composited over them. Floors are 4.5 (WCAG AA text), 3 for large text and fills, 7 for AAA, and about 1.3 for selection versus background. Fix the color; never lower the gate.
- When painting text on a colored fill (treemap tiles, chips), pick whichever ink has the higher contrast ratio, and lower the fill's alpha until text clears 4.5.

```ts
const rgb = (h: string) => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16))
const lum = (h: string) => { const [r, g, b] = rgb(h).map(v => { v /= 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4 }); return 0.2126 * r! + 0.7152 * g! + 0.0722 * b! }
export const contrast = (a: string, b: string) => { const [hi, lo] = [lum(a), lum(b)].sort((x, y) => y - x); return (hi! + 0.05) / (lo! + 0.05) }
export const mix = (a: string, b: string, t: number) => '#' + rgb(a).map((v, i) => Math.round(v * (1 - t) + rgb(b)[i]! * t).toString(16).padStart(2, '0')).join('')
export const inkOn = (fill: string, inks: string[]) => inks.reduce((best, c) => (contrast(c, fill) > contrast(best, fill) ? c : best))
```

- **Detect a light terminal** before choosing tones. Read the terminal's own config where you can (filetree parses Ghostty's), or offer an option. Ship light and dark tone sets.
- **Transparent pane (version-dependent; check your `.d.ts` for `backgroundColor` on `PaneOpenArgs`):** newer engines (filetree gates on 2.1.311, using `$.session.version()`) accept `backgroundColor: 'transparent'` in `$.ui.open`, so the terminal's background shows through. Otherwise give the pane's root `Box` an explicit `backgroundColor`.
- Some engine versions let you restyle Desktop as a whole with `$.theme.set({ colors, overrideColorScheme })`. It isn't in every version's types, so grep yours first. prismantis builds a full role map (`surface-*`, `text-*`, `fill-*`, `border*`) with contrast floors.
- Accept user palette overrides as a `key=#hex` string option, validate each entry, and toast what was ignored.

## 10. Options with `userConfig`

```json
"userConfig": {
  "chartStyle": { "type": "string", "title": "Chart style", "description": "bars: … braille: …", "options": ["auto", "bars", "braille"], "default": "auto" }
}
```

- Values are flat primitives, and a `string` with `options` becomes a picker in `/config`.
- Options are fixed for one activation. A change reloads the plugin and calls `register(on, options)` again, so read them once in `register`.
- Prefer `auto` defaults that detect the environment (Nerd Font, kitty graphics, surface), with explicit overrides.
- When a feature has several plausible looks, ship 3 or 4 styles behind one option rather than a pile of booleans. Describe each value in `description`.
- React to `/config theme` and similar changes with an `on('config.set', …)` hook.

## 11. Performance and limits

- **Tree limits:** 20,000 nodes, 32 levels deep, 100,000 serialized characters. Past them the tree is refused and Claude Code silently draws its own fallback, or a `Client` instance unmounts. Merge runs, cap rows, and show "… N more".
- **Cache derived work** in a bounded LRU keyed by everything the output depends on (text, columns, theme, surface):

```ts
export const memo = <T>(cache: Map<string, T>, key: string, make: () => T, limit = 200): T => {
  const hit = cache.get(key)
  if (hit !== undefined) { cache.delete(key); cache.set(key, hit); return hit }
  const v = make(); cache.set(key, v)
  if (cache.size > limit) cache.delete(cache.keys().next().value!)
  return v
}
```

- **Render hooks must not write `$.state`.** Load outside the render: `$.clock.after(0, …)` writes an atom, and `read($, atom)` in the render subscribes and redraws. Draw a placeholder until the value arrives.
- **Never block a render on slow work.** Run `du`, `git` or scans with `void (async () => …)()` or a `$.clock.every` poll, keep results in module state, and `$.ui.invalidate('ui.render')` when they change.
- **Animate locally.** `Client` timers (`surface.every`) and `$.ui.blit` redraw without rerunning hooks. `$.ui.invalidate` is throttled (10/s, or 30/s for a visible pane).
- **Degrade gracefully.** If something can't be drawn well (too wide, failed parse, unsupported surface), `return next(e)`.

## 12. Testing visuals

Run `claude plugin test .`, which needs no session and no network. `claude-code/testing` only exists inside that harness, so `bun test` and `vitest` can't resolve it.

```tsx
import { expect, mock, test } from 'claude-code/testing'

for (const surface of ['terminal', 'desktop'] as const)
  test(`tree rows on ${surface}`, { options: { glyphs: 'plain' } }, async ($, on) => {
    mock.env(on, { HOME: '/home/u' })
    const clock = mock.clock(on, { now: 1_800_000_000_000 })
    mock.store(on)
    await $.session.start({ cwd: '/repo', surface, isInteractive: true })
    const ui = await $.ui.mount({ plugin: 'my-mod', surface, component: 'Pane', requestId: 'my-pane',
      props: { bodyColumns: 60, placement: 'dock', isFocused: true, scroll: { bodyRows: 30, offset: 0 } } })
    await ui.post({ press: '/repo/README.md' }, { in: 'rows' })         // what the Client would post
    await ui.pointer({ type: 'up', x: 0, y: 0, in: 'button-refresh' })  // simulate the mouse on a Client
    await clock.advance(2_000)                                          // drive $.clock timers
    expect(JSON.stringify(await ui.drawn({ in: 'rows' }))).toContain('README.md')   // a Client's own tree
    expect(await ui.find({ type: 'Text', text: /^README\.md$/ })).toBeDefined()
    await ui.unmount()
  })
```

- `ui.find({ text })` matches substrings, so anchor with `/^…$/`.
- `ui.drawn({ in: key })` returns a `Client`'s rendered tree, while `ui.post`, `ui.pointer`, `ui.key` and `ui.press` drive input.
- If your hook calls `next(e)`, register an engine stand-in that returns a tree.
- Loop every visual test over `terminal` and `desktop`, and over each style option.
- **Tests prove the tree; only a real render proves the look.** Run `claude --plugin-dir ./my-mod` and look at the result in a narrow inline pane, a wide docked pane, a light theme, a dark theme, and on Desktop. Ship a `/my-mod demo` that shows every feature at once. Keep GIFs or screenshots in `docs/` up to date.

## 13. UX checklist

- [ ] Works at 20 and 200 columns, and in both inline and docked panes. Truncates with `…`.
- [ ] Terminal uses glyphs, `Raster` or `Image`; Desktop uses `Svg` and real typography; every picture has `alt`.
- [ ] Readable in light and dark themes. Contrast is gated in CI. Colors default to palette indices and theme keys.
- [ ] Hover feedback on every pressable row (a `hover` prop, or local `Client` state).
- [ ] Mouse: left click selects, right click copies; scrollbar is draggable; `Svg` and `Image` are clickable through a hit layer.
- [ ] Keyboard: every `Button` has a `key` and a `hotkey`; there's a visible hotkey footer or a `?` overlay; Escape returns focus.
- [ ] Animation runs only while something is active, and timers stop when idle.
- [ ] Stays far below 20,000 nodes on the largest real input, with "… N more" beyond that.
- [ ] Nerd Font and emoji have plain-Unicode fallbacks.
- [ ] Every look is a `userConfig` option with an `auto` default.
- [ ] Falls back to `next(e)` when it can't draw well.

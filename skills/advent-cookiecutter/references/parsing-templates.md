# Parsing Templates

Paste the matching section verbatim as the `parse()` function in the generated `.cpp` file.
Pick exactly one section based on the classification from SKILL.md Step 2.

---

## Grid

Use when all lines have equal length and contain only printable non-digit ASCII (e.g. `#`, `.`, `@`).

```cpp
vector<string> parse(){
  vector<string> grid;
  string line;
  while (getline(cin, line))
    grid.push_back(line);
  return grid;
}
// int rows = grid.size();
// int cols = grid[0].size();
// grid[r][c] accesses cell at row r, column c
```

---

## Integer-Tokens

Use when every line contains only integers (and whitespace / minus signs).

```cpp
vector<int> parse(){
  vector<int> vals;
  int v;
  while (cin >> v)
    vals.push_back(v);
  return vals;
}
```

If the input has multiple integers per line that must be kept grouped, use this variant instead:

```cpp
vector<vector<int>> parse(){
  vector<vector<int>> rows;
  string line;
  while (getline(cin, line)){
    if (line.empty()) continue;
    vector<int> row;
    istringstream ss(line);
    int v;
    while (ss >> v)
      row.push_back(v);
    rows.push_back(row);
  }
  return rows;
}
```

---

## Comma-Separated

Use when lines contain comma-delimited tokens (may be integers, strings, or mixed).

```cpp
vector<vector<string>> parse(){
  vector<vector<string>> rows;
  string line;
  while (getline(cin, line)){
    if (line.empty()) continue;
    vector<string> row;
    istringstream ss(line);
    string token;
    while (getline(ss, token, ','))
      row.push_back(token);
    rows.push_back(row);
  }
  return rows;
}
```

---

## Space-Separated

Use when each line contains a mix of space-separated words and/or numbers.

```cpp
vector<vector<string>> parse(){
  vector<vector<string>> rows;
  string line;
  while (getline(cin, line)){
    if (line.empty()) continue;
    vector<string> row;
    istringstream ss(line);
    string token;
    while (ss >> token)
      row.push_back(token);
    rows.push_back(row);
  }
  return rows;
}
```

---

## Structured-sscanf

Use when lines follow a fixed template (e.g. `"p=%d,%d v=%d,%d"` or `"Sensor at x=%d, y=%d"`).
Adjust the struct fields and format string to match your input.

```cpp
struct Entry {
  int a, b, c, d;
};

vector<Entry> parse(){
  vector<Entry> entries;
  string line;
  while (getline(cin, line)){
    if (line.empty()) continue;
    Entry e;
    // TODO: adjust format string to match your input
    sscanf(line.c_str(), "%d %d %d %d", &e.a, &e.b, &e.c, &e.d);
    entries.push_back(e);
  }
  return entries;
}
```

---

## Multi-Group

Use when blank lines separate distinct groups of lines.

```cpp
vector<vector<string>> parse(){
  vector<vector<string>> groups;
  vector<string> group;
  string line;
  while (getline(cin, line)){
    if (line.empty()){
      if (not group.empty()){
        groups.push_back(group);
        group.clear();
      }
    } else {
      group.push_back(line);
    }
  }
  if (not group.empty())
    groups.push_back(group);
  return groups;
}
```

---

## Stub

Use when the format is ambiguous or the input file could not be read.

```cpp
// TODO: implement parse() — input format not recognized
auto parse(){
  vector<string> lines;
  string line;
  while (getline(cin, line))
    lines.push_back(line);
  return lines;
}
```

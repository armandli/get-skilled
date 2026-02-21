# Struct Templates

Paste each labeled section verbatim into the generated `.cpp` file.
Each section is self-contained. Include only the sections listed in the SKILL.md Step 3 table.

**Important ordering rule**: When D is included, emit D before P so `P::operator+=` can reference `D` inline.

---

## P-2D-simple

Use for `p2` (position only, no direction). No D dependency.

```cpp
struct P {
  int x, y;

  P() = default;
  P(int x, int y): x(x), y(y) {}
};
```

---

## D-2D

```cpp
struct D {
  int x, y;

  D() = default;
  constexpr D(int x, int y): x(x), y(y) {}
};
```

---

## P-2D-full

Use after `D-2D` (D must be defined first). Includes `operator+=`.

```cpp
struct P {
  int x, y;

  P() = default;
  P(int x, int y): x(x), y(y) {}

  P& operator+=(const D& d){
    x += d.x;
    y += d.y;
    return *this;
  }
};
```

---

## Comparators-2D

Free comparison operators for P. Include for all 2D specifiers.

```cpp
bool operator==(const P& a, const P& b){
  return a.x == b.x and a.y == b.y;
}

bool operator!=(const P& a, const P& b){
  return not operator==(a, b);
}

bool operator<(const P& a, const P& b){
  if (a.x < b.x)      return true;
  else if (a.x > b.x) return false;
  if (a.y < b.y)      return true;
  else                return false;
}
```

---

## Free-Operators-2D

Free functions mixing P and D. Include for pd2 and pdpd2 (after D-2D and P-2D-full).

```cpp
P operator+(const P& p, const D& d){
  return P(p.x + d.x, p.y + d.y);
}

bool operator==(const D& a, const D& b){
  return a.x == b.x and a.y == b.y;
}
```

---

## hash-P-2D

```cpp
namespace std {
template <>
struct hash<P> {
  size_t operator()(const P& p) const {
    return ((size_t)(unsigned)p.x << 32U) | (size_t)(unsigned)p.y;
  }
};
}  // namespace std
```

---

## Direction-Constants-2D

```cpp
[[maybe_unused]] constexpr D NORTH(-1,  0);
[[maybe_unused]] constexpr D SOUTH( 1,  0);
[[maybe_unused]] constexpr D EAST ( 0,  1);
[[maybe_unused]] constexpr D WEST ( 0, -1);
[[maybe_unused]] constexpr D NE   (-1,  1);
[[maybe_unused]] constexpr D NW   (-1, -1);
[[maybe_unused]] constexpr D SE   ( 1,  1);
[[maybe_unused]] constexpr D SW   ( 1, -1);

[[maybe_unused]] constexpr array<D, 4> DIRECTIONS     = {NORTH, SOUTH, EAST, WEST};
[[maybe_unused]] constexpr array<D, 8> ALL_DIRECTIONS = {NORTH, SOUTH, EAST, WEST, NE, NW, SE, SW};
```

---

## hashing-turn-helpers

```cpp
constexpr size_t hashing(D d){
  return ((size_t)(d.x + 1) << 2) | (size_t)(d.y + 1);
}

D left_turn(D dir){
  switch (hashing(dir)){
  break; case hashing(NORTH): return WEST;
  break; case hashing(WEST):  return SOUTH;
  break; case hashing(SOUTH): return EAST;
  break; case hashing(EAST):  return NORTH;
  break; default: assert(false); return dir;
  }
}

D right_turn(D dir){
  switch (hashing(dir)){
  break; case hashing(NORTH): return EAST;
  break; case hashing(EAST):  return SOUTH;
  break; case hashing(SOUTH): return WEST;
  break; case hashing(WEST):  return NORTH;
  break; default: assert(false); return dir;
  }
}
```

---

## PD-2D

```cpp
struct PD {
  P pos;
  D dir;

  PD(const P& pos, const D& dir): pos(pos), dir(dir) {}
};

bool operator==(const PD& a, const PD& b){
  return a.pos == b.pos and a.dir == b.dir;
}
```

---

## hash-PD-2D

```cpp
namespace std {
template <>
struct hash<PD> {
  size_t operator()(const PD& pd) const {
    size_t hp = hash<P>{}(pd.pos);
    size_t hd = (size_t)(pd.dir.x + 1) * 3 + (size_t)(pd.dir.y + 1);
    return hp ^ (hd << 32U);
  }
};
}  // namespace std
```

---

## P-3D-simple

Use for `p3` (position only, no direction). No D dependency.

```cpp
struct P {
  short x, y, z;

  P() = default;
  P(int x, int y, int z): x((short)x), y((short)y), z((short)z) {}
};
```

---

## D-3D

```cpp
struct D {
  short x, y, z;

  D() = default;
  constexpr D(int x, int y, int z): x((short)x), y((short)y), z((short)z) {}
};
```

---

## P-3D-full

Use after `D-3D` (D must be defined first). Includes `operator+=`.

```cpp
struct P {
  short x, y, z;

  P() = default;
  P(int x, int y, int z): x((short)x), y((short)y), z((short)z) {}

  P& operator+=(const D& d){
    x = (short)(x + d.x);
    y = (short)(y + d.y);
    z = (short)(z + d.z);
    return *this;
  }
};
```

---

## Comparators-3D

Free comparison operators for P. Include for all 3D specifiers.

```cpp
bool operator==(const P& a, const P& b){
  return a.x == b.x and a.y == b.y and a.z == b.z;
}

bool operator!=(const P& a, const P& b){
  return not operator==(a, b);
}

bool operator<(const P& a, const P& b){
  if (a.x != b.x) return a.x < b.x;
  if (a.y != b.y) return a.y < b.y;
  return a.z < b.z;
}
```

---

## Free-Operators-3D

Free functions mixing P and D. Include for pd3 and pdpd3 (after D-3D and P-3D-full).

```cpp
P operator+(const P& p, const D& d){
  return P(p.x + d.x, p.y + d.y, p.z + d.z);
}

bool operator==(const D& a, const D& b){
  return a.x == b.x and a.y == b.y and a.z == b.z;
}
```

---

## hash-P-3D

```cpp
namespace std {
template <>
struct hash<P> {
  size_t operator()(const P& p) const {
    return ((size_t)(uint16_t)p.x << 32U)
         | ((size_t)(uint16_t)p.y << 16U)
         |  (size_t)(uint16_t)p.z;
  }
};
}  // namespace std
```

---

## Direction-Constants-3D

```cpp
// 6 cardinal directions
[[maybe_unused]] constexpr D UP   (-1,  0,  0);
[[maybe_unused]] constexpr D DOWN ( 1,  0,  0);
[[maybe_unused]] constexpr D NORTH( 0, -1,  0);
[[maybe_unused]] constexpr D SOUTH( 0,  1,  0);
[[maybe_unused]] constexpr D WEST ( 0,  0, -1);
[[maybe_unused]] constexpr D EAST ( 0,  0,  1);

[[maybe_unused]] constexpr array<D, 6> DIRECTIONS = {UP, DOWN, NORTH, SOUTH, WEST, EAST};

// All 26 neighbors
[[maybe_unused]] constexpr array<D, 26> ALL_DIRECTIONS = {
  D(-1,-1,-1), D(-1,-1, 0), D(-1,-1, 1),
  D(-1, 0,-1), D(-1, 0, 0), D(-1, 0, 1),
  D(-1, 1,-1), D(-1, 1, 0), D(-1, 1, 1),
  D( 0,-1,-1), D( 0,-1, 0), D( 0,-1, 1),
  D( 0, 0,-1),               D( 0, 0, 1),
  D( 0, 1,-1), D( 0, 1, 0), D( 0, 1, 1),
  D( 1,-1,-1), D( 1,-1, 0), D( 1,-1, 1),
  D( 1, 0,-1), D( 1, 0, 0), D( 1, 0, 1),
  D( 1, 1,-1), D( 1, 1, 0), D( 1, 1, 1),
};
```

---

## PD-3D

```cpp
struct PD {
  P pos;
  D dir;

  PD(const P& pos, const D& dir): pos(pos), dir(dir) {}
};

bool operator==(const PD& a, const PD& b){
  return a.pos == b.pos and a.dir == b.dir;
}
```

---

## hash-PD-3D

```cpp
namespace std {
template <>
struct hash<PD> {
  size_t operator()(const PD& pd) const {
    size_t hp = hash<P>{}(pd.pos);
    size_t hd = (size_t)(pd.dir.x + 1) * 9
              + (size_t)(pd.dir.y + 1) * 3
              + (size_t)(pd.dir.z + 1);
    return hp ^ (hd << 48U);
  }
};
}  // namespace std
```

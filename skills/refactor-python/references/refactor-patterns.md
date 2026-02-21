# Refactor Patterns Reference

Each section covers one **operand type** and lists the signals to look for,
similarity thresholds, Auto/Suggest conditions, the target utility class, and
before/after examples.

---

## R01 — String Operations

**Utility class:** `StringUtils` in `utils/string_utils.py`

### Signals
- Same prefix or suffix stripped in ≥ 2 places (e.g., `s[len("PREFIX"):]`,
  `s.removeprefix("PREFIX")`, `s.lstrip("PREFIX")`)
- Identical regex pattern applied in ≥ 2 functions or files
  (e.g., `re.sub(r'\s+', ' ', text)`)
- Same format string template used in ≥ 2 places to build an output string
- Same sanitization pipeline: strip → lower → replace applied in sequence
- Same truncation-with-ellipsis pattern
  (e.g., `text[:n] + "..."` applied in ≥ 2 places)

### Similarity Threshold
| Level | Description |
|-------|-------------|
| Exact | Identical code block, same string literal |
| Parameterized | Same operation, different string constant or length limit |
| Semantic | Same result via different Python idioms (e.g., `lstrip` vs slice vs `removeprefix`) |

### Auto Conditions
- Same prefix/suffix literal stripped in ≥ 2 locations → extract with a
  `prefix: str` parameter
- Same regex `re.sub` / `re.match` pattern (identical pattern string) in ≥ 2
  locations → extract with a compiled-pattern helper
- Same truncation length and sentinel in ≥ 3 locations

### Suggest Conditions
- Two locations only, or the regex pattern differs by small amounts (may have
  diverged intentionally)
- Sanitization pipeline where one call site has extra steps not present in the
  others (asymmetric pipelines)
- Any string operation that relies on locale-specific behavior

### Before / After Example

```python
# Before (in multiple places)
name = raw.removeprefix("user_")
label = text.removeprefix("user_")

# After — utils/string_utils.py
"""Shared string manipulation utilities."""

class StringUtils:
    @staticmethod
    def strip_prefix(text: str, prefix: str) -> str:
        """Return text with prefix removed if present."""
        return text.removeprefix(prefix)

# Updated call sites
from utils.string_utils import StringUtils

name  = StringUtils.strip_prefix(raw, "user_")
label = StringUtils.strip_prefix(text, "user_")
```

---

## R02 — Numeric / Mathematical Calculations

**Utility class:** named after the domain (e.g., `RateCalculator`,
`UnitConverter`, `StatsUtils`) in `utils/numeric_utils.py`

### Signals
- Same formula appearing in ≥ 2 functions (e.g., compound interest:
  `principal * (1 + rate) ** periods`)
- Same unit conversion (km ↔ mi, °C ↔ °F, etc.) applied in multiple places
- Same rounding strategy: `round(x, n)` with the same `n` in ≥ 2 call sites
  where both sites share business meaning
- Same normalization / min-max scaling formula:
  `(x - min_val) / (max_val - min_val)`
- Identical arithmetic expression with named constants in ≥ 2 files

### Similarity Threshold
| Level | Description |
|-------|-------------|
| Exact | Identical formula, identical coefficient literals |
| Parameterized | Same formula, varying rate/period/coefficient (extract as parameter) |
| Semantic | Algebraically equivalent but written differently — **Suggest only** |

### Auto Conditions
- Exact or parameterized formula in ≥ 2 locations, no side effects, pure
  function (inputs → output only)
- Unit conversion: same conversion factor used in ≥ 2 places

### Suggest Conditions
- Algebraically equivalent expressions (verify manually before merging)
- Formulas inside `try/except` blocks catching `ZeroDivisionError` or
  `OverflowError` where exception handling logic differs between sites
- Formulas that mutate state or write to external resources

### Before / After Example

```python
# Before (in multiple places)
monthly_payment = principal * rate / (1 - (1 + rate) ** -n_payments)
cost = loan_amount * interest_rate / (1 - (1 + interest_rate) ** -terms)

# After — utils/numeric_utils.py
"""Shared numeric and financial calculation utilities."""

class RateCalculator:
    @staticmethod
    def amortized_payment(principal: float, rate: float, n_payments: int) -> float:
        """Return the fixed periodic payment for an amortized loan."""
        return principal * rate / (1 - (1 + rate) ** -n_payments)

# Updated call sites
from utils.numeric_utils import RateCalculator

monthly_payment = RateCalculator.amortized_payment(principal, rate, n_payments)
cost = RateCalculator.amortized_payment(loan_amount, interest_rate, terms)
```

---

## R03 — Date and Time

**Utility class:** `DateUtils` in `utils/date_utils.py`

### Signals
- Same `strftime` / `strptime` format string used in ≥ 2 places
- Same business-day offset calculation (add N workdays, skip weekends)
- Same timezone conversion applied in ≥ 2 functions
- Same age or delta calculation: `(date.today() - birthdate).days // 365`
- Same date range generation pattern

### Similarity Threshold
| Level | Description |
|-------|-------------|
| Exact | Identical format string and surrounding logic |
| Parameterized | Same operation, different timezone, different format string (extract as parameter) |
| Semantic | Same result computed differently (e.g., `timedelta` vs `dateutil`) — **Suggest only** |

### Auto Conditions
- Identical `strftime` format string in ≥ 2 locations → extract with a
  `dt: datetime` parameter
- Identical timezone conversion in ≥ 2 functions using the same `pytz`/`zoneinfo`
  zone name

### Suggest Conditions
- Business-day offsets that skip holidays (holiday list may differ)
- Date calculations that mix naive and aware datetimes across call sites
- Any date logic involving DST transitions

### Before / After Example

```python
# Before (in multiple places)
display_date = event.start.strftime("%Y-%m-%d %H:%M")
log_entry = record.timestamp.strftime("%Y-%m-%d %H:%M")

# After — utils/date_utils.py
"""Shared date and time formatting utilities."""
from datetime import datetime

class DateUtils:
    ISO_DATETIME_FMT = "%Y-%m-%d %H:%M"

    @staticmethod
    def format_datetime(dt: datetime) -> str:
        """Return datetime formatted as 'YYYY-MM-DD HH:MM'."""
        return dt.strftime(DateUtils.ISO_DATETIME_FMT)

# Updated call sites
from utils.date_utils import DateUtils

display_date = DateUtils.format_datetime(event.start)
log_entry    = DateUtils.format_datetime(record.timestamp)
```

---

## R04 — Collections

**Utility class:** `CollectionUtils` in `utils/collection_utils.py`

### Signals
- Same filter predicate applied to different lists in ≥ 2 places
  (e.g., `[x for x in items if x.active and x.role == "admin"]`)
- Same sort key expression repeated (e.g., `sorted(lst, key=lambda x: x.score)`)
- Same deduplication pattern: `list(dict.fromkeys(items))` or
  `seen = set(); [seen.add(x) or x for x in items if x not in seen]`
- Same partition-by-predicate pattern:
  splitting a list into two lists based on a condition

### Similarity Threshold
| Level | Description |
|-------|-------------|
| Exact | Identical comprehension including predicate literals |
| Parameterized | Same structure, differing attribute name or threshold (extract as parameter) |
| Semantic | Equivalent result via different collection idioms — **Suggest only** |

### Auto Conditions
- Identical filter predicate in ≥ 2 locations operating on same element type
- Identical sort key in ≥ 2 locations
- Identical deduplication pattern (exact code match) in ≥ 2 locations

### Suggest Conditions
- Predicates that close over outer-scope mutable state
- Filter + transform combined in one comprehension (extraction may change
  intermediate representation)
- Partitioning logic where the two halves are used in different `try/except`
  scopes

### Before / After Example

```python
# Before (in multiple places)
active_admins = [u for u in users if u.active and u.role == "admin"]
admin_list    = [m for m in members if m.active and m.role == "admin"]

# After — utils/collection_utils.py
"""Shared collection filtering and sorting utilities."""
from typing import TypeVar, Callable, Iterable

T = TypeVar("T")

class CollectionUtils:
    @staticmethod
    def filter_active_admins(items: Iterable[T]) -> list[T]:
        """Return items where .active is True and .role == 'admin'."""
        return [x for x in items if x.active and x.role == "admin"]

# Updated call sites
from utils.collection_utils import CollectionUtils

active_admins = CollectionUtils.filter_active_admins(users)
admin_list    = CollectionUtils.filter_active_admins(members)
```

---

## R05 — Validation

**Utility class:** `Validators` in `utils/validators.py`

### Signals
- Same guard pattern repeated: `if not x or len(x) < n: raise ValueError(...)`
- Same email or phone regex validation in ≥ 2 places
- Same range check: `if not (MIN <= value <= MAX): raise ...`
- Same non-empty-string check with the same error message
- Same type + range check combined (e.g., `isinstance(x, int) and x > 0`)

### Similarity Threshold
| Level | Description |
|-------|-------------|
| Exact | Identical guard expression and error message |
| Parameterized | Same guard shape, different threshold/field name (extract as parameter) |
| Semantic | Equivalent but raises different exception types — **Suggest only** |

### Auto Conditions
- Identical guard pattern (same predicate, same exception class) in ≥ 2
  locations
- Same regex pattern string in ≥ 2 locations for the same data type (email,
  phone, postal code)

### Suggest Conditions
- Same guard expression but different exception types or messages across sites
  (semantics may diverge intentionally)
- Validation inside a `try/except` where the caller depends on the specific
  exception type
- Guards that also perform logging or metric emission alongside raising

### Before / After Example

```python
# Before (in multiple places)
if not email or "@" not in email:
    raise ValueError("Invalid email address")
if not user_email or "@" not in user_email:
    raise ValueError("Invalid email address")

# After — utils/validators.py
"""Input validation utilities."""
import re

class Validators:
    _EMAIL_RE = re.compile(r"^[^@]+@[^@]+\.[^@]+$")

    @staticmethod
    def validate_email(email: str) -> None:
        """Raise ValueError if email is not a valid address."""
        if not email or not Validators._EMAIL_RE.match(email):
            raise ValueError("Invalid email address")

# Updated call sites
from utils.validators import Validators

Validators.validate_email(email)
Validators.validate_email(user_email)
```

---

## R06 — I/O / Serialization

**Utility class:** `SerializationUtils` in `utils/serialization_utils.py`

### Signals
- Same JSON key extraction chain: `data["a"]["b"]["c"]` with the same key
  sequence in ≥ 2 places
- Same CSV row normalization: strip whitespace, cast types, fill defaults
- Same file-path construction pattern:
  `os.path.join(BASE_DIR, category, f"{name}.json")` repeated with same
  `BASE_DIR`
- Same JSON load + key access + default fallback pattern
- Same `open` / `json.dumps` / `json.loads` wrapper with identical encoding
  arguments

### Similarity Threshold
| Level | Description |
|-------|-------------|
| Exact | Identical path construction or key chain |
| Parameterized | Same structure, varying key name or base directory (extract as parameter) |
| Semantic | Equivalent result via different I/O libraries — **Suggest only** |

### Auto Conditions
- Identical file-path construction in ≥ 2 locations (same base directory,
  same join structure)
- Identical JSON key extraction chain in ≥ 2 locations

### Suggest Conditions
- File I/O inside `try/except` blocks where exception handling differs
- Patterns that mix reading and writing state in the same block
- Serialization that relies on ordering (e.g., `json.dumps` with `sort_keys`)
  where different call sites may have differing requirements

### Before / After Example

```python
# Before (in multiple places)
path_a = os.path.join(BASE_DIR, "reports", f"{report_id}.json")
path_b = os.path.join(BASE_DIR, "reports", f"{doc_id}.json")

# After — utils/serialization_utils.py
"""File path construction and serialization utilities."""
import os

BASE_DIR = os.environ.get("APP_BASE_DIR", "/data")

class SerializationUtils:
    @staticmethod
    def report_path(report_id: str, base_dir: str = BASE_DIR) -> str:
        """Return the canonical path for a report JSON file."""
        return os.path.join(base_dir, "reports", f"{report_id}.json")

# Updated call sites
from utils.serialization_utils import SerializationUtils

path_a = SerializationUtils.report_path(report_id)
path_b = SerializationUtils.report_path(doc_id)
```

---

## R07 — Domain-specific

**Utility class:** domain-named class (e.g., `TaxCalculator`, `ScoringEngine`)
in `utils/<domain>_utils.py`

This is a catch-all for business formulas that do not fit cleanly into the
categories above — tax brackets, scoring algorithms, fee calculations, penalty
schedules, rate tables, etc.

### Signals
- An identical arithmetic expression referencing named domain constants in ≥ 2
  files (e.g., same tax rate applied multiple ways)
- Same scoring formula or weighted sum in ≥ 2 functions
- Same penalty or discount calculation referenced in multiple modules
- Named constants defined redundantly in multiple files
  (e.g., `TAX_RATE = 0.07` in `billing.py` and `invoicing.py`)

### Similarity Threshold
| Level | Description |
|-------|-------------|
| Exact | Identical expression and identical constant values |
| Parameterized | Same formula, varying bracket threshold or rate (extract as parameter) |
| Semantic | Economically equivalent but algorithmically different — **Suggest only** |

### Auto Conditions
- Exact formula in ≥ 2 files, pure function (no I/O, no state mutation)
- Same named constant defined with the same value in ≥ 2 files → extract the
  constant to the utility module and import it

### Suggest Conditions
- Formulas that may need to change independently in each module (intentional
  divergence)
- Tax or regulatory calculations where different sites intentionally use
  different rule sets
- Any domain formula inside exception-handling logic

### Before / After Example

```python
# Before (in billing.py and invoicing.py)
# billing.py
TAX_RATE = 0.07
total = subtotal * (1 + TAX_RATE)

# invoicing.py
TAX_RATE = 0.07
invoice_total = net * (1 + TAX_RATE)

# After — utils/tax_utils.py
"""Tax and fee calculation utilities."""

TAX_RATE = 0.07

class TaxCalculator:
    @staticmethod
    def apply_tax(amount: float, rate: float = TAX_RATE) -> float:
        """Return amount with tax applied."""
        return amount * (1 + rate)

# Updated call sites (billing.py)
from utils.tax_utils import TaxCalculator

total = TaxCalculator.apply_tax(subtotal)

# Updated call sites (invoicing.py)
from utils.tax_utils import TaxCalculator

invoice_total = TaxCalculator.apply_tax(net)
```

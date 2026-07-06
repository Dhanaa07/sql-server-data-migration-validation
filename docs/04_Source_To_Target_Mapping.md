# Source-to-Target Mapping
### LegacyRetailDB → RetailReportingDB

---

## Business Purpose

The retail company is retiring its legacy database and replacing it with a
clean, well-structured reporting database. The legacy system stores customer
and order data with known quality issues — NULLs, inconsistent formatting,
duplicates, and text-based numeric/date fields.

This document defines exactly how each source column will be transformed and
validated before it is loaded into the new reporting database. It serves as
the single reference point for building the migration logic and for
explaining migration decisions during review or interviews.

---

## Assumptions

- `LegacyRetailDB` is the read-only source system. No data in the legacy
  database will be modified during migration.
- `RetailReportingDB` already has its target schema created, including data
  types, primary keys, and the `Orders → Customers` foreign key.
- Source keys (`CustomerID`, `OrderID`) are preserved as-is; no new surrogate
  keys are generated.
- Orders referencing a non-existent `CustomerID` will be excluded from the
  initial load (they violate referential integrity) and reported separately.
- Basic email format validation is a sanity check (text@text.text pattern),
  not full RFC-5322 validation.
- Standardized phone format target: `(555) 123-4567`.
- Standardized state format target: two-character uppercase code (e.g. `NY`).

---

## Source-to-Target Mapping Table

### Customers

| Source Table | Source Column | Source Data Type | Target Table | Target Column | Target Data Type | Transformation Rule | Validation Rule | Notes |
|---|---|---|---|---|---|---|---|---|
| Customers | CustomerID | INT | Customers | CustomerID | INT | Preserve source key as-is | Cannot be NULL; must be unique | Primary key in target; no identity column used |
| Customers | FirstName | VARCHAR(50) | Customers | FirstName | VARCHAR(50) | Trim leading/trailing spaces; convert to Proper Case | Cannot be NULL after cleanup | Fixes mixed casing (e.g. `EMILY` → `Emily`) |
| Customers | LastName | VARCHAR(50) | Customers | LastName | VARCHAR(50) | Trim leading/trailing spaces; convert to Proper Case | Cannot be NULL after cleanup | Rows with missing LastName flagged for review |
| Customers | Email | VARCHAR(100) | Customers | Email | VARCHAR(100) | Trim spaces; replace empty string with NULL; lowercase | Must match basic `text@text.text` pattern or be NULL | Invalid emails loaded as NULL, not blocked |
| Customers | Phone | VARCHAR(50) | Customers | Phone | VARCHAR(20) | Remove non-digit characters; reformat to `(555) 123-4567` | Standardized 10-digit phone format or NULL | Handles formats like `555.456.7890`, `5553456789` |
| Customers | City | VARCHAR(50) | Customers | City | VARCHAR(50) | Trim spaces; convert to Proper Case | Replace empty string with NULL | Cosmetic cleanup only |
| Customers | State | VARCHAR(50) | Customers | State | CHAR(2) | Trim spaces; convert to uppercase; truncate/validate to 2 characters | Must be a 2-character code or NULL | Legacy field allowed free text; target enforces code format |
| Customers | CreatedDate | VARCHAR(20) | Customers | CreatedDate | DATE | `TRY_CONVERT(DATE, CreatedDate)` | Must convert successfully or load as NULL | Legacy dates stored in mixed formats (`YYYY-MM-DD`, `MM/DD/YYYY`, `DD-Mon-YYYY`) |
| *(system-generated)* | — | — | Customers | LoadDate | DATETIME | Defaulted to `GETDATE()` at load time | Cannot be NULL | Tracks migration timestamp; not sourced from legacy |

### Orders

| Source Table | Source Column | Source Data Type | Target Table | Target Column | Target Data Type | Transformation Rule | Validation Rule | Notes |
|---|---|---|---|---|---|---|---|---|
| Orders | OrderID | INT | Orders | OrderID | INT | Preserve source key as-is | Cannot be NULL; must be unique | Primary key in target |
| Orders | CustomerID | INT | Orders | CustomerID | INT | Preserve source key as-is | Must exist in target Customers table | Enforced by foreign key; orphan orders excluded |
| Orders | OrderDate | VARCHAR(20) | Orders | OrderDate | DATE | `TRY_CONVERT(DATE, OrderDate)` | Must convert successfully or load as NULL | Same mixed-format issue as CreatedDate |
| Orders | OrderAmount | VARCHAR(20) | Orders | OrderAmount | DECIMAL(10,2) | Remove currency symbols/spaces; `TRY_CONVERT(DECIMAL(10,2), OrderAmount)` | Must convert successfully or load as NULL | Handles values like `$120.00`, `' 45.99 '` |
| Orders | OrderStatus | VARCHAR(20) | Orders | OrderStatus | VARCHAR(20) | Trim spaces; standardize casing (e.g. Proper Case); map to a fixed set of known status values | Must match one of the approved status values | Fixes inconsistencies like `PENDING`, `pending`, `Pending` |
| *(system-generated)* | — | — | Orders | LoadDate | DATETIME | Defaulted to `GETDATE()` at load time | Cannot be NULL | Tracks migration timestamp; not sourced from legacy |

---

## Transformation Summary

| Transformation | Applied To |
|---|---|
| Trim leading/trailing spaces | FirstName, LastName, City, State, Email, OrderStatus |
| Convert to Proper Case | FirstName, LastName, City, OrderStatus |
| Convert to uppercase | State |
| Replace empty string with NULL | Email, City, State |
| Remove non-digit characters / reformat | Phone |
| `TRY_CONVERT(DATE, ...)` | CreatedDate, OrderDate |
| `TRY_CONVERT(DECIMAL(10,2), ...)` | OrderAmount |
| Preserve source key | CustomerID, OrderID |
| Standardize to fixed value set | OrderStatus |
| Default system value on load | LoadDate (Customers, Orders) |

---

## Validation Summary

| Validation | Rule | Applies To |
|---|---|---|
| Primary key not NULL | `CustomerID` / `OrderID` must be present and unique | Customers, Orders |
| Referential integrity | `Orders.CustomerID` must exist in `Customers.CustomerID` | Orders |
| Date conversion | `CreatedDate` / `OrderDate` must convert via `TRY_CONVERT(DATE, ...)` | Customers, Orders |
| Numeric conversion | `OrderAmount` must convert via `TRY_CONVERT(DECIMAL(10,2), ...)` | Orders |
| Email format | Must match a basic `text@text.text` pattern | Customers |
| Phone format | Must be standardized to `(555) 123-4567` or NULL | Customers |
| State format | Must be a 2-character code | Customers |
| Row count reconciliation | Source row counts vs. loaded row counts must be reconciled, with excluded/rejected rows explicitly accounted for | Customers, Orders |

---

## Notes

- Rows that fail a validation rule (e.g. unconvertible date/amount, orphan
  order) are **not silently dropped** — they are excluded from the load and
  counted separately during row count reconciliation, so every source row is
  accounted for.
- This mapping document will drive the migration scripts built in a later
  step. No migration SQL is included here.

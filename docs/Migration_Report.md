# Migration Report

## SQL Server Data Migration \& Validation

**Project:** LegacyRetailDB → RetailReportingDB
**Report Date:** 2026-07-06
**Prepared By:** Dhana Lakshmi

\---

## Migration Summary

The migration of customer and order data from `LegacyRetailDB` into
`RetailReportingDB` was executed using the stored procedures
`dbo.sp\_MigrateCustomers` and `dbo.sp\_MigrateOrders`, followed by an
independent validation script (`07\_Migration\_Validation.sql`).

All Customers records were successfully migrated. One Orders record was
correctly rejected due to a broken customer reference (orphan record), which
is the expected behavior enforced by referential integrity rules defined in
the Source-to-Target Mapping document. The migration completed with a final
validation status of **PASS**.

|Item|Result|
|-|-|
|Migration executed|Yes|
|Errors encountered|None|
|Customers migrated|10 of 10|
|Orders migrated|9 of 10|
|Orders rejected (expected)|1 (orphan `CustomerID`)|
|Final Validation Status|**PASS**|

\---

## Legacy Database

**Database:** `LegacyRetailDB`

|Table|Row Count|Notes|
|-|-|-|
|`dbo.Customers`|10|Includes 1 duplicate record pair, mixed casing, inconsistent phone/date formats|
|`dbo.Orders`|10|Includes 1 orphan record referencing a non-existent `CustomerID` (99)|

The legacy database was treated as read-only throughout the project. No
source data was modified, deleted, or reformatted in place.

\---

## RetailReportingDB

**Database:** `RetailReportingDB`

|Table|Row Count (Post-Migration)|Notes|
|-|-|-|
|`dbo.Customers`|10|Primary key enforced; all rows typed and standardized|
|`dbo.Orders`|9|Foreign key enforced; orphan order excluded|

### Customers

* All 10 source customer rows were migrated — none were skipped, since
every `CustomerID` was present and unique.
* The known duplicate pair (`CustomerID 1` and `CustomerID 7`, both
"John Smith") was **not** removed during migration. Per the project's
scope, deduplication was identified during data quality assessment but
intentionally left in the target dataset, since both rows have distinct
source keys and no business rule was defined to merge or discard either
one.
* All `CreatedDate` values converted successfully via `TRY\_CONVERT(DATE, ...)`
except one pre-existing `NULL` (`CustomerID 9`), which loaded as `NULL`
as expected.
* All `Email` values passed basic format validation except one pre-existing
`NULL` (`CustomerID 4`).
* All `Phone` values standardized successfully to `(555) 123-4567` format
except one pre-existing `NULL` (`CustomerID 5`).

### Orders

* 9 of 10 source order rows were migrated.
* 1 row (`OrderID 110`) was rejected because its `CustomerID` (99) does not
exist in the target `Customers` table — this is the intended orphan
record built into the sample dataset to validate referential integrity
handling.
* All `OrderDate` values converted successfully via `TRY\_CONVERT(DATE, ...)`
except one pre-existing `NULL` (`OrderID 105`).
* All `OrderAmount` values converted successfully via
`TRY\_CONVERT(DECIMAL(10,2), ...)` after stripping `$` and spaces, except
one pre-existing `NULL` (`OrderID 106`).
* All `OrderStatus` values were successfully standardized to one of
`Completed`, `Pending`, `Shipped`, or `Cancelled`, regardless of original
casing (e.g. `PENDING`, `pending` → `Pending`).

\---

## Validation Results

The validation script independently confirmed the migration outcome:

|Check|Result|
|-|-|
|Source vs. Target Customer count|10 vs. 10 — Difference: 0|
|Source vs. Target Order count|10 vs. 9 — Difference: 1 (expected, orphan order)|
|Missing Customers (unexplained)|0|
|Missing Orders (unexplained)|0|
|Orphan Orders identified|1 (`OrderID 110`, `CustomerID 99`)|
|Invalid Dates (converted to NULL)|0 beyond pre-existing NULLs|
|Invalid Amounts (converted to NULL)|0 beyond pre-existing NULLs|
|Invalid Emails (converted to NULL)|0 beyond pre-existing NULLs|
|Invalid Phones (converted to NULL)|0 beyond pre-existing NULLs|
|**Final Validation Status**|**PASS**|

The single row-count difference in Orders is fully explained by the orphan
record check, meeting the criteria for a **PASS** result as defined in the
validation script.

\---

## Data Quality Findings

The initial data quality assessment (`03\_Legacy\_Data\_Assessment.sql`)
identified the following issues prior to migration:

|Issue|Finding|
|-|-|
|NULL values|Present in `Email`, `Phone`, `CreatedDate` (Customers) and `OrderDate`, `OrderAmount` (Orders)|
|Duplicate customers|1 duplicate group found (`CustomerID 1` and `7`, matching name/email)|
|Inconsistent phone formats|4 distinct formats observed: `(555) 123-4567`, `555-123-4567`, `555.123.4567`, digits-only|
|Inconsistent date formats|5 distinct formats observed across `CreatedDate`/`OrderDate` (ISO, US slash, dashes, `Mon` abbreviation)|
|Currency symbols in amounts|`OrderAmount` contained `$` symbols and extra spaces (e.g. `$85.00`, `' 45.99 '`)|
|Inconsistent status casing|`OrderStatus` values found in multiple casings (`Completed`, `completed`, `PENDING`, `pending`)|
|Orphan orders|1 order referenced a `CustomerID` not present in `Customers`|
|Mixed name casing|Names found in all-uppercase, all-lowercase, and mixed forms|
|Leading/trailing spaces|Found in `FirstName` and `LastName` values|

\---

## Transformation Rules Applied

|Field|Rule Applied|
|-|-|
|`FirstName` / `LastName`|Trimmed; converted to Proper Case|
|`Email`|Trimmed; lowercased; blank or invalid format → `NULL`|
|`Phone`|Formatting characters stripped; valid 10-digit numbers reformatted to `(555) 123-4567`; otherwise → `NULL`|
|`City`|Trimmed; converted to Proper Case|
|`State`|Trimmed; uppercased; truncated to 2 characters|
|`CreatedDate` / `OrderDate`|Converted via `TRY\_CONVERT(DATE, ...)`; failures → `NULL`|
|`OrderAmount`|`$`, commas, and spaces stripped; converted via `TRY\_CONVERT(DECIMAL(10,2), ...)`; failures → `NULL`|
|`OrderStatus`|Trimmed; standardized to `Completed`, `Pending`, `Shipped`, or `Cancelled`|
|`CustomerID` / `OrderID`|Preserved exactly as-is from source (no surrogate keys)|
|`LoadDate`|Populated automatically via target table `DEFAULT(GETDATE())`|

All transformation rules matched those defined in the
[Source-to-Target Mapping document](docs/04_Source_To_Target_Mapping.md)
with no deviations during execution.

\---

## Lessons Learned

* **Graceful transformations reduce data loss.** Converting bad values to
`NULL` instead of rejecting the entire row preserved far more usable data
than an all-or-nothing validation approach would have.
* **Referential integrity should be enforced during migration, not after.**
Filtering out the orphan order at load time (rather than loading it and
catching a foreign key violation) kept the migration script simple and
avoided a runtime error.
* **Row count reconciliation alone isn't enough.** A raw count difference
(10 vs. 9 orders) looks like a problem until it's explained — validating
*why* rows are missing, not just *how many*, is what actually confirms
migration correctness.
* **Assessment before mapping is worthwhile.** Running the data quality
assessment first made it possible to write realistic, targeted
transformation rules instead of guessing at what the dirty data might
contain.
* **Duplicate detection and duplicate resolution are separate concerns.**
Identifying the duplicate customer pair during assessment did not
automatically mean removing it during migration — that requires an
explicit business rule, which is a reasonable scope boundary to call out
rather than solve unprompted.

\---

## Business Value

* Reporting can now run against strongly-typed `DATE` and `DECIMAL` columns
instead of parsing free-text fields on every query.
* Referential integrity between Orders and Customers is guaranteed going
forward, preventing orphaned reporting data.
* Standardized phone, state, and status values eliminate the need for
ad hoc `CASE` statements or manual cleanup in every downstream report.
* The validation process provides an auditable, repeatable way to confirm
data integrity after any future migration or reload.
* Reusable functions (`fn\_ProperCase`, `fn\_FormatPhone`) and stored
procedures (`sp\_MigrateCustomers`, `sp\_MigrateOrders`) mean the same
migration can be safely re-run if the legacy system is refreshed again.

\---

## Final Migration Statistics

|Metric|Value|
|-|-|
|Source Customers|10|
|Target Customers|10|
|Rejected Customers|0|
|Source Orders|10|
|Target Orders|9|
|Rejected Orders|1|
|Duplicate Customer Groups Identified|1|
|Orphan Orders Identified|1|
|Invalid Dates Converted to NULL|0 (beyond pre-existing NULLs)|
|Invalid Amounts Converted to NULL|0 (beyond pre-existing NULLs)|
|Invalid Emails Converted to NULL|0 (beyond pre-existing NULLs)|
|Invalid Phones Converted to NULL|0 (beyond pre-existing NULLs)|
|**Final Validation Status**|**PASS**|




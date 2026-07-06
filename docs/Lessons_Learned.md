# Lessons Learned

## SQL Server Data Migration \& Validation

This project was developed as a hands-on learning exercise to strengthen practical SQL Server, T-SQL, and data migration skills. The lessons below summarize key technical concepts and best practices learned while designing, implementing, and validating an end-to-end SQL Server data migration workflow.

\---

## SQL Server

* **Two databases on one instance is a realistic pattern.** Keeping
`LegacyRetailDB` and `RetailReportingDB` as separate databases (rather
than separate schemas) mirrors how real migrations often work — the old
system usually isn't just a schema inside the new one, it's a genuinely
separate database, sometimes on a separate server entirely.
* **Cross-database queries are straightforward in SQL Server.** Using
three-part naming (`LegacyRetailDB.dbo.Customers`) made it simple to
read from one database and write to another without linked servers or
special configuration, as long as both databases live on the same
instance.
* **Constraints do real work.** Adding a primary key and foreign key to
`RetailReportingDB` wasn't just documentation — it actively prevented an
orphan order from being inserted, which is exactly the kind of
protection a reporting database needs.
* **Indexes should map to actual query patterns.** Rather than indexing
everything, adding indexes on `Orders.CustomerID` and
`Orders.OrderStatus` was a deliberate choice tied to how the data would
realistically be filtered and joined in reporting.

\---

## Data Migration

* **Migration is mostly about decisions, not code.** The actual
`INSERT INTO ... SELECT` statements were simple. The hard part was
deciding what should happen to a bad value — reject the row entirely, or
load it as `NULL`? Defining that up front (in the mapping document) made
the SQL itself easy to write.
* **Order of operations matters.** Customers had to be migrated before
Orders, because Orders depend on Customers already existing in the
target. This is an obvious dependency in hindsight, but it's the kind of
sequencing detail that becomes second nature only after doing it.
* **Migrations should be safe to re-run.** Using `NOT EXISTS` checks
against the target table meant the migration script wouldn't blow up or
create duplicates if it was accidentally run twice — an important
property for anything wrapped in a stored procedure meant to be
reusable.
* **Preserving source keys avoids unnecessary complexity.** Reusing
`CustomerID` and `OrderID` from the legacy system instead of generating
new identity values kept the mapping between source and target simple
and traceable.

\---

## T-SQL

* **`TRY\_CONVERT` is essential for messy data.** Using `TRY\_CONVERT`
instead of `CONVERT` or `CAST` turned potential runtime errors into
simple `NULL` results, which was the difference between a migration that
crashes on bad data and one that gracefully handles it.
* **String cleanup often needs to be layered.** Standardizing a phone
number required chaining multiple `REPLACE()` calls to strip out
different formatting characters before the value could even be
validated — a good reminder that real-world text cleanup is rarely a
single function call.
* **Scalar functions are worth extracting once logic repeats.** Writing
`fn\_ProperCase` and `fn\_FormatPhone` as standalone functions made it
clear which pieces of logic were reusable versus which were specific to
a single migration step.
* **`TRY...CATCH` belongs in anything meant to run unattended.** Wrapping
the migration procedures in `TRY...CATCH` with `ERROR\_MESSAGE()` and
`ERROR\_LINE()` meant a failure would produce a useful message instead of
an unhandled error.

\---

## Referential Integrity

* **Referential integrity should be enforced at load time, not discovered
later.** Filtering out the orphan order (`CustomerID 99`) during the
`INSERT` was far simpler than trying to load it and then handle a
foreign key violation error.
* **A foreign key constraint is a safety net, not the whole solution.**
The constraint on `Orders.CustomerID` would have blocked the orphan row
regardless, but explicitly checking for it in the `WHERE` clause meant
the rejection was intentional and logged, not just a database error.
* **Integrity issues in legacy data are often invisible until you look.**
The orphan order wasn't obvious from a quick glance at the sample data —
it only became clear once a dedicated check (`NOT EXISTS` against
Customers) was written during the data quality assessment.

\---

## Data Cleansing

* **Not all bad data should be treated the same way.** A missing email
and a missing `CustomerID` are very different problems — one is
acceptable to load as `NULL`, the other means the row can't be linked
to a customer at all. Recognizing which fields are "soft" (can degrade
gracefully) versus "hard" (must be valid) shaped every transformation
rule.
* **Standardization needs a defined target format.** Deciding on
`(555) 123-4567` as the one accepted phone format — before writing any
cleansing logic — made the transformation rule unambiguous and testable.
* **Case normalization is deceptively simple-looking but easy to get
wrong.** Converting `'JOHN'` and `'jAnE'` to `'John'` and `'Jane'`
required trimming first, then applying the case logic — reversing that
order would have produced incorrect results on names with leading
spaces.
* **Cleansing rules belong in the mapping document, not just in code.**
Writing the transformation rules down before implementing them made the
SQL a direct translation of an already-agreed-upon plan, rather than a
place where ad hoc decisions got made mid-script.

\---

## Validation

* **Validation should be independent of migration.** Writing the
validation script separately from the migration procedures — and making
it strictly read-only — meant it could be trusted as an honest check,
rather than one that might share a bug with the migration logic itself.
* **A row count match isn't proof of success on its own.** Source and
target counts differing by exactly the number of expected orphan
rejections was the real confirmation — a matching count with the wrong
rows included would have been just as misleading as a mismatch.
* **"Missing" and "rejected" are different findings.** Explicitly
separating orphan orders (expected rejections) from truly unexplained
missing rows made it possible to define a clear PASS/FAIL condition
instead of treating every discrepancy the same way.
* **A single summary report saves time.** Consolidating all the
individual checks into one final PASS/FAIL query made it possible to
get a yes/no answer quickly, while still having the detailed queries
available to drill into if the answer was FAIL.

\---

## Source-to-Target Mapping

* **Writing the mapping document first prevented scope creep in the SQL.**
Every transformation implemented later traced back to a rule that was
already agreed upon, which made it easy to say "that's not in scope"
when tempted to add extra cleansing logic.
* **Mapping documents double as interview-ready documentation.** Having a
single table that lists every column, its source type, target type,
transformation, and validation rule turned out to be one of the most
useful artifacts in the whole project — it's a natural way to walk
someone through the entire migration in a few minutes.
* **Assumptions need to be written down, not just implied.** Documenting
things like "orphan orders are excluded, not force-loaded" made
decisions explicit that could otherwise cause confusion later, especially
if someone else picked up the project.
* **The mapping document is a contract, not just documentation.** Treating
it as the definition of correct behavior — rather than a description
written after the fact — is what made the validation script possible to
write with clear, objective pass/fail criteria.



\---



\## Final Reflection



Building this project helped reinforce the complete lifecycle of a SQL Server data migration—from understanding legacy data and designing a target schema to implementing transformations, validating results, and documenting migration decisions. Beyond improving technical T-SQL skills, the project highlighted the importance of planning, data quality assessment, and clear documentation in delivering reliable data engineering solutions.



This project also strengthened my confidence in working with SQL Server Management Studio (SSMS), T-SQL, stored procedures, views, user-defined functions, and migration validation techniques, providing a solid foundation for future data engineering projects.


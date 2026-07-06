/*
==============================================================================
Script Name : 07_Migration_Validation.sql
Author      : Dhana Lakshmi
Created On  : 2026-07-06
Purpose     : Validates that the migration from LegacyRetailDB into
              RetailReportingDB completed as expected, by comparing row
              counts, identifying rejected/missing records, and reviewing
              the outcome of transformation rules (dates, amounts, email,
              phone).

Business Purpose:
              After running the Customers and Orders migration scripts,
              we need an independent, read-only way to confirm the
              migration behaved correctly - that expected rows were
              rejected for the right reasons (orphan orders, duplicate
              keys) and that transformation rules produced sensible
              results (NULLs only where expected).

Assumptions:
              - 05_Migrate_Customers.sql and 06_Migrate_Orders.sql have
                already been executed.
              - "Missing" records are rows present in the source but not
                found in the target for a reason other than an expected
                rejection rule (NULL key, duplicate key, orphan CustomerID).
              - This script is READ-ONLY. It does not create tables,
                procedures, or modify any data in either database.
==============================================================================
*/

------------------------------------------------------------------------------
-- 1. Source vs Target Customer Row Count
-- Compares total row counts between source and target Customers tables.
------------------------------------------------------------------------------
SELECT
    (SELECT COUNT(*) FROM LegacyRetailDB.dbo.Customers)      AS SourceCount,
    (SELECT COUNT(*) FROM RetailReportingDB.dbo.Customers)   AS TargetCount,
    (SELECT COUNT(*) FROM LegacyRetailDB.dbo.Customers)
        - (SELECT COUNT(*) FROM RetailReportingDB.dbo.Customers) AS Difference;
GO

------------------------------------------------------------------------------
-- 2. Source vs Target Order Row Count
-- Compares total row counts between source and target Orders tables.
------------------------------------------------------------------------------
SELECT
    (SELECT COUNT(*) FROM LegacyRetailDB.dbo.Orders)         AS SourceCount,
    (SELECT COUNT(*) FROM RetailReportingDB.dbo.Orders)      AS TargetCount,
    (SELECT COUNT(*) FROM LegacyRetailDB.dbo.Orders)
        - (SELECT COUNT(*) FROM RetailReportingDB.dbo.Orders) AS Difference;
GO

------------------------------------------------------------------------------
-- 3. Missing Customers
-- Customers that exist in the source but were NOT loaded into the target,
-- for a reason OTHER than the expected rejection rules (NULL key or
-- duplicate key already in target). Any rows returned here indicate an
-- unexpected gap in the migration.
------------------------------------------------------------------------------
SELECT
    src.CustomerID,
    src.FirstName,
    src.LastName
FROM LegacyRetailDB.dbo.Customers AS src
WHERE src.CustomerID IS NOT NULL
  AND NOT EXISTS (
        SELECT 1
        FROM RetailReportingDB.dbo.Customers AS tgt
        WHERE tgt.CustomerID = src.CustomerID
      );
GO

------------------------------------------------------------------------------
-- 4. Missing Orders
-- Orders that exist in the source but were NOT loaded into the target,
-- for a reason OTHER than the expected rejection rules (NULL key,
-- duplicate key, or orphan CustomerID). Any rows returned here indicate
-- an unexpected gap in the migration.
------------------------------------------------------------------------------
SELECT
    src.OrderID,
    src.CustomerID
FROM LegacyRetailDB.dbo.Orders AS src
WHERE src.OrderID IS NOT NULL
  AND NOT EXISTS (
        SELECT 1
        FROM RetailReportingDB.dbo.Orders AS tgt
        WHERE tgt.OrderID = src.OrderID
      )
  AND EXISTS (
        SELECT 1
        FROM RetailReportingDB.dbo.Customers AS cust
        WHERE cust.CustomerID = src.CustomerID
      );
GO

------------------------------------------------------------------------------
-- 5. Orphan Orders
-- Orders rejected during migration because their CustomerID does not
-- exist in the target Customers table.
------------------------------------------------------------------------------
SELECT
    src.OrderID,
    src.CustomerID
FROM LegacyRetailDB.dbo.Orders AS src
WHERE src.CustomerID IS NULL
   OR NOT EXISTS (
        SELECT 1
        FROM RetailReportingDB.dbo.Customers AS cust
        WHERE cust.CustomerID = src.CustomerID
      );
GO

------------------------------------------------------------------------------
-- 6. Invalid Dates
-- Rows where CreatedDate (Customers) or OrderDate (Orders) became NULL
-- in the target after migration, even though the source value was NOT
-- NULL - meaning TRY_CONVERT(DATE, ...) failed during migration.
------------------------------------------------------------------------------

-- Customers.CreatedDate
SELECT
    tgt.CustomerID,
    src.CreatedDate AS SourceCreatedDate,
    tgt.CreatedDate AS TargetCreatedDate
FROM RetailReportingDB.dbo.Customers AS tgt
JOIN LegacyRetailDB.dbo.Customers AS src
    ON src.CustomerID = tgt.CustomerID
WHERE tgt.CreatedDate IS NULL
  AND src.CreatedDate IS NOT NULL;
GO

-- Orders.OrderDate
SELECT
    tgt.OrderID,
    src.OrderDate AS SourceOrderDate,
    tgt.OrderDate AS TargetOrderDate
FROM RetailReportingDB.dbo.Orders AS tgt
JOIN LegacyRetailDB.dbo.Orders AS src
    ON src.OrderID = tgt.OrderID
WHERE tgt.OrderDate IS NULL
  AND src.OrderDate IS NOT NULL;
GO

------------------------------------------------------------------------------
-- 7. Invalid Amounts
-- Rows where OrderAmount became NULL in the target after migration, even
-- though the source value was NOT NULL - meaning TRY_CONVERT(DECIMAL(10,2))
-- failed during migration.
------------------------------------------------------------------------------
SELECT
    tgt.OrderID,
    src.OrderAmount AS SourceOrderAmount,
    tgt.OrderAmount AS TargetOrderAmount
FROM RetailReportingDB.dbo.Orders AS tgt
JOIN LegacyRetailDB.dbo.Orders AS src
    ON src.OrderID = tgt.OrderID
WHERE tgt.OrderAmount IS NULL
  AND src.OrderAmount IS NOT NULL;
GO

------------------------------------------------------------------------------
-- 8. Email Validation
-- Customers whose Email became NULL in the target after migration, even
-- though the source value was NOT NULL - meaning the email failed basic
-- format validation or was blank.
------------------------------------------------------------------------------
SELECT
    tgt.CustomerID,
    src.Email AS SourceEmail,
    tgt.Email AS TargetEmail
FROM RetailReportingDB.dbo.Customers AS tgt
JOIN LegacyRetailDB.dbo.Customers AS src
    ON src.CustomerID = tgt.CustomerID
WHERE tgt.Email IS NULL
  AND src.Email IS NOT NULL;
GO

------------------------------------------------------------------------------
-- 9. Phone Validation
-- Customers whose Phone became NULL in the target after migration, even
-- though the source value was NOT NULL - meaning the phone number did
-- not resolve to a valid 10-digit number during standardization.
------------------------------------------------------------------------------
SELECT
    tgt.CustomerID,
    src.Phone AS SourcePhone,
    tgt.Phone AS TargetPhone
FROM RetailReportingDB.dbo.Customers AS tgt
JOIN LegacyRetailDB.dbo.Customers AS src
    ON src.CustomerID = tgt.CustomerID
WHERE tgt.Phone IS NULL
  AND src.Phone IS NOT NULL;
GO

------------------------------------------------------------------------------
-- 10. Summary Report
------------------------------------------------------------------------------

DECLARE @SourceCustomers INT;
DECLARE @TargetCustomers INT;
DECLARE @SourceOrders INT;
DECLARE @TargetOrders INT;

SELECT @SourceCustomers = COUNT(*)
FROM LegacyRetailDB.dbo.Customers;

SELECT @TargetCustomers = COUNT(*)
FROM RetailReportingDB.dbo.Customers;

SELECT @SourceOrders = COUNT(*)
FROM LegacyRetailDB.dbo.Orders;

SELECT @TargetOrders = COUNT(*)
FROM RetailReportingDB.dbo.Orders;

SELECT

    @SourceCustomers AS SourceCustomers,

    @TargetCustomers AS TargetCustomers,

    @SourceOrders AS SourceOrders,

    @TargetOrders AS TargetOrders,

    (@SourceCustomers - @TargetCustomers) AS RejectedCustomers,

    (@SourceOrders - @TargetOrders) AS RejectedOrders,

    CASE

        WHEN (@SourceCustomers - @TargetCustomers) = 0
         AND (@SourceOrders - @TargetOrders) = 1

        THEN 'PASS'

        ELSE 'FAIL'

    END AS ValidationStatus;
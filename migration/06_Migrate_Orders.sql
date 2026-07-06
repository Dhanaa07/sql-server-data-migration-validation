/*
==============================================================================
Script Name : 06_Migrate_Orders.sql
Author      : Dhana Lakshmi
Created On  : 2026-07-06
Purpose     : Migrates order data from the legacy source database
              (LegacyRetailDB.dbo.Orders) into the clean reporting
              database (RetailReportingDB.dbo.Orders), applying the
              transformation and validation rules defined in the
              Source-to-Target Mapping document (04_Source_To_Target_Mapping.md).

Business Purpose:
              The legacy Orders table stores dates and amounts as text,
              contains inconsistent status casing, and includes orders
              tied to customers that do not exist. This script cleans and
              standardizes that data while enforcing referential integrity
              against the already-migrated Customers table.

Assumptions:
              - RetailReportingDB.dbo.Orders already exists with the
                target schema (see 02_Create_RetailReportingDB.sql).
              - RetailReportingDB.dbo.Customers has already been populated
                by 05_Migrate_Customers.sql. Orders cannot reference a
                customer that does not exist in the target.
              - OrderID and CustomerID are preserved as-is from the source.
              - Rows are only skipped if OrderID is NULL, OrderID already
                exists in the target, or CustomerID does not exist in the
                target Customers table. Bad OrderDate/OrderAmount values do
                NOT block a row from migrating - they load as NULL instead.
              - LoadDate is populated automatically by the target table's
                DEFAULT(GETDATE()) constraint and is not set explicitly here.

Notes       : - Simple INSERT INTO ... SELECT approach only.
              - No stored procedures, views, functions, or temp objects.
==============================================================================
*/

------------------------------------------------------------------------------
-- Step 1: Log source row count before migration
------------------------------------------------------------------------------
DECLARE @SourceCount   INT;
DECLARE @TargetCount   INT;
DECLARE @MigratedCount INT;
DECLARE @RejectedCount INT;

SELECT @SourceCount = COUNT(*)
FROM LegacyRetailDB.dbo.Orders;

PRINT 'Source Order Count: ' + CAST(@SourceCount AS VARCHAR(10));

------------------------------------------------------------------------------
-- Step 2: Migrate order data with transformations applied
--
-- OrderID      : preserved exactly as-is from source
-- CustomerID   : preserved exactly as-is from source (must exist in target)
-- OrderDate    : converted using TRY_CONVERT(DATE, ...), invalid -> NULL
-- OrderAmount  : $ , and spaces stripped, then TRY_CONVERT(DECIMAL(10,2)),
--                invalid -> NULL
-- OrderStatus  : trimmed, converted to Proper Case, standardized to a
--                known set of values (Completed, Pending, Shipped,
--                Cancelled); anything unrecognized -> NULL
-- LoadDate     : not inserted; target DEFAULT(GETDATE()) populates it
--
-- Rows are skipped only when:
--   - OrderID is NULL
--   - OrderID already exists in the target table
--   - CustomerID does not exist in RetailReportingDB.dbo.Customers
------------------------------------------------------------------------------
BEGIN TRY

    INSERT INTO RetailReportingDB.dbo.Orders
    (
        OrderID,
        CustomerID,
        OrderDate,
        OrderAmount,
        OrderStatus
    )
    SELECT
        src.OrderID,

        src.CustomerID,

        -- OrderDate: safe conversion, invalid -> NULL
        TRY_CONVERT(DATE, src.OrderDate),

        -- OrderAmount: strip $ , and spaces, then safe conversion
        TRY_CONVERT(
            DECIMAL(10,2),
            REPLACE(REPLACE(REPLACE(src.OrderAmount, '$', ''), ',', ''), ' ', '')
        ),

        -- OrderStatus: trim, Proper Case, standardize to known values
        CASE LOWER(LTRIM(RTRIM(src.OrderStatus)))
            WHEN 'completed' THEN 'Completed'
            WHEN 'pending'   THEN 'Pending'
            WHEN 'shipped'   THEN 'Shipped'
            WHEN 'cancelled' THEN 'Cancelled'
            ELSE NULL
        END

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

    ------------------------------------------------------------------------------
    -- Step 3: Log post-migration results
    ------------------------------------------------------------------------------
    SELECT @TargetCount = COUNT(*)
    FROM RetailReportingDB.dbo.Orders;

    SELECT @MigratedCount = COUNT(*)
    FROM LegacyRetailDB.dbo.Orders AS src
    WHERE src.OrderID IS NOT NULL
      AND EXISTS (
            SELECT 1
            FROM RetailReportingDB.dbo.Orders AS tgt
            WHERE tgt.OrderID = src.OrderID
          );

    SELECT @RejectedCount = COUNT(*)
    FROM LegacyRetailDB.dbo.Orders AS src
    WHERE src.OrderID IS NULL
       OR NOT EXISTS (
            SELECT 1
            FROM RetailReportingDB.dbo.Orders AS tgt
            WHERE tgt.OrderID = src.OrderID
          );

    PRINT 'Target Order Count: '  + CAST(@TargetCount AS VARCHAR(10));
    PRINT 'Migrated Row Count: '  + CAST(@MigratedCount AS VARCHAR(10));
    PRINT 'Rejected Row Count: '  + CAST(@RejectedCount AS VARCHAR(10));

    PRINT 'Order migration completed successfully.';

END TRY
BEGIN CATCH

    PRINT 'Order migration failed.';
    PRINT 'Error Message: ' + ERROR_MESSAGE();
    PRINT 'Error Line: '    + CAST(ERROR_LINE() AS VARCHAR(10));

END CATCH;
/*
==============================================================================
Script Name : 13_sp_MigrateOrders.sql
Author      : Dhana Lakshmi
Created On  : 2026-07-06
Purpose     : Wraps the existing order migration logic from
              06_Migrate_Orders.sql into a reusable stored procedure, so
              the migration can be executed on demand without running a
              raw script.

Business Purpose:
              Encapsulating the migration logic in a stored procedure
              makes it easier to re-run the Orders migration safely and
              consistently (e.g. after a legacy data refresh) without
              copy/pasting the script.

Assumptions:
              - RetailReportingDB.dbo.Orders already exists with the
                target schema (see 02_Create_RetailReportingDB.sql).
              - RetailReportingDB.dbo.Customers has already been
                populated (via dbo.sp_MigrateCustomers or
                05_Migrate_Customers.sql) before this procedure runs.
              - All transformation and validation rules are unchanged
                from 06_Migrate_Orders.sql - this procedure only
                encapsulates that existing logic.
              - OrderID and CustomerID are preserved as-is from the
                source. Rows are skipped only if OrderID is NULL, OrderID
                already exists in the target, or CustomerID does not
                exist in the target Customers table. Invalid
                OrderDate/OrderAmount load as NULL rather than rejecting
                the row.
              - LoadDate is populated automatically by the target
                table's DEFAULT(GETDATE()) constraint.
==============================================================================
*/

USE RetailReportingDB;
GO

IF OBJECT_ID('dbo.sp_MigrateOrders', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_MigrateOrders;
GO

CREATE PROCEDURE dbo.sp_MigrateOrders
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SourceCount   INT;
    DECLARE @TargetCount   INT;
    DECLARE @MigratedCount INT;
    DECLARE @RejectedCount INT;

    BEGIN TRY

        ------------------------------------------------------------------
        -- Step 1: Log source row count before migration
        ------------------------------------------------------------------
        SELECT @SourceCount = COUNT(*)
        FROM LegacyRetailDB.dbo.Orders;

        PRINT 'Source Order Count: ' + CAST(@SourceCount AS VARCHAR(10));

        ------------------------------------------------------------------
        -- Step 2: Migrate order data with transformations applied
        -- (logic preserved as-is from 06_Migrate_Orders.sql)
        ------------------------------------------------------------------
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

        ------------------------------------------------------------------
        -- Step 3: Log post-migration results
        ------------------------------------------------------------------
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

        RETURN 0;  -- Success

    END TRY
    BEGIN CATCH

        PRINT 'Order migration failed.';
        PRINT 'Error Message: ' + ERROR_MESSAGE();
        PRINT 'Error Line: '    + CAST(ERROR_LINE() AS VARCHAR(10));

        RETURN 1;  -- Failure

    END CATCH;

END;
GO

------------------------------------------------------------------------------
-- Example Usage:
--
-- DECLARE @ReturnCode INT;
-- EXEC @ReturnCode = dbo.sp_MigrateOrders;
-- SELECT @ReturnCode AS ReturnCode;   -- 0 = Success, 1 = Failure
------------------------------------------------------------------------------
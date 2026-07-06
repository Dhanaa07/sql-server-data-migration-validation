/*
==============================================================================
Script Name : 12_sp_MigrateCustomers.sql
Author      : Dhana Lakshmi
Created On  : 2026-07-06
Purpose     : Wraps the existing customer migration logic from
              05_Migrate_Customers.sql into a reusable stored procedure,
              so the migration can be executed on demand without running
              a raw script.

Business Purpose:
              Encapsulating the migration logic in a stored procedure
              makes it easier to re-run the Customers migration safely
              and consistently (e.g. after a legacy data refresh) without
              copy/pasting the script.

Assumptions:
              - RetailReportingDB.dbo.Customers already exists with the
                target schema (see 02_Create_RetailReportingDB.sql).
              - All transformation and validation rules are unchanged
                from 05_Migrate_Customers.sql - this procedure only
                encapsulates that existing logic.
              - CustomerID is preserved as-is from the source. Rows are
                skipped only if CustomerID is NULL or already exists in
                the target. Invalid Email/Phone/CreatedDate load as NULL
                rather than rejecting the row.
              - LoadDate is populated automatically by the target table's
                DEFAULT(GETDATE()) constraint.
==============================================================================
*/

USE RetailReportingDB;
GO

IF OBJECT_ID('dbo.sp_MigrateCustomers', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_MigrateCustomers;
GO

CREATE PROCEDURE dbo.sp_MigrateCustomers
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
        FROM LegacyRetailDB.dbo.Customers;

        PRINT 'Source Customer Count: ' + CAST(@SourceCount AS VARCHAR(10));

        ------------------------------------------------------------------
        -- Step 2: Migrate customer data with transformations applied
        -- (logic preserved as-is from 05_Migrate_Customers.sql)
        ------------------------------------------------------------------
        INSERT INTO RetailReportingDB.dbo.Customers
        (
            CustomerID,
            FirstName,
            LastName,
            Email,
            Phone,
            City,
            State,
            CreatedDate
        )
        SELECT
            src.CustomerID,

            -- FirstName: trim + Proper Case
            UPPER(LEFT(LTRIM(RTRIM(src.FirstName)), 1))
                + LOWER(SUBSTRING(LTRIM(RTRIM(src.FirstName)), 2, LEN(LTRIM(RTRIM(src.FirstName))))),

            -- LastName: trim + Proper Case
            UPPER(LEFT(LTRIM(RTRIM(src.LastName)), 1))
                + LOWER(SUBSTRING(LTRIM(RTRIM(src.LastName)), 2, LEN(LTRIM(RTRIM(src.LastName))))),

            -- Email: trim, lowercase, blank/invalid -> NULL
            CASE
                WHEN src.Email IS NULL THEN NULL
                WHEN LTRIM(RTRIM(src.Email)) = '' THEN NULL
                WHEN LOWER(LTRIM(RTRIM(src.Email))) NOT LIKE '%_@__%.__%' THEN NULL
                ELSE LOWER(LTRIM(RTRIM(src.Email)))
            END,

            -- Phone: strip formatting characters, validate 10 digits, reformat
            CASE
                WHEN REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                        src.Phone, '(', ''), ')', ''), '-', ''), '.', ''), ' ', '')
                     NOT LIKE '%[^0-9]%'
                 AND LEN(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                        src.Phone, '(', ''), ')', ''), '-', ''), '.', ''), ' ', '')) = 10
                THEN
                    '(' + SUBSTRING(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                                src.Phone, '(', ''), ')', ''), '-', ''), '.', ''), ' ', ''), 1, 3) + ') '
                        + SUBSTRING(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                                src.Phone, '(', ''), ')', ''), '-', ''), '.', ''), ' ', ''), 4, 3) + '-'
                        + SUBSTRING(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                                src.Phone, '(', ''), ')', ''), '-', ''), '.', ''), ' ', ''), 7, 4)
                ELSE NULL
            END,

            -- City: trim + Proper Case
            CASE
                WHEN src.City IS NULL OR LTRIM(RTRIM(src.City)) = '' THEN NULL
                ELSE UPPER(LEFT(LTRIM(RTRIM(src.City)), 1))
                        + LOWER(SUBSTRING(LTRIM(RTRIM(src.City)), 2, LEN(LTRIM(RTRIM(src.City)))))
            END,

            -- State: trim, uppercase, first 2 characters
            CASE
                WHEN src.State IS NULL OR LTRIM(RTRIM(src.State)) = '' THEN NULL
                ELSE LEFT(UPPER(LTRIM(RTRIM(src.State))), 2)
            END,

            -- CreatedDate: safe conversion, invalid -> NULL
            TRY_CONVERT(DATE, src.CreatedDate)

        FROM LegacyRetailDB.dbo.Customers AS src
        WHERE src.CustomerID IS NOT NULL
          AND NOT EXISTS (
                SELECT 1
                FROM RetailReportingDB.dbo.Customers AS tgt
                WHERE tgt.CustomerID = src.CustomerID
              );

        ------------------------------------------------------------------
        -- Step 3: Log post-migration results
        ------------------------------------------------------------------
        SELECT @TargetCount = COUNT(*)
        FROM RetailReportingDB.dbo.Customers;

        SELECT @MigratedCount = COUNT(*)
        FROM LegacyRetailDB.dbo.Customers AS src
        WHERE src.CustomerID IS NOT NULL
          AND EXISTS (
                SELECT 1
                FROM RetailReportingDB.dbo.Customers AS tgt
                WHERE tgt.CustomerID = src.CustomerID
              );

        SELECT @RejectedCount = COUNT(*)
        FROM LegacyRetailDB.dbo.Customers AS src
        WHERE src.CustomerID IS NULL
           OR NOT EXISTS (
                SELECT 1
                FROM RetailReportingDB.dbo.Customers AS tgt
                WHERE tgt.CustomerID = src.CustomerID
              );

        PRINT 'Target Customer Count: ' + CAST(@TargetCount AS VARCHAR(10));
        PRINT 'Migrated Row Count: '    + CAST(@MigratedCount AS VARCHAR(10));
        PRINT 'Rejected Row Count: '    + CAST(@RejectedCount AS VARCHAR(10));

        PRINT 'Customer migration completed successfully.';

        RETURN 0;  -- Success

    END TRY
    BEGIN CATCH

        PRINT 'Customer migration failed.';
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
-- EXEC @ReturnCode = dbo.sp_MigrateCustomers;
-- SELECT @ReturnCode AS ReturnCode;   -- 0 = Success, 1 = Failure
------------------------------------------------------------------------------
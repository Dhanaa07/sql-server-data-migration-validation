/*
==============================================================================
Script Name : 03_Legacy_Data_Assessment.sql
Author      : Dhana Lakshmi
Created On  : 2026-07-06
Purpose     : Performs a read-only data quality assessment of LegacyRetailDB
              prior to migration into RetailReportingDB.

              This script identifies and quantifies common data issues:
              NULLs, blanks, duplicates, invalid formats, orphan records,
              and inconsistent values.

Notes       : - This script is READ-ONLY. It does not modify any data.
              - No tables, views, or stored procedures are created.
              - Results are meant to be reviewed manually in SSMS and used
                to document findings before building the migration logic.
==============================================================================
*/

USE LegacyRetailDB;
GO

------------------------------------------------------------------------------
-- 1. Total Customer Count
------------------------------------------------------------------------------
SELECT COUNT(*) AS TotalCustomers
FROM dbo.Customers;
GO

------------------------------------------------------------------------------
-- 2. Total Order Count
------------------------------------------------------------------------------
SELECT COUNT(*) AS TotalOrders
FROM dbo.Orders;
GO

------------------------------------------------------------------------------
-- 3. NULL Values by Column
-- Checks each column in Customers and Orders for how many NULLs exist.
------------------------------------------------------------------------------

-- Customers table
SELECT
    SUM(CASE WHEN FirstName    IS NULL THEN 1 ELSE 0 END) AS Null_FirstName,
    SUM(CASE WHEN LastName     IS NULL THEN 1 ELSE 0 END) AS Null_LastName,
    SUM(CASE WHEN Email        IS NULL THEN 1 ELSE 0 END) AS Null_Email,
    SUM(CASE WHEN Phone        IS NULL THEN 1 ELSE 0 END) AS Null_Phone,
    SUM(CASE WHEN City         IS NULL THEN 1 ELSE 0 END) AS Null_City,
    SUM(CASE WHEN State        IS NULL THEN 1 ELSE 0 END) AS Null_State,
    SUM(CASE WHEN CreatedDate  IS NULL THEN 1 ELSE 0 END) AS Null_CreatedDate
FROM dbo.Customers;
GO

-- Orders table
SELECT
    SUM(CASE WHEN CustomerID   IS NULL THEN 1 ELSE 0 END) AS Null_CustomerID,
    SUM(CASE WHEN OrderDate    IS NULL THEN 1 ELSE 0 END) AS Null_OrderDate,
    SUM(CASE WHEN OrderAmount  IS NULL THEN 1 ELSE 0 END) AS Null_OrderAmount,
    SUM(CASE WHEN OrderStatus  IS NULL THEN 1 ELSE 0 END) AS Null_OrderStatus
FROM dbo.Orders;
GO

------------------------------------------------------------------------------
-- 4. Empty String Values by Column
-- NULL and '' are different issues. This checks for blank/whitespace-only
-- values that are NOT NULL but still contain no useful data.
------------------------------------------------------------------------------

-- Customers table
SELECT
    SUM(CASE WHEN LTRIM(RTRIM(FirstName))   = '' THEN 1 ELSE 0 END) AS Empty_FirstName,
    SUM(CASE WHEN LTRIM(RTRIM(LastName))    = '' THEN 1 ELSE 0 END) AS Empty_LastName,
    SUM(CASE WHEN LTRIM(RTRIM(Email))       = '' THEN 1 ELSE 0 END) AS Empty_Email,
    SUM(CASE WHEN LTRIM(RTRIM(Phone))       = '' THEN 1 ELSE 0 END) AS Empty_Phone,
    SUM(CASE WHEN LTRIM(RTRIM(City))        = '' THEN 1 ELSE 0 END) AS Empty_City,
    SUM(CASE WHEN LTRIM(RTRIM(State))       = '' THEN 1 ELSE 0 END) AS Empty_State
FROM dbo.Customers;
GO

-- Orders table
SELECT
    SUM(CASE WHEN LTRIM(RTRIM(OrderStatus)) = '' THEN 1 ELSE 0 END) AS Empty_OrderStatus
FROM dbo.Orders;
GO

------------------------------------------------------------------------------
-- 5. Duplicate Customers
-- Identifies customers that appear to be duplicates based on matching
-- FirstName, LastName, and Email (case-insensitive, ignoring spacing).
------------------------------------------------------------------------------
SELECT
    LTRIM(RTRIM(LOWER(FirstName))) AS FirstName_Normalized,
    LTRIM(RTRIM(LOWER(LastName)))  AS LastName_Normalized,
    LTRIM(RTRIM(LOWER(Email)))     AS Email_Normalized,
    COUNT(*)                       AS DuplicateCount
FROM dbo.Customers
GROUP BY
    LTRIM(RTRIM(LOWER(FirstName))),
    LTRIM(RTRIM(LOWER(LastName))),
    LTRIM(RTRIM(LOWER(Email)))
HAVING COUNT(*) > 1;
GO

------------------------------------------------------------------------------
-- 6. Invalid Email Addresses
-- Flags emails that are NULL, blank, or do not match a basic pattern
-- of "text@text.text" (simple sanity check, not full RFC validation).
------------------------------------------------------------------------------
SELECT
    CustomerID,
    Email
FROM dbo.Customers
WHERE Email IS NULL
   OR LTRIM(RTRIM(Email)) = ''
   OR Email NOT LIKE '%_@__%.__%';
GO

------------------------------------------------------------------------------
-- 7. Inconsistent Phone Number Formats
-- Legacy phone numbers appear in multiple formats. This lists the distinct
-- "shapes" of phone data (based on length and non-digit characters) so we
-- can see how many different formats exist before standardizing them.
------------------------------------------------------------------------------
SELECT
    CustomerID,
    Phone,
    LEN(Phone) AS PhoneLength,
    CASE
        WHEN Phone IS NULL THEN 'NULL'
        WHEN Phone LIKE '(___) ___-____'        THEN 'Format: (555) 123-4567'
        WHEN Phone LIKE '___-___-____'          THEN 'Format: 555-123-4567'
        WHEN Phone LIKE '___.___.____'          THEN 'Format: 555.123.4567'
        WHEN Phone NOT LIKE '%[^0-9]%'          THEN 'Format: Digits only'
        ELSE 'Format: Other/Unrecognized'
    END AS PhoneFormat
FROM dbo.Customers
ORDER BY PhoneFormat;
GO

------------------------------------------------------------------------------
-- 8. Invalid Order Amounts
-- OrderAmount is stored as text in the legacy system. This finds values
-- that cannot be safely converted to DECIMAL (e.g. currency symbols,
-- stray spaces, or non-numeric text) using TRY_CONVERT.
------------------------------------------------------------------------------
SELECT
    OrderID,
    OrderAmount,
    TRY_CONVERT(DECIMAL(10,2), OrderAmount) AS ConvertedAmount
FROM dbo.Orders
WHERE OrderAmount IS NOT NULL
  AND TRY_CONVERT(DECIMAL(10,2), OrderAmount) IS NULL;
GO

------------------------------------------------------------------------------
-- 9. Invalid Dates
-- OrderDate and CreatedDate are stored as text with mixed formats.
-- This finds values that cannot be safely converted to DATE using
-- TRY_CONVERT.
------------------------------------------------------------------------------

-- Orders.OrderDate
SELECT
    OrderID,
    OrderDate,
    TRY_CONVERT(DATE, OrderDate) AS ConvertedDate
FROM dbo.Orders
WHERE OrderDate IS NOT NULL
  AND TRY_CONVERT(DATE, OrderDate) IS NULL;
GO

-- Customers.CreatedDate
SELECT
    CustomerID,
    CreatedDate,
    TRY_CONVERT(DATE, CreatedDate) AS ConvertedDate
FROM dbo.Customers
WHERE CreatedDate IS NOT NULL
  AND TRY_CONVERT(DATE, CreatedDate) IS NULL;
GO

------------------------------------------------------------------------------
-- 10. Orphan Orders
-- Finds orders whose CustomerID does not exist in the Customers table.
-- These records would violate referential integrity in the target database.
------------------------------------------------------------------------------
SELECT
    o.OrderID,
    o.CustomerID
FROM dbo.Orders o
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.Customers c
    WHERE c.CustomerID = o.CustomerID
);
GO

------------------------------------------------------------------------------
-- 11. Distribution of Order Status Values
-- Shows all distinct OrderStatus values (including case variations) and
-- how often each occurs, to reveal inconsistent casing/spelling.
------------------------------------------------------------------------------
SELECT
    OrderStatus,
    COUNT(*) AS StatusCount
FROM dbo.Orders
GROUP BY OrderStatus
ORDER BY StatusCount DESC;
GO

------------------------------------------------------------------------------
-- 12. Summary of Data Quality Issues
-- Consolidates the key issue counts from the checks above into a single
-- result set for quick reporting/documentation purposes.
------------------------------------------------------------------------------
SELECT
    (SELECT COUNT(*) FROM dbo.Customers) AS TotalCustomers,

    (SELECT COUNT(*) FROM dbo.Orders) AS TotalOrders,

    (SELECT COUNT(*)
     FROM (
         SELECT LTRIM(RTRIM(LOWER(FirstName))) AS FN,
                LTRIM(RTRIM(LOWER(LastName)))  AS LN,
                LTRIM(RTRIM(LOWER(Email)))     AS EM
         FROM dbo.Customers
         GROUP BY LTRIM(RTRIM(LOWER(FirstName))),
                  LTRIM(RTRIM(LOWER(LastName))),
                  LTRIM(RTRIM(LOWER(Email)))
         HAVING COUNT(*) > 1
     ) AS DupCheck) AS DuplicateCustomerGroups,

    (SELECT COUNT(*)
     FROM dbo.Customers
     WHERE Email IS NULL
        OR LTRIM(RTRIM(Email)) = ''
        OR Email NOT LIKE '%_@__%.__%') AS InvalidEmails,

    (SELECT COUNT(*)
     FROM dbo.Orders
     WHERE OrderAmount IS NOT NULL
       AND TRY_CONVERT(DECIMAL(10,2), OrderAmount) IS NULL) AS InvalidOrderAmounts,

    (SELECT COUNT(*)
     FROM dbo.Orders
     WHERE OrderDate IS NOT NULL
       AND TRY_CONVERT(DATE, OrderDate) IS NULL) AS InvalidOrderDates,

    (SELECT COUNT(*)
     FROM dbo.Customers
     WHERE CreatedDate IS NOT NULL
       AND TRY_CONVERT(DATE, CreatedDate) IS NULL) AS InvalidCreatedDates,

    (SELECT COUNT(*)
     FROM dbo.Orders o
     WHERE NOT EXISTS (
         SELECT 1 FROM dbo.Customers c WHERE c.CustomerID = o.CustomerID
     )) AS OrphanOrders;
GO

PRINT 'Legacy data assessment completed. No data was modified.';
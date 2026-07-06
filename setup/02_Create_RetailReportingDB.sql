/*
==============================================================================
Script Name : 02_Create_RetailReportingDB.sql
Author      : Dhana Lakshmi
Created On  : 2026-07-06
Purpose     : Creates the clean target database (RetailReportingDB) that
              will receive migrated and transformed data from LegacyRetailDB.

              This database represents the "after" state of the migration:
              proper data types, constraints, and relationships enforced.

Notes       : - No data is inserted here. This script only creates structure.
              - Data will be populated later via migration scripts.
==============================================================================
*/

-- Step 1: Create the Reporting Database
IF DB_ID('RetailReportingDB') IS NOT NULL
BEGIN
    ALTER DATABASE RetailReportingDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE RetailReportingDB;
END
GO

CREATE DATABASE RetailReportingDB;
GO

USE RetailReportingDB;
GO

-- Step 2: Create Customers table (clean structure)
CREATE TABLE dbo.Customers
(
    CustomerID      INT             NOT NULL PRIMARY KEY,   -- matches legacy CustomerID (no identity, to preserve source keys)
    FirstName       VARCHAR(50)     NOT NULL,
    LastName        VARCHAR(50)     NOT NULL,
    Email           VARCHAR(100)    NULL,
    Phone           VARCHAR(20)     NULL,                    -- standardized format, e.g. (555) 123-4567
    City            VARCHAR(50)     NULL,
    State           CHAR(2)         NULL,                    -- standardized 2-letter state code
    CreatedDate     DATE            NULL,                    -- proper DATE type instead of text
    LoadDate        DATETIME        NOT NULL DEFAULT GETDATE()  -- tracks when the row was migrated
);
GO

-- Step 3: Create Orders table (clean structure)
CREATE TABLE dbo.Orders
(
    OrderID         INT             NOT NULL PRIMARY KEY,
    CustomerID      INT             NOT NULL,
    OrderDate       DATE            NULL,
    OrderAmount     DECIMAL(10,2)   NULL,                    -- proper numeric type instead of text
    OrderStatus     VARCHAR(20)     NULL,
    LoadDate        DATETIME        NOT NULL DEFAULT GETDATE(),

    CONSTRAINT FK_Orders_Customers FOREIGN KEY (CustomerID)
        REFERENCES dbo.Customers(CustomerID)
);
GO

-- Step 4: Basic indexing to support common reporting queries
-- (e.g. looking up all orders for a customer, or filtering by status)
CREATE INDEX IX_Orders_CustomerID ON dbo.Orders(CustomerID);
CREATE INDEX IX_Orders_OrderStatus ON dbo.Orders(OrderStatus);
GO

PRINT 'RetailReportingDB created successfully with clean schema.';
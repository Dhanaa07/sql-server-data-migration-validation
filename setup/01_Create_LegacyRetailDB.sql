/*
==============================================================================
Script Name : 01_Create_LegacyRetailDB.sql
Author      : Dhana Lakshmi
Created On  : 2026-07-06
Purpose     : Creates the legacy source database (LegacyRetailDB) that
              simulates an old retail system with common data quality
              issues (NULLs, inconsistent formatting, duplicates, etc.).
              This database will act as the SOURCE for our migration
              project into a cleaner reporting database.

Notes       : - This is intentionally messy data. Do NOT clean it here.
              - Cleanup/transformation happens later during migration.
==============================================================================
*/

-- Step 1: Create the Legacy Database
IF DB_ID('LegacyRetailDB') IS NOT NULL
BEGIN
    ALTER DATABASE LegacyRetailDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE LegacyRetailDB;
END
GO

CREATE DATABASE LegacyRetailDB;
GO

USE LegacyRetailDB;
GO

-- Step 2: Create Customers table (legacy structure, no constraints on quality)
CREATE TABLE dbo.Customers
(
    CustomerID      INT             NOT NULL,   -- legacy system used plain INT, not identity
    FirstName       VARCHAR(50)     NULL,
    LastName        VARCHAR(50)     NULL,
    Email           VARCHAR(100)    NULL,
    Phone           VARCHAR(50)     NULL,        -- inconsistent formats expected
    City            VARCHAR(50)     NULL,
    State           VARCHAR(50)     NULL,
    CreatedDate     VARCHAR(20)     NULL         -- stored as text in legacy system, mixed date formats
);
GO

-- Step 3: Create Orders table (legacy structure)
CREATE TABLE dbo.Orders
(
    OrderID         INT             NOT NULL,
    CustomerID      INT             NULL,
    OrderDate       VARCHAR(20)     NULL,        -- inconsistent date formats expected
    OrderAmount     VARCHAR(20)     NULL,        -- stored as text; some values dirty (e.g. "$120.00")
    OrderStatus     VARCHAR(20)     NULL
);
GO

/*
==============================================================================
Step 4: Insert sample dirty data into Customers
Deliberately includes:
  - NULLs
  - trailing/leading spaces
  - mixed case names
  - inconsistent phone formats
  - duplicate records
  - inconsistent date formats
==============================================================================
*/
INSERT INTO dbo.Customers (CustomerID, FirstName, LastName, Email, Phone, City, State, CreatedDate)
VALUES
(1,  'John',      'Smith',    'john.smith@email.com',   '(555) 123-4567', 'New York',   'NY', '2023-01-15'),
(2,  'jane',      'DOE',      'jane.doe@email.com',     '555-234-5678',   'los angeles','CA', '01/20/2023'),
(3,  ' Michael ', 'Brown',    'michael.brown@email.com','5553456789',     'Chicago',    'IL', '2023/02/10'),
(4,  'Sarah',     'Johnson',  NULL,                      '555.456.7890',  'Houston',    'TX', '15-Feb-2023'),
(5,  'David',     'Williams', 'david.williams@email.com',NULL,            'Phoenix',    'AZ', '2023-03-01'),
(6,  'EMILY',     'davis',    'emily.davis@email.com',  '(555) 567-8901', 'Philadelphia','PA','03/05/2023'),
(7,  'John',      'Smith',    'john.smith@email.com',   '(555) 123-4567', 'New York',   'NY', '2023-01-15'),  -- duplicate of CustomerID 1 (data entry duplicate, different ID)
(8,  'Robert',    NULL,       'robert@email.com',       '555-678-9012',   'San Antonio','TX', '2023-04-12'),
(9,  '  Linda',   'Martinez', 'linda.martinez@email.com','5557890123',    'San Diego',  'CA', NULL),
(10, 'james',     'wilson',   'JAMES.WILSON@EMAIL.COM', '(555) 890-1234', 'Dallas',     'TX', '2023-05-20');
GO

/*
==============================================================================
Step 5: Insert sample dirty data into Orders
Deliberately includes:
  - inconsistent date formats
  - inconsistent amount formatting (currency symbols, spaces)
  - inconsistent status casing
  - a couple of orphan CustomerIDs (referential integrity issue)
==============================================================================
*/
INSERT INTO dbo.Orders (OrderID, CustomerID, OrderDate, OrderAmount, OrderStatus)
VALUES
(101, 1,  '2023-06-01',   '120.50',   'Completed'),
(102, 2,  '06/02/2023',   '$85.00',   'completed'),
(103, 3,  '2023/06/03',   '200',      'PENDING'),
(104, 4,  '05-Jun-2023',  ' 45.99 ',  'Shipped'),
(105, 5,  NULL,           '99.99',    'Completed'),
(106, 6,  '2023-06-07',   NULL,       'Cancelled'),
(107, 7,  '2023-06-01',   '120.50',   'Completed'),   -- duplicate order tied to duplicate customer
(108, 9,  '06/09/2023',   '150.00',   'pending'),
(109, 10, '2023-06-10',   '$60',      'Shipped'),
(110, 99, '2023-06-11',   '75.00',    'Completed');   -- CustomerID 99 does not exist (orphan record)
GO

PRINT 'LegacyRetailDB created successfully with sample dirty data.';
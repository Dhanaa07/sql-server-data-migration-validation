/*
==============================================================================
Script Name : 09_vwOrderSummary.sql
Author      : Dhana Lakshmi
Created On  : 2026-07-06
Purpose     : Creates a reporting view that lists each order along with
              the associated customer's name.

Business Purpose:
              Provides a simple, ready-to-use view for order-level
              reporting so reports don't need to repeatedly join Orders
              to Customers.

Assumptions:
              - Runs against RetailReportingDB after Customers and Orders
                have been migrated.
              - INNER JOIN is used because every Order must have a valid
                CustomerID enforced by the foreign key constraint.
==============================================================================
*/

USE RetailReportingDB;
GO

IF OBJECT_ID('dbo.vwOrderSummary', 'V') IS NOT NULL
    DROP VIEW dbo.vwOrderSummary;
GO

CREATE VIEW dbo.vwOrderSummary
AS
SELECT
    o.OrderID,
    o.CustomerID,
    c.FirstName + ' ' + c.LastName AS CustomerName,
    o.OrderDate,
    o.OrderAmount,
    o.OrderStatus
FROM dbo.Orders AS o
INNER JOIN dbo.Customers AS c
    ON c.CustomerID = o.CustomerID;
GO
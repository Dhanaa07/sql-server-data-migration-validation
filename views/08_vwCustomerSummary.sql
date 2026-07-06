/*
==============================================================================
Script Name : 08_vwCustomerSummary.sql
Author      : Dhana Lakshmi
Created On  : 2026-07-06
Purpose     : Creates a reporting view that summarizes each customer along
              with their order activity (total orders, total spend, and
              average order amount).

Business Purpose:
              Provides a single, easy-to-query view for reporting on
              customer value and order behavior, without repeating the
              underlying join/aggregation logic in every report or query.

Assumptions:
              - Runs against RetailReportingDB after Customers and Orders
                have been migrated.
              - LEFT JOIN is used so customers with zero orders still
                appear in the summary (with zero totals).
==============================================================================
*/

USE RetailReportingDB;
GO

IF OBJECT_ID('dbo.vwCustomerSummary', 'V') IS NOT NULL
    DROP VIEW dbo.vwCustomerSummary;
GO

CREATE VIEW dbo.vwCustomerSummary
AS
SELECT
    c.CustomerID,
    c.FirstName + ' ' + c.LastName          AS CustomerName,
    c.Email,
    c.Phone,
    c.City,
    c.State,
    COUNT(o.OrderID)                        AS TotalOrders,
    ISNULL(SUM(o.OrderAmount), 0)           AS TotalOrderAmount,
    ISNULL(AVG(o.OrderAmount), 0)           AS AverageOrderAmount
FROM dbo.Customers AS c
LEFT JOIN dbo.Orders AS o
    ON o.CustomerID = c.CustomerID
GROUP BY
    c.CustomerID,
    c.FirstName,
    c.LastName,
    c.Email,
    c.Phone,
    c.City,
    c.State;
GO
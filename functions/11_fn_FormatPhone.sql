/*
==============================================================================
Script Name : 11_fn_FormatPhone.sql
Author      : Dhana Lakshmi
Created On  : 2026-07-06
Purpose     : Creates a reusable scalar function that standardizes a phone
              number into the format (555) 123-4567.

Business Purpose:
              The legacy system stores phone numbers in multiple formats
              (e.g. '5551234567', '555-123-4567', '(555)1234567',
              '555.123.4567'). This function centralizes the cleanup and
              formatting logic so it can be reused across migration
              scripts instead of repeating the same expression inline.

Assumptions:
              - Only standard formatting characters are stripped:
                parentheses, hyphens, periods, and spaces.
              - After stripping formatting characters, the remaining
                value must be exactly 10 numeric digits to be considered
                valid.
              - Returns NULL if the input is NULL, or if the cleaned
                value is not exactly 10 digits.
              - No regular expressions or CLR functions are used; only
                simple T-SQL string functions (REPLACE, LIKE, LEN).
              - Runs against RetailReportingDB.
==============================================================================
*/

USE RetailReportingDB;
GO

IF OBJECT_ID('dbo.fn_FormatPhone', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_FormatPhone;
GO

CREATE FUNCTION dbo.fn_FormatPhone (@InputPhone VARCHAR(50))
RETURNS VARCHAR(20)
AS
BEGIN
    DECLARE @Cleaned VARCHAR(50);

    IF @InputPhone IS NULL
        RETURN NULL;

    -- Strip common formatting characters: ( ) - . and spaces
    SET @Cleaned = REPLACE(@InputPhone, '(', '');
    SET @Cleaned = REPLACE(@Cleaned, ')', '');
    SET @Cleaned = REPLACE(@Cleaned, '-', '');
    SET @Cleaned = REPLACE(@Cleaned, '.', '');
    SET @Cleaned = REPLACE(@Cleaned, ' ', '');

    -- Must be exactly 10 numeric digits to be considered valid
    IF LEN(@Cleaned) <> 10 OR @Cleaned LIKE '%[^0-9]%'
        RETURN NULL;

    RETURN '(' + SUBSTRING(@Cleaned, 1, 3) + ') '
               + SUBSTRING(@Cleaned, 4, 3) + '-'
               + SUBSTRING(@Cleaned, 7, 4);
END;
GO

------------------------------------------------------------------------------
-- Example Usage:
-- SELECT dbo.fn_FormatPhone('5551234567');      -- Returns '(555) 123-4567'
-- SELECT dbo.fn_FormatPhone('555-123-4567');     -- Returns '(555) 123-4567'
-- SELECT dbo.fn_FormatPhone(NULL);               -- Returns NULL
------------------------------------------------------------------------------

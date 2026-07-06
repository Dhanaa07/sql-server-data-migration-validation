/*
==============================================================================
Script Name : 10_fn_ProperCase.sql
Author      : Dhana Lakshmi
Created On  : 2026-07-06
Purpose     : Creates a reusable scalar function that converts a string
              into Proper Case (first letter uppercase, remaining letters
              lowercase), after trimming leading/trailing spaces.

Business Purpose:
              Name and city fields in the legacy system arrive in mixed
              casing (e.g. 'JOHN', 'jAnE'). This function centralizes the
              Proper Case logic so it can be reused across migration
              scripts instead of repeating the same expression inline.

Assumptions:
              - Input is a single word or simple name (e.g. 'JOHN',
                'michael'). This is a simple implementation and does not
                handle multi-word names (e.g. 'mary jane') or hyphenated
                names specially.
              - Returns NULL if the input is NULL.
              - Runs against RetailReportingDB.
==============================================================================
*/

USE RetailReportingDB;
GO

IF OBJECT_ID('dbo.fn_ProperCase', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_ProperCase;
GO

CREATE FUNCTION dbo.fn_ProperCase (@InputText VARCHAR(100))
RETURNS VARCHAR(100)
AS
BEGIN
    DECLARE @Result VARCHAR(100);
    DECLARE @Trimmed VARCHAR(100);

    IF @InputText IS NULL
        RETURN NULL;

    SET @Trimmed = LTRIM(RTRIM(@InputText));

    IF @Trimmed = ''
        RETURN @Trimmed;

    SET @Result = UPPER(LEFT(@Trimmed, 1)) + LOWER(SUBSTRING(@Trimmed, 2, LEN(@Trimmed)));

    RETURN @Result;
END;
GO

------------------------------------------------------------------------------
-- Example Usage:
-- SELECT dbo.fn_ProperCase('JOHN');        -- Returns 'John'
-- SELECT dbo.fn_ProperCase(NULL);          -- Returns NULL
------------------------------------------------------------------------------

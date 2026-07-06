------------------------------------------------------------------------------
-- Step 1: Log source row count
------------------------------------------------------------------------------
DECLARE @SourceCount INT;
DECLARE @TargetCount INT;
DECLARE @MigratedCount INT;
DECLARE @RejectedCount INT;

SELECT @SourceCount = COUNT(*)
FROM LegacyRetailDB.dbo.Customers;

PRINT 'Starting Customer Migration...';
PRINT 'Source Customer Count: ' + CAST(@SourceCount AS VARCHAR(10));

------------------------------------------------------------------------------
-- Step 2: Customer Migration
------------------------------------------------------------------------------
BEGIN TRY

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

    --------------------------------------------------------------------------
    -- First Name
    --------------------------------------------------------------------------
    CASE
        WHEN src.FirstName IS NULL
             OR LTRIM(RTRIM(src.FirstName)) = ''
        THEN 'Unknown'
        ELSE
            UPPER(LEFT(LTRIM(RTRIM(src.FirstName)),1))
            + LOWER(SUBSTRING(LTRIM(RTRIM(src.FirstName)),2,100))
    END,

    --------------------------------------------------------------------------
    -- Last Name
    --------------------------------------------------------------------------
    CASE
        WHEN src.LastName IS NULL
             OR LTRIM(RTRIM(src.LastName)) = ''
        THEN 'Unknown'
        ELSE
            UPPER(LEFT(LTRIM(RTRIM(src.LastName)),1))
            + LOWER(SUBSTRING(LTRIM(RTRIM(src.LastName)),2,100))
    END,

    --------------------------------------------------------------------------
    -- Email
    --------------------------------------------------------------------------
    CASE
        WHEN src.Email IS NULL THEN NULL
        WHEN LTRIM(RTRIM(src.Email))='' THEN NULL
        WHEN LOWER(LTRIM(RTRIM(src.Email)))
             NOT LIKE '%_@__%.__%'
        THEN NULL
        ELSE LOWER(LTRIM(RTRIM(src.Email)))
    END,

    --------------------------------------------------------------------------
    -- Phone
    --------------------------------------------------------------------------
    CASE

        WHEN LEN(
            REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
            src.Phone,'(',''),')',''),'-',''),'.',''),' ','')
            ) = 10

        AND
        REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
            src.Phone,'(',''),')',''),'-',''),'.',''),' ','')
        NOT LIKE '%[^0-9]%'

        THEN

            '('
            + SUBSTRING(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                src.Phone,'(',''),')',''),'-',''),'.',''),' ',''),1,3)
            + ') '
            + SUBSTRING(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                src.Phone,'(',''),')',''),'-',''),'.',''),' ',''),4,3)
            + '-'
            + SUBSTRING(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                src.Phone,'(',''),')',''),'-',''),'.',''),' ',''),7,4)

        ELSE NULL

    END,

    --------------------------------------------------------------------------
    -- City
    --------------------------------------------------------------------------
    CASE
        WHEN src.City IS NULL
             OR LTRIM(RTRIM(src.City))=''
        THEN NULL

        ELSE
            UPPER(LEFT(LTRIM(RTRIM(src.City)),1))
            + LOWER(SUBSTRING(LTRIM(RTRIM(src.City)),2,100))
    END,

    --------------------------------------------------------------------------
    -- State
    --------------------------------------------------------------------------
    CASE

        WHEN src.State IS NULL
             OR LTRIM(RTRIM(src.State))=''
        THEN NULL

        ELSE LEFT(UPPER(LTRIM(RTRIM(src.State))),2)

    END,

    --------------------------------------------------------------------------
    -- Created Date
    --------------------------------------------------------------------------
    TRY_CONVERT(DATE,src.CreatedDate)

FROM LegacyRetailDB.dbo.Customers src

WHERE src.CustomerID IS NOT NULL

AND NOT EXISTS
(
    SELECT 1
    FROM RetailReportingDB.dbo.Customers tgt
    WHERE tgt.CustomerID = src.CustomerID
);

SET @MigratedCount = @@ROWCOUNT;

SELECT @TargetCount = COUNT(*)
FROM RetailReportingDB.dbo.Customers;

SET @RejectedCount = @SourceCount - @MigratedCount;

PRINT '----------------------------------------';
PRINT 'Target Customer Count : ' + CAST(@TargetCount AS VARCHAR(10));
PRINT 'Migrated Row Count    : ' + CAST(@MigratedCount AS VARCHAR(10));
PRINT 'Rejected Row Count    : ' + CAST(@RejectedCount AS VARCHAR(10));
PRINT 'Customer migration completed successfully.';
PRINT '----------------------------------------';

END TRY

BEGIN CATCH

PRINT 'Customer migration failed.';
PRINT ERROR_MESSAGE();

END CATCH;
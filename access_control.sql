-- ============================================================
--   access_control.sql (Member 2 - Roles, users, views, stored procedures)
--
--	 Green Acres Realty Sdn Bhd
--	 Estate Management System (EMS) - Full Database Schema
--   CT069-3-3 Database Security Assignment
--
--   Assigned Roles (Based on existing roles from SystemUsers table):
--   'DBA'				[role_DBA]
--   'PropMgmtDev'		[role_PropMgmtDev]
--   'ClientPortalDev'	[role_ClientPortalDev]
--   'Analyst'			[role_Analyst]
--   'ReadOnly'			[role_ReadOnly]
--   'Admin'			[role_Admin]
--
--   ============================================================

USE GreenAcresEMS;
GO


-- ============================================================
--   SECTION 1: Database Roles
--   ------------------------------------------------------------
--   One role per UserRole value from SystemUsers table.
--   Permissions are granted based on the role (PoLP - Principle of Least Privilege).
--
--   role_DBA			  : Database administrators (Full Control on Database)
--   role_Admin			  : System administrators with broad operational read/write (but not full Database control)
--   role_PropMgmtDev	  : Property & maintenance developers
--   role_ClientPortalDev : Client-facing portal developers
--   role_Analyst         : Analytics/reporting (Read-only aggregates)
--   role_ReadOnly        : General staff (Read via safe views only)
--   ============================================================ 

-- Remove members before dropping roles
DECLARE @RoleName   NVARCHAR(128);
DECLARE @MemberName NVARCHAR(128);
DECLARE @sql        NVARCHAR(500);

-- Remove members one at a time until none remain
WHILE EXISTS (
    SELECT 1
    FROM sys.database_role_members rm
    JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
    WHERE r.name IN (
        'role_Admin', 'role_DBA', 'role_PropMgmtDev',
        'role_ClientPortalDev', 'role_Analyst', 'role_ReadOnly'
    )
)
BEGIN
    SELECT TOP 1
        @RoleName   = r.name,
        @MemberName = m.name
    FROM sys.database_role_members rm
    JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
    JOIN sys.database_principals m ON m.principal_id = rm.member_principal_id
    WHERE r.name IN (
        'role_Admin', 'role_DBA', 'role_PropMgmtDev',
        'role_ClientPortalDev', 'role_Analyst', 'role_ReadOnly'
    );

    SET @sql = 'ALTER ROLE [' + @RoleName + '] DROP MEMBER [' + @MemberName + ']';
    EXEC(@sql);
END;

-- All roles are now empty so safe to drop
IF DATABASE_PRINCIPAL_ID('role_Admin')           IS NOT NULL DROP ROLE role_Admin;
IF DATABASE_PRINCIPAL_ID('role_DBA')             IS NOT NULL DROP ROLE role_DBA;
IF DATABASE_PRINCIPAL_ID('role_PropMgmtDev')     IS NOT NULL DROP ROLE role_PropMgmtDev;
IF DATABASE_PRINCIPAL_ID('role_ClientPortalDev') IS NOT NULL DROP ROLE role_ClientPortalDev;
IF DATABASE_PRINCIPAL_ID('role_Analyst')         IS NOT NULL DROP ROLE role_Analyst;
IF DATABASE_PRINCIPAL_ID('role_ReadOnly')        IS NOT NULL DROP ROLE role_ReadOnly;

PRINT 'All roles removed successfully.';
GO

-- Create the 6 necessary roles
CREATE ROLE role_Admin;
CREATE ROLE role_DBA;
CREATE ROLE role_PropMgmtDev;
CREATE ROLE role_ClientPortalDev;
CREATE ROLE role_Analyst;
CREATE ROLE role_ReadOnly;
GO

-- ============================================================
--   SECTION 2: Logins And Database Users (Create two login acc per role)
--   ============================================================

----------------------------------------------------------------
-- 2.1  DBA users  (Database Administration)
----------------------------------------------------------------
IF SUSER_ID('arun.kumar') IS NULL
    CREATE LOGIN [arun.kumar] WITH PASSWORD = 'Dba@Strong#2026',
        CHECK_POLICY = ON;
GO
IF USER_ID('arun.kumar') IS NULL
    CREATE USER [arun.kumar] FOR LOGIN [arun.kumar];
GO
ALTER ROLE role_DBA ADD MEMBER [arun.kumar];
GO

IF SUSER_ID('linda.tan') IS NULL
    CREATE LOGIN [linda.tan] WITH PASSWORD = 'Dba@Strong#2026',
        CHECK_POLICY = ON;
GO
IF USER_ID('linda.tan') IS NULL
    CREATE USER [linda.tan] FOR LOGIN [linda.tan];
GO
ALTER ROLE role_DBA ADD MEMBER [linda.tan];
GO

----------------------------------------------------------------
-- 2.2  Admin users  (IT dept / Cybersecurity managers)
----------------------------------------------------------------
IF SUSER_ID('farid.rahman') IS NULL
    CREATE LOGIN [farid.rahman] WITH PASSWORD = 'Admin@Strong#2026',
        CHECK_POLICY = ON;
GO
IF USER_ID('farid.rahman') IS NULL
    CREATE USER [farid.rahman] FOR LOGIN [farid.rahman];
GO
ALTER ROLE role_Admin ADD MEMBER [farid.rahman];
GO

IF SUSER_ID('melissa.wong') IS NULL
    CREATE LOGIN [melissa.wong] WITH PASSWORD = 'Admin@Strong#2026',
        CHECK_POLICY = ON;
GO
IF USER_ID('melissa.wong') IS NULL
    CREATE USER [melissa.wong] FOR LOGIN [melissa.wong];
GO
ALTER ROLE role_Admin ADD MEMBER [melissa.wong];
GO



----------------------------------------------------------------
-- 2.3  Property Management developers
----------------------------------------------------------------
IF SUSER_ID('kelvin.ong') IS NULL
    CREATE LOGIN [kelvin.ong] WITH PASSWORD = 'Prop@Strong#2026',
        CHECK_POLICY = ON;
GO
IF USER_ID('kelvin.ong') IS NULL
    CREATE USER [kelvin.ong] FOR LOGIN [kelvin.ong];
GO
ALTER ROLE role_PropMgmtDev ADD MEMBER [kelvin.ong];
GO

IF SUSER_ID('aminah.salleh') IS NULL
    CREATE LOGIN [aminah.salleh] WITH PASSWORD = 'Prop@Strong#2026',
        CHECK_POLICY = ON;
GO
IF USER_ID('aminah.salleh') IS NULL
    CREATE USER [aminah.salleh] FOR LOGIN [aminah.salleh];
GO
ALTER ROLE role_PropMgmtDev ADD MEMBER [aminah.salleh];
GO

----------------------------------------------------------------
-- 2.4  Client Portal developers
----------------------------------------------------------------
IF SUSER_ID('vijay.menon') IS NULL
    CREATE LOGIN [vijay.menon] WITH PASSWORD = 'Portal@Strong#2026',
        CHECK_POLICY = ON;
GO
IF USER_ID('vijay.menon') IS NULL
    CREATE USER [vijay.menon] FOR LOGIN [vijay.menon];
GO
ALTER ROLE role_ClientPortalDev ADD MEMBER [vijay.menon];
GO

IF SUSER_ID('sofia.aziz') IS NULL
    CREATE LOGIN [sofia.aziz] WITH PASSWORD = 'Portal@Strong#2026',
        CHECK_POLICY = ON;
GO
IF USER_ID('sofia.aziz') IS NULL
    CREATE USER [sofia.aziz] FOR LOGIN [sofia.aziz];
GO
ALTER ROLE role_ClientPortalDev ADD MEMBER [sofia.aziz];
GO

----------------------------------------------------------------
-- 2.5  Analysts  (Data Analytics department)
----------------------------------------------------------------
IF SUSER_ID('hakim.zulkifli') IS NULL
    CREATE LOGIN [hakim.zulkifli] WITH PASSWORD = 'Analyst@Strong#2026',
        CHECK_POLICY = ON;
GO
IF USER_ID('hakim.zulkifli') IS NULL
    CREATE USER [hakim.zulkifli] FOR LOGIN [hakim.zulkifli];
GO
ALTER ROLE role_Analyst ADD MEMBER [hakim.zulkifli];
GO

IF SUSER_ID('rachel.lee') IS NULL
    CREATE LOGIN [rachel.lee] WITH PASSWORD = 'Analyst@Strong#2026',
        CHECK_POLICY = ON;
GO
IF USER_ID('rachel.lee') IS NULL
    CREATE USER [rachel.lee] FOR LOGIN [rachel.lee];
GO
ALTER ROLE role_Analyst ADD MEMBER [rachel.lee];
GO

----------------------------------------------------------------
-- 2.6  Read-only staff  (Audit, Application Support, etc.)
----------------------------------------------------------------
IF SUSER_ID('jason.lim') IS NULL
    CREATE LOGIN [jason.lim] WITH PASSWORD = 'Read@Strong#2026',
        CHECK_POLICY = ON;
GO
IF USER_ID('jason.lim') IS NULL
    CREATE USER [jason.lim] FOR LOGIN [jason.lim];
GO
ALTER ROLE role_ReadOnly ADD MEMBER [jason.lim];
GO

IF SUSER_ID('nurul.huda') IS NULL
    CREATE LOGIN [nurul.huda] WITH PASSWORD = 'Read@Strong#2026',
        CHECK_POLICY = ON;
GO
IF USER_ID('nurul.huda') IS NULL
    CREATE USER [nurul.huda] FOR LOGIN [nurul.huda];
GO
ALTER ROLE role_ReadOnly ADD MEMBER [nurul.huda];
GO


-- ============================================================
--   SECTION 3: Permissions 
--   ------------------------------------------------------------
--     role_DBA           = Full control on the database (full access including UNMASK)
--     role_Admin         = Broad read/write on all operational tables (UNMASK granted to see real PII when needed & no DB structural control)
--     role_PropMgmtDev   = Property & maintenance domain only (Writes are funnelled through procedures)
--     role_ClientPortalDev = Client & transaction domain (Denied encrypted blob columns and financials)
--     role_Analyst       = SELECT on views only (NOT granted UNMASK)
--     role_ReadOnly      = SELECT on safe views only (no base table access at all)

--	   UNMASK/ CONTROL will make sure DDM shows the real values (Information will be masked for non-UNMASK roles)
--   ============================================================ 

----------------------------------------------------------------
-- 3.1  DBA: Full control (UNMASK + Alter any information)
----------------------------------------------------------------
GRANT CONTROL ON DATABASE::GreenAcresEMS TO role_DBA;
GO

----------------------------------------------------------------
-- 3.2  Admin: Broad operational read/write + UNMASK for PII
--      (They need to resolve client queries)
----------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE ON dbo.Properties          TO role_Admin;
GRANT SELECT, INSERT, UPDATE ON dbo.Clients             TO role_Admin;
GRANT SELECT, INSERT, UPDATE ON dbo.Agents              TO role_Admin;
GRANT SELECT, INSERT, UPDATE ON dbo.Transactions        TO role_Admin;
GRANT SELECT, INSERT, UPDATE ON dbo.MaintenanceRequests TO role_Admin;
GRANT SELECT, INSERT, UPDATE ON dbo.LeaseAgreements     TO role_Admin;
GRANT SELECT, INSERT, UPDATE ON dbo.CommissionPayments  TO role_Admin;
GRANT SELECT, INSERT, UPDATE ON dbo.SystemUsers         TO role_Admin;
GRANT SELECT, INSERT, UPDATE ON dbo.Departments         TO role_Admin;
GRANT SELECT, INSERT, UPDATE ON dbo.Notifications       TO role_Admin;
GRANT SELECT, INSERT, UPDATE ON dbo.MaintenanceStaff    TO role_Admin;
-- Admin can see real PII values
GRANT UNMASK TO role_Admin;
GO

----------------------------------------------------------------
-- 3.3  Property Management developer:
--      Property + maintenance domain & read on supporting tables
----------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE ON dbo.Properties          TO role_PropMgmtDev;
GRANT SELECT, INSERT, UPDATE ON dbo.MaintenanceRequests TO role_PropMgmtDev;
GRANT SELECT, INSERT, UPDATE ON dbo.MaintenanceStaff    TO role_PropMgmtDev;
GRANT SELECT                  ON dbo.Clients            TO role_PropMgmtDev;
GRANT SELECT                  ON dbo.Agents             TO role_PropMgmtDev;
GRANT SELECT                  ON dbo.Departments        TO role_PropMgmtDev;
-- PropMgmtDev cannot see commission data
DENY  SELECT ON dbo.CommissionPayments                  TO role_PropMgmtDev;
GO

----------------------------------------------------------------
-- 3.4  Client Portal developer:
--      Client & transaction domain
----------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE ON dbo.Clients             TO role_ClientPortalDev;
GRANT SELECT                  ON dbo.Properties         TO role_ClientPortalDev;
GRANT SELECT, INSERT, UPDATE ON dbo.Transactions        TO role_ClientPortalDev;
GRANT SELECT, INSERT, UPDATE ON dbo.LeaseAgreements     TO role_ClientPortalDev;
GRANT SELECT                  ON dbo.Agents             TO role_ClientPortalDev;

----------------------------------------------------------------
-- 3.5  Analyst: Read-only reporting via views only. (Not granted UNMASK so analysts see anonymised PII)
----------------------------------------------------------------
GRANT SELECT ON dbo.Properties          TO role_Analyst;
GRANT SELECT ON dbo.Transactions        TO role_Analyst;
GRANT SELECT ON dbo.MaintenanceRequests TO role_Analyst;
GRANT SELECT ON dbo.Agents              TO role_Analyst;
GRANT SELECT ON dbo.Departments         TO role_Analyst;


----------------------------------------------------------------
-- 3.6  ReadOnly: No base-table grants at all (Access is only through safe views)
----------------------------------------------------------------

-- No base-table grants so skip
GO


-- ============================================================
--   SECTION 4: VIEWS
--   ------------------------------------------------------------
--   Give selective column and information viewing (So that base tables cannot be accessed directly.)
--
--   Views created:
--     1. vw_PropertyListing       - Public-safe property catalogue
--     2. vw_ClientDirectory       - Client list without PII blobs
--     3. vw_ActiveLeases          - Active lease summary
--     4. vw_AgentPerformance      - Per-agent transaction summary
--     5. vw_MonthlySalesSummary   - Monthly revenue roll-up
--     6. vw_MaintenanceOverview   - Maintenance workload overview
--     7. vw_CommissionSummary     - Commission roll-up
--   ============================================================

----------------------------------------------------------------
-- 4.1  Property listing (List of Properties with their information & status)
----------------------------------------------------------------
CREATE OR ALTER VIEW vw_PropertyListing
AS
    SELECT
        PropertyID,
        PropertyName,
        City,
        State,
        PostalCode,
        PropertyType,
        Bedrooms,
        Bathrooms,
        SizeSqft,
        Price,       -- Masked for non-UNMASK roles
        Status
    FROM dbo.Properties
    WHERE IsActive = 1;
GO

SELECT * FROM vw_PropertyListing;

----------------------------------------------------------------
-- 4.2  Client directory (List of clients and their respective information)
----------------------------------------------------------------
CREATE OR ALTER VIEW vw_ClientDirectory
AS
    SELECT
        ClientID,
        FullName,
        NRIC,            -- Masked for non-UNMASK roles
        ContactNumber,   -- Masked for non-UNMASK roles
        Email,           -- Masked for non-UNMASK roles
        ClientType,
        IsActive,
        RegisteredDate
    FROM dbo.Clients;
GO

SELECT * FROM vw_ClientDirectory;

----------------------------------------------------------------
-- 4.3  Active leases (List of properties that still have Active lease status)
----------------------------------------------------------------
CREATE OR ALTER VIEW vw_ActiveLeases
AS
    SELECT
        l.LeaseID,
        p.PropertyName,
        p.City,
        c.FullName          AS ClientName,
        l.LeaseStartDate,
        l.LeaseEndDate,
        l.MonthlyRent,      -- Masked for non-UNMASK roles
        l.LeaseStatus
    FROM dbo.LeaseAgreements l
    INNER JOIN dbo.Properties p ON p.PropertyID = l.PropertyID
    INNER JOIN dbo.Clients    c ON c.ClientID   = l.ClientID
    WHERE l.LeaseStatus = 'Active';
GO

SELECT * FROM vw_ActiveLeases;

----------------------------------------------------------------
-- 4.4  Agent performance (List of Agents with their compiled sales/ performance and their values)
----------------------------------------------------------------
CREATE OR ALTER VIEW vw_AgentPerformance
AS
    SELECT
        a.AgentID,
        a.FullName              AS AgentName,
        a.LicenseNumber,
        COUNT(t.TransactionID)  AS TotalTransactions,
        SUM(CASE WHEN t.TransactionType = 'Sale' THEN 1 ELSE 0 END) AS TotalSales,
        SUM(CASE WHEN t.TransactionType = 'Rent' THEN 1 ELSE 0 END) AS TotalRentals,
        SUM(t.Amount)           AS TotalTransactionValue
    FROM dbo.Agents a
    LEFT JOIN dbo.Transactions t ON t.AgentID = a.AgentID
    WHERE a.IsActive = 1
    GROUP BY a.AgentID, a.FullName, a.LicenseNumber;
GO

SELECT * FROM vw_AgentPerformance;

----------------------------------------------------------------
-- 4.5  Monthly sales summary (Revenue summary of rent and sale transactions based on sales year and month - For analytics)
----------------------------------------------------------------
CREATE OR ALTER VIEW vw_MonthlySalesSummary
AS
    SELECT
        YEAR(t.TransactionDate)     AS SalesYear,
        MONTH(t.TransactionDate)    AS SalesMonth,
        t.TransactionType,
        COUNT(t.TransactionID)      AS NumberOfTransactions,
        SUM(t.Amount)               AS TotalAmount
    FROM dbo.Transactions t
    WHERE t.PaymentStatus = 'Completed'
    GROUP BY
        YEAR(t.TransactionDate),
        MONTH(t.TransactionDate),
        t.TransactionType;
GO

SELECT * FROM vw_MonthlySalesSummary;

----------------------------------------------------------------
-- 4.6  Maintenance overview (List of properties with Maintenance works and their respective details/progress)
----------------------------------------------------------------
CREATE OR ALTER VIEW vw_MaintenanceOverview
AS
    SELECT
        m.RequestID,
        p.PropertyName,
        p.City,
        m.Priority,
        m.Status,
        m.RequestDate,
        m.CompletedDate,
        s.FullName          AS AssignedStaff
    FROM dbo.MaintenanceRequests m
    INNER JOIN dbo.Properties p       ON p.PropertyID = m.PropertyID
    LEFT  JOIN dbo.MaintenanceStaff s ON s.StaffID    = m.AssignedStaffID;
GO

SELECT * FROM vw_MaintenanceOverview;

----------------------------------------------------------------
-- 4.7  Commission summary (List of Agents and their commission details & history)
----------------------------------------------------------------
CREATE OR ALTER VIEW vw_CommissionSummary
AS
    SELECT
        cp.CommissionID,
        a.FullName          AS AgentName,
        t.TransactionType,
        cp.CommissionRate,  -- masked for non-UNMASK roles
        cp.CommissionAmount,-- masked for non-UNMASK roles
        cp.PaymentStatus,
        cp.PaymentDate
    FROM dbo.CommissionPayments cp
    INNER JOIN dbo.Agents       a ON a.AgentID       = cp.AgentID
    INNER JOIN dbo.Transactions t ON t.TransactionID = cp.TransactionID;
GO

SELECT * FROM vw_CommissionSummary;

-- ------------------------------------------------------------
--   4.8  View-Level Permission Grants
--   ------------------------------------------------------------
--   Read-only and Analyst roles get SELECT on views only. (role_ReadOnly gets data without any base-table permission.)
--   ------------------------------------------------------------

-- role_Admin: All views (Direct table access)
GRANT SELECT ON vw_PropertyListing     TO role_Admin;
GRANT SELECT ON vw_ClientDirectory     TO role_Admin;
GRANT SELECT ON vw_ActiveLeases        TO role_Admin;
GRANT SELECT ON vw_AgentPerformance    TO role_Admin;
GRANT SELECT ON vw_MonthlySalesSummary TO role_Admin;
GRANT SELECT ON vw_MaintenanceOverview TO role_Admin;
GRANT SELECT ON vw_CommissionSummary   TO role_Admin;
GO

-- role_PropMgmtDev: Property & maintenance views
GRANT SELECT ON vw_PropertyListing     TO role_PropMgmtDev;
GRANT SELECT ON vw_MaintenanceOverview TO role_PropMgmtDev;
GO

-- role_ClientPortalDev: Client, property & lease views
GRANT SELECT ON vw_PropertyListing     TO role_ClientPortalDev;
GRANT SELECT ON vw_ClientDirectory     TO role_ClientPortalDev;
GRANT SELECT ON vw_ActiveLeases        TO role_ClientPortalDev;
GO

-- role_Analyst: Reporting / analytical views (including financial)
GRANT SELECT ON vw_PropertyListing     TO role_Analyst;
GRANT SELECT ON vw_AgentPerformance    TO role_Analyst;
GRANT SELECT ON vw_MonthlySalesSummary TO role_Analyst;
GRANT SELECT ON vw_MaintenanceOverview TO role_Analyst;
GRANT SELECT ON vw_CommissionSummary   TO role_Analyst;
GRANT SELECT ON vw_ClientDirectory	   TO role_Analyst;
GO

-- role_ReadOnly: Operational non-financial views
GRANT SELECT ON vw_PropertyListing     TO role_ReadOnly;
GRANT SELECT ON vw_ClientDirectory     TO role_ReadOnly;
GRANT SELECT ON vw_ActiveLeases        TO role_ReadOnly;
GRANT SELECT ON vw_MaintenanceOverview TO role_ReadOnly;
GO

-- ============================================================
--   SECTION 5: STORED PROCEDURES
--   ------------------------------------------------------------
--     Client Management
--       1. usp_ManageClient         
--       2. usp_DeactivateClient
--       3. usp_ReactivateClient 

--     Property Management
--       4. usp_ManageProperty       
--       5. usp_UpdatePropertyStatus 

--     Transaction / Operations
--       6. usp_RecordTransaction 
--       7. usp_UpdateTransactionStatus
--       8. usp_LogMaintenanceRequest 
--       9. usp_AssignMaintenanceStaff 

--     Reporting
--       10. usp_GetAgentTransactions

--     User Access Management (Extra)
--       11. usp_ProvisionUser 
--       12. usp_DeprovisionUser 
--   ============================================================

----------------------------------------------------------------
-- 5.1  usp_ManageClient (Adding a new client)
--      When ClientID is NULL = INSERT new client
--      When ClientID is Non-NULL= UPDATE info (Only selected details)
----------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.usp_ManageClient
    @ClientID      INT            = NULL,
    @FullName      NVARCHAR(100)  = NULL,
    @NRIC          NVARCHAR(20)   = NULL,
    @ContactNumber NVARCHAR(20)   = NULL,
    @Email         NVARCHAR(100)  = NULL,
    @Address       NVARCHAR(255)  = NULL,
    @ClientType    NVARCHAR(50)   = 'Individual'
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- INSERT: New client
        IF @ClientID IS NULL
        BEGIN
            IF @FullName IS NULL OR @ContactNumber IS NULL OR @Email IS NULL
            BEGIN
                RAISERROR('FullName, ContactNumber and Email are mandatory for a new client.', 16, 1);
                RETURN;
            END;

            INSERT INTO dbo.Clients
                (FullName, NRIC, ContactNumber, Email, Address, ClientType)
            VALUES
                (@FullName, @NRIC, @ContactNumber, @Email, @Address, @ClientType);

            PRINT 'New client created with ID: ' + CAST(SCOPE_IDENTITY() AS VARCHAR(10));
        END
        -- UPDATE: Existing client (Only non-NULL info change)
        ELSE
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.Clients WHERE ClientID = @ClientID)
            BEGIN
                RAISERROR('Client ID not found.', 16, 1);
                RETURN;
            END;

            UPDATE dbo.Clients
            SET
                FullName      = ISNULL(@FullName,      FullName),
                NRIC          = ISNULL(@NRIC,          NRIC),
                ContactNumber = ISNULL(@ContactNumber, ContactNumber),
                Email         = ISNULL(@Email,         Email),
                Address       = ISNULL(@Address,       Address),
                ClientType    = ISNULL(@ClientType,    ClientType)
            WHERE ClientID = @ClientID;

            PRINT 'Client record updated.';
        END;
    END TRY
    BEGIN CATCH
        RAISERROR('Client operation failed. Please contact the DBA.', 16, 1);
    END CATCH;
END;
GO

----------------------------------------------------------------
-- 5.2  usp_DeactivateClient  (Deactivating an existing client - Soft delete)
----------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.usp_DeactivateClient
    @ClientID INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Clients WHERE ClientID = @ClientID)
    BEGIN
        RAISERROR('Client ID not found.', 16, 1);
        RETURN;
    END;

    UPDATE dbo.Clients
    SET IsActive = 0
    WHERE ClientID = @ClientID;

    PRINT 'Client deactivated.';
END;
GO

----------------------------------------------------------------
-- 5.3  usp_ReactivateClient  (Undo - Reactivating a deactivated client)
----------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.usp_ReactivateClient
    @ClientID INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Check if client record exists
    IF NOT EXISTS (SELECT 1 FROM dbo.Clients WHERE ClientID = @ClientID)
    BEGIN
        RAISERROR('Client ID not found.', 16, 1);
        RETURN;
    END;

    -- Check if client is actually deactivated 
    IF NOT EXISTS (SELECT 1 FROM dbo.Clients WHERE ClientID = @ClientID AND IsActive = 0)
    BEGIN
        RAISERROR('Client is already active. No changes made.', 16, 1);
        RETURN;
    END;

    UPDATE dbo.Clients
    SET IsActive = 1
    WHERE ClientID = @ClientID;

    PRINT 'Client reactivated successfully.';
END;
GO

----------------------------------------------------------------
-- 5.4  usp_ManageProperty (Adding a new property & Updating an existing property)
----------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.usp_ManageProperty
    @PropertyID   INT            = NULL,
    @PropertyName NVARCHAR(150)  = NULL,
    @Address      NVARCHAR(255)  = NULL,
    @City         NVARCHAR(100)  = NULL,
    @State        NVARCHAR(100)  = NULL,
    @PostalCode   NVARCHAR(10)   = NULL,
    @PropertyType NVARCHAR(50)   = NULL,
    @Bedrooms     TINYINT        = NULL,
    @Bathrooms    TINYINT        = NULL,
    @SizeSqft     DECIMAL(10,2)  = NULL,
    @Price        DECIMAL(18,2)  = NULL,
    @Status       NVARCHAR(50)   = 'Available'
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF @PropertyID IS NULL
        BEGIN
            IF @PropertyName IS NULL OR @Address IS NULL OR @City IS NULL
               OR @State IS NULL OR @PropertyType IS NULL OR @Price IS NULL
            BEGIN
                RAISERROR('Name, Address, City, State, PropertyType and Price are mandatory.', 16, 1);
                RETURN;
            END;

            INSERT INTO dbo.Properties
                (PropertyName, Address, City, State, PostalCode,
                 PropertyType, Bedrooms, Bathrooms, SizeSqft, Price, Status)
            VALUES
                (@PropertyName, @Address, @City, @State, @PostalCode,
                 @PropertyType, @Bedrooms, @Bathrooms, @SizeSqft, @Price, @Status);

            PRINT 'New property created with ID: ' + CAST(SCOPE_IDENTITY() AS VARCHAR(10));
        END
        ELSE
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.Properties WHERE PropertyID = @PropertyID)
            BEGIN
                RAISERROR('Property ID not found.', 16, 1);
                RETURN;
            END;

            UPDATE dbo.Properties
            SET
                PropertyName = ISNULL(@PropertyName, PropertyName),
                Address      = ISNULL(@Address,      Address),
                City         = ISNULL(@City,         City),
                State        = ISNULL(@State,        State),
                PostalCode   = ISNULL(@PostalCode,   PostalCode),
                PropertyType = ISNULL(@PropertyType, PropertyType),
                Bedrooms     = ISNULL(@Bedrooms,     Bedrooms),
                Bathrooms    = ISNULL(@Bathrooms,    Bathrooms),
                SizeSqft     = ISNULL(@SizeSqft,     SizeSqft),
                Price        = ISNULL(@Price,        Price),
                Status       = ISNULL(@Status,       Status)
            WHERE PropertyID = @PropertyID;

            PRINT 'Property record updated.';
        END;
    END TRY
    BEGIN CATCH
        RAISERROR('Property operation failed. Please contact the DBA.', 16, 1);
    END CATCH;
END;
GO

----------------------------------------------------------------
-- 5.5  usp_UpdatePropertyStatus  (Changing status of existing property - Cannot be other than predetermined status)
----------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.usp_UpdatePropertyStatus
    @PropertyID INT,
    @NewStatus  NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    IF @NewStatus NOT IN ('Available','Sold','Rented','Under Maintenance','Reserved')
    BEGIN
        RAISERROR('Invalid status. Allowed: Available, Sold, Rented, Under Maintenance, Reserved.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (SELECT 1 FROM dbo.Properties WHERE PropertyID = @PropertyID)
    BEGIN
        RAISERROR('Property ID not found.', 16, 1);
        RETURN;
    END;

    UPDATE dbo.Properties
    SET Status = @NewStatus
    WHERE PropertyID = @PropertyID;

    PRINT 'Property status updated to: ' + @NewStatus;
END;
GO

----------------------------------------------------------------
-- 5.6  usp_RecordTransaction  (Adding a new sale/rent transaction record - Makes sure all info are available)
----------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.usp_RecordTransaction
    @PropertyID      INT,
    @ClientID        INT,
    @AgentID         INT,
    @TransactionType NVARCHAR(50),
    @Amount          DECIMAL(18,2),
    @RentStartDate   DATE         = NULL,
    @RentEndDate     DATE         = NULL,
    @PaymentMethod   NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.Properties WHERE PropertyID = @PropertyID)
            BEGIN RAISERROR('Property not found.', 16, 1); RETURN; END;

        IF NOT EXISTS (SELECT 1 FROM dbo.Clients WHERE ClientID = @ClientID AND IsActive = 1)
            BEGIN RAISERROR('Client not found or inactive.', 16, 1); RETURN; END;

        IF NOT EXISTS (SELECT 1 FROM dbo.Agents WHERE AgentID = @AgentID AND IsActive = 1)
            BEGIN RAISERROR('Agent not found or inactive.', 16, 1); RETURN; END;

        IF @TransactionType NOT IN ('Sale','Rent')
            BEGIN RAISERROR('TransactionType must be Sale or Rent.', 16, 1); RETURN; END;

        INSERT INTO dbo.Transactions
            (PropertyID, ClientID, AgentID, TransactionType, Amount,
             RentStartDate, RentEndDate, PaymentStatus, PaymentMethod)
        VALUES
            (@PropertyID, @ClientID, @AgentID, @TransactionType, @Amount,
             @RentStartDate, @RentEndDate, 'Pending', @PaymentMethod);

        PRINT 'Transaction recorded with ID: ' + CAST(SCOPE_IDENTITY() AS VARCHAR(10));
    END TRY
    BEGIN CATCH
        RAISERROR('Transaction failed. Please contact the DBA.', 16, 1);
    END CATCH;
END;
GO

----------------------------------------------------------------
-- 5.7  usp_UpdateTransactionStatus  (Update payment status of existing transaction)
----------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.usp_UpdateTransactionStatus
    @TransactionID INT,
    @PaymentStatus NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    -- Check if transaction exists
    IF NOT EXISTS (SELECT 1 FROM dbo.Transactions WHERE TransactionID = @TransactionID)
    BEGIN
        RAISERROR('Transaction ID not found.', 16, 1);
        RETURN;
    END;

    -- Make sure status not invalid
    IF @PaymentStatus NOT IN ('Pending', 'Completed')
    BEGIN
        RAISERROR('PaymentStatus must be Pending or Completed.', 16, 1);
        RETURN;
    END;

    UPDATE dbo.Transactions
    SET PaymentStatus = @PaymentStatus
    WHERE TransactionID = @TransactionID;

    PRINT 'Transaction ' + CAST(@TransactionID AS VARCHAR(10)) + ' status updated to ' + @PaymentStatus + '.';
END;
GO


----------------------------------------------------------------
-- 5.8  usp_LogMaintenanceRequest (Raise a new Maintenance Request)
----------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.usp_LogMaintenanceRequest
    @PropertyID          INT,
    @RequestedByClientID INT           = NULL,
    @RequestDetails      NVARCHAR(MAX),
    @Priority            NVARCHAR(20)  = 'Medium',
    @EstimatedCost       DECIMAL(18,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Properties WHERE PropertyID = @PropertyID)
        BEGIN RAISERROR('Property not found.', 16, 1); RETURN; END;

    IF @Priority NOT IN ('Low','Medium','High','Critical')
        BEGIN RAISERROR('Invalid priority. Allowed: Low, Medium, High, Critical.', 16, 1); RETURN; END;

    INSERT INTO dbo.MaintenanceRequests
        (PropertyID, RequestedByClientID, RequestDetails,
         Priority, Status, EstimatedCost)
    VALUES
        (@PropertyID, @RequestedByClientID, @RequestDetails,
         @Priority, 'Pending', @EstimatedCost);

    PRINT 'Maintenance request logged with ID: ' + CAST(SCOPE_IDENTITY() AS VARCHAR(10));
END;
GO

----------------------------------------------------------------
-- 5.9  usp_AssignMaintenanceStaff  (Assigning a respective Maintenance Staff and changing status of request to In Progress)
----------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.usp_AssignMaintenanceStaff
    @RequestID INT,
    @StaffID   INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.MaintenanceRequests WHERE RequestID = @RequestID)
        BEGIN RAISERROR('Maintenance request not found.', 16, 1); RETURN; END;

    IF NOT EXISTS (SELECT 1 FROM dbo.MaintenanceStaff WHERE StaffID = @StaffID AND IsActive = 1)
        BEGIN RAISERROR('Maintenance staff not found or inactive.', 16, 1); RETURN; END;

    UPDATE dbo.MaintenanceRequests
    SET AssignedStaffID = @StaffID,
        Status          = 'In Progress'
    WHERE RequestID = @RequestID;

    PRINT 'Staff assigned and request status set to In Progress.';
END;
GO

----------------------------------------------------------------
-- 5.10  usp_GetAgentTransactions  (Full list of per-Agent transactions and history based on Agent ID)
----------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.usp_GetAgentTransactions
    @AgentID INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Agents WHERE AgentID = @AgentID)
        BEGIN RAISERROR('Agent not found.', 16, 1); RETURN; END;

    SELECT
        t.TransactionID,
        p.PropertyName,
        c.FullName          AS ClientName,
        t.TransactionType,
        t.Amount,           -- Masked for non-UNMASK roles
        t.TransactionDate,
        t.PaymentStatus
    FROM dbo.Transactions t
    INNER JOIN dbo.Properties p ON p.PropertyID = t.PropertyID
    INNER JOIN dbo.Clients    c ON c.ClientID   = t.ClientID
    WHERE t.AgentID = @AgentID
    ORDER BY t.TransactionDate DESC;
END;
GO

-- =============================
--   EXTRA FUNCTIONS/ STORED PROCEDURES
--   ===========================

----------------------------------------------------------------
-- 5.11: usp_ProvisionUser (User Provisioning - Add new user access) 
----------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.usp_ProvisionUser
    @LoginName NVARCHAR(100),
    @Password  NVARCHAR(128),
    @RoleName  NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
 
    -- Match role name against the 6 defined roles
    IF @RoleName NOT IN (
        'role_Admin', 'role_DBA', 'role_PropMgmtDev',
        'role_ClientPortalDev', 'role_Analyst', 'role_ReadOnly'
    )
    BEGIN
        RAISERROR('Invalid role name.', 16, 1);
        RETURN;
    END;

	-- Make sure no empty information is given
	IF @LoginName IS NULL OR @Password IS NULL OR @RoleName IS NULL
        BEGIN
            RAISERROR('LoginName, Password and RoleName are needed and cannot be empty.', 16, 1);
            RETURN;
        END;
 
    -- Check if login already exist
    IF SUSER_ID(@LoginName) IS NOT NULL
    BEGIN
        RAISERROR('Login already exists.', 16, 1);
        RETURN;
    END;
 
    -- Step 1: Create server-level login with password policy
    EXEC('CREATE LOGIN [' + @LoginName + '] WITH PASSWORD = N''' + @Password + ''', CHECK_POLICY = ON;');
    PRINT 'Step 1: Server login created for ' + @LoginName;
 
    -- Step 2: Create database user mapped to the login
    EXEC('CREATE USER [' + @LoginName + '] FOR LOGIN [' + @LoginName + '];');
    PRINT 'Step 2: Database user created.';
 
    -- Step 3: Assign user to the specified role
    EXEC('ALTER ROLE [' + @RoleName + '] ADD MEMBER [' + @LoginName + '];');
    PRINT 'Step 3: ' + @LoginName + ' assigned to ' + @RoleName;
 
    PRINT @LoginName + ' added successfully.';
END;
GO


----------------------------------------------------------------
-- 5.12: usp_DeprovisionUser (User De-provisioning - Remove user access)
----------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.usp_DeprovisionUser
    @LoginName NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
 
    -- Check if login actually exists
    IF SUSER_ID(@LoginName) IS NULL
    BEGIN
        RAISERROR('Login not found. No action taken.', 16, 1);
        RETURN;
    END;
 
    DECLARE @RoleName NVARCHAR(128);
 
    -- Step 1: Remove user from every role they exist in
    WHILE EXISTS (
        SELECT 1 FROM sys.database_role_members rm
        JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
        JOIN sys.database_principals m ON m.principal_id = rm.member_principal_id
        WHERE m.name = @LoginName
    )
    BEGIN
        SELECT TOP 1 @RoleName = r.name
        FROM sys.database_role_members rm
        JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
        JOIN sys.database_principals m ON m.principal_id = rm.member_principal_id
        WHERE m.name = @LoginName;
 

        EXEC('ALTER ROLE [' + @RoleName + '] DROP MEMBER [' + @LoginName + '];');
    END;
    PRINT 'Step 1: ' + @LoginName + ' removed from all roles.';
 
    -- Step 2: Drop the database-level user
    IF USER_ID(@LoginName) IS NOT NULL
        EXEC('DROP USER [' + @LoginName + '];');
    PRINT 'Step 2: Database user dropped.';
 
    -- Step 3: Drop the server-level login
    EXEC('DROP LOGIN [' + @LoginName + '];');
    PRINT 'Step 3: Server login dropped.';
 
    PRINT @LoginName + ' fully removed.';
END;
GO


-- ------------------------------------------------------------
--   5.13  Procedure-Level Execute Grants
--   (Roles receive EXECUTE only on procedures relevant to their job function)
--   ------------------------------------------------------------

-- Admin: All procedures (Full operational scope)
GRANT EXECUTE ON dbo.usp_ManageClient           TO role_Admin;
GRANT EXECUTE ON dbo.usp_DeactivateClient       TO role_Admin;
GRANT EXECUTE ON dbo.usp_ReactivateClient		TO role_Admin;
GRANT EXECUTE ON dbo.usp_ManageProperty         TO role_Admin;
GRANT EXECUTE ON dbo.usp_UpdatePropertyStatus   TO role_Admin;
GRANT EXECUTE ON dbo.usp_RecordTransaction      TO role_Admin;
GRANT EXECUTE ON dbo.usp_UpdateTransactionStatus TO role_Admin;
GRANT EXECUTE ON dbo.usp_LogMaintenanceRequest  TO role_Admin;
GRANT EXECUTE ON dbo.usp_AssignMaintenanceStaff TO role_Admin;
GRANT EXECUTE ON dbo.usp_GetAgentTransactions   TO role_Admin;
GRANT EXECUTE ON dbo.usp_ProvisionUser			TO role_Admin;
GRANT EXECUTE ON dbo.usp_DeprovisionUser		TO role_Admin;
GO

-- PropMgmtDev: Property & Maintenance procedures only
GRANT EXECUTE ON dbo.usp_ManageProperty         TO role_PropMgmtDev;
GRANT EXECUTE ON dbo.usp_UpdatePropertyStatus   TO role_PropMgmtDev;
GRANT EXECUTE ON dbo.usp_LogMaintenanceRequest  TO role_PropMgmtDev;
GRANT EXECUTE ON dbo.usp_AssignMaintenanceStaff TO role_PropMgmtDev;
GO

-- ClientPortalDev: Client & Transaction procedures
GRANT EXECUTE ON dbo.usp_ManageClient           TO role_ClientPortalDev;
GRANT EXECUTE ON dbo.usp_DeactivateClient       TO role_ClientPortalDev;
GRANT EXECUTE ON dbo.usp_ReactivateClient		TO role_ClientPortalDev;
GRANT EXECUTE ON dbo.usp_RecordTransaction      TO role_ClientPortalDev;
GRANT EXECUTE ON dbo.usp_UpdateTransactionStatus TO role_ClientPortalDev;
GO

-- Analyst: Read-only reporting access
GRANT EXECUTE ON dbo.usp_GetAgentTransactions   TO role_Analyst;
GO



-- ============================================================
--   SECTION 6: VERIFICATION (To test if everything is working accordingly)
--   ============================================================

-- Roles created
SELECT name FROM sys.database_principals WHERE type = 'R' AND name LIKE 'role_%';

-- Role membership list (Confirms each RoleName and MemberName)
SELECT r.name AS RoleName, m.name AS MemberName
FROM sys.database_role_members rm
JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
JOIN sys.database_principals m ON m.principal_id = rm.member_principal_id
WHERE r.name LIKE 'role_%' ORDER BY RoleName;

-- Views created
SELECT name FROM sys.views WHERE name LIKE 'vw_%';

-- Procedures created
SELECT name FROM sys.procedures WHERE name LIKE 'usp_%';




-- =====
-- END
-- =====
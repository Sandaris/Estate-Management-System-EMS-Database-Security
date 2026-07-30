/* ========================================================================
   DDL.sql - Green Acres Realty Sdn Bhd, Estate Management System (EMS)
   CT069-3-3 Database Security Assignment

   Structure only: tables, roles, users, permissions, views, procedures,
   masking, keys, audit objects and triggers. Loads no data.

   RUN THIS FIRST, THEN DML.sql. This file drops and recreates the
   GreenAcresEMS database, so re-running it means re-running DML.sql too.
   Connect as sysadmin. See README.md for the full design discussion.
   ======================================================================== */


USE master;
GO

-- Remove the logon trigger from any previous run FIRST.
IF EXISTS (SELECT 1 FROM sys.server_triggers WHERE name = 'trg_ServerLogon_AuditLogin')
BEGIN
    DROP TRIGGER trg_ServerLogon_AuditLogin ON ALL SERVER;
    PRINT 'Removed logon trigger from previous run.';
END;
GO

-- Kick any leftover sessions off the database, otherwise DROP DATABASE fails
-- with "database is currently in use" when someone still has a query window
-- open against GreenAcresEMS.
IF EXISTS (SELECT name FROM sys.databases WHERE name = 'GreenAcresEMS')
BEGIN
    ALTER DATABASE GreenAcresEMS SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
END;
GO

-- Drop and recreate the database for a clean setup
IF EXISTS (SELECT name FROM sys.databases WHERE name = 'GreenAcresEMS')
    DROP DATABASE GreenAcresEMS;
GO

CREATE DATABASE GreenAcresEMS;
GO

USE GreenAcresEMS;
GO


-- Enhanced: added PropertyType, Bedrooms, Bathrooms, Sizesqft, IsActive for
-- richer operational data.

/* ========================================================================
   REQUIREMENT 12: ADD NEW TABLE OR EDIT EXISTING TABLE
   ======================================================================== */
CREATE TABLE Properties (
    PropertyID      INT             IDENTITY(1,1)   PRIMARY KEY,
    PropertyName    NVARCHAR(150)   NOT NULL,
    Address         NVARCHAR(255)   NOT NULL,
    City            NVARCHAR(100)   NOT NULL,
    State           NVARCHAR(100)   NOT NULL,
    PostalCode      NVARCHAR(10),
    PropertyType    NVARCHAR(50)    NOT NULL        -- 'Residential', 'Commercial', 'Industrial'
        CONSTRAINT CK_Properties_Type CHECK (PropertyType IN ('Residential','Commercial','Industrial','Land')),
    Bedrooms        TINYINT         NULL,
    Bathrooms       TINYINT         NULL,
    SizeSqft        DECIMAL(10,2)   NULL,
    Price           DECIMAL(18,2)   NOT NULL,
    Status          NVARCHAR(50)    NOT NULL        DEFAULT 'Available'
        CONSTRAINT CK_Properties_Status CHECK (Status IN ('Available','Sold','Rented','Under Maintenance','Reserved')),
    IsActive        BIT             NOT NULL        DEFAULT 1,  -- soft-delete flag
    CreatedDate     DATETIME        NOT NULL        DEFAULT GETDATE()
);
GO

-- Enhanced: added NRIC (for encryption later), ClientType, IsActive.
CREATE TABLE Clients (
    ClientID        INT             IDENTITY(1,1)   PRIMARY KEY,
    FullName        NVARCHAR(100)   NOT NULL,
    NRIC            NVARCHAR(20)    NULL,           -- [SENSITIVE - will be encrypted]
    ContactNumber   NVARCHAR(20)    NOT NULL,       -- [SENSITIVE - will be masked]
    Email           NVARCHAR(100)   NOT NULL,       -- [SENSITIVE - will be masked]
    Address         NVARCHAR(255)   NULL,
    ClientType      NVARCHAR(50)    NOT NULL        DEFAULT 'Individual'
        CONSTRAINT CK_Clients_Type CHECK (ClientType IN ('Individual','Corporate')),
    IsActive        BIT             NOT NULL        DEFAULT 1,
    RegisteredDate  DATETIME        NOT NULL        DEFAULT GETDATE()
);
GO
-- Enhanced: added DepartmentID (FK), LicenseNumber, IsActive.
CREATE TABLE Agents (
    AgentID         INT             IDENTITY(1,1)   PRIMARY KEY,
    FullName        NVARCHAR(100)   NOT NULL,
    ContactNumber   NVARCHAR(20)    NOT NULL,       -- [SENSITIVE - will be masked]
    Email           NVARCHAR(100)   NOT NULL,
    LicenseNumber   NVARCHAR(50)    NULL,           -- real-estate agent license
    CommissionRate  DECIMAL(5,2)    NOT NULL        DEFAULT 2.50, -- [SENSITIVE]
        CONSTRAINT CK_Agents_CommRate CHECK (CommissionRate BETWEEN 0 AND 100),
    IsActive        BIT             NOT NULL        DEFAULT 1,
    JoinedDate      DATETIME        NOT NULL        DEFAULT GETDATE()
);
GO
-- Enhanced: added RentEndDate, PaymentStatus, PaymentMethod for lease/sale
-- lifecycle tracking.
CREATE TABLE Transactions (
    TransactionID   INT             IDENTITY(1,1)   PRIMARY KEY,
    PropertyID      INT             NOT NULL
        CONSTRAINT FK_Trans_Property FOREIGN KEY REFERENCES Properties(PropertyID),
    ClientID        INT             NOT NULL
        CONSTRAINT FK_Trans_Client  FOREIGN KEY REFERENCES Clients(ClientID),
    AgentID         INT             NOT NULL
        CONSTRAINT FK_Trans_Agent   FOREIGN KEY REFERENCES Agents(AgentID),
    TransactionType NVARCHAR(50)    NOT NULL
        CONSTRAINT CK_Trans_Type CHECK (TransactionType IN ('Sale','Rent')),
    TransactionDate DATETIME        NOT NULL        DEFAULT GETDATE(),
    Amount          DECIMAL(18,2)   NOT NULL,       -- [SENSITIVE - financial]
    RentStartDate   DATE            NULL,           -- populated for Rent transactions
    RentEndDate     DATE            NULL,
    PaymentStatus   NVARCHAR(50)    NOT NULL        DEFAULT 'Pending'
        CONSTRAINT CK_Trans_PayStatus CHECK (PaymentStatus IN ('Pending','Completed','Cancelled','Refunded')),
    PaymentMethod   NVARCHAR(50)    NULL            -- 'Cash','Bank Transfer','Cheque'
);
GO

-- Enhanced: added AssignedStaffID, Priority, CompletedDate, EstimatedCost,
-- ActualCost for full work-order tracking.
CREATE TABLE MaintenanceRequests (
    RequestID       INT             IDENTITY(1,1)   PRIMARY KEY,
    PropertyID      INT             NOT NULL
        CONSTRAINT FK_Maint_Property FOREIGN KEY REFERENCES Properties(PropertyID),
    RequestedByClientID INT         NULL            -- NULL = internal/owner request
        CONSTRAINT FK_Maint_Client   FOREIGN KEY REFERENCES Clients(ClientID),
    RequestDetails  NVARCHAR(MAX)   NOT NULL,
    Priority        NVARCHAR(20)    NOT NULL        DEFAULT 'Medium'
        CONSTRAINT CK_Maint_Priority CHECK (Priority IN ('Low','Medium','High','Critical')),
    RequestDate     DATETIME        NOT NULL        DEFAULT GETDATE(),
    Status          NVARCHAR(50)    NOT NULL        DEFAULT 'Pending'
        CONSTRAINT CK_Maint_Status CHECK (Status IN ('Pending','In Progress','Completed','Cancelled')),
    EstimatedCost   DECIMAL(18,2)   NULL,
    ActualCost      DECIMAL(18,2)   NULL,           -- [SENSITIVE - financial]
    CompletedDate   DATETIME        NULL
);
GO


-- Represents the IT and business departments formed during the company's
-- expansion.
CREATE TABLE Departments (
    DepartmentID    INT             IDENTITY(1,1)   PRIMARY KEY,
    DepartmentName  NVARCHAR(100)   NOT NULL        UNIQUE,
    Description     NVARCHAR(255)   NULL,
    IsActive        BIT             NOT NULL        DEFAULT 1,
    CreatedDate     DATETIME        NOT NULL        DEFAULT GETDATE()
);
GO


-- Internal IT/staff users who access the EMS database (developers, DBAs,
-- analysts).
CREATE TABLE SystemUsers (
    SystemUserID    INT             IDENTITY(1,1)   PRIMARY KEY,
    DepartmentID    INT             NOT NULL
        CONSTRAINT FK_SysUser_Dept  FOREIGN KEY REFERENCES Departments(DepartmentID),
    FullName        NVARCHAR(100)   NOT NULL,
    LoginName       NVARCHAR(100)   NOT NULL        UNIQUE, -- matches SQL Server login
    Email           NVARCHAR(100)   NOT NULL,               -- [SENSITIVE - will be masked]
    -- LEGACY, INHERITED FROM THE ORIGINAL DEVELOPERS.
    PasswordHash    VARBINARY(64)   NULL,                   -- [DEPRECATED - weak SHA2_256]
    PasswordSalt    NVARCHAR(50)    NULL,                   -- [DEPRECATED - salt in plain text]
    UserRole        NVARCHAR(50)    NOT NULL
        CONSTRAINT CK_SysUser_Role CHECK (UserRole IN (
            'DBA','PropMgmtDev','ClientPortalDev','Analyst','ReadOnly','Admin'
        )),
    IsActive        BIT             NOT NULL        DEFAULT 1,
    CreatedDate     DATETIME        NOT NULL        DEFAULT GETDATE()
);
GO

-- Tracks every login attempt (success + failure) against the EMS.
CREATE TABLE UserLoginLog (
    LogID           INT             IDENTITY(1,1)   PRIMARY KEY,
    SystemUserID    INT             NULL            -- NULL if login name not matched
        CONSTRAINT FK_LoginLog_User FOREIGN KEY REFERENCES SystemUsers(SystemUserID),
    LoginName       NVARCHAR(100)   NOT NULL,
    LoginTime       DATETIME        NOT NULL        DEFAULT GETDATE(),
    LogoutTime      DATETIME        NULL,
    IsSuccessful    BIT             NOT NULL,
    IPAddress       NVARCHAR(50)    NULL,
    HostName        NVARCHAR(100)   NULL,
    FailureReason   NVARCHAR(255)   NULL            -- populated on failed attempts
);
GO


-- Central audit trail for all DML events (INSERT, UPDATE, DELETE) across
-- sensitive tables.
CREATE TABLE AuditLog (
    AuditID         INT             IDENTITY(1,1)   PRIMARY KEY,
    EventTime       DATETIME        NOT NULL        DEFAULT GETDATE(),
    TableName       NVARCHAR(128)   NOT NULL,
    OperationType   NVARCHAR(10)    NOT NULL
        CONSTRAINT CK_Audit_Op CHECK (OperationType IN ('INSERT','UPDATE','DELETE','SELECT')),
    RecordID        NVARCHAR(50)    NOT NULL,       -- PK value of affected row (stored as string)
    ChangedBy       NVARCHAR(100)   NOT NULL        DEFAULT SYSTEM_USER,
    OldValues       NVARCHAR(MAX)   NULL,           -- JSON snapshot of old row
    NewValues       NVARCHAR(MAX)   NULL,           -- JSON snapshot of new row
    ApplicationName NVARCHAR(128)   NULL,
    HostName        NVARCHAR(128)   NULL
);
GO


-- 10. LeaseAgreements - Formalises rental agreements between clients and
-- properties.
CREATE TABLE LeaseAgreements (
    LeaseID             INT             IDENTITY(1,1)   PRIMARY KEY,
    TransactionID       INT             NOT NULL        UNIQUE  -- 1 lease per rental transaction
        CONSTRAINT FK_Lease_Trans   FOREIGN KEY REFERENCES Transactions(TransactionID),
    PropertyID          INT             NOT NULL
        CONSTRAINT FK_Lease_Prop    FOREIGN KEY REFERENCES Properties(PropertyID),
    ClientID            INT             NOT NULL
        CONSTRAINT FK_Lease_Client  FOREIGN KEY REFERENCES Clients(ClientID),
    LeaseStartDate      DATE            NOT NULL,
    LeaseEndDate        DATE            NOT NULL,
    MonthlyRent         DECIMAL(18,2)   NOT NULL,   -- [SENSITIVE - financial]
    SecurityDeposit     DECIMAL(18,2)   NOT NULL,   -- [SENSITIVE - financial]
    LeaseStatus         NVARCHAR(50)    NOT NULL    DEFAULT 'Active'
        CONSTRAINT CK_Lease_Status CHECK (LeaseStatus IN ('Active','Expired','Terminated','Renewed')),
    AgreementDocPath    NVARCHAR(500)   NULL,       -- path to signed agreement document
    SignedDate          DATE            NULL,
    CreatedDate         DATETIME        NOT NULL    DEFAULT GETDATE()
);
GO


-- 11. CommissionPayments - Tracks commission earned and paid to agents per
-- transaction.
CREATE TABLE CommissionPayments (
    CommissionID    INT             IDENTITY(1,1)   PRIMARY KEY,
    TransactionID   INT             NOT NULL
        CONSTRAINT FK_Comm_Trans    FOREIGN KEY REFERENCES Transactions(TransactionID),
    AgentID         INT             NOT NULL
        CONSTRAINT FK_Comm_Agent    FOREIGN KEY REFERENCES Agents(AgentID),
    CommissionRate  DECIMAL(5,2)    NOT NULL,       -- rate at time of transaction (snapshot)
    CommissionAmount DECIMAL(18,2)  NOT NULL,       -- [SENSITIVE - financial]
    PaymentStatus   NVARCHAR(50)    NOT NULL        DEFAULT 'Unpaid'
        CONSTRAINT CK_Comm_Status CHECK (PaymentStatus IN ('Unpaid','Paid','Disputed')),
    PaymentDate     DATETIME        NULL,
    Remarks         NVARCHAR(255)   NULL
);
GO


-- 12. MaintenanceStaff - Tracks in-house or contracted maintenance workers.
CREATE TABLE MaintenanceStaff (
    StaffID         INT             IDENTITY(1,1)   PRIMARY KEY,
    FullName        NVARCHAR(100)   NOT NULL,
    ContactNumber   NVARCHAR(20)    NOT NULL,       -- [SENSITIVE - will be masked]
    Specialisation  NVARCHAR(100)   NULL,           -- 'Plumbing','Electrical','General', etc.
    IsContractor    BIT             NOT NULL        DEFAULT 0,  -- 0=in-house, 1=external
    IsActive        BIT             NOT NULL        DEFAULT 1,
    JoinedDate      DATETIME        NOT NULL        DEFAULT GETDATE()
);
GO


-- Add FK back to MaintenanceRequests for assigned staff
ALTER TABLE MaintenanceRequests
    ADD AssignedStaffID INT NULL
        CONSTRAINT FK_Maint_Staff FOREIGN KEY REFERENCES MaintenanceStaff(StaffID);
GO

-- 13. Notifications - Stores system notifications sent to clients or agents
-- (lease expiry reminders, maintenance updates, etc.).
CREATE TABLE Notifications (
    NotificationID  INT             IDENTITY(1,1)   PRIMARY KEY,
    RecipientType   NVARCHAR(20)    NOT NULL
        CONSTRAINT CK_Notif_RecipType CHECK (RecipientType IN ('Client','Agent','SystemUser')),
    RecipientID     INT             NOT NULL,       -- FK resolved via RecipientType at app layer
    Subject         NVARCHAR(200)   NOT NULL,
    MessageBody     NVARCHAR(MAX)   NOT NULL,
    Channel         NVARCHAR(50)    NOT NULL        DEFAULT 'Email'
        CONSTRAINT CK_Notif_Channel CHECK (Channel IN ('Email','SMS','InApp')),
    IsSent          BIT             NOT NULL        DEFAULT 0,
    SentAt          DATETIME        NULL,
    CreatedAt       DATETIME        NOT NULL        DEFAULT GETDATE(),
    RelatedTable    NVARCHAR(128)   NULL,           -- e.g. 'LeaseAgreements'
    RelatedRecordID INT             NULL            -- e.g. LeaseID
);
GO


-- >>> MOVED TO DML.sql: Seed data for all 10 tables (467 rows)


USE GreenAcresEMS;
GO


-- Clean-up before creating principals Database-scoped principals (roles +
-- users) do NOT need to be dropped here: the DROP DATABASE / CREATE DATABASE at
-- the very top of this script already destroyed every role and user that lived
-- inside GreenAcresEMS.
DECLARE @EmsLogins TABLE (LoginName SYSNAME);

INSERT INTO @EmsLogins (LoginName)
VALUES ('arun.kumar'), ('linda.tan'), ('farid.rahman'), ('melissa.wong'),
       ('kelvin.ong'), ('aminah.salleh'), ('vijay.menon'), ('sofia.aziz'),
       ('hakim.zulkifli'), ('rachel.lee'), ('jason.lim'), ('nurul.huda');

DECLARE @LoginName SYSNAME;
DECLARE @sql       NVARCHAR(500);

DECLARE login_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT LoginName FROM @EmsLogins;

OPEN login_cursor;
FETCH NEXT FROM login_cursor INTO @LoginName;

WHILE @@FETCH_STATUS = 0
BEGIN
    IF SUSER_ID(@LoginName) IS NOT NULL
    BEGIN
        BEGIN TRY
            -- QUOTENAME protects the identifier even though these names are
            -- hard-coded here (defence in depth / consistent style).
            SET @sql = N'DROP LOGIN ' + QUOTENAME(@LoginName) + N';';
            EXEC sys.sp_executesql @sql;
            PRINT 'Dropped orphaned login: ' + @LoginName;
        END TRY
        BEGIN CATCH
            PRINT 'Could not drop login ' + @LoginName + ' -> ' + ERROR_MESSAGE();
        END CATCH;
    END;

    FETCH NEXT FROM login_cursor INTO @LoginName;
END;

CLOSE login_cursor;
DEALLOCATE login_cursor;

PRINT 'Login clean-up finished. Ready to create roles and users.';
GO

-- Create the 6 necessary roles

/* ========================================================================
   REQUIREMENT 3: ROLE
   ======================================================================== */
CREATE ROLE role_Admin;
CREATE ROLE role_DBA;
CREATE ROLE role_PropMgmtDev;
CREATE ROLE role_ClientPortalDev;
CREATE ROLE role_Analyst;
CREATE ROLE role_ReadOnly;
GO


/* ========================================================================
   REQUIREMENT 4: USER (AND PERMISSIONS)
   Every IT staff member gets their OWN login with a UNIQUE password, so that
   the audit trail (ORIGINAL_LOGIN()) can attribute every change to a single
   named person.
   ======================================================================== */
IF SUSER_ID('arun.kumar') IS NULL
    CREATE LOGIN [arun.kumar] WITH PASSWORD = 'Dba#Arun!7fK2026',
        CHECK_POLICY = ON,       -- enforce Windows password complexity
        CHECK_EXPIRATION = ON;   -- subject the login to the password-age policy
GO
IF USER_ID('arun.kumar') IS NULL
    CREATE USER [arun.kumar] FOR LOGIN [arun.kumar];
GO
ALTER ROLE role_DBA ADD MEMBER [arun.kumar];
GO

IF SUSER_ID('linda.tan') IS NULL
    CREATE LOGIN [linda.tan] WITH PASSWORD = 'Dba#Linda!3qM2026',
        CHECK_POLICY = ON,       -- enforce Windows password complexity
        CHECK_EXPIRATION = ON;   -- subject the login to the password-age policy
GO
IF USER_ID('linda.tan') IS NULL
    CREATE USER [linda.tan] FOR LOGIN [linda.tan];
GO
ALTER ROLE role_DBA ADD MEMBER [linda.tan];
GO

IF SUSER_ID('farid.rahman') IS NULL
    CREATE LOGIN [farid.rahman] WITH PASSWORD = 'Adm#Farid!8xR2026',
        CHECK_POLICY = ON,       -- enforce Windows password complexity
        CHECK_EXPIRATION = ON;   -- subject the login to the password-age policy
GO
IF USER_ID('farid.rahman') IS NULL
    CREATE USER [farid.rahman] FOR LOGIN [farid.rahman];
GO
ALTER ROLE role_Admin ADD MEMBER [farid.rahman];
GO

IF SUSER_ID('melissa.wong') IS NULL
    CREATE LOGIN [melissa.wong] WITH PASSWORD = 'Adm#Melissa!5tW2026',
        CHECK_POLICY = ON,       -- enforce Windows password complexity
        CHECK_EXPIRATION = ON;   -- subject the login to the password-age policy
GO
IF USER_ID('melissa.wong') IS NULL
    CREATE USER [melissa.wong] FOR LOGIN [melissa.wong];
GO
ALTER ROLE role_Admin ADD MEMBER [melissa.wong];
GO


IF SUSER_ID('kelvin.ong') IS NULL
    CREATE LOGIN [kelvin.ong] WITH PASSWORD = 'Prp#Kelvin!9bL2026',
        CHECK_POLICY = ON,       -- enforce Windows password complexity
        CHECK_EXPIRATION = ON;   -- subject the login to the password-age policy
GO
IF USER_ID('kelvin.ong') IS NULL
    CREATE USER [kelvin.ong] FOR LOGIN [kelvin.ong];
GO
ALTER ROLE role_PropMgmtDev ADD MEMBER [kelvin.ong];
GO

IF SUSER_ID('aminah.salleh') IS NULL
    CREATE LOGIN [aminah.salleh] WITH PASSWORD = 'Prp#Aminah!4nS2026',
        CHECK_POLICY = ON,       -- enforce Windows password complexity
        CHECK_EXPIRATION = ON;   -- subject the login to the password-age policy
GO
IF USER_ID('aminah.salleh') IS NULL
    CREATE USER [aminah.salleh] FOR LOGIN [aminah.salleh];
GO
ALTER ROLE role_PropMgmtDev ADD MEMBER [aminah.salleh];
GO

IF SUSER_ID('vijay.menon') IS NULL
    CREATE LOGIN [vijay.menon] WITH PASSWORD = 'Ptl#Vijay!6vD2026',
        CHECK_POLICY = ON,       -- enforce Windows password complexity
        CHECK_EXPIRATION = ON;   -- subject the login to the password-age policy
GO
IF USER_ID('vijay.menon') IS NULL
    CREATE USER [vijay.menon] FOR LOGIN [vijay.menon];
GO
ALTER ROLE role_ClientPortalDev ADD MEMBER [vijay.menon];
GO

IF SUSER_ID('sofia.aziz') IS NULL
    CREATE LOGIN [sofia.aziz] WITH PASSWORD = 'Ptl#Sofia!2zG2026',
        CHECK_POLICY = ON,       -- enforce Windows password complexity
        CHECK_EXPIRATION = ON;   -- subject the login to the password-age policy
GO
IF USER_ID('sofia.aziz') IS NULL
    CREATE USER [sofia.aziz] FOR LOGIN [sofia.aziz];
GO
ALTER ROLE role_ClientPortalDev ADD MEMBER [sofia.aziz];
GO

IF SUSER_ID('hakim.zulkifli') IS NULL
    CREATE LOGIN [hakim.zulkifli] WITH PASSWORD = 'Anl#Hakim!7hJ2026',
        CHECK_POLICY = ON,       -- enforce Windows password complexity
        CHECK_EXPIRATION = ON;   -- subject the login to the password-age policy
GO
IF USER_ID('hakim.zulkifli') IS NULL
    CREATE USER [hakim.zulkifli] FOR LOGIN [hakim.zulkifli];
GO
ALTER ROLE role_Analyst ADD MEMBER [hakim.zulkifli];
GO

IF SUSER_ID('rachel.lee') IS NULL
    CREATE LOGIN [rachel.lee] WITH PASSWORD = 'Anl#Rachel!1cP2026',
        CHECK_POLICY = ON,       -- enforce Windows password complexity
        CHECK_EXPIRATION = ON;   -- subject the login to the password-age policy
GO
IF USER_ID('rachel.lee') IS NULL
    CREATE USER [rachel.lee] FOR LOGIN [rachel.lee];
GO
ALTER ROLE role_Analyst ADD MEMBER [rachel.lee];
GO

IF SUSER_ID('jason.lim') IS NULL
    CREATE LOGIN [jason.lim] WITH PASSWORD = 'Ro#Jason!5yT2026',
        CHECK_POLICY = ON,       -- enforce Windows password complexity
        CHECK_EXPIRATION = ON;   -- subject the login to the password-age policy
GO
IF USER_ID('jason.lim') IS NULL
    CREATE USER [jason.lim] FOR LOGIN [jason.lim];
GO
ALTER ROLE role_ReadOnly ADD MEMBER [jason.lim];
GO

IF SUSER_ID('nurul.huda') IS NULL
    CREATE LOGIN [nurul.huda] WITH PASSWORD = 'Ro#Nurul!8kQ2026',
        CHECK_POLICY = ON,       -- enforce Windows password complexity
        CHECK_EXPIRATION = ON;   -- subject the login to the password-age policy
GO
IF USER_ID('nurul.huda') IS NULL
    CREATE USER [nurul.huda] FOR LOGIN [nurul.huda];
GO
ALTER ROLE role_ReadOnly ADD MEMBER [nurul.huda];
GO


GRANT CONTROL ON DATABASE::GreenAcresEMS TO role_DBA;
GO

-- Server-level permission for the DBA logins.
USE master;
GO

GRANT ALTER ANY LOGIN TO [arun.kumar];
GRANT ALTER ANY LOGIN TO [linda.tan];
GO

-- VIEW ANY DEFINITION lets the DBAs inspect object definitions across the
-- instance when troubleshooting, without any data access.
GRANT VIEW ANY DEFINITION TO [arun.kumar];
GRANT VIEW ANY DEFINITION TO [linda.tan];
GO

USE GreenAcresEMS;
GO

--      (They need to resolve client queries)
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

--      Property + maintenance domain & read on supporting tables
GRANT SELECT, INSERT, UPDATE ON dbo.Properties          TO role_PropMgmtDev;
GRANT SELECT, INSERT, UPDATE ON dbo.MaintenanceRequests TO role_PropMgmtDev;
GRANT SELECT, INSERT, UPDATE ON dbo.MaintenanceStaff    TO role_PropMgmtDev;
GRANT SELECT                  ON dbo.Clients            TO role_PropMgmtDev;
GRANT SELECT                  ON dbo.Agents             TO role_PropMgmtDev;
GRANT SELECT                  ON dbo.Departments        TO role_PropMgmtDev;
-- PropMgmtDev cannot see commission data
DENY  SELECT ON dbo.CommissionPayments                  TO role_PropMgmtDev;
GO

--      Client & transaction domain
GRANT SELECT, INSERT, UPDATE ON dbo.Clients             TO role_ClientPortalDev;
GRANT SELECT                  ON dbo.Properties         TO role_ClientPortalDev;
GRANT SELECT, INSERT, UPDATE ON dbo.Transactions        TO role_ClientPortalDev;
GRANT SELECT, INSERT, UPDATE ON dbo.LeaseAgreements     TO role_ClientPortalDev;
GRANT SELECT                  ON dbo.Agents             TO role_ClientPortalDev;
GO

--      Read-only across the reporting domain
GRANT SELECT ON dbo.Properties          TO role_Analyst;
GRANT SELECT ON dbo.Transactions        TO role_Analyst;
GRANT SELECT ON dbo.MaintenanceRequests TO role_Analyst;
GRANT SELECT ON dbo.Agents              TO role_Analyst;
GRANT SELECT ON dbo.Departments         TO role_Analyst;
GO


/* ========================================================================
   REQUIREMENT 1: VIEW
   ======================================================================== */
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


-- 4.8 View-Level Permission Grants Read-only and Analyst roles get SELECT on
-- views only.

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


-- When ClientID is NULL = INSERT new client When ClientID is Non-NULL= UPDATE
-- info (Only selected details)


/* ========================================================================
   REQUIREMENT 2: STORED PROCEDURE
   ======================================================================== */
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


-- usp_ProvisionUser: Single, auditable entry point for onboarding a new IT
-- staff member: creates the login, the database user and the role membership in
-- one step.
CREATE OR ALTER PROCEDURE dbo.usp_ProvisionUser
    @LoginName NVARCHAR(100),
    @Password  NVARCHAR(128),
    @RoleName  NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    -- Make sure no empty information is given (checked FIRST, because "NULL NOT
    -- IN (...)" evaluates to UNKNOWN and would fall through the role check
    -- below without ever raising an error).
    IF @LoginName IS NULL OR LTRIM(RTRIM(@LoginName)) = ''
       OR @Password IS NULL OR @Password = ''
       OR @RoleName IS NULL OR LTRIM(RTRIM(@RoleName)) = ''
    BEGIN
        RAISERROR('LoginName, Password and RoleName are needed and cannot be empty.', 16, 1);
        RETURN;
    END;

    -- Match role name against the 6 defined roles
    IF @RoleName NOT IN (
        'role_Admin', 'role_DBA', 'role_PropMgmtDev',
        'role_ClientPortalDev', 'role_Analyst', 'role_ReadOnly'
    )
    BEGIN
        RAISERROR('Invalid role name.', 16, 1);
        RETURN;
    END;

    -- Whitelist the login name: letters, digits, dot, underscore and hyphen
    -- only.
    IF @LoginName LIKE '%[^a-zA-Z0-9._-]%'
    BEGIN
        RAISERROR('LoginName may only contain letters, digits, dot, underscore or hyphen.', 16, 1);
        RETURN;
    END;

    IF LEN(@Password) < 12
    BEGIN
        RAISERROR('Password must be at least 12 characters long.', 16, 1);
        RETURN;
    END;

    -- Check if login already exist
    IF SUSER_ID(@LoginName) IS NOT NULL
    BEGIN
        RAISERROR('Login already exists.', 16, 1);
        RETURN;
    END;

    DECLARE @sql NVARCHAR(MAX);

    BEGIN TRY
        -- Step 1: Create server-level login with password policy.
        SET @sql = N'CREATE LOGIN ' + QUOTENAME(@LoginName)
                 + N' WITH PASSWORD = @pwd, CHECK_POLICY = ON, CHECK_EXPIRATION = ON;';
        EXEC sys.sp_executesql @sql, N'@pwd NVARCHAR(128)', @pwd = @Password;
        PRINT 'Step 1: Server login created for ' + @LoginName;

        -- Step 2: Create database user mapped to the login
        SET @sql = N'CREATE USER ' + QUOTENAME(@LoginName)
                 + N' FOR LOGIN ' + QUOTENAME(@LoginName) + N';';
        EXEC sys.sp_executesql @sql;
        PRINT 'Step 2: Database user created.';

        -- Step 3: Assign user to the specified role
        SET @sql = N'ALTER ROLE ' + QUOTENAME(@RoleName)
                 + N' ADD MEMBER ' + QUOTENAME(@LoginName) + N';';
        EXEC sys.sp_executesql @sql;
        PRINT 'Step 3: ' + @LoginName + ' assigned to ' + @RoleName;

        PRINT @LoginName + ' added successfully.';
    END TRY
    BEGIN CATCH
        -- Surface the real reason (usually "permission denied" when the caller
        -- is not a sysadmin / has no ALTER ANY LOGIN).
        DECLARE @msg NVARCHAR(2048) = N'usp_ProvisionUser failed: ' + ERROR_MESSAGE();
        RAISERROR(@msg, 16, 1);
    END CATCH;
END;
GO


-- usp_DeprovisionUser: Offboarding counterpart to usp_ProvisionUser: strips
-- role membership, drops the database user, then drops the server login - in
-- that order, because SQL Server refuses to drop a login that still has a
-- mapped user.
CREATE OR ALTER PROCEDURE dbo.usp_DeprovisionUser
    @LoginName NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    IF @LoginName IS NULL OR LTRIM(RTRIM(@LoginName)) = ''
    BEGIN
        RAISERROR('LoginName is required.', 16, 1);
        RETURN;
    END;

    -- Same whitelist as usp_ProvisionUser - never build dynamic SQL from an
    -- unvalidated identifier.
    IF @LoginName LIKE '%[^a-zA-Z0-9._-]%'
    BEGIN
        RAISERROR('LoginName may only contain letters, digits, dot, underscore or hyphen.', 16, 1);
        RETURN;
    END;

    -- Check if login actually exists
    IF SUSER_ID(@LoginName) IS NULL
    BEGIN
        RAISERROR('Login not found. No action taken.', 16, 1);
        RETURN;
    END;

    DECLARE @RoleName NVARCHAR(128);
    DECLARE @sql      NVARCHAR(MAX);

    BEGIN TRY
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

            SET @sql = N'ALTER ROLE ' + QUOTENAME(@RoleName)
                     + N' DROP MEMBER ' + QUOTENAME(@LoginName) + N';';
            EXEC sys.sp_executesql @sql;
        END;
        PRINT 'Step 1: ' + @LoginName + ' removed from all roles.';

        -- Step 2: Drop the database-level user
        IF USER_ID(@LoginName) IS NOT NULL
        BEGIN
            SET @sql = N'DROP USER ' + QUOTENAME(@LoginName) + N';';
            EXEC sys.sp_executesql @sql;
        END;
        PRINT 'Step 2: Database user dropped.';

        -- Step 3: Drop the server-level login
        SET @sql = N'DROP LOGIN ' + QUOTENAME(@LoginName) + N';';
        EXEC sys.sp_executesql @sql;
        PRINT 'Step 3: Server login dropped.';

        PRINT @LoginName + ' fully removed.';
    END TRY
    BEGIN CATCH
        DECLARE @msg NVARCHAR(2048) = N'usp_DeprovisionUser failed: ' + ERROR_MESSAGE();
        RAISERROR(@msg, 16, 1);
    END CATCH;
END;
GO

-- 5.13 Procedure-Level Execute Grants (Roles receive EXECUTE only on procedures
-- relevant to their job function)

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
-- User provisioning is a DBA duty, not a business-admin duty, so EXECUTE on the
-- two provisioning procedures goes to role_DBA only.
GRANT EXECUTE ON dbo.usp_ProvisionUser			TO role_DBA;
GRANT EXECUTE ON dbo.usp_DeprovisionUser		TO role_DBA;
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


-- >>> MOVED TO DML.sql: Role / view / procedure inventory queries


USE GreenAcresEMS;
GO


IF NOT EXISTS (
    SELECT 1
    FROM sys.masked_columns
    WHERE object_id = OBJECT_ID('dbo.Clients')
      AND name = 'NRIC'
)
BEGIN
    ALTER TABLE dbo.Clients
    ALTER COLUMN NRIC 
/* ========================================================================
   REQUIREMENT 7: MASKING
   ======================================================================== */
ADD MASKED WITH (FUNCTION = 'partial(0, "XXXXXX", 4)');
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.masked_columns
    WHERE object_id = OBJECT_ID('dbo.Clients')
      AND name = 'ContactNumber'
)
BEGIN
    ALTER TABLE dbo.Clients
    ALTER COLUMN ContactNumber 
/* ========================================================================
   REQUIREMENT 7: MASKING
   ======================================================================== */
ADD MASKED WITH (FUNCTION = 'partial(3, "XXXXXXX", 2)');
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.masked_columns
    WHERE object_id = OBJECT_ID('dbo.Clients')
      AND name = 'Email'
)
BEGIN
    ALTER TABLE dbo.Clients
    ALTER COLUMN Email 
/* ========================================================================
   REQUIREMENT 7: MASKING
   ======================================================================== */
ADD MASKED WITH (FUNCTION = 'email()');
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.masked_columns
    WHERE object_id = OBJECT_ID('dbo.Clients')
      AND name = 'Address'
)
BEGIN
    ALTER TABLE dbo.Clients
    ALTER COLUMN Address 
/* ========================================================================
   REQUIREMENT 7: MASKING
   ======================================================================== */
ADD MASKED WITH (FUNCTION = 'partial(8, "XXXXXXXXXX", 0)');
END;
GO


IF NOT EXISTS (
    SELECT 1
    FROM sys.masked_columns
    WHERE object_id = OBJECT_ID('dbo.Agents')
      AND name = 'ContactNumber'
)
BEGIN
    ALTER TABLE dbo.Agents
    ALTER COLUMN ContactNumber 
/* ========================================================================
   REQUIREMENT 7: MASKING
   ======================================================================== */
ADD MASKED WITH (FUNCTION = 'partial(3, "XXXXXXX", 2)');
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.masked_columns
    WHERE object_id = OBJECT_ID('dbo.Agents')
      AND name = 'Email'
)
BEGIN
    ALTER TABLE dbo.Agents
    ALTER COLUMN Email 
/* ========================================================================
   REQUIREMENT 7: MASKING
   ======================================================================== */
ADD MASKED WITH (FUNCTION = 'email()');
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.masked_columns
    WHERE object_id = OBJECT_ID('dbo.Agents')
      AND name = 'CommissionRate'
)
BEGIN
    ALTER TABLE dbo.Agents
    ALTER COLUMN CommissionRate 
/* ========================================================================
   REQUIREMENT 7: MASKING
   ======================================================================== */
ADD MASKED WITH (FUNCTION = 'default()');
END;
GO


IF NOT EXISTS (
    SELECT 1
    FROM sys.masked_columns
    WHERE object_id = OBJECT_ID('dbo.Properties')
      AND name = 'Address'
)
BEGIN
    ALTER TABLE dbo.Properties
    ALTER COLUMN Address 
/* ========================================================================
   REQUIREMENT 7: MASKING
   ======================================================================== */
ADD MASKED WITH (FUNCTION = 'partial(8, "XXXXXXXXXX", 0)');
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.masked_columns
    WHERE object_id = OBJECT_ID('dbo.Properties')
      AND name = 'Price'
)
BEGIN
    ALTER TABLE dbo.Properties
    ALTER COLUMN Price 
/* ========================================================================
   REQUIREMENT 7: MASKING
   ======================================================================== */
ADD MASKED WITH (FUNCTION = 'random(100000, 1000000)');
END;
GO


IF NOT EXISTS (
    SELECT 1
    FROM sys.masked_columns
    WHERE object_id = OBJECT_ID('dbo.Transactions')
      AND name = 'Amount'
)
BEGIN
    ALTER TABLE dbo.Transactions
    ALTER COLUMN Amount 
/* ========================================================================
   REQUIREMENT 7: MASKING
   ======================================================================== */
ADD MASKED WITH (FUNCTION = 'random(1000, 100000)');
END;
GO


IF NOT EXISTS (
    SELECT 1
    FROM sys.masked_columns
    WHERE object_id = OBJECT_ID('dbo.MaintenanceRequests')
      AND name = 'EstimatedCost'
)
BEGIN
    ALTER TABLE dbo.MaintenanceRequests
    ALTER COLUMN EstimatedCost 
/* ========================================================================
   REQUIREMENT 7: MASKING
   ======================================================================== */
ADD MASKED WITH (FUNCTION = 'random(100, 10000)');
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.masked_columns
    WHERE object_id = OBJECT_ID('dbo.MaintenanceRequests')
      AND name = 'ActualCost'
)
BEGIN
    ALTER TABLE dbo.MaintenanceRequests
    ALTER COLUMN ActualCost 
/* ========================================================================
   REQUIREMENT 7: MASKING
   ======================================================================== */
ADD MASKED WITH (FUNCTION = 'random(100, 10000)');
END;
GO


IF NOT EXISTS (
    SELECT 1
    FROM sys.masked_columns
    WHERE object_id = OBJECT_ID('dbo.SystemUsers')
      AND name = 'Email'
)
BEGIN
    ALTER TABLE dbo.SystemUsers
    ALTER COLUMN Email 
/* ========================================================================
   REQUIREMENT 7: MASKING
   ======================================================================== */
ADD MASKED WITH (FUNCTION = 'email()');
END;
GO


IF NOT EXISTS (
    SELECT 1
    FROM sys.masked_columns
    WHERE object_id = OBJECT_ID('dbo.LeaseAgreements')
      AND name = 'MonthlyRent'
)
BEGIN
    ALTER TABLE dbo.LeaseAgreements
    ALTER COLUMN MonthlyRent 
/* ========================================================================
   REQUIREMENT 7: MASKING
   ======================================================================== */
ADD MASKED WITH (FUNCTION = 'random(1000, 10000)');
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.masked_columns
    WHERE object_id = OBJECT_ID('dbo.LeaseAgreements')
      AND name = 'SecurityDeposit'
)
BEGIN
    ALTER TABLE dbo.LeaseAgreements
    ALTER COLUMN SecurityDeposit 
/* ========================================================================
   REQUIREMENT 7: MASKING
   ======================================================================== */
ADD MASKED WITH (FUNCTION = 'random(1000, 20000)');
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.masked_columns
    WHERE object_id = OBJECT_ID('dbo.LeaseAgreements')
      AND name = 'AgreementDocPath'
)
BEGIN
    ALTER TABLE dbo.LeaseAgreements
    ALTER COLUMN AgreementDocPath 
/* ========================================================================
   REQUIREMENT 7: MASKING
   ======================================================================== */
ADD MASKED WITH (FUNCTION = 'partial(5, "XXXXXXXXXX", 4)');
END;
GO


IF NOT EXISTS (
    SELECT 1
    FROM sys.masked_columns
    WHERE object_id = OBJECT_ID('dbo.CommissionPayments')
      AND name = 'CommissionRate'
)
BEGIN
    ALTER TABLE dbo.CommissionPayments
    ALTER COLUMN CommissionRate 
/* ========================================================================
   REQUIREMENT 7: MASKING
   ======================================================================== */
ADD MASKED WITH (FUNCTION = 'default()');
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.masked_columns
    WHERE object_id = OBJECT_ID('dbo.CommissionPayments')
      AND name = 'CommissionAmount'
)
BEGIN
    ALTER TABLE dbo.CommissionPayments
    ALTER COLUMN CommissionAmount 
/* ========================================================================
   REQUIREMENT 7: MASKING
   ======================================================================== */
ADD MASKED WITH (FUNCTION = 'random(100, 100000)');
END;
GO


IF NOT EXISTS (
    SELECT 1
    FROM sys.masked_columns
    WHERE object_id = OBJECT_ID('dbo.MaintenanceStaff')
      AND name = 'ContactNumber'
)
BEGIN
    ALTER TABLE dbo.MaintenanceStaff
    ALTER COLUMN ContactNumber
/* ========================================================================
   REQUIREMENT 7: MASKING
   ======================================================================== */
ADD MASKED WITH (FUNCTION = 'partial(3, "XXXXXXX", 2)');
END;
GO


/* ========================================================================
   REQUIREMENT 7 (continued): MASKING - KNOWN LIMIT + ANALYST EXCEPTION
   IMPORTANT LIMITATION, stated deliberately for the report: Dynamic Data
   Masking is a PRESENTATION control, not a security boundary.
   ======================================================================== */
-- Issued through sp_executesql so a SQL Server 2019 parser never sees the
-- 2022-only column-level UNMASK syntax and rejects the whole batch.
IF CAST(SERVERPROPERTY('ProductMajorVersion') AS INT) >= 16
BEGIN
    PRINT 'SQL Server 2022+ detected: applying column-level UNMASK for role_Analyst.';

    -- Financial columns the analytics team reports on:
    EXEC sys.sp_executesql N'GRANT UNMASK ON dbo.Transactions(Amount)                TO role_Analyst;';
    EXEC sys.sp_executesql N'GRANT UNMASK ON dbo.Properties(Price)                   TO role_Analyst;';
    EXEC sys.sp_executesql N'GRANT UNMASK ON dbo.CommissionPayments(CommissionAmount) TO role_Analyst;';
    EXEC sys.sp_executesql N'GRANT UNMASK ON dbo.CommissionPayments(CommissionRate)   TO role_Analyst;';
    EXEC sys.sp_executesql N'GRANT UNMASK ON dbo.LeaseAgreements(MonthlyRent)         TO role_Analyst;';

    -- NOTE what is deliberately NOT granted: Clients.NRIC, Clients.Email,
    -- Clients.ContactNumber, Clients.Address, Agents.ContactNumber,
    -- Agents.Email, SystemUsers.Email, MaintenanceStaff.ContactNumber.
END
ELSE
BEGIN
    PRINT 'SQL Server 2019 or older detected: column-level UNMASK is not available.';
    PRINT 'role_Analyst keeps masked columns; the aggregate limitation above is accepted and documented.';
END;
GO


IF NOT EXISTS (
    SELECT 1
    FROM sys.symmetric_keys
    WHERE name = '##MS_DatabaseMasterKey##'
)
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'EMS_MasterKey_StrongPassword_2026!';
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.certificates
    WHERE name = 'EMS_DataProtectionCertificate'
)
BEGIN
    CREATE CERTIFICATE EMS_DataProtectionCertificate
    WITH SUBJECT = 'Certificate used to protect sensitive EMS client data';
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.symmetric_keys
    WHERE name = 'EMS_ClientDataSymmetricKey'
)
BEGIN
    
/* ========================================================================
   REQUIREMENT 5 & 6: HASH & ENCRYPTION
   ======================================================================== */
CREATE SYMMETRIC KEY EMS_ClientDataSymmetricKey
    WITH ALGORITHM = AES_256
    ENCRYPTION BY CERTIFICATE EMS_DataProtectionCertificate;
END;
GO


IF COL_LENGTH('dbo.Clients', 'NRIC_Encrypted') IS NULL
BEGIN
    ALTER TABLE dbo.Clients
    ADD NRIC_Encrypted VARBINARY(MAX) NULL;
END;
GO

IF COL_LENGTH('dbo.Clients', 'ContactNumber_Encrypted') IS NULL
BEGIN
    ALTER TABLE dbo.Clients
    ADD ContactNumber_Encrypted VARBINARY(MAX) NULL;
END;
GO

IF COL_LENGTH('dbo.Clients', 'Email_Encrypted') IS NULL
BEGIN
    ALTER TABLE dbo.Clients
    ADD Email_Encrypted VARBINARY(MAX) NULL;
END;
GO

IF COL_LENGTH('dbo.Clients', 'Address_Encrypted') IS NULL
BEGIN
    ALTER TABLE dbo.Clients
    ADD Address_Encrypted VARBINARY(MAX) NULL;
END;
GO


-- >>> MOVED TO DML.sql: Encrypting the Clients PII columns


IF COL_LENGTH('dbo.LeaseAgreements', 'AgreementDocPath_Encrypted') IS NULL
BEGIN
    ALTER TABLE dbo.LeaseAgreements
    ADD AgreementDocPath_Encrypted VARBINARY(MAX) NULL;
END;
GO


-- >>> MOVED TO DML.sql: Encrypting LeaseAgreements.AgreementDocPath


IF COL_LENGTH('dbo.SystemUsers', 'PasswordSaltSecure') IS NULL
BEGIN
    ALTER TABLE dbo.SystemUsers
    ADD PasswordSaltSecure VARBINARY(32) NULL;
END;
GO

IF COL_LENGTH('dbo.SystemUsers', 'PasswordHashSecure') IS NULL
BEGIN
    ALTER TABLE dbo.SystemUsers
    ADD PasswordHashSecure VARBINARY(64) NULL;
END;
GO

IF COL_LENGTH('dbo.SystemUsers', 'PasswordHashAlgorithm') IS NULL
BEGIN
    ALTER TABLE dbo.SystemUsers
    ADD PasswordHashAlgorithm NVARCHAR(20) NULL;
END;
GO

IF COL_LENGTH('dbo.SystemUsers', 'PasswordLastUpdated') IS NULL
BEGIN
    ALTER TABLE dbo.SystemUsers
    ADD PasswordLastUpdated DATETIME NULL;
END;
GO


-- >>> MOVED TO DML.sql: Generating the per-user salts and SHA2_512 hashes

-- Forced-reset flag: 1 = still on the onboarding password.
IF COL_LENGTH('dbo.SystemUsers', 'PasswordMustChange') IS NULL
BEGIN
    ALTER TABLE dbo.SystemUsers
    ADD PasswordMustChange BIT NOT NULL CONSTRAINT DF_SysUser_MustChange DEFAULT 1;
END;
GO


/* ========================================================================
   ------------------------------------------------------------------------
   REMOVING THE OLD, WEAKER CREDENTIAL STORE The original developers stored
   credentials in two columns: PasswordHash VARBINARY(64) --
   HASHBYTES('SHA2_256', password + salt) PasswordSalt NVARCHAR(50) -- the salt,
   in PLAIN TEXT Both are now superseded by PasswordHashSecure /
   PasswordSaltSecure, and leaving them in place would be a real weakness, not
   just clutter: * the salt sat next to the hash in a readable NVARCHAR column,
   so anyone with SELECT on SystemUsers had everything needed to run an offline
   dictionary attack; * SHA2_256 over a short salt is far cheaper to brute-force
   than the SHA2_512 over a 32-byte CRYPT_GEN_RANDOM salt we use now; * two
   credential stores for one account means an attacker simply attacks the weaker
   one.
   ======================================================================== */
IF COL_LENGTH('dbo.SystemUsers', 'PasswordHash') IS NOT NULL
BEGIN
    ALTER TABLE dbo.SystemUsers DROP COLUMN PasswordHash;
    PRINT 'Dropped legacy column SystemUsers.PasswordHash (SHA2_256).';
END;
GO

IF COL_LENGTH('dbo.SystemUsers', 'PasswordSalt') IS NOT NULL
BEGIN
    ALTER TABLE dbo.SystemUsers DROP COLUMN PasswordSalt;
    PRINT 'Dropped legacy column SystemUsers.PasswordSalt (plain-text salt).';
END;
GO


CREATE OR ALTER PROCEDURE dbo.usp_UpdateSystemUserPassword
    @LoginName NVARCHAR(100),
    @NewPlainPassword NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @NewSalt VARBINARY(32);
    DECLARE @NewHash VARBINARY(64);

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.SystemUsers
        WHERE LoginName = @LoginName
          AND IsActive = 1
    )
    BEGIN
        RAISERROR('System user does not exist or is inactive.', 16, 1);
        RETURN;
    END;

    SET @NewSalt = CRYPT_GEN_RANDOM(32);

    SET @NewHash = HASHBYTES(
        'SHA2_512',
        CONVERT(VARBINARY(MAX), @NewPlainPassword) + @NewSalt
    );

    UPDATE dbo.SystemUsers
    SET
        PasswordSaltSecure = @NewSalt,
        PasswordHashSecure = @NewHash,
        PasswordHashAlgorithm = 'SHA2_512',
        PasswordLastUpdated = GETDATE(),
        PasswordMustChange = 0      -- the onboarding password is now replaced
    WHERE LoginName = @LoginName;

    PRINT 'Password updated for ' + @LoginName + '.';
END;
GO


-- usp_VerifySystemUserPassword: Verifies an application-level login by re-
-- hashing the supplied password with the stored per-user salt and comparing the
-- digests.
CREATE OR ALTER PROCEDURE dbo.usp_VerifySystemUserPassword
    @LoginName NVARCHAR(100),
    @PlainPassword NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StoredSalt   VARBINARY(32);
    DECLARE @StoredHash   VARBINARY(64);
    DECLARE @InputHash    VARBINARY(64);
    DECLARE @SystemUserID INT;

    SELECT
        @SystemUserID = SystemUserID,
        @StoredSalt   = PasswordSaltSecure,
        @StoredHash   = PasswordHashSecure
    FROM dbo.SystemUsers
    WHERE LoginName = @LoginName
      AND IsActive = 1;

    IF @StoredSalt IS NULL OR @StoredHash IS NULL
    BEGIN
        -- Unknown or deactivated account.
        INSERT INTO dbo.UserLoginLog
            (SystemUserID, LoginName, IsSuccessful, HostName, FailureReason)
        VALUES
            (@SystemUserID, @LoginName, 0, HOST_NAME(),
             'Unknown or inactive account');

        SELECT
            'Invalid Login' AS LoginStatus,
            @LoginName AS LoginName;
        RETURN;
    END;

    SET @InputHash = HASHBYTES(
        'SHA2_512',
        CONVERT(VARBINARY(MAX), @PlainPassword) + @StoredSalt
    );

    IF @InputHash = @StoredHash
    BEGIN
        INSERT INTO dbo.UserLoginLog
            (SystemUserID, LoginName, IsSuccessful, HostName, FailureReason)
        VALUES
            (@SystemUserID, @LoginName, 1, HOST_NAME(), NULL);

        DECLARE @LogID INT = SCOPE_IDENTITY();

        -- Correct password, but still the shared onboarding secret: the
        -- credential is valid yet must not be usable for real work until the
        -- account owner replaces it.
        IF EXISTS (SELECT 1 FROM dbo.SystemUsers
                   WHERE LoginName = @LoginName AND PasswordMustChange = 1)
        BEGIN
            SELECT
                'Password Change Required' AS LoginStatus,
                @LogID                     AS LogID,
                SystemUserID,
                FullName,
                LoginName,
                UserRole
            FROM dbo.SystemUsers
            WHERE LoginName = @LoginName;
            RETURN;
        END;

        SELECT
            'Login Successful' AS LoginStatus,
            @LogID             AS LogID,   -- pass to usp_RecordLogout later
            SystemUserID,
            FullName,
            LoginName,
            UserRole
        FROM dbo.SystemUsers
        WHERE LoginName = @LoginName;
    END
    ELSE
    BEGIN
        INSERT INTO dbo.UserLoginLog
            (SystemUserID, LoginName, IsSuccessful, HostName, FailureReason)
        VALUES
            (@SystemUserID, @LoginName, 0, HOST_NAME(), 'Incorrect password');

        SELECT
            'Invalid Login' AS LoginStatus,
            @LoginName AS LoginName;
    END;
END;
GO


-- usp_RecordLogout: Closes off a session row in UserLoginLog so the audit trail
-- shows how long each account was connected, not just when it arrived.
CREATE OR ALTER PROCEDURE dbo.usp_RecordLogout
    @LogID INT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.UserLoginLog
    SET LogoutTime = GETDATE()
    WHERE LogID = @LogID
      AND LogoutTime IS NULL;

    IF @@ROWCOUNT = 0
        PRINT 'No open session found for that LogID (already closed or invalid).';
    ELSE
        PRINT 'Logout recorded.';
END;
GO


-- usp_ReportSuspiciousLogins: Detection query for the DBA: any account with 3
-- or more failed attempts inside a rolling window is reported as a possible
-- brute-force attempt.
CREATE OR ALTER PROCEDURE dbo.usp_ReportSuspiciousLogins
    @WindowMinutes  INT = 60,
    @FailThreshold  INT = 3
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        LoginName,
        COUNT(*)        AS FailedAttempts,
        MIN(LoginTime)  AS FirstAttempt,
        MAX(LoginTime)  AS LastAttempt,
        MAX(HostName)   AS LastHostName
    FROM dbo.UserLoginLog
    WHERE IsSuccessful = 0
      AND LoginTime >= DATEADD(MINUTE, -@WindowMinutes, GETDATE())
    GROUP BY LoginName
    HAVING COUNT(*) >= @FailThreshold
    ORDER BY FailedAttempts DESC;
END;
GO


/* ========================================================================
   REQUIREMENT 6 (continued): CONTROLLED DECRYPTION PATH
   Encrypting the data is only half the job - the business still has to be able
   to READ it.
   ======================================================================== */

-- usp_GetClientSensitiveData: Returns decrypted client PII for ONE client at a
-- time.
CREATE OR ALTER PROCEDURE dbo.usp_GetClientSensitiveData
    @ClientID INT,
    @Reason   NVARCHAR(200) = NULL   -- purpose-of-access, written to AuditLog
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    IF @ClientID IS NULL
    BEGIN
        RAISERROR('ClientID is required.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (SELECT 1 FROM dbo.Clients WHERE ClientID = @ClientID)
    BEGIN
        RAISERROR('Client ID not found.', 16, 1);
        RETURN;
    END;

    -- Record WHO asked for decrypted PII and WHY, before handing it over.
    INSERT INTO dbo.AuditLog
        (TableName, OperationType, RecordID, ChangedBy,
         NewValues, ApplicationName, HostName)
    VALUES
        ('Clients', 'SELECT', CONVERT(NVARCHAR(50), @ClientID), ORIGINAL_LOGIN(),
         (SELECT 'DECRYPT_READ'                AS Action,
                 ISNULL(@Reason, 'not stated') AS Reason
          FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
         APP_NAME(), HOST_NAME());

    OPEN SYMMETRIC KEY EMS_ClientDataSymmetricKey
        DECRYPTION BY CERTIFICATE EMS_DataProtectionCertificate;

    SELECT
        c.ClientID,
        c.FullName,
        CONVERT(NVARCHAR(20),  DecryptByKey(c.NRIC_Encrypted))          AS NRIC,
        CONVERT(NVARCHAR(20),  DecryptByKey(c.ContactNumber_Encrypted)) AS ContactNumber,
        CONVERT(NVARCHAR(100), DecryptByKey(c.Email_Encrypted))         AS Email,
        CONVERT(NVARCHAR(255), DecryptByKey(c.Address_Encrypted))       AS Address,
        c.ClientType,
        c.IsActive
    FROM dbo.Clients AS c
    WHERE c.ClientID = @ClientID;

    CLOSE SYMMETRIC KEY EMS_ClientDataSymmetricKey;
END;
GO


-- usp_GetLeaseDocumentPath: Same pattern for the encrypted lease-document
-- location.
CREATE OR ALTER PROCEDURE dbo.usp_GetLeaseDocumentPath
    @LeaseID INT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.LeaseAgreements WHERE LeaseID = @LeaseID)
    BEGIN
        RAISERROR('Lease ID not found.', 16, 1);
        RETURN;
    END;

    OPEN SYMMETRIC KEY EMS_ClientDataSymmetricKey
        DECRYPTION BY CERTIFICATE EMS_DataProtectionCertificate;

    SELECT
        l.LeaseID,
        l.ClientID,
        l.PropertyID,
        CONVERT(NVARCHAR(500), DecryptByKey(l.AgreementDocPath_Encrypted))
            AS AgreementDocPath,
        l.LeaseStatus
    FROM dbo.LeaseAgreements AS l
    WHERE l.LeaseID = @LeaseID;

    CLOSE SYMMETRIC KEY EMS_ClientDataSymmetricKey;
END;
GO


-- usp_EncryptClientPII: Re-encrypts the sensitive columns for a client after an
-- INSERT/UPDATE.
CREATE OR ALTER PROCEDURE dbo.usp_EncryptClientPII
    @ClientID INT = NULL       -- NULL = refresh every row that needs it
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    OPEN SYMMETRIC KEY EMS_ClientDataSymmetricKey
        DECRYPTION BY CERTIFICATE EMS_DataProtectionCertificate;

    UPDATE dbo.Clients
    SET
        NRIC_Encrypted = EncryptByKey(
            Key_GUID('EMS_ClientDataSymmetricKey'), CONVERT(VARBINARY(MAX), NRIC)),
        ContactNumber_Encrypted = EncryptByKey(
            Key_GUID('EMS_ClientDataSymmetricKey'), CONVERT(VARBINARY(MAX), ContactNumber)),
        Email_Encrypted = EncryptByKey(
            Key_GUID('EMS_ClientDataSymmetricKey'), CONVERT(VARBINARY(MAX), Email)),
        Address_Encrypted = EncryptByKey(
            Key_GUID('EMS_ClientDataSymmetricKey'), CONVERT(VARBINARY(MAX), Address))
    WHERE (@ClientID IS NULL OR ClientID = @ClientID)
      AND (
            NRIC_Encrypted IS NULL
         OR ContactNumber_Encrypted IS NULL
         OR Email_Encrypted IS NULL
         OR Address_Encrypted IS NULL
         OR @ClientID IS NOT NULL      -- explicit refresh for one client
          );

    DECLARE @Rows INT = @@ROWCOUNT;

    CLOSE SYMMETRIC KEY EMS_ClientDataSymmetricKey;

    PRINT 'Rows re-encrypted: ' + CAST(@Rows AS VARCHAR(10));
END;
GO


-- Who may decrypt? role_Admin - business owners of client data, needed for
-- daily service.
GRANT EXECUTE ON dbo.usp_GetClientSensitiveData TO role_Admin;
GRANT EXECUTE ON dbo.usp_GetClientSensitiveData TO role_DBA;
GRANT EXECUTE ON dbo.usp_GetLeaseDocumentPath   TO role_Admin;
GRANT EXECUTE ON dbo.usp_GetLeaseDocumentPath   TO role_DBA;
GRANT EXECUTE ON dbo.usp_EncryptClientPII       TO role_Admin;
GRANT EXECUTE ON dbo.usp_EncryptClientPII       TO role_DBA;
GRANT EXECUTE ON dbo.usp_RecordLogout           TO role_Admin;
GRANT EXECUTE ON dbo.usp_ReportSuspiciousLogins TO role_DBA;
GO

-- Explicit DENY on the decryption doors for the developer/reporting roles.
DENY EXECUTE ON dbo.usp_GetClientSensitiveData TO role_PropMgmtDev;
DENY EXECUTE ON dbo.usp_GetClientSensitiveData TO role_ClientPortalDev;
DENY EXECUTE ON dbo.usp_GetClientSensitiveData TO role_Analyst;
DENY EXECUTE ON dbo.usp_GetClientSensitiveData TO role_ReadOnly;
DENY EXECUTE ON dbo.usp_GetLeaseDocumentPath   TO role_Analyst;
DENY EXECUTE ON dbo.usp_GetLeaseDocumentPath   TO role_ReadOnly;
GO

-- Ad-hoc key access for DBAs only.
GRANT VIEW DEFINITION ON SYMMETRIC KEY::EMS_ClientDataSymmetricKey TO role_DBA;
GRANT CONTROL ON CERTIFICATE::EMS_DataProtectionCertificate        TO role_DBA;
GO

PRINT 'Controlled decryption path created (procedures + grants).';
GO


/* ========================================================================
   OPTIONAL HARDENING - REMOVING THE PLAINTEXT DUPLICATES
   Each protected column exists twice (readable + ciphertext) so masking stays
   demonstrable, which makes the encryption defence-in-depth rather than true
   encryption-at-rest; un-comment below for the latter, then fix
   vw_ClientDirectory, usp_ManageClient, the two masking blocks and tests
   B2/C5/C6/C7. See README.md "Known limitations".
   ------------------------------------------------------------------------
   ALTER TABLE dbo.Clients         DROP COLUMN NRIC;
   ALTER TABLE dbo.LeaseAgreements DROP COLUMN AgreementDocPath;
   GO
   ======================================================================== */


USE master;
GO


ALTER DATABASE GreenAcresEMS SET RECOVERY FULL;
GO

-- >>> MOVED TO DML.sql: Key-material backup, database backups, restore rehearsal


USE GreenAcresEMS;
GO

-- PART 12: AUDIT TABLES, RETENTION AND AUDIT PERMISSIONS Green Acres Realty Sdn
-- Bhd - EMS Database Security CT069-3-3 Database Security Assignment Purpose:
-- 1. Create the central AuditLog table if it does not exist.

USE GreenAcresEMS;
GO

IF OBJECT_ID('dbo.AuditLog', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.AuditLog (
        AuditID         INT IDENTITY(1,1) PRIMARY KEY,
        EventTime       DATETIME NOT NULL DEFAULT GETDATE(),
        TableName       NVARCHAR(128) NOT NULL,
        OperationType   NVARCHAR(10) NOT NULL
            CONSTRAINT CK_Audit_Op CHECK (OperationType IN ('INSERT','UPDATE','DELETE','SELECT')),
        RecordID        NVARCHAR(50) NOT NULL,
        ChangedBy       NVARCHAR(100) NOT NULL DEFAULT SYSTEM_USER,
        OldValues       NVARCHAR(MAX) NULL,
        NewValues       NVARCHAR(MAX) NULL,
        ApplicationName NVARCHAR(128) NULL,
        HostName        NVARCHAR(128) NULL
    );
END;
GO

-- Index used by incident-history and date-range searches.
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.AuditLog')
      AND name = 'IX_AuditLog_EventTime'
)
BEGIN
    CREATE INDEX IX_AuditLog_EventTime
        ON dbo.AuditLog (EventTime DESC)
        INCLUDE (TableName, OperationType, RecordID, ChangedBy);
END;
GO

-- Older audit rows are moved here instead of being permanently deleted.
IF OBJECT_ID('dbo.AuditLogArchive', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.AuditLogArchive (
        AuditID         INT NOT NULL PRIMARY KEY,
        EventTime       DATETIME NOT NULL,
        TableName       NVARCHAR(128) NOT NULL,
        OperationType   NVARCHAR(10) NOT NULL,
        RecordID        NVARCHAR(50) NOT NULL,
        ChangedBy       NVARCHAR(100) NOT NULL,
        OldValues       NVARCHAR(MAX) NULL,
        NewValues       NVARCHAR(MAX) NULL,
        ApplicationName NVARCHAR(128) NULL,
        HostName        NVARCHAR(128) NULL,
        ArchivedAt      DATETIME2(0) NOT NULL
            CONSTRAINT DF_AuditLogArchive_ArchivedAt DEFAULT SYSUTCDATETIME()
    );

    CREATE INDEX IX_AuditLogArchive_EventTime
        ON dbo.AuditLogArchive (EventTime DESC)
        INCLUDE (TableName, OperationType, RecordID, ChangedBy);
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_ArchiveAuditLog
    @RetainDays INT = 365
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @RetainDays < 30
        THROW 50001, 'RetainDays must be at least 30 days.', 1;

    DECLARE @Cutoff DATETIME = DATEADD(DAY, -@RetainDays, GETDATE());
    DECLARE @RowsArchived INT;

    BEGIN TRANSACTION;

    DELETE FROM dbo.AuditLog
    OUTPUT
        deleted.AuditID,
        deleted.EventTime,
        deleted.TableName,
        deleted.OperationType,
        deleted.RecordID,
        deleted.ChangedBy,
        deleted.OldValues,
        deleted.NewValues,
        deleted.ApplicationName,
        deleted.HostName
    INTO dbo.AuditLogArchive (
        AuditID,
        EventTime,
        TableName,
        OperationType,
        RecordID,
        ChangedBy,
        OldValues,
        NewValues,
        ApplicationName,
        HostName
    )
    WHERE EventTime < @Cutoff;

    SET @RowsArchived = @@ROWCOUNT;
    COMMIT TRANSACTION;

    SELECT
        @RowsArchived AS RowsArchived,
        @Cutoff AS CutoffDate,
        @RetainDays AS RetainDays;
END;
GO

-- Only DBA/Admin should read the audit trail directly.
IF DATABASE_PRINCIPAL_ID('role_DBA') IS NOT NULL
BEGIN
    GRANT SELECT ON dbo.AuditLog TO role_DBA;
    GRANT SELECT ON dbo.AuditLogArchive TO role_DBA;
    GRANT EXECUTE ON dbo.usp_ArchiveAuditLog TO role_DBA;
END;
GO

IF DATABASE_PRINCIPAL_ID('role_Admin') IS NOT NULL
BEGIN
    GRANT SELECT ON dbo.AuditLog TO role_Admin;
    GRANT SELECT ON dbo.AuditLogArchive TO role_Admin;
END;
GO

IF DATABASE_PRINCIPAL_ID('role_PropMgmtDev') IS NOT NULL
BEGIN
    DENY SELECT, INSERT, UPDATE, DELETE ON dbo.AuditLog TO role_PropMgmtDev;
    DENY SELECT, INSERT, UPDATE, DELETE ON dbo.AuditLogArchive TO role_PropMgmtDev;
END;
GO

IF DATABASE_PRINCIPAL_ID('role_ClientPortalDev') IS NOT NULL
BEGIN
    DENY SELECT, INSERT, UPDATE, DELETE ON dbo.AuditLog TO role_ClientPortalDev;
    DENY SELECT, INSERT, UPDATE, DELETE ON dbo.AuditLogArchive TO role_ClientPortalDev;
END;
GO

IF DATABASE_PRINCIPAL_ID('role_Analyst') IS NOT NULL
BEGIN
    DENY SELECT, INSERT, UPDATE, DELETE ON dbo.AuditLog TO role_Analyst;
    DENY SELECT, INSERT, UPDATE, DELETE ON dbo.AuditLogArchive TO role_Analyst;
END;
GO

IF DATABASE_PRINCIPAL_ID('role_ReadOnly') IS NOT NULL
BEGIN
    DENY SELECT, INSERT, UPDATE, DELETE ON dbo.AuditLog TO role_ReadOnly;
    DENY SELECT, INSERT, UPDATE, DELETE ON dbo.AuditLogArchive TO role_ReadOnly;
END;
GO

USE GreenAcresEMS;
GO

-- Drop the database audit specification first if this script is re-run.
IF EXISTS (SELECT 1 FROM sys.database_audit_specifications WHERE name = 'GA_EMS_DatabaseAuditSpec')
BEGIN
    ALTER DATABASE AUDIT SPECIFICATION GA_EMS_DatabaseAuditSpec WITH (STATE = OFF);
    DROP DATABASE AUDIT SPECIFICATION GA_EMS_DatabaseAuditSpec;
END;
GO

USE master;
GO

IF EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'GA_EMS_ServerAuditSpec')
BEGIN
    ALTER SERVER AUDIT SPECIFICATION GA_EMS_ServerAuditSpec WITH (STATE = OFF);
    DROP SERVER AUDIT SPECIFICATION GA_EMS_ServerAuditSpec;
END;
GO

IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'GA_EMS_ServerAudit')
BEGIN
    ALTER SERVER AUDIT GA_EMS_ServerAudit WITH (STATE = OFF);
    DROP SERVER AUDIT GA_EMS_ServerAudit;
END;
GO


/* ========================================================================
   REQUIREMENT 9 & 10: SERVER & DATABASE AUDITING
   ======================================================================== */
CREATE SERVER AUDIT GA_EMS_ServerAudit
TO FILE (
    FILEPATH = 'C:\SQLAudit\',
    MAXSIZE = 20 MB,
    MAX_ROLLOVER_FILES = 5,
    RESERVE_DISK_SPACE = OFF
)
WITH (
    QUEUE_DELAY = 1000,
    ON_FAILURE = CONTINUE
);
GO

CREATE SERVER AUDIT SPECIFICATION GA_EMS_ServerAuditSpec
FOR SERVER AUDIT GA_EMS_ServerAudit
    ADD (FAILED_LOGIN_GROUP),
    ADD (SUCCESSFUL_LOGIN_GROUP),
    ADD (AUDIT_CHANGE_GROUP),
    ADD (SERVER_PRINCIPAL_CHANGE_GROUP),
    ADD (SERVER_PERMISSION_CHANGE_GROUP),
    ADD (SERVER_ROLE_MEMBER_CHANGE_GROUP);
GO

ALTER SERVER AUDIT GA_EMS_ServerAudit WITH (STATE = ON);
GO

ALTER SERVER AUDIT SPECIFICATION GA_EMS_ServerAuditSpec WITH (STATE = ON);
GO

USE GreenAcresEMS;
GO

IF EXISTS (SELECT 1 FROM sys.database_audit_specifications WHERE name = 'GA_EMS_DatabaseAuditSpec')
BEGIN
    ALTER DATABASE AUDIT SPECIFICATION GA_EMS_DatabaseAuditSpec WITH (STATE = OFF);
    DROP DATABASE AUDIT SPECIFICATION GA_EMS_DatabaseAuditSpec;
END;
GO

CREATE DATABASE AUDIT SPECIFICATION GA_EMS_DatabaseAuditSpec
FOR SERVER AUDIT GA_EMS_ServerAudit
    ADD (DATABASE_PRINCIPAL_CHANGE_GROUP),
    ADD (DATABASE_PERMISSION_CHANGE_GROUP),
    ADD (DATABASE_ROLE_MEMBER_CHANGE_GROUP),
    ADD (SCHEMA_OBJECT_PERMISSION_CHANGE_GROUP),
    ADD (SCHEMA_OBJECT_CHANGE_GROUP),
    ADD (SELECT ON OBJECT::dbo.Clients BY public),
    ADD (UPDATE ON OBJECT::dbo.Clients BY public),
    ADD (DELETE ON OBJECT::dbo.Clients BY public),
    ADD (SELECT ON OBJECT::dbo.Transactions BY public),
    ADD (UPDATE ON OBJECT::dbo.Transactions BY public),
    ADD (DELETE ON OBJECT::dbo.Transactions BY public),
    ADD (SELECT ON OBJECT::dbo.CommissionPayments BY public),
    ADD (UPDATE ON OBJECT::dbo.CommissionPayments BY public),
    ADD (DELETE ON OBJECT::dbo.CommissionPayments BY public),
    ADD (SELECT ON OBJECT::dbo.AuditLog BY public),
    ADD (INSERT ON OBJECT::dbo.AuditLog BY public),
    ADD (UPDATE ON OBJECT::dbo.AuditLog BY public),
    ADD (DELETE ON OBJECT::dbo.AuditLog BY public),
    ADD (SELECT ON OBJECT::dbo.AuditLogArchive BY public),
    ADD (INSERT ON OBJECT::dbo.AuditLogArchive BY public),
    ADD (UPDATE ON OBJECT::dbo.AuditLogArchive BY public),
    ADD (DELETE ON OBJECT::dbo.AuditLogArchive BY public);
GO

ALTER DATABASE AUDIT SPECIFICATION GA_EMS_DatabaseAuditSpec WITH (STATE = ON);
GO

-- >>> MOVED TO DML.sql: Audit status verification queries


/* ========================================================================
   REQUIREMENT 9 & 10 (continued): LOGIN HISTORY IN dbo.UserLoginLog
   The Server Audit above writes to .sqlaudit FILES, which are excellent tamper-
   resistant evidence but awkward to query from the application and impossible
   to join to our own SystemUsers table.
   ======================================================================== */
USE master;
GO

-- Drop first so this script stays re-runnable.
IF EXISTS (SELECT 1 FROM sys.server_triggers WHERE name = 'trg_ServerLogon_AuditLogin')
BEGIN
    DROP TRIGGER trg_ServerLogon_AuditLogin ON ALL SERVER;
    PRINT 'Existing logon trigger dropped.';
END;
GO

-- Only create the trigger if we can impersonate 'sa' to do the write.
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'sa' AND type = 'S')
BEGIN
    EXEC('
    CREATE TRIGGER trg_ServerLogon_AuditLogin
    ON ALL SERVER
    WITH EXECUTE AS ''sa''
    FOR LOGON
    AS
    BEGIN
        SET NOCOUNT ON;

        BEGIN TRY
            DECLARE @LoginName NVARCHAR(100) = ORIGINAL_LOGIN();

            -- Only log principals the EMS knows about; everything else is
            -- ignored so this trigger stays cheap and quiet.
            IF EXISTS (
                SELECT 1
                FROM GreenAcresEMS.dbo.SystemUsers
                WHERE LoginName = @LoginName
            )
            BEGIN
                INSERT INTO GreenAcresEMS.dbo.UserLoginLog
                    (SystemUserID, LoginName, LoginTime, IsSuccessful,
                     IPAddress, HostName, FailureReason)
                SELECT
                    su.SystemUserID,
                    @LoginName,
                    GETDATE(),
                    1,                       -- a logon trigger only fires on success
                    CONVERT(NVARCHAR(50), CONNECTIONPROPERTY(''client_net_address'')),
                    HOST_NAME(),
                    NULL
                FROM GreenAcresEMS.dbo.SystemUsers su
                WHERE su.LoginName = @LoginName;
            END;
        END TRY
        BEGIN CATCH
            -- Swallowed on purpose: never block a login because auditing
            -- failed, and never while GreenAcresEMS is offline.
            DECLARE @Ignored NVARCHAR(4000) = ERROR_MESSAGE();
        END CATCH;
    END;
    ');
    PRINT 'Logon trigger trg_ServerLogon_AuditLogin created.';
END
ELSE
BEGIN
    PRINT 'WARNING: login ''sa'' not found - logon trigger NOT created.';
    PRINT 'Application logins are still recorded by usp_VerifySystemUserPassword,';
    PRINT 'and failed server logins are still captured by the Server Audit.';
END;
GO

USE GreenAcresEMS;
GO

-- vw_ServerLoginAudit: Reads the FAILED and SUCCESSFUL login events straight
-- out of the audit files.
CREATE OR ALTER VIEW dbo.vw_ServerLoginAudit
AS
    SELECT TOP 1000
        event_time                  AS EventTime,
        action_id                   AS ActionID,
        succeeded                   AS Succeeded,
        server_principal_name       AS LoginName,
        client_ip                   AS ClientIP,
        application_name            AS ApplicationName,
        host_name                   AS HostName,
        statement                   AS StatementText
    FROM sys.fn_get_audit_file('C:\SQLAudit\GA_EMS_ServerAudit*.sqlaudit', DEFAULT, DEFAULT)
    WHERE action_id IN ('LGIS', 'LGIF')   -- LGIS = login succeeded, LGIF = failed
    ORDER BY event_time DESC;
GO

-- vw_LoginHistory: The in-database login history, joined to the staff record
-- and department so the DBA can answer "who was connected, from where, and
-- when" without opening an audit file.
CREATE OR ALTER VIEW dbo.vw_LoginHistory
AS
    SELECT
        ull.LogID,
        ull.LoginName,
        su.FullName,
        d.DepartmentName,
        su.UserRole,
        ull.LoginTime,
        ull.LogoutTime,
        DATEDIFF(MINUTE, ull.LoginTime, ISNULL(ull.LogoutTime, GETDATE()))
            AS SessionMinutes,
        ull.IsSuccessful,
        ull.IPAddress,
        ull.HostName,
        ull.FailureReason
    FROM dbo.UserLoginLog AS ull
    LEFT JOIN dbo.SystemUsers AS su ON su.SystemUserID = ull.SystemUserID
    LEFT JOIN dbo.Departments AS d  ON d.DepartmentID  = su.DepartmentID;
GO

-- Login history is audit evidence: DBA and Admin may read it, the
-- developer/reporting roles may not (they could otherwise profile who works
-- when, and confirm which accounts exist).
GRANT SELECT ON dbo.vw_LoginHistory TO role_DBA;
GRANT SELECT ON dbo.vw_LoginHistory TO role_Admin;
GO

DENY SELECT ON dbo.UserLoginLog TO role_PropMgmtDev;
DENY SELECT ON dbo.UserLoginLog TO role_ClientPortalDev;
DENY SELECT ON dbo.UserLoginLog TO role_Analyst;
DENY SELECT ON dbo.UserLoginLog TO role_ReadOnly;
GO

GRANT SELECT ON dbo.UserLoginLog TO role_DBA;
GO

PRINT 'Login auditing wired up: logon trigger + UserLoginLog + reporting views.';
GO

PRINT 'Auditing setup completed. Triggers are created next, then run DML.sql.';
GO

-- PART 15: TRIGGERS - 8 AUDIT, 4 OPERATIONAL Green Acres Realty Sdn Bhd - EMS
-- Database Security Purpose: Create one set-based history trigger for each
-- important table.

USE GreenAcresEMS;
GO

IF OBJECT_ID('dbo.AuditLog', 'U') IS NULL
    THROW 50010, 'dbo.AuditLog is missing. Run this file from the top.', 1;
GO


/* ========================================================================
   REQUIREMENT 11: TRIGGER (AUDITING & OPERATIONAL)
   ======================================================================== */
CREATE OR ALTER TRIGGER dbo.trg_Clients_Audit
ON dbo.Clients
WITH EXECUTE AS OWNER
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             OldValues, NewValues, ApplicationName, HostName)
        SELECT
            'Clients', 'UPDATE', CONVERT(NVARCHAR(50), i.ClientID),
            ORIGINAL_LOGIN(),
            (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM inserted AS i
        INNER JOIN deleted AS d ON d.ClientID = i.ClientID;
    END
    ELSE IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             NewValues, ApplicationName, HostName)
        SELECT
            'Clients', 'INSERT', CONVERT(NVARCHAR(50), i.ClientID),
            ORIGINAL_LOGIN(),
            (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM inserted AS i;
    END
    ELSE
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             OldValues, ApplicationName, HostName)
        SELECT
            'Clients', 'DELETE', CONVERT(NVARCHAR(50), d.ClientID),
            ORIGINAL_LOGIN(),
            (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM deleted AS d;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_Agents_Audit
ON dbo.Agents
WITH EXECUTE AS OWNER
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             OldValues, NewValues, ApplicationName, HostName)
        SELECT
            'Agents', 'UPDATE', CONVERT(NVARCHAR(50), i.AgentID),
            ORIGINAL_LOGIN(),
            (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM inserted AS i
        INNER JOIN deleted AS d ON d.AgentID = i.AgentID;
    END
    ELSE IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             NewValues, ApplicationName, HostName)
        SELECT
            'Agents', 'INSERT', CONVERT(NVARCHAR(50), i.AgentID),
            ORIGINAL_LOGIN(),
            (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM inserted AS i;
    END
    ELSE
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             OldValues, ApplicationName, HostName)
        SELECT
            'Agents', 'DELETE', CONVERT(NVARCHAR(50), d.AgentID),
            ORIGINAL_LOGIN(),
            (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM deleted AS d;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_Transactions_Audit
ON dbo.Transactions
WITH EXECUTE AS OWNER
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             OldValues, NewValues, ApplicationName, HostName)
        SELECT
            'Transactions', 'UPDATE',
            CONVERT(NVARCHAR(50), i.TransactionID), ORIGINAL_LOGIN(),
            (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM inserted AS i
        INNER JOIN deleted AS d ON d.TransactionID = i.TransactionID;
    END
    ELSE IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             NewValues, ApplicationName, HostName)
        SELECT
            'Transactions', 'INSERT',
            CONVERT(NVARCHAR(50), i.TransactionID), ORIGINAL_LOGIN(),
            (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM inserted AS i;
    END
    ELSE
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             OldValues, ApplicationName, HostName)
        SELECT
            'Transactions', 'DELETE',
            CONVERT(NVARCHAR(50), d.TransactionID), ORIGINAL_LOGIN(),
            (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM deleted AS d;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_LeaseAgreements_Audit
ON dbo.LeaseAgreements
WITH EXECUTE AS OWNER
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             OldValues, NewValues, ApplicationName, HostName)
        SELECT
            'LeaseAgreements', 'UPDATE',
            CONVERT(NVARCHAR(50), i.LeaseID), ORIGINAL_LOGIN(),
            (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM inserted AS i
        INNER JOIN deleted AS d ON d.LeaseID = i.LeaseID;
    END
    ELSE IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             NewValues, ApplicationName, HostName)
        SELECT
            'LeaseAgreements', 'INSERT',
            CONVERT(NVARCHAR(50), i.LeaseID), ORIGINAL_LOGIN(),
            (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM inserted AS i;
    END
    ELSE
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             OldValues, ApplicationName, HostName)
        SELECT
            'LeaseAgreements', 'DELETE',
            CONVERT(NVARCHAR(50), d.LeaseID), ORIGINAL_LOGIN(),
            (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM deleted AS d;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_CommissionPayments_Audit
ON dbo.CommissionPayments
WITH EXECUTE AS OWNER
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             OldValues, NewValues, ApplicationName, HostName)
        SELECT
            'CommissionPayments', 'UPDATE',
            CONVERT(NVARCHAR(50), i.CommissionID), ORIGINAL_LOGIN(),
            (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM inserted AS i
        INNER JOIN deleted AS d ON d.CommissionID = i.CommissionID;
    END
    ELSE IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             NewValues, ApplicationName, HostName)
        SELECT
            'CommissionPayments', 'INSERT',
            CONVERT(NVARCHAR(50), i.CommissionID), ORIGINAL_LOGIN(),
            (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM inserted AS i;
    END
    ELSE
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             OldValues, ApplicationName, HostName)
        SELECT
            'CommissionPayments', 'DELETE',
            CONVERT(NVARCHAR(50), d.CommissionID), ORIGINAL_LOGIN(),
            (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM deleted AS d;
    END;
END;
GO

-- Columns are listed one by one on purpose: every credential column
-- (PasswordHashSecure, PasswordSaltSecure, PasswordHashAlgorithm) is
-- deliberately excluded so hashes and salts never reach dbo.AuditLog.
CREATE OR ALTER TRIGGER dbo.trg_SystemUsers_Audit
ON dbo.SystemUsers
WITH EXECUTE AS OWNER
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             OldValues, NewValues, ApplicationName, HostName)
        SELECT
            'SystemUsers', 'UPDATE',
            CONVERT(NVARCHAR(50), i.SystemUserID), ORIGINAL_LOGIN(),
            (
                SELECT d.SystemUserID, d.DepartmentID, d.FullName,
                       d.LoginName, d.Email, d.UserRole, d.IsActive,
                       d.CreatedDate
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ),
            (
                SELECT i.SystemUserID, i.DepartmentID, i.FullName,
                       i.LoginName, i.Email, i.UserRole, i.IsActive,
                       i.CreatedDate
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ),
            APP_NAME(), HOST_NAME()
        FROM inserted AS i
        INNER JOIN deleted AS d ON d.SystemUserID = i.SystemUserID;
    END
    ELSE IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             NewValues, ApplicationName, HostName)
        SELECT
            'SystemUsers', 'INSERT',
            CONVERT(NVARCHAR(50), i.SystemUserID), ORIGINAL_LOGIN(),
            (
                SELECT i.SystemUserID, i.DepartmentID, i.FullName,
                       i.LoginName, i.Email, i.UserRole, i.IsActive,
                       i.CreatedDate
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ),
            APP_NAME(), HOST_NAME()
        FROM inserted AS i;
    END
    ELSE
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             OldValues, ApplicationName, HostName)
        SELECT
            'SystemUsers', 'DELETE',
            CONVERT(NVARCHAR(50), d.SystemUserID), ORIGINAL_LOGIN(),
            (
                SELECT d.SystemUserID, d.DepartmentID, d.FullName,
                       d.LoginName, d.Email, d.UserRole, d.IsActive,
                       d.CreatedDate
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ),
            APP_NAME(), HOST_NAME()
        FROM deleted AS d;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_MaintenanceRequests_Audit
ON dbo.MaintenanceRequests
WITH EXECUTE AS OWNER
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             OldValues, NewValues, ApplicationName, HostName)
        SELECT
            'MaintenanceRequests', 'UPDATE',
            CONVERT(NVARCHAR(50), i.RequestID), ORIGINAL_LOGIN(),
            (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM inserted AS i
        INNER JOIN deleted AS d ON d.RequestID = i.RequestID;
    END
    ELSE IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             NewValues, ApplicationName, HostName)
        SELECT
            'MaintenanceRequests', 'INSERT',
            CONVERT(NVARCHAR(50), i.RequestID), ORIGINAL_LOGIN(),
            (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM inserted AS i;
    END
    ELSE
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             OldValues, ApplicationName, HostName)
        SELECT
            'MaintenanceRequests', 'DELETE',
            CONVERT(NVARCHAR(50), d.RequestID), ORIGINAL_LOGIN(),
            (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM deleted AS d;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_Properties_Audit
ON dbo.Properties
WITH EXECUTE AS OWNER
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             OldValues, NewValues, ApplicationName, HostName)
        SELECT
            'Properties', 'UPDATE',
            CONVERT(NVARCHAR(50), i.PropertyID), ORIGINAL_LOGIN(),
            (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM inserted AS i
        INNER JOIN deleted AS d ON d.PropertyID = i.PropertyID;
    END
    ELSE IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             NewValues, ApplicationName, HostName)
        SELECT
            'Properties', 'INSERT',
            CONVERT(NVARCHAR(50), i.PropertyID), ORIGINAL_LOGIN(),
            (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM inserted AS i;
    END
    ELSE
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             OldValues, ApplicationName, HostName)
        SELECT
            'Properties', 'DELETE',
            CONVERT(NVARCHAR(50), d.PropertyID), ORIGINAL_LOGIN(),
            (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM deleted AS d;
    END;
END;
GO

-- >>> MOVED TO DML.sql: Trigger inventory verification query

PRINT 'Eight row-history audit triggers created successfully.';
GO


-- B1. New Transaction -> Property.Status: 'Sale' becomes Sold, 'Rent' becomes
--     Rented, so no dev team has to remember to do it in application code.
CREATE OR ALTER TRIGGER trg_Transactions_UpdatePropertyStatus
ON dbo.Transactions
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE p
    SET p.Status = CASE i.TransactionType
                        WHEN 'Sale' THEN 'Sold'
                        WHEN 'Rent' THEN 'Rented'
                        ELSE p.Status
                   END
    FROM dbo.Properties p
    JOIN inserted i ON i.PropertyID = p.PropertyID
    WHERE i.TransactionType IN ('Sale', 'Rent');
END;
GO

-- B2. New Transaction -> auto-generate its CommissionPayments row, snapshotting
--     the agent's current CommissionRate at the time of the sale.
CREATE OR ALTER TRIGGER trg_Transactions_AutoCommission
ON dbo.Transactions
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.CommissionPayments (TransactionID, AgentID, CommissionRate, CommissionAmount, PaymentStatus, Remarks)
    SELECT i.TransactionID,
           i.AgentID,
           a.CommissionRate,
           ROUND(i.Amount * a.CommissionRate / 100.0, 2),
           'Unpaid',
           'Auto-generated by trg_Transactions_AutoCommission'
    FROM inserted i
    JOIN dbo.Agents a ON a.AgentID = i.AgentID
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.CommissionPayments cp WHERE cp.TransactionID = i.TransactionID
    );
END;
GO

-- B3. Lease Expired/Terminated -> free up the Property (only if no other Active
--     lease holds it) and notify the client.
CREATE OR ALTER TRIGGER trg_LeaseAgreements_StatusChange
ON dbo.LeaseAgreements
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT UPDATE(LeaseStatus)
        RETURN;

    -- Free up the property when a lease ends, unless another active lease is
    -- still keeping it occupied.
    UPDATE p
    SET p.Status = 'Available'
    FROM dbo.Properties p
    JOIN inserted i ON i.PropertyID = p.PropertyID
    JOIN deleted d ON d.LeaseID = i.LeaseID
    WHERE i.LeaseStatus IN ('Expired', 'Terminated')
      AND d.LeaseStatus <> i.LeaseStatus
      AND p.Status <> 'Sold'
      AND NOT EXISTS (
            SELECT 1 FROM dbo.LeaseAgreements la
            WHERE la.PropertyID = p.PropertyID
              AND la.LeaseStatus = 'Active'
              AND la.LeaseID <> i.LeaseID
      );

    -- Notify the client their lease has ended.
    INSERT INTO dbo.Notifications (RecipientType, RecipientID, Subject, MessageBody, Channel, RelatedTable, RelatedRecordID)
    SELECT 'Client', i.ClientID,
           'Lease ' + i.LeaseStatus,
           'Your lease agreement (LeaseID ' + CAST(i.LeaseID AS NVARCHAR(20)) + ') is now ' + i.LeaseStatus + '.',
           'Email', 'LeaseAgreements', i.LeaseID
    FROM inserted i
    JOIN deleted d ON d.LeaseID = i.LeaseID
    WHERE i.LeaseStatus IN ('Expired', 'Terminated')
      AND d.LeaseStatus <> i.LeaseStatus;
END;
GO

-- B4. Maintenance request Completed -> stamp CompletedDate and notify the
--     client; direct recursion is off by default, so the self-UPDATE is safe.
CREATE OR ALTER TRIGGER trg_MaintenanceRequests_AutoComplete
ON dbo.MaintenanceRequests
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT UPDATE(Status)
        RETURN;

    UPDATE mr
    SET mr.CompletedDate = GETDATE()
    FROM dbo.MaintenanceRequests mr
    JOIN inserted i ON i.RequestID = mr.RequestID
    WHERE i.Status = 'Completed'
      AND mr.CompletedDate IS NULL;

    INSERT INTO dbo.Notifications (RecipientType, RecipientID, Subject, MessageBody, Channel, RelatedTable, RelatedRecordID)
    SELECT 'Client', i.RequestedByClientID,
           'Maintenance Request Completed',
           'Your maintenance request (RequestID ' + CAST(i.RequestID AS NVARCHAR(20)) + ') has been completed.',
           'Email', 'MaintenanceRequests', i.RequestID
    FROM inserted i
    JOIN deleted d ON d.RequestID = i.RequestID
    WHERE i.Status = 'Completed'
      AND d.Status <> 'Completed'
      AND i.RequestedByClientID IS NOT NULL;
END;
GO

PRINT 'All triggers (auditing + operational) created successfully.';
GO

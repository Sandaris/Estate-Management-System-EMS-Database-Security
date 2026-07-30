-- ============================================================
-- 08_auditing.sql
-- Green Acres Realty Sdn Bhd - EMS Database Security
-- CT069-3-3 Database Security Assignment
--
-- Purpose:
--   1. Create the central AuditLog table if it does not exist.
--   2. Create an archive and controlled retention procedure for history.
--   3. Protect audit evidence from normal developer roles.
--   4. Create SQL Server Audit objects for security events.
--   5. Create a Database Audit Specification for GreenAcresEMS.
--
-- Beginner note:
--   Run this AFTER the database, tables, roles, users and permissions
--   have been created.
--
-- Important:
--   Before running this script, create this Windows folder manually:
--       C:\SQLAudit\
--   SQL Server must have permission to write into that folder.
--   If CREATE SERVER AUDIT fails, run SSMS as administrator or ask
--   your lecturer/lab admin for sysadmin permission.
-- ============================================================

USE GreenAcresEMS;
GO

-- ============================================================
-- A. Central table audit log
-- ============================================================
IF OBJECT_ID('dbo.AuditLog', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.AuditLog (
        AuditID         INT IDENTITY(1,1) PRIMARY KEY,
        EventTime       DATETIME NOT NULL DEFAULT GETDATE(),
        TableName       NVARCHAR(128) NOT NULL,
        OperationType   NVARCHAR(10) NOT NULL
            CONSTRAINT CK_Audit_Op CHECK (OperationType IN ('INSERT','UPDATE','DELETE')),
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
-- Normal developer roles should not be able to change or delete audit evidence.
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

-- ============================================================
-- B. Server-level SQL Server Audit
-- ============================================================
USE GreenAcresEMS;
GO

-- Drop the database audit specification first if this script is re-run.
-- SQL Server will not allow the server audit to be dropped while a database
-- audit specification is still using it.
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

-- ============================================================
-- C. Database-level SQL Server Audit
-- ============================================================
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

-- ============================================================
-- D. Quick status check for screenshot evidence
-- ============================================================
SELECT
    name AS ServerAuditName,
    is_state_enabled AS IsEnabled,
    type_desc AS AuditTarget
FROM sys.server_audits
WHERE name = 'GA_EMS_ServerAudit';
GO

SELECT
    name AS DatabaseAuditSpecification,
    is_state_enabled AS IsEnabled
FROM sys.database_audit_specifications
WHERE name = 'GA_EMS_DatabaseAuditSpec';
GO

PRINT 'Auditing setup completed. Next: run the trigger script and auditing_testcases.sql.';
GO

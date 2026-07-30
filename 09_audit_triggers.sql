-- ============================================================
-- 09_audit_triggers.sql
-- Green Acres Realty Sdn Bhd - EMS Database Security
--
-- Purpose:
--   Create one set-based history trigger for each important table.
--   Every changed row produces one AuditLog row containing the
--   original login, time, application, host and before/after JSON.
--
-- Run after:
--   1. Compiled SQL file.sql
--   2. 08_auditing.sql
--
-- Security note:
--   The SystemUsers trigger intentionally excludes PasswordHash and
--   PasswordSalt. Credential material must not be copied into logs.
-- ============================================================

USE GreenAcresEMS;
GO

IF OBJECT_ID('dbo.AuditLog', 'U') IS NULL
    THROW 50010, 'dbo.AuditLog is missing. Run 08_auditing.sql first.', 1;
GO

-- ============================================================
-- 1. Clients
-- ============================================================
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

-- ============================================================
-- 2. Agents
-- ============================================================
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

-- ============================================================
-- 3. Transactions
-- ============================================================
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

-- ============================================================
-- 4. LeaseAgreements
-- ============================================================
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

-- ============================================================
-- 5. CommissionPayments
-- ============================================================
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

-- ============================================================
-- 6. SystemUsers
-- PasswordHash and PasswordSalt are deliberately excluded.
-- ============================================================
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

-- ============================================================
-- 7. MaintenanceRequests
-- ============================================================
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

-- ============================================================
-- 8. Properties
-- ============================================================
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

SELECT
    tr.name AS TriggerName,
    OBJECT_SCHEMA_NAME(tr.parent_id) AS TableSchema,
    OBJECT_NAME(tr.parent_id) AS TableName,
    CASE WHEN tr.is_disabled = 0 THEN 'Enabled' ELSE 'Disabled' END AS Status
FROM sys.triggers AS tr
WHERE tr.name IN (
    'trg_Clients_Audit',
    'trg_Agents_Audit',
    'trg_Transactions_Audit',
    'trg_LeaseAgreements_Audit',
    'trg_CommissionPayments_Audit',
    'trg_SystemUsers_Audit',
    'trg_MaintenanceRequests_Audit',
    'trg_Properties_Audit'
)
ORDER BY TableName;
GO

PRINT 'Eight row-history audit triggers created successfully.';
GO

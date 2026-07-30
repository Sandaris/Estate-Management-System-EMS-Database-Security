-- ============================================================
-- 00_BEGINNER_COPY_PASTE_FULL_SETUP.sql
-- Green Acres Realty Sdn Bhd - EMS Database Security Assignment
--
-- How to use:
--   1. Open this file in SQL Server Management Studio.
--   2. Press Execute.
--   3. Read the Messages tab.
--   4. Take screenshots from the result grids near the bottom.
--
-- Important beginner rule:
--   Lines starting with -- are comments. SQL Server ignores them.
--   Everything else is SQL code.
--
-- Scope warning:
--   This is a reduced teaching/demo database with fewer tables,
--   triggers and different role names. It does not implement the full
--   audit matrix in section_4_auditing_report.md. For final assignment
--   evidence, use:
--     Compiled SQL file.sql
--     08_auditing.sql
--     09_audit_triggers.sql
--     auditing_testcases.sql
-- ============================================================

-- ============================================================
-- 1. CREATE DATABASE
-- ============================================================
USE master;
GO

IF DB_ID('GreenAcresEMS') IS NULL
BEGIN
    CREATE DATABASE GreenAcresEMS;
END;
GO

USE GreenAcresEMS;
GO

-- ============================================================
-- Clean old objects so this practice script can be re-run.
-- If this is your final group database with important work,
-- do not run this script without backing up first.
-- ============================================================
DROP TRIGGER IF EXISTS dbo.trg_Clients_Audit;
DROP TRIGGER IF EXISTS dbo.trg_Properties_Audit;
DROP TRIGGER IF EXISTS dbo.trg_Transactions_Audit;
DROP TRIGGER IF EXISTS dbo.trg_MaintenanceRequests_Audit;
DROP TRIGGER IF EXISTS dbo.trg_Transactions_UpdatePropertyStatus;
DROP TRIGGER IF EXISTS dbo.trg_MaintenanceRequests_AutoComplete;
GO

DROP PROCEDURE IF EXISTS dbo.usp_RegisterClient;
DROP PROCEDURE IF EXISTS dbo.usp_AddProperty;
DROP PROCEDURE IF EXISTS dbo.usp_CreateTransaction;
DROP PROCEDURE IF EXISTS dbo.usp_SubmitMaintenanceRequest;
DROP PROCEDURE IF EXISTS dbo.usp_UpdateMaintenanceStatus;
GO

DROP VIEW IF EXISTS dbo.vw_PropertySummary;
DROP VIEW IF EXISTS dbo.vw_ClientMaskedInfo;
DROP VIEW IF EXISTS dbo.vw_TransactionAnalytics;
DROP VIEW IF EXISTS dbo.vw_MaintenanceStatus;
GO

DROP TABLE IF EXISTS dbo.AuditLog;
DROP TABLE IF EXISTS dbo.MaintenanceRequests;
DROP TABLE IF EXISTS dbo.Transactions;
DROP TABLE IF EXISTS dbo.SystemUsers;
DROP TABLE IF EXISTS dbo.Agents;
DROP TABLE IF EXISTS dbo.Clients;
DROP TABLE IF EXISTS dbo.Properties;
GO

IF EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = 'GreenAcresSymmetricKey')
    DROP SYMMETRIC KEY GreenAcresSymmetricKey;
GO

IF EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'GreenAcresCertificate')
    DROP CERTIFICATE GreenAcresCertificate;
GO

DROP USER IF EXISTS AdminUser;
DROP USER IF EXISTS PropertyDeveloper;
DROP USER IF EXISTS ClientPortalDeveloper;
DROP USER IF EXISTS AnalyticsDeveloper;
DROP USER IF EXISTS AuditOfficer;
GO

DROP ROLE IF EXISTS role_Admin;
DROP ROLE IF EXISTS role_PropertyManagement;
DROP ROLE IF EXISTS role_ClientPortal;
DROP ROLE IF EXISTS role_Analytics;
DROP ROLE IF EXISTS role_AuditOfficer;
GO

-- ============================================================
-- 2. CREATE TABLES
-- ============================================================
CREATE TABLE dbo.Properties (
    PropertyID INT IDENTITY(1,1) PRIMARY KEY,
    PropertyName NVARCHAR(150) NOT NULL,
    Address NVARCHAR(255) NOT NULL,
    City NVARCHAR(100) NOT NULL,
    State NVARCHAR(100) NOT NULL,
    Price DECIMAL(18,2) NOT NULL,
    Status NVARCHAR(50) NOT NULL DEFAULT 'Available',
    CreatedDate DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT CK_Properties_Status CHECK (Status IN ('Available','Sold','Rented','Under Maintenance','Reserved'))
);
GO

CREATE TABLE dbo.Clients (
    ClientID INT IDENTITY(1,1) PRIMARY KEY,
    FullName NVARCHAR(100) NOT NULL,
    NRIC NVARCHAR(20) NULL,
    ContactNumber NVARCHAR(20) NOT NULL,
    Email NVARCHAR(100) NOT NULL,
    Address NVARCHAR(255) NULL,
    RegisteredDate DATETIME NOT NULL DEFAULT GETDATE()
);
GO

CREATE TABLE dbo.Agents (
    AgentID INT IDENTITY(1,1) PRIMARY KEY,
    FullName NVARCHAR(100) NOT NULL,
    ContactNumber NVARCHAR(20) NOT NULL,
    Email NVARCHAR(100) NOT NULL,
    CommissionRate DECIMAL(5,2) NOT NULL,
    JoinedDate DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT CK_Agents_CommissionRate CHECK (CommissionRate BETWEEN 0 AND 100)
);
GO

CREATE TABLE dbo.Transactions (
    TransactionID INT IDENTITY(1,1) PRIMARY KEY,
    PropertyID INT NOT NULL,
    ClientID INT NOT NULL,
    AgentID INT NOT NULL,
    TransactionType NVARCHAR(50) NOT NULL,
    TransactionDate DATETIME NOT NULL DEFAULT GETDATE(),
    Amount DECIMAL(18,2) NOT NULL,
    CONSTRAINT FK_Transactions_Properties FOREIGN KEY (PropertyID) REFERENCES dbo.Properties(PropertyID),
    CONSTRAINT FK_Transactions_Clients FOREIGN KEY (ClientID) REFERENCES dbo.Clients(ClientID),
    CONSTRAINT FK_Transactions_Agents FOREIGN KEY (AgentID) REFERENCES dbo.Agents(AgentID),
    CONSTRAINT CK_Transactions_Type CHECK (TransactionType IN ('Sale','Rent'))
);
GO

CREATE TABLE dbo.MaintenanceRequests (
    RequestID INT IDENTITY(1,1) PRIMARY KEY,
    PropertyID INT NOT NULL,
    RequestedByClientID INT NULL,
    RequestDetails NVARCHAR(MAX) NOT NULL,
    RequestDate DATETIME NOT NULL DEFAULT GETDATE(),
    Status NVARCHAR(50) NOT NULL DEFAULT 'Pending',
    CompletedDate DATETIME NULL,
    CONSTRAINT FK_Maintenance_Properties FOREIGN KEY (PropertyID) REFERENCES dbo.Properties(PropertyID),
    CONSTRAINT FK_Maintenance_Clients FOREIGN KEY (RequestedByClientID) REFERENCES dbo.Clients(ClientID),
    CONSTRAINT CK_Maintenance_Status CHECK (Status IN ('Pending','In Progress','Completed','Cancelled'))
);
GO

CREATE TABLE dbo.SystemUsers (
    SystemUserID INT IDENTITY(1,1) PRIMARY KEY,
    LoginName NVARCHAR(100) NOT NULL UNIQUE,
    FullName NVARCHAR(100) NOT NULL,
    UserRole NVARCHAR(50) NOT NULL,
    PasswordSalt NVARCHAR(50) NOT NULL,
    PasswordHash VARBINARY(32) NOT NULL,
    CreatedDate DATETIME NOT NULL DEFAULT GETDATE()
);
GO

-- ============================================================
-- 3. INSERT SAMPLE DATA
-- ============================================================
INSERT INTO dbo.Properties (PropertyName, Address, City, State, Price, Status)
VALUES
('Seri Mutiara Residence', 'No. 12, Jalan Ampang Indah', 'Kuala Lumpur', 'Kuala Lumpur', 980000.00, 'Available'),
('Cyber Heights Condo', 'Unit A-18-03, Persiaran Multimedia', 'Cyberjaya', 'Selangor', 620000.00, 'Available'),
('Sunway Business Hub', 'Lot 22, Bandar Sunway', 'Subang Jaya', 'Selangor', 2500000.00, 'Reserved');
GO

INSERT INTO dbo.Clients (FullName, NRIC, ContactNumber, Email, Address)
VALUES
('Ali Rahman', '990101-14-5555', '0123456789', 'ali.rahman@example.com', 'Kuala Lumpur'),
('Siti Tan', '000202-10-7777', '0133334444', 'siti.tan@example.com', 'Selangor'),
('David Lee', '980303-08-9999', '0168889999', 'david.lee@example.com', 'Penang');
GO

INSERT INTO dbo.Agents (FullName, ContactNumber, Email, CommissionRate)
VALUES
('Farah Lim', '0111112222', 'farah.lim@greenacres.com', 2.50),
('Kumar Raj', '0122223333', 'kumar.raj@greenacres.com', 3.00);
GO

INSERT INTO dbo.Transactions (PropertyID, ClientID, AgentID, TransactionType, Amount)
VALUES
(1, 1, 1, 'Sale', 980000.00),
(2, 2, 2, 'Rent', 2500.00);
GO

INSERT INTO dbo.MaintenanceRequests (PropertyID, RequestedByClientID, RequestDetails, Status)
VALUES
(2, 2, 'Air conditioner leaking in bedroom.', 'Pending'),
(3, NULL, 'Lobby lighting needs replacement.', 'In Progress');
GO

INSERT INTO dbo.SystemUsers (LoginName, FullName, UserRole, PasswordSalt, PasswordHash)
VALUES
('admin.user', 'Admin User', 'Admin', 'SaltA1', HASHBYTES('SHA2_256', CONCAT('Admin@123', 'SaltA1'))),
('property.dev', 'Property Developer', 'PropertyManagement', 'SaltB2', HASHBYTES('SHA2_256', CONCAT('Property@123', 'SaltB2'))),
('client.dev', 'Client Portal Developer', 'ClientPortal', 'SaltC3', HASHBYTES('SHA2_256', CONCAT('Client@123', 'SaltC3'))),
('analytics.dev', 'Analytics Developer', 'Analytics', 'SaltD4', HASHBYTES('SHA2_256', CONCAT('Analytics@123', 'SaltD4'))),
('audit.officer', 'Audit Officer', 'AuditOfficer', 'SaltE5', HASHBYTES('SHA2_256', CONCAT('Audit@123', 'SaltE5')));
GO

-- ============================================================
-- 4. CREATE VIEWS
-- ============================================================
CREATE VIEW dbo.vw_PropertySummary
AS
SELECT PropertyID, PropertyName, City, State, Price, Status
FROM dbo.Properties;
GO

CREATE VIEW dbo.vw_ClientMaskedInfo
AS
SELECT ClientID, FullName, ContactNumber, Email
FROM dbo.Clients;
GO

CREATE VIEW dbo.vw_TransactionAnalytics
AS
SELECT
    t.TransactionID,
    p.PropertyName,
    a.FullName AS AgentName,
    t.TransactionType,
    t.TransactionDate,
    t.Amount
FROM dbo.Transactions t
JOIN dbo.Properties p ON p.PropertyID = t.PropertyID
JOIN dbo.Agents a ON a.AgentID = t.AgentID;
GO

CREATE VIEW dbo.vw_MaintenanceStatus
AS
SELECT
    mr.RequestID,
    p.PropertyName,
    mr.RequestDetails,
    mr.Status,
    mr.RequestDate,
    mr.CompletedDate
FROM dbo.MaintenanceRequests mr
JOIN dbo.Properties p ON p.PropertyID = mr.PropertyID;
GO

-- ============================================================
-- 5. CREATE STORED PROCEDURES
-- ============================================================
CREATE PROCEDURE dbo.usp_RegisterClient
    @FullName NVARCHAR(100),
    @NRIC NVARCHAR(20),
    @ContactNumber NVARCHAR(20),
    @Email NVARCHAR(100),
    @Address NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.Clients (FullName, NRIC, ContactNumber, Email, Address)
    VALUES (@FullName, @NRIC, @ContactNumber, @Email, @Address);
END;
GO

CREATE PROCEDURE dbo.usp_AddProperty
    @PropertyName NVARCHAR(150),
    @Address NVARCHAR(255),
    @City NVARCHAR(100),
    @State NVARCHAR(100),
    @Price DECIMAL(18,2),
    @Status NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.Properties (PropertyName, Address, City, State, Price, Status)
    VALUES (@PropertyName, @Address, @City, @State, @Price, @Status);
END;
GO

CREATE PROCEDURE dbo.usp_CreateTransaction
    @PropertyID INT,
    @ClientID INT,
    @AgentID INT,
    @TransactionType NVARCHAR(50),
    @Amount DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.Transactions (PropertyID, ClientID, AgentID, TransactionType, Amount)
    VALUES (@PropertyID, @ClientID, @AgentID, @TransactionType, @Amount);
END;
GO

CREATE PROCEDURE dbo.usp_SubmitMaintenanceRequest
    @PropertyID INT,
    @RequestedByClientID INT,
    @RequestDetails NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.MaintenanceRequests (PropertyID, RequestedByClientID, RequestDetails)
    VALUES (@PropertyID, @RequestedByClientID, @RequestDetails);
END;
GO

CREATE PROCEDURE dbo.usp_UpdateMaintenanceStatus
    @RequestID INT,
    @Status NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.MaintenanceRequests
    SET Status = @Status
    WHERE RequestID = @RequestID;
END;
GO

-- ============================================================
-- 6. CREATE ROLES, USERS, PERMISSIONS
-- ============================================================
CREATE ROLE role_Admin;
CREATE ROLE role_PropertyManagement;
CREATE ROLE role_ClientPortal;
CREATE ROLE role_Analytics;
CREATE ROLE role_AuditOfficer;
GO

CREATE USER AdminUser WITHOUT LOGIN;
CREATE USER PropertyDeveloper WITHOUT LOGIN;
CREATE USER ClientPortalDeveloper WITHOUT LOGIN;
CREATE USER AnalyticsDeveloper WITHOUT LOGIN;
CREATE USER AuditOfficer WITHOUT LOGIN;
GO

ALTER ROLE role_Admin ADD MEMBER AdminUser;
ALTER ROLE role_PropertyManagement ADD MEMBER PropertyDeveloper;
ALTER ROLE role_ClientPortal ADD MEMBER ClientPortalDeveloper;
ALTER ROLE role_Analytics ADD MEMBER AnalyticsDeveloper;
ALTER ROLE role_AuditOfficer ADD MEMBER AuditOfficer;
GO

GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Properties TO role_Admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Clients TO role_Admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Agents TO role_Admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Transactions TO role_Admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.MaintenanceRequests TO role_Admin;
GO

GRANT SELECT ON dbo.vw_PropertySummary TO role_PropertyManagement;
GRANT EXECUTE ON dbo.usp_AddProperty TO role_PropertyManagement;
GRANT EXECUTE ON dbo.usp_SubmitMaintenanceRequest TO role_PropertyManagement;
GRANT EXECUTE ON dbo.usp_UpdateMaintenanceStatus TO role_PropertyManagement;
GO

GRANT SELECT ON dbo.vw_ClientMaskedInfo TO role_ClientPortal;
GRANT EXECUTE ON dbo.usp_RegisterClient TO role_ClientPortal;
GO

GRANT SELECT ON dbo.vw_ClientMaskedInfo TO role_Analytics;
GRANT SELECT ON dbo.vw_TransactionAnalytics TO role_Analytics;
GRANT SELECT ON dbo.vw_PropertySummary TO role_Analytics;
GO

-- Normal developer roles are not granted direct table access.
-- They can only use the views and stored procedures granted above.

-- ============================================================
-- 7. APPLY MASKING, HASHING, ENCRYPTION
-- ============================================================
ALTER TABLE dbo.Clients
ALTER COLUMN Email ADD MASKED WITH (FUNCTION = 'email()');
GO

ALTER TABLE dbo.Clients
ALTER COLUMN ContactNumber ADD MASKED WITH (FUNCTION = 'partial(3,"XXXX",2)');
GO

ALTER TABLE dbo.Clients
ALTER COLUMN NRIC ADD MASKED WITH (FUNCTION = 'partial(0,"XXXXXX",4)');
GO

-- Admin and AuditOfficer can see unmasked data.
GRANT UNMASK TO role_Admin;
GRANT UNMASK TO role_AuditOfficer;
GO

-- Hashing is already shown in SystemUsers.PasswordHash using HASHBYTES.
SELECT LoginName, FullName, UserRole, PasswordHash
FROM dbo.SystemUsers;
GO

-- Simple encryption demo for client NRIC.
IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'GreenAcres_MasterKey_2026!';
GO

CREATE CERTIFICATE GreenAcresCertificate
WITH SUBJECT = 'Green Acres EMS data protection certificate';
GO

CREATE SYMMETRIC KEY GreenAcresSymmetricKey
WITH ALGORITHM = AES_256
ENCRYPTION BY CERTIFICATE GreenAcresCertificate;
GO

ALTER TABLE dbo.Clients
ADD NRIC_Encrypted VARBINARY(MAX) NULL;
GO

OPEN SYMMETRIC KEY GreenAcresSymmetricKey
DECRYPTION BY CERTIFICATE GreenAcresCertificate;
GO

UPDATE dbo.Clients
SET NRIC_Encrypted = EncryptByKey(Key_GUID('GreenAcresSymmetricKey'), NRIC);
GO

CLOSE SYMMETRIC KEY GreenAcresSymmetricKey;
GO

-- ============================================================
-- 8. CREATE AUDIT TABLE
-- ============================================================
CREATE TABLE dbo.AuditLog (
    AuditID INT IDENTITY(1,1) PRIMARY KEY,
    EventTime DATETIME NOT NULL DEFAULT GETDATE(),
    TableName NVARCHAR(128) NOT NULL,
    OperationType NVARCHAR(10) NOT NULL,
    RecordID NVARCHAR(50) NOT NULL,
    ChangedBy NVARCHAR(100) NOT NULL DEFAULT ORIGINAL_LOGIN(),
    OldValues NVARCHAR(MAX) NULL,
    NewValues NVARCHAR(MAX) NULL,
    ApplicationName NVARCHAR(128) NULL,
    HostName NVARCHAR(128) NULL,
    CONSTRAINT CK_AuditLog_Operation CHECK (OperationType IN ('INSERT','UPDATE','DELETE'))
);
GO

GRANT SELECT ON dbo.AuditLog TO role_Admin;
GRANT SELECT ON dbo.AuditLog TO role_AuditOfficer;
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.AuditLog TO role_PropertyManagement;
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.AuditLog TO role_ClientPortal;
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.AuditLog TO role_Analytics;
GO

-- ============================================================
-- 9. CREATE AUDIT TRIGGERS
-- ============================================================
CREATE TRIGGER dbo.trg_Clients_Audit
ON dbo.Clients
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, OperationType, RecordID, ChangedBy, OldValues, NewValues, ApplicationName, HostName)
        SELECT 'Clients', 'UPDATE', CAST(i.ClientID AS NVARCHAR(50)), ORIGINAL_LOGIN(),
               (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               APP_NAME(), HOST_NAME()
        FROM inserted i
        JOIN deleted d ON d.ClientID = i.ClientID;
    END
    ELSE IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, OperationType, RecordID, ChangedBy, NewValues, ApplicationName, HostName)
        SELECT 'Clients', 'INSERT', CAST(i.ClientID AS NVARCHAR(50)), ORIGINAL_LOGIN(),
               (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               APP_NAME(), HOST_NAME()
        FROM inserted i;
    END
    ELSE
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, OperationType, RecordID, ChangedBy, OldValues, ApplicationName, HostName)
        SELECT 'Clients', 'DELETE', CAST(d.ClientID AS NVARCHAR(50)), ORIGINAL_LOGIN(),
               (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               APP_NAME(), HOST_NAME()
        FROM deleted d;
    END
END;
GO

CREATE TRIGGER dbo.trg_Properties_Audit
ON dbo.Properties
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, OperationType, RecordID, ChangedBy, OldValues, NewValues, ApplicationName, HostName)
        SELECT 'Properties', 'UPDATE', CAST(i.PropertyID AS NVARCHAR(50)), ORIGINAL_LOGIN(),
               (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               APP_NAME(), HOST_NAME()
        FROM inserted i
        JOIN deleted d ON d.PropertyID = i.PropertyID;
    END
    ELSE IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, OperationType, RecordID, ChangedBy, NewValues, ApplicationName, HostName)
        SELECT 'Properties', 'INSERT', CAST(i.PropertyID AS NVARCHAR(50)), ORIGINAL_LOGIN(),
               (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               APP_NAME(), HOST_NAME()
        FROM inserted i;
    END
    ELSE
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, OperationType, RecordID, ChangedBy, OldValues, ApplicationName, HostName)
        SELECT 'Properties', 'DELETE', CAST(d.PropertyID AS NVARCHAR(50)), ORIGINAL_LOGIN(),
               (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               APP_NAME(), HOST_NAME()
        FROM deleted d;
    END
END;
GO

CREATE TRIGGER dbo.trg_Transactions_Audit
ON dbo.Transactions
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, OperationType, RecordID, ChangedBy, OldValues, NewValues, ApplicationName, HostName)
        SELECT 'Transactions', 'UPDATE', CAST(i.TransactionID AS NVARCHAR(50)), ORIGINAL_LOGIN(),
               (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               APP_NAME(), HOST_NAME()
        FROM inserted i
        JOIN deleted d ON d.TransactionID = i.TransactionID;
    END
    ELSE IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, OperationType, RecordID, ChangedBy, NewValues, ApplicationName, HostName)
        SELECT 'Transactions', 'INSERT', CAST(i.TransactionID AS NVARCHAR(50)), ORIGINAL_LOGIN(),
               (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               APP_NAME(), HOST_NAME()
        FROM inserted i;
    END
    ELSE
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, OperationType, RecordID, ChangedBy, OldValues, ApplicationName, HostName)
        SELECT 'Transactions', 'DELETE', CAST(d.TransactionID AS NVARCHAR(50)), ORIGINAL_LOGIN(),
               (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               APP_NAME(), HOST_NAME()
        FROM deleted d;
    END
END;
GO

CREATE TRIGGER dbo.trg_MaintenanceRequests_Audit
ON dbo.MaintenanceRequests
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, OperationType, RecordID, ChangedBy, OldValues, NewValues, ApplicationName, HostName)
        SELECT 'MaintenanceRequests', 'UPDATE', CAST(i.RequestID AS NVARCHAR(50)), ORIGINAL_LOGIN(),
               (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               APP_NAME(), HOST_NAME()
        FROM inserted i
        JOIN deleted d ON d.RequestID = i.RequestID;
    END
    ELSE IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, OperationType, RecordID, ChangedBy, NewValues, ApplicationName, HostName)
        SELECT 'MaintenanceRequests', 'INSERT', CAST(i.RequestID AS NVARCHAR(50)), ORIGINAL_LOGIN(),
               (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               APP_NAME(), HOST_NAME()
        FROM inserted i;
    END
    ELSE
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, OperationType, RecordID, ChangedBy, OldValues, ApplicationName, HostName)
        SELECT 'MaintenanceRequests', 'DELETE', CAST(d.RequestID AS NVARCHAR(50)), ORIGINAL_LOGIN(),
               (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               APP_NAME(), HOST_NAME()
        FROM deleted d;
    END
END;
GO

-- Operational trigger 1: transaction automatically changes property status.
CREATE TRIGGER dbo.trg_Transactions_UpdatePropertyStatus
ON dbo.Transactions
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE p
    SET Status = CASE i.TransactionType
                    WHEN 'Sale' THEN 'Sold'
                    WHEN 'Rent' THEN 'Rented'
                    ELSE p.Status
                 END
    FROM dbo.Properties p
    JOIN inserted i ON i.PropertyID = p.PropertyID;
END;
GO

-- Operational trigger 2: completed maintenance request gets completion date.
CREATE TRIGGER dbo.trg_MaintenanceRequests_AutoComplete
ON dbo.MaintenanceRequests
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE mr
    SET CompletedDate = GETDATE()
    FROM dbo.MaintenanceRequests mr
    JOIN inserted i ON i.RequestID = mr.RequestID
    WHERE i.Status = 'Completed'
      AND mr.CompletedDate IS NULL;
END;
GO

-- ============================================================
-- 10. CREATE SQL SERVER AUDIT / DATABASE AUDIT
-- This part may fail if you do not have administrator permission.
-- If it fails, your trigger-based AuditLog still works.
--
-- Before running, create this Windows folder manually:
-- C:\SQLAudit\
-- ============================================================
USE GreenAcresEMS;
GO

BEGIN TRY
    IF EXISTS (SELECT 1 FROM sys.database_audit_specifications WHERE name = 'GA_EMS_DatabaseAuditSpec')
    BEGIN
        ALTER DATABASE AUDIT SPECIFICATION GA_EMS_DatabaseAuditSpec WITH (STATE = OFF);
        DROP DATABASE AUDIT SPECIFICATION GA_EMS_DatabaseAuditSpec;
    END;
END TRY
BEGIN CATCH
    PRINT 'Old database audit specification could not be dropped. Reason: ' + ERROR_MESSAGE();
END CATCH;
GO

USE master;
GO

BEGIN TRY
    IF EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'GA_EMS_ServerAuditSpec')
    BEGIN
        ALTER SERVER AUDIT SPECIFICATION GA_EMS_ServerAuditSpec WITH (STATE = OFF);
        DROP SERVER AUDIT SPECIFICATION GA_EMS_ServerAuditSpec;
    END;

    IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'GA_EMS_ServerAudit')
    BEGIN
        ALTER SERVER AUDIT GA_EMS_ServerAudit WITH (STATE = OFF);
        DROP SERVER AUDIT GA_EMS_ServerAudit;
    END;

    EXEC('CREATE SERVER AUDIT GA_EMS_ServerAudit
          TO FILE (FILEPATH = ''C:\SQLAudit\'', MAXSIZE = 20 MB, MAX_ROLLOVER_FILES = 5)
          WITH (QUEUE_DELAY = 1000, ON_FAILURE = CONTINUE);');

    EXEC('CREATE SERVER AUDIT SPECIFICATION GA_EMS_ServerAuditSpec
          FOR SERVER AUDIT GA_EMS_ServerAudit
          ADD (FAILED_LOGIN_GROUP),
          ADD (AUDIT_CHANGE_GROUP),
          ADD (SERVER_PERMISSION_CHANGE_GROUP),
          ADD (SERVER_ROLE_MEMBER_CHANGE_GROUP);');

    ALTER SERVER AUDIT GA_EMS_ServerAudit WITH (STATE = ON);
    ALTER SERVER AUDIT SPECIFICATION GA_EMS_ServerAuditSpec WITH (STATE = ON);

    PRINT 'Server audit created successfully.';
END TRY
BEGIN CATCH
    PRINT 'Server audit was skipped or failed. Reason: ' + ERROR_MESSAGE();
END CATCH;
GO

USE GreenAcresEMS;
GO

BEGIN TRY
    IF EXISTS (SELECT 1 FROM sys.database_audit_specifications WHERE name = 'GA_EMS_DatabaseAuditSpec')
    BEGIN
        ALTER DATABASE AUDIT SPECIFICATION GA_EMS_DatabaseAuditSpec WITH (STATE = OFF);
        DROP DATABASE AUDIT SPECIFICATION GA_EMS_DatabaseAuditSpec;
    END;

    EXEC('CREATE DATABASE AUDIT SPECIFICATION GA_EMS_DatabaseAuditSpec
          FOR SERVER AUDIT GA_EMS_ServerAudit
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
          ADD (SELECT ON OBJECT::dbo.AuditLog BY public);');

    ALTER DATABASE AUDIT SPECIFICATION GA_EMS_DatabaseAuditSpec WITH (STATE = ON);

    PRINT 'Database audit specification created successfully.';
END TRY
BEGIN CATCH
    PRINT 'Database audit specification was skipped or failed. Reason: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
-- 11. RUN TEST CASES
-- ============================================================
USE GreenAcresEMS;
GO

-- Test 1: confirm database exists.
SELECT DB_NAME() AS CurrentDatabase;
GO

-- Test 2: confirm tables exist.
SELECT name AS TableName
FROM sys.tables
ORDER BY name;
GO

-- Test 3: confirm roles and users exist.
SELECT r.name AS RoleName, m.name AS MemberName
FROM sys.database_role_members rm
JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
JOIN sys.database_principals m ON m.principal_id = rm.member_principal_id
WHERE r.name LIKE 'role_%'
ORDER BY r.name, m.name;
GO

-- Test 4: masked view works.
EXECUTE AS USER = 'AnalyticsDeveloper';
SELECT TOP 5 ClientID, FullName, ContactNumber, Email
FROM dbo.vw_ClientMaskedInfo;
REVERT;
GO

-- Test 5: permission denied example.
EXECUTE AS USER = 'AnalyticsDeveloper';
BEGIN TRY
    SELECT TOP 1 * FROM dbo.Clients;
    PRINT 'FAIL: AnalyticsDeveloper accessed Clients table directly.';
END TRY
BEGIN CATCH
    PRINT 'PASS: AnalyticsDeveloper cannot access Clients table directly.';
    PRINT ERROR_MESSAGE();
END CATCH;
REVERT;
GO

-- Test 6: audit trigger records UPDATE.
UPDATE dbo.Clients
SET Email = 'audit.test@example.com'
WHERE ClientID = 1;
GO

SELECT TOP 10
    AuditID,
    EventTime,
    TableName,
    OperationType,
    RecordID,
    ChangedBy,
    OldValues,
    NewValues
FROM dbo.AuditLog
ORDER BY AuditID DESC;
GO

-- Test 7: operational trigger changes property status.
EXEC dbo.usp_CreateTransaction
    @PropertyID = 3,
    @ClientID = 3,
    @AgentID = 1,
    @TransactionType = 'Sale',
    @Amount = 2500000.00;
GO

SELECT PropertyID, PropertyName, Status
FROM dbo.Properties
WHERE PropertyID = 3;
GO

-- Test 8: operational trigger sets CompletedDate.
EXEC dbo.usp_UpdateMaintenanceStatus
    @RequestID = 1,
    @Status = 'Completed';
GO

SELECT RequestID, Status, CompletedDate
FROM dbo.MaintenanceRequests
WHERE RequestID = 1;
GO

-- Test 9: encryption check.
OPEN SYMMETRIC KEY GreenAcresSymmetricKey
DECRYPTION BY CERTIFICATE GreenAcresCertificate;
GO

SELECT
    ClientID,
    FullName,
    NRIC,
    NRIC_Encrypted,
    CONVERT(NVARCHAR(20), DecryptByKey(NRIC_Encrypted)) AS DecryptedNRIC
FROM dbo.Clients;
GO

CLOSE SYMMETRIC KEY GreenAcresSymmetricKey;
GO

-- ============================================================
-- 12. SCREENSHOT EVIDENCE QUERIES FOR REPORT
-- ============================================================

-- Screenshot A: AuditLog table exists.
SELECT name AS TableName, create_date AS CreatedDate
FROM sys.tables
WHERE name = 'AuditLog';
GO

-- Screenshot B: Audit triggers exist and are enabled.
SELECT
    tr.name AS TriggerName,
    OBJECT_NAME(tr.parent_id) AS TableName,
    CASE WHEN tr.is_disabled = 0 THEN 'Enabled' ELSE 'Disabled' END AS TriggerStatus
FROM sys.triggers tr
WHERE tr.name LIKE 'trg_%_Audit'
ORDER BY TableName;
GO

-- Screenshot C: Latest audit history.
SELECT TOP 20
    AuditID,
    EventTime,
    TableName,
    OperationType,
    RecordID,
    ChangedBy,
    ApplicationName,
    HostName
FROM dbo.AuditLog
ORDER BY AuditID DESC;
GO

-- Screenshot D: Server audit status.
USE master;
GO

SELECT name AS ServerAuditName, is_state_enabled AS IsEnabled
FROM sys.server_audits
WHERE name = 'GA_EMS_ServerAudit';
GO

-- Screenshot E: Database audit status.
USE GreenAcresEMS;
GO

SELECT name AS DatabaseAuditSpecification, is_state_enabled AS IsEnabled
FROM sys.database_audit_specifications
WHERE name = 'GA_EMS_DatabaseAuditSpec';
GO

-- Screenshot F: Read audit file if SQL Server Audit was created.
BEGIN TRY
    SELECT TOP 50
        event_time,
        action_id,
        succeeded,
        server_principal_name,
        database_name,
        schema_name,
        object_name,
        statement
    FROM sys.fn_get_audit_file('C:\SQLAudit\*.sqlaudit', DEFAULT, DEFAULT)
    WHERE database_name = 'GreenAcresEMS'
    ORDER BY event_time DESC;
END TRY
BEGIN CATCH
    PRINT 'Cannot read SQL Server Audit file. Reason: ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT 'FULL BEGINNER SETUP SCRIPT COMPLETED.';
GO

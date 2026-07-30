-- ============================================================
-- auditing_testcases.sql
-- Green Acres Realty Sdn Bhd - EMS Database Security
-- CT069-3-3 Database Security Assignment
--
-- Purpose:
--   Screenshot-friendly test cases for Documentation Section 4.
--
-- Run order:
--   1. Main database script
--   2. 08_auditing.sql
--   3. 09_audit_triggers.sql
--   4. This file
--
-- Run this file using a sysadmin/DBA account because the tests inspect
-- SQL Server Audit files and temporarily create/drop a test principal.
-- ============================================================

USE GreenAcresEMS;
GO

-- ============================================================
-- TEST 1: AuditLog table exists
-- Expected: One row showing dbo.AuditLog.
-- Screenshot: result grid.
-- ============================================================
SELECT
    CASE
        WHEN OBJECT_ID('dbo.AuditLog', 'U') IS NOT NULL THEN 'PASS'
        ELSE 'FAIL'
    END AS TestResult,
    'dbo' AS SchemaName,
    'AuditLog' AS TableName,
    (
        SELECT create_date
        FROM sys.tables
        WHERE object_id = OBJECT_ID('dbo.AuditLog', 'U')
    ) AS CreatedDate;
GO

-- ============================================================
-- TEST 2: Audit triggers exist on important tables
-- Expected: 8 trigger rows, all enabled.
-- Screenshot: result grid.
-- ============================================================
SELECT
    tr.name AS TriggerName,
    OBJECT_NAME(tr.parent_id) AS TableName,
    CASE WHEN tr.is_disabled = 0 THEN 'Enabled' ELSE 'Disabled' END AS TriggerStatus
FROM sys.triggers tr
WHERE tr.name LIKE 'trg_%_Audit'
ORDER BY TableName, TriggerName;

SELECT
    COUNT(*) AS EnabledAuditTriggers,
    CASE WHEN COUNT(*) = 8 THEN 'PASS' ELSE 'FAIL' END AS TestResult
FROM sys.triggers
WHERE name LIKE 'trg_%_Audit'
  AND is_disabled = 0;
GO

-- ============================================================
-- TEST 3: UPDATE client data and prove AuditLog records it
-- Expected:
--   1. Client Email changes.
--   2. AuditLog shows one UPDATE row for Clients.
-- Screenshot:
--   Take one screenshot before UPDATE and one after AuditLog SELECT.
--   The original email is restored after evidence is displayed.
-- ============================================================
DECLARE @AuditClientID INT;
DECLARE @OriginalEmail NVARCHAR(100);
DECLARE @DemoEmail NVARCHAR(100);

SELECT TOP (1)
    @AuditClientID = ClientID,
    @OriginalEmail = Email
FROM dbo.Clients
ORDER BY ClientID;

IF @AuditClientID IS NULL
    THROW 50100, 'TEST 3 cannot run because dbo.Clients is empty.', 1;

SET @DemoEmail = CONCAT('audit.demo.', @AuditClientID, '@example.com');

SELECT
    @AuditClientID AS ClientID,
    @OriginalEmail AS EmailBefore,
    @DemoEmail AS EmailDuringTest;

UPDATE dbo.Clients
SET Email = @DemoEmail
WHERE ClientID = @AuditClientID;

SELECT TOP (1)
    'PASS' AS TestResult,
    AuditID,
    EventTime,
    TableName,
    OperationType,
    RecordID,
    ChangedBy,
    ApplicationName,
    HostName,
    OldValues,
    NewValues
FROM dbo.AuditLog
WHERE TableName = 'Clients'
  AND OperationType = 'UPDATE'
  AND RecordID = CONVERT(NVARCHAR(50), @AuditClientID)
ORDER BY AuditID DESC;

UPDATE dbo.Clients
SET Email = @OriginalEmail
WHERE ClientID = @AuditClientID;
GO

-- ============================================================
-- TEST 4: INSERT transaction and prove trigger audit works
-- Expected:
--   1. New transaction is inserted.
--   2. AuditLog shows INSERT for Transactions.
-- Note:
--   The test runs in a transaction and rolls back all business changes.
-- ============================================================
DECLARE @PropertyID INT =
    (SELECT TOP (1) PropertyID FROM dbo.Properties WHERE Status = 'Available' ORDER BY PropertyID);
DECLARE @ClientID INT =
    (SELECT TOP (1) ClientID FROM dbo.Clients ORDER BY ClientID);
DECLARE @AgentID INT =
    (SELECT TOP (1) AgentID FROM dbo.Agents ORDER BY AgentID);
DECLARE @TransactionID INT;

IF @PropertyID IS NULL OR @ClientID IS NULL OR @AgentID IS NULL
    THROW 50101, 'TEST 4 needs an available property, a client and an agent.', 1;

BEGIN TRANSACTION;

INSERT INTO dbo.Transactions
    (PropertyID, ClientID, AgentID, TransactionType, Amount, PaymentStatus, PaymentMethod)
VALUES
    (@PropertyID, @ClientID, @AgentID, 'Sale', 888000.00, 'Pending', 'Bank Transfer');

SET @TransactionID = SCOPE_IDENTITY();

SELECT TOP (1)
    'PASS' AS TestResult,
    AuditID,
    EventTime,
    TableName,
    OperationType,
    RecordID,
    ChangedBy,
    NewValues
FROM dbo.AuditLog
WHERE TableName = 'Transactions'
  AND OperationType = 'INSERT'
  AND RecordID = CONVERT(NVARCHAR(50), @TransactionID)
ORDER BY AuditID DESC;

ROLLBACK TRANSACTION;
GO

-- ============================================================
-- TEST 5: ReadOnly user cannot read AuditLog
-- Expected:
--   PASS message with permission denied.
-- Screenshot:
--   Messages tab.
-- ============================================================
IF USER_ID('jason.lim') IS NULL
BEGIN
    SELECT
        'NOT RUN' AS TestResult,
        'Database user jason.lim does not exist.' AS Details;
END
ELSE
BEGIN
    EXECUTE AS USER = 'jason.lim';
    BEGIN TRY
        SELECT TOP (1) * FROM dbo.AuditLog;
        SELECT
            'FAIL' AS TestResult,
            'ReadOnly user can read AuditLog.' AS Details;
    END TRY
    BEGIN CATCH
        SELECT
            'PASS' AS TestResult,
            ERROR_MESSAGE() AS Details;
    END CATCH;
    REVERT;
END;
GO

-- ============================================================
-- TEST 6: SQL Server Audit is enabled
-- Expected:
--   Server audit and database audit specification both show enabled.
-- Screenshot:
--   Result grids.
-- ============================================================
USE master;
GO

SELECT
    name AS ServerAuditName,
    is_state_enabled AS IsEnabled,
    CASE WHEN is_state_enabled = 1 THEN 'PASS' ELSE 'FAIL' END AS TestResult,
    type_desc AS AuditTarget
FROM sys.server_audits
WHERE name = 'GA_EMS_ServerAudit';
GO

SELECT
    name AS ServerAuditSpecification,
    is_state_enabled AS IsEnabled,
    CASE WHEN is_state_enabled = 1 THEN 'PASS' ELSE 'FAIL' END AS TestResult
FROM sys.server_audit_specifications
WHERE name = 'GA_EMS_ServerAuditSpec';
GO

USE GreenAcresEMS;
GO

SELECT
    name AS DatabaseAuditSpecification,
    is_state_enabled AS IsEnabled,
    CASE WHEN is_state_enabled = 1 THEN 'PASS' ELSE 'FAIL' END AS TestResult
FROM sys.database_audit_specifications
WHERE name = 'GA_EMS_DatabaseAuditSpec';
GO

-- ============================================================
-- TEST 7: Read SQL Server Audit file
-- Expected:
--   Audit rows appear after SELECT/UPDATE/permission tests.
-- If no rows appear immediately, wait a few seconds and run again.
-- Screenshot:
--   Result grid showing event_time, action_id, succeeded,
--   database_name, schema_name, object_name, statement.
-- ============================================================
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
GO

-- ============================================================
-- TEST 8: Audit specifications contain the required actions
-- Expected:
--   Result grids show login, principal, permission, role, schema,
--   sensitive-object and audit-evidence actions.
-- ============================================================
USE master;
GO

SELECT
    sas.name AS SpecificationName,
    sad.audit_action_name AS AuditedAction
FROM sys.server_audit_specifications AS sas
INNER JOIN sys.server_audit_specification_details AS sad
    ON sad.server_specification_id = sas.server_specification_id
WHERE sas.name = 'GA_EMS_ServerAuditSpec'
ORDER BY sad.audit_action_name;
GO

USE GreenAcresEMS;
GO

SELECT
    das.name AS SpecificationName,
    dad.audit_action_name AS AuditedAction,
    dad.class_desc AS SecurableClass,
    OBJECT_SCHEMA_NAME(dad.major_id) AS ObjectSchema,
    OBJECT_NAME(dad.major_id) AS ObjectName
FROM sys.database_audit_specifications AS das
INNER JOIN sys.database_audit_specification_details AS dad
    ON dad.database_specification_id = das.database_specification_id
WHERE das.name = 'GA_EMS_DatabaseAuditSpec'
ORDER BY dad.audit_action_name, ObjectName;
GO

-- ============================================================
-- TEST 9: Multi-row updates create one history row per changed row
-- Expected: RowsAffected = AuditRowsCreated and TestResult = PASS.
-- ============================================================
DECLARE @AuditCountBefore INT =
    (SELECT COUNT(*) FROM dbo.AuditLog
     WHERE TableName = 'Agents' AND OperationType = 'UPDATE');
DECLARE @ExpectedRows INT = (SELECT COUNT(*) FROM dbo.Agents);

UPDATE dbo.Agents
SET CommissionRate = CommissionRate;

DECLARE @AuditCountAfter INT =
    (SELECT COUNT(*) FROM dbo.AuditLog
     WHERE TableName = 'Agents' AND OperationType = 'UPDATE');
DECLARE @AuditRowsCreated INT = @AuditCountAfter - @AuditCountBefore;

SELECT
    @ExpectedRows AS RowsAffected,
    @AuditRowsCreated AS AuditRowsCreated,
    CASE
        WHEN @ExpectedRows = @AuditRowsCreated THEN 'PASS'
        ELSE 'FAIL'
    END AS TestResult;
GO

-- ============================================================
-- TEST 10: Generate permission, role, principal and schema events
-- The test objects are removed before the batch completes.
-- ============================================================
DROP TABLE IF EXISTS dbo.AuditMatrixTestTable;

IF USER_ID('AuditMatrixTestUser') IS NOT NULL
BEGIN
    IF IS_ROLEMEMBER('role_ReadOnly', 'AuditMatrixTestUser') = 1
        ALTER ROLE role_ReadOnly DROP MEMBER AuditMatrixTestUser;
    DROP USER AuditMatrixTestUser;
END;

CREATE USER AuditMatrixTestUser WITHOUT LOGIN;
GRANT SELECT ON dbo.Clients TO AuditMatrixTestUser;

IF DATABASE_PRINCIPAL_ID('role_ReadOnly') IS NOT NULL
BEGIN
    ALTER ROLE role_ReadOnly ADD MEMBER AuditMatrixTestUser;
    ALTER ROLE role_ReadOnly DROP MEMBER AuditMatrixTestUser;
END;

CREATE TABLE dbo.AuditMatrixTestTable (
    TestID INT NOT NULL PRIMARY KEY
);

DROP TABLE dbo.AuditMatrixTestTable;
REVOKE SELECT ON dbo.Clients FROM AuditMatrixTestUser;
DROP USER AuditMatrixTestUser;

WAITFOR DELAY '00:00:02';

SELECT TOP (50)
    event_time,
    action_id,
    succeeded,
    server_principal_name,
    database_principal_name,
    object_name,
    statement
FROM sys.fn_get_audit_file('C:\SQLAudit\*.sqlaudit', DEFAULT, DEFAULT)
WHERE database_name = 'GreenAcresEMS'
  AND (
      statement LIKE '%AuditMatrixTest%'
      OR object_name = 'AuditMatrixTestTable'
  )
ORDER BY event_time DESC;
GO

-- ============================================================
-- TEST 11: History retention moves old rows to the archive
-- Expected: ArchivedRows = 1 and TestResult = PASS.
-- The outer rollback removes the artificial demonstration row.
-- ============================================================
BEGIN TRANSACTION;

INSERT dbo.AuditLog
    (EventTime, TableName, OperationType, RecordID, ChangedBy, NewValues)
VALUES
    (DATEADD(DAY, -400, GETDATE()), 'RetentionTest', 'INSERT',
     'RETENTION-TEST', ORIGINAL_LOGIN(), N'{"test":true}');

EXEC dbo.usp_ArchiveAuditLog @RetainDays = 365;

SELECT
    COUNT(*) AS ArchivedRows,
    CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END AS TestResult
FROM dbo.AuditLogArchive
WHERE TableName = 'RetentionTest'
  AND RecordID = 'RETENTION-TEST';

ROLLBACK TRANSACTION;
GO

-- ============================================================
-- TEST 12: Login audit evidence
--
-- To generate a FAILED login:
--   1. Open a second SSMS connection.
--   2. Choose SQL Server Authentication.
--   3. Enter a real login name but an intentionally wrong password once.
--   4. Return here, wait a few seconds and run this query.
--
-- LGIF = failed login, LGIS = successful login.
-- ============================================================
USE master;
GO

SELECT TOP (50)
    event_time,
    action_id,
    succeeded,
    server_principal_name,
    server_instance_name,
    statement
FROM sys.fn_get_audit_file('C:\SQLAudit\*.sqlaudit', DEFAULT, DEFAULT)
WHERE action_id IN ('LGIF', 'LGIS')
ORDER BY event_time DESC;
GO

PRINT 'Auditing test cases completed.';
GO

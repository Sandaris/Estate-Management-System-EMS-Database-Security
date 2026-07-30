/* ========================================================================
   test_cases.sql - Green Acres Realty Sdn Bhd, EMS
   CT069-3-3 Database Security Assignment

   77 test cases in six blocks. Each states the result it expects, so run
   the block, capture what actually comes back, and record the two side by
   side for the DBS_TestCases_<group number>.docx deliverable.

     SECTION A  - Auditing & operational triggers      (A1-A10)
     SECTION B  - Data protection                      (B1-B15)
     SECTION C  - Access control                       (C1-C20)
     TEST 1-12  - Audit evidence for the documentation
     SECTION D  - Backup, recovery & availability      (D1-D10)
     SECTION E  - Login auditing                       (E1-E10)

   Run the build first (Compiled_code.sql, or DDL.sql then DML.sql).
   Connect as sysadmin: some tests read the audit files and impersonate
   other users. This is the same content as DML.sql Section 7.
   ======================================================================== */

USE GreenAcresEMS;
GO


/* ========================================================================
   SECTION A: AUDITING & OPERATIONAL TRIGGERS
   Member: Sarvein Goal: Prove the audit triggers (log every
   INSERT/UPDATE/DELETE) and the operational triggers (auto-update statuses,
   auto-create commission/notification rows) work correctly.
   ======================================================================== */

-- A1: INSERT audit test - insert a new Client.
-- Expected: a new AuditLog row with OperationType 'INSERT', NewValues filled
-- in and OldValues NULL.
INSERT INTO dbo.Clients (FullName, NRIC, ContactNumber, Email, Address, ClientType)
VALUES ('Test Trigger Client', '999999999999', '0100000000', 'test.trigger@example.com', 'Test Address', 'Individual');

DECLARE @TestClientID INT = SCOPE_IDENTITY();

SELECT TOP 1 * FROM dbo.AuditLog
WHERE TableName = 'Clients' AND OperationType = 'INSERT' AND RecordID = CAST(@TestClientID AS NVARCHAR(50))
ORDER BY AuditID DESC;
GO


-- A2: UPDATE audit test - update the Email of the Client from A1.
-- Expected: an AuditLog row with OperationType 'UPDATE', OldValues showing the
-- previous email and NewValues the new one.
DECLARE @TestClientID INT = (SELECT TOP 1 ClientID FROM dbo.Clients WHERE FullName = 'Test Trigger Client');

UPDATE dbo.Clients
SET Email = 'updated.trigger@example.com'
WHERE ClientID = @TestClientID;

SELECT TOP 1 * FROM dbo.AuditLog
WHERE TableName = 'Clients' AND OperationType = 'UPDATE' AND RecordID = CAST(@TestClientID AS NVARCHAR(50))
ORDER BY AuditID DESC;
GO


-- A3: DELETE audit test - delete the test Client.
-- Expected: an AuditLog row with OperationType 'DELETE', OldValues filled in
-- and NewValues NULL.
DECLARE @TestClientID INT = (SELECT TOP 1 ClientID FROM dbo.Clients WHERE FullName = 'Test Trigger Client');

DELETE FROM dbo.Clients WHERE ClientID = @TestClientID;

SELECT TOP 1 * FROM dbo.AuditLog
WHERE TableName = 'Clients' AND OperationType = 'DELETE' AND RecordID = CAST(@TestClientID AS NVARCHAR(50))
ORDER BY AuditID DESC;
GO


-- A4: Multi-row audit test - one UPDATE touching many Agent rows.
-- Expected: one AuditLog row PER row changed, not one for the statement -
-- AgentsUpdated should equal AuditRowsAdded and Result should say PASS.
DECLARE @BeforeCount INT = (SELECT COUNT(*) FROM dbo.AuditLog WHERE TableName = 'Agents' AND OperationType = 'UPDATE');
DECLARE @AffectedRows INT = (SELECT COUNT(*) FROM dbo.Agents WHERE CommissionRate < 2.00);

UPDATE dbo.Agents SET CommissionRate = CommissionRate  -- no real change, just enough to fire the trigger
WHERE CommissionRate < 2.00;

DECLARE @AfterCount INT = (SELECT COUNT(*) FROM dbo.AuditLog WHERE TableName = 'Agents' AND OperationType = 'UPDATE');

SELECT @AffectedRows AS AgentsUpdated, (@AfterCount - @BeforeCount) AS AuditRowsAdded,
       CASE WHEN @AffectedRows = (@AfterCount - @BeforeCount) THEN 'PASS' ELSE 'FAIL' END AS Result;
GO


-- A5: Operational trigger - a 'Sale' transaction marks the Property Sold.
-- Expected: that Property's Status automatically becomes 'Sold'.
DECLARE @PropID INT = (SELECT TOP 1 PropertyID FROM dbo.Properties WHERE Status = 'Available');
DECLARE @ClientID INT = (SELECT TOP 1 ClientID FROM dbo.Clients);
DECLARE @AgentID INT = (SELECT TOP 1 AgentID FROM dbo.Agents);

INSERT INTO dbo.Transactions (PropertyID, ClientID, AgentID, TransactionType, Amount, PaymentStatus)
VALUES (@PropID, @ClientID, @AgentID, 'Sale', 500000.00, 'Completed');

SELECT PropertyID, Status FROM dbo.Properties WHERE PropertyID = @PropID;
-- Expected Status = 'Sold'
GO


-- A6: Operational trigger - a Transaction auto-creates its Commission row.
-- Expected: a matching CommissionPayments row exists with CommissionAmount =
-- Amount x the agent's rate / 100, and Result says PASS.
DECLARE @LastTransID INT = (SELECT MAX(TransactionID) FROM dbo.Transactions);

SELECT t.TransactionID, t.Amount, a.CommissionRate, cp.CommissionAmount,
       ROUND(t.Amount * a.CommissionRate / 100.0, 2) AS ExpectedAmount,
       CASE WHEN cp.CommissionAmount = ROUND(t.Amount * a.CommissionRate / 100.0, 2)
            THEN 'PASS' ELSE 'FAIL' END AS Result
FROM dbo.Transactions t
JOIN dbo.Agents a ON a.AgentID = t.AgentID
JOIN dbo.CommissionPayments cp ON cp.TransactionID = t.TransactionID
WHERE t.TransactionID = @LastTransID;
GO


-- A7: Operational trigger - terminating a Lease frees up the Property.
-- Expected: the linked Property returns to 'Available' unless it was already
-- Sold, and exactly 1 new Notification is created.
DECLARE @LeaseID INT = (SELECT TOP 1 LeaseID FROM dbo.LeaseAgreements WHERE LeaseStatus = 'Active');
DECLARE @LeasePropID INT = (SELECT PropertyID FROM dbo.LeaseAgreements WHERE LeaseID = @LeaseID);
DECLARE @NotifCountBefore INT = (SELECT COUNT(*) FROM dbo.Notifications WHERE RelatedTable = 'LeaseAgreements' AND RelatedRecordID = @LeaseID);

UPDATE dbo.LeaseAgreements SET LeaseStatus = 'Terminated' WHERE LeaseID = @LeaseID;

SELECT
    (SELECT Status FROM dbo.Properties WHERE PropertyID = @LeasePropID) AS PropertyStatusAfter,
    (SELECT COUNT(*) FROM dbo.Notifications WHERE RelatedTable = 'LeaseAgreements' AND RelatedRecordID = @LeaseID) - @NotifCountBefore AS NewNotifications;
-- Expected: PropertyStatusAfter = 'Available' (unless it was 'Sold'),
-- NewNotifications = 1
GO


-- A8: Operational trigger - completing a MaintenanceRequest stamps the date.
-- Expected: CompletedDate is filled in automatically and 1 new Notification is
-- created.
DECLARE @ReqID INT = (
    SELECT TOP 1 RequestID FROM dbo.MaintenanceRequests
    WHERE Status <> 'Completed' AND RequestedByClientID IS NOT NULL
);

IF @ReqID IS NOT NULL
BEGIN
    DECLARE @NotifCountBefore2 INT = (SELECT COUNT(*) FROM dbo.Notifications WHERE RelatedTable = 'MaintenanceRequests' AND RelatedRecordID = @ReqID);

    UPDATE dbo.MaintenanceRequests SET Status = 'Completed' WHERE RequestID = @ReqID;

    SELECT RequestID, Status, CompletedDate,
           (SELECT COUNT(*) FROM dbo.Notifications WHERE RelatedTable = 'MaintenanceRequests' AND RelatedRecordID = @ReqID) - @NotifCountBefore2 AS NewNotifications
    FROM dbo.MaintenanceRequests WHERE RequestID = @ReqID;
END
ELSE
    PRINT 'No eligible MaintenanceRequests row found (all completed or none with a client) - skip test.';
GO


-- A9: Masking and encryption do not break the audit trigger.
-- Expected: NewValues still captures the encrypted column as Base64 with no
-- error, because the trigger runs WITH EXECUTE AS OWNER.
INSERT INTO dbo.Clients (FullName, NRIC, ContactNumber, Email, Address, ClientType)
VALUES ('Masking Test Client', '888888888888', '0111111111', 'masking.test@example.com', 'Masking Test Address', 'Individual');

SELECT TOP 1 NewValues FROM dbo.AuditLog
WHERE TableName = 'Clients' AND OperationType = 'INSERT'
ORDER BY AuditID DESC;

-- cleanup so this test can be re-run safely
DELETE FROM dbo.Clients WHERE FullName = 'Masking Test Client';
GO


-- A10: Summary - everything the audit log has captured so far
SELECT TableName, OperationType, COUNT(*) AS EventCount
FROM dbo.AuditLog
GROUP BY TableName, OperationType
ORDER BY TableName, OperationType;
GO


/* ========================================================================
   SECTION B: DATA PROTECTION (MASKING / ENCRYPTION / HASHING)
   Member: Irfan Goal: Prove that sensitive data is masked for normal users,
   properly encrypted at rest, and passwords are stored as salted hashes instead
   of plain text.
   ======================================================================== */

-- B1: List every masked column that was set up
-- Expected: One row per masked column across all the listed tables.
SELECT
    OBJECT_NAME(object_id) AS TableName,
    name AS MaskedColumnName,
    masking_function
FROM sys.masked_columns
WHERE OBJECT_NAME(object_id) IN (
    'Clients',
    'Agents',
    'Properties',
    'Transactions',
    'MaintenanceRequests',
    'SystemUsers',
    'LeaseAgreements',
    'CommissionPayments',
    'MaintenanceStaff'
)
ORDER BY TableName, MaskedColumnName;
GO


-- B2: Confirm encrypted Client columns look unreadable
-- Expected: The *_Encrypted columns show random binary bytes, not the plain
-- NRIC/ContactNumber/Email/Address values.
SELECT TOP 10
    ClientID,
    FullName,
    NRIC,
    NRIC_Encrypted,
    ContactNumber,
    ContactNumber_Encrypted,
    Email,
    Email_Encrypted,
    Address,
    Address_Encrypted
FROM dbo.Clients;
GO


-- B3: Decrypt Client data using the symmetric key
-- Expected: Once the key is opened, the Decrypted* columns show the original
-- readable values again.
OPEN SYMMETRIC KEY EMS_ClientDataSymmetricKey
DECRYPTION BY CERTIFICATE EMS_DataProtectionCertificate;
GO

SELECT TOP 10
    ClientID,
    FullName,
    CONVERT(NVARCHAR(20), DecryptByKey(NRIC_Encrypted)) AS DecryptedNRIC,
    CONVERT(NVARCHAR(20), DecryptByKey(ContactNumber_Encrypted)) AS DecryptedContactNumber,
    CONVERT(NVARCHAR(100), DecryptByKey(Email_Encrypted)) AS DecryptedEmail,
    CONVERT(NVARCHAR(255), DecryptByKey(Address_Encrypted)) AS DecryptedAddress
FROM dbo.Clients;
GO

CLOSE SYMMETRIC KEY EMS_ClientDataSymmetricKey;
GO


-- B4: Confirm the lease document path is encrypted
-- Expected: AgreementDocPath_Encrypted shows binary, not the plain path.
SELECT TOP 10
    LeaseID,
    TransactionID,
    AgreementDocPath,
    AgreementDocPath_Encrypted
FROM dbo.LeaseAgreements;
GO


-- B5: Decrypt the lease document path
-- Expected: DecryptedAgreementDocPath matches the original plain path.
OPEN SYMMETRIC KEY EMS_ClientDataSymmetricKey
DECRYPTION BY CERTIFICATE EMS_DataProtectionCertificate;
GO

SELECT TOP 10
    LeaseID,
    TransactionID,
    CONVERT(NVARCHAR(500), DecryptByKey(AgreementDocPath_Encrypted)) AS DecryptedAgreementDocPath
FROM dbo.LeaseAgreements;
GO

CLOSE SYMMETRIC KEY EMS_ClientDataSymmetricKey;
GO


-- B6: Confirm passwords are never stored as plain text
-- Expected: PasswordSaltSecure and PasswordHashSecure show unreadable binary
-- values, never the actual password.
SELECT TOP 10
    SystemUserID,
    FullName,
    LoginName,
    Email,
    PasswordSaltSecure,
    PasswordHashSecure,
    PasswordHashAlgorithm,
    PasswordLastUpdated
FROM dbo.SystemUsers;
GO


-- B7: Update a password and verify login works correctly
-- Expected: Correct password -> "Login Successful".
EXEC dbo.usp_UpdateSystemUserPassword
    @LoginName = 'irfan.hakim',
    @NewPlainPassword = 'IrfanSecure@2026';
GO

EXEC dbo.usp_VerifySystemUserPassword
    @LoginName = 'irfan.hakim',
    @PlainPassword = 'IrfanSecure@2026';
GO

EXEC dbo.usp_VerifySystemUserPassword
    @LoginName = 'irfan.hakim',
    @PlainPassword = 'WrongPassword';
GO


-- B8: Final summary - which data protection features actually exist
-- Expected: Every SecurityFeature row shows a count greater than 0.
SELECT
    'Dynamic Data Masking' AS SecurityFeature,
    COUNT(*) AS AppliedColumnCount
FROM sys.masked_columns
WHERE OBJECT_NAME(object_id) IN (
    'Clients',
    'Agents',
    'Properties',
    'Transactions',
    'MaintenanceRequests',
    'SystemUsers',
    'LeaseAgreements',
    'CommissionPayments',
    'MaintenanceStaff'
)

UNION ALL

SELECT
    'Client Encrypted Columns',
    COUNT(*)
FROM sys.columns
WHERE object_id = OBJECT_ID('dbo.Clients')
  AND name IN (
      'NRIC_Encrypted',
      'ContactNumber_Encrypted',
      'Email_Encrypted',
      'Address_Encrypted'
  )

UNION ALL

SELECT
    'Lease Encrypted Columns',
    COUNT(*)
FROM sys.columns
WHERE object_id = OBJECT_ID('dbo.LeaseAgreements')
  AND name = 'AgreementDocPath_Encrypted'

UNION ALL

SELECT
    'Secure Hash Columns',
    COUNT(*)
FROM sys.columns
WHERE object_id = OBJECT_ID('dbo.SystemUsers')
  AND name IN (
      'PasswordSaltSecure',
      'PasswordHashSecure',
      'PasswordHashAlgorithm',
      'PasswordLastUpdated'
  );
GO


-- B9: The old, weaker credential columns are GONE
-- Expected: 0 rows. PasswordHash (SHA2_256) and PasswordSalt (plain-text salt)
-- were dropped once the salted SHA2_512 columns took over, so there is no
-- second, weaker credential store left to attack.
SELECT name AS LegacyCredentialColumnStillPresent
FROM sys.columns
WHERE object_id = OBJECT_ID('dbo.SystemUsers')
  AND name IN ('PasswordHash', 'PasswordSalt');
GO


-- B10: Controlled decryption THROUGH the stored procedure
-- Expected: Readable NRIC / ContactNumber / Email / Address for ClientID 1. The
-- procedure is WITH EXECUTE AS OWNER, so it - not the caller - opens the
-- symmetric key.
EXEC dbo.usp_GetClientSensitiveData
    @ClientID = 1,
    @Reason   = 'Test case B10 - verifying controlled decryption path';
GO

-- The access itself is audit evidence: this call must appear in AuditLog as a
-- SELECT/DECRYPT_READ event naming the real login.
-- Expected: at least one row, ChangedBy = your login, and the NewValues JSON
-- contains "DECRYPT_READ" plus the reason.
SELECT TOP 5
    AuditID, EventTime, TableName, OperationType,
    RecordID, ChangedBy, NewValues
FROM dbo.AuditLog
WHERE TableName = 'Clients'
  AND OperationType = 'SELECT'
ORDER BY AuditID DESC;
GO


-- B11: Decrypting the lease document path through its procedure
-- Expected: The readable 'docs/leases/LA-TR002.pdf' style path.
DECLARE @AnyLeaseID INT = (SELECT MIN(LeaseID) FROM dbo.LeaseAgreements);
EXEC dbo.usp_GetLeaseDocumentPath @LeaseID = @AnyLeaseID;
GO


-- B12: A developer role CANNOT reach the decryption door
-- Expected: 'PASS' for both.
EXECUTE AS USER = 'vijay.menon';
    BEGIN TRY
        EXEC dbo.usp_GetClientSensitiveData @ClientID = 1;
        PRINT 'FAIL: ClientPortalDev decrypted client PII.';
    END TRY
    BEGIN CATCH
        PRINT 'PASS: Decryption procedure denied -> ' + ERROR_MESSAGE();
    END CATCH;
REVERT;
GO

EXECUTE AS USER = 'vijay.menon';
    BEGIN TRY
        OPEN SYMMETRIC KEY EMS_ClientDataSymmetricKey
            DECRYPTION BY CERTIFICATE EMS_DataProtectionCertificate;
        PRINT 'FAIL: ClientPortalDev opened the symmetric key directly.';
        CLOSE SYMMETRIC KEY EMS_ClientDataSymmetricKey;
    END TRY
    BEGIN CATCH
        PRINT 'PASS: Key access denied -> ' + ERROR_MESSAGE();
    END CATCH;
REVERT;
GO


-- B13: New data added later is encrypted too
-- Expected: The new client starts with NULL ciphertext, and after
-- usp_EncryptClientPII the ciphertext columns are populated.
EXEC dbo.usp_ManageClient
    @FullName      = 'B13 Encryption Coverage Test',
    @NRIC          = '900101101234',
    @ContactNumber = '012-3330000',
    @Email         = 'b13.test@example.com',
    @Address       = 'Test Address, Kuala Lumpur';
GO

DECLARE @NewClientID INT =
    (SELECT MAX(ClientID) FROM dbo.Clients
     WHERE FullName = 'B13 Encryption Coverage Test');

SELECT 'Before' AS Stage, ClientID, FullName, NRIC_Encrypted
FROM dbo.Clients WHERE ClientID = @NewClientID;

EXEC dbo.usp_EncryptClientPII @ClientID = @NewClientID;

SELECT 'After' AS Stage, ClientID, FullName, NRIC_Encrypted
FROM dbo.Clients WHERE ClientID = @NewClientID;

-- Tidy up so repeated runs do not pile up test rows.
DELETE FROM dbo.Clients WHERE ClientID = @NewClientID;
GO


-- B14: The masking limit we documented, proved
-- Expected: MaskedRead shows a masked/random value while RealTotal returns a
-- genuine figure.
EXECUTE AS USER = 'jason.lim';          -- role_ReadOnly, no UNMASK
    SELECT TOP 3
        'MaskedRead' AS TestPart,
        MonthlyRent  AS MaskedValue
    FROM vw_ActiveLeases;
REVERT;
GO

EXECUTE AS USER = 'nurul.huda';         -- role_ReadOnly, no UNMASK
    BEGIN TRY
        SELECT 'RealTotal' AS TestPart,
               SUM(MonthlyRent) AS AggregateOverMaskedColumn
        FROM vw_ActiveLeases;
    END TRY
    BEGIN CATCH
        PRINT 'Aggregate blocked -> ' + ERROR_MESSAGE();
    END CATCH;
REVERT;
GO


-- B15: Analyst UNMASK is explicit and column-level (SQL 2022+)
-- Expected: On SQL Server 2022 or newer, role_Analyst holds UNMASK on financial
-- columns ONLY - never on a PII column.
SELECT
    dp.permission_name,
    OBJECT_NAME(dp.major_id) AS TableName,
    c.name                   AS ColumnName,
    pr.name                  AS GrantedTo
FROM sys.database_permissions AS dp
JOIN sys.database_principals AS pr ON pr.principal_id = dp.grantee_principal_id
LEFT JOIN sys.columns AS c
       ON c.object_id = dp.major_id
      AND c.column_id = dp.minor_id
WHERE dp.permission_name = 'UNMASK'
ORDER BY pr.name, TableName, ColumnName;
GO


/* ========================================================================
   SECTION C: ACCESS CONTROL (ROLES / USERS / VIEWS / PROCEDURES)
   Member: Rama Goal: Prove that each database role only has the permissions it
   should have - no more, no less (principle of least privilege).
   ======================================================================== */

-- C1: Confirm all roles exist and have members
-- Expected: 6 roles listed (role_...), each with at least 1 member.
SELECT r.name AS RoleName, m.name AS MemberName
FROM sys.database_role_members rm
JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
JOIN sys.database_principals m ON m.principal_id = rm.member_principal_id
WHERE r.name LIKE 'role_%'
ORDER BY RoleName, MemberName;
GO


-- C2: Confirm every SystemUsers.UserRole has a matching database role
-- Expected: RoleStatus = 'EXISTS' for every distinct UserRole value.
SELECT DISTINCT
    su.UserRole,
    'role_' + su.UserRole AS ExpectedRoleName,
    CASE WHEN dp.name IS NOT NULL THEN 'EXISTS' ELSE 'MISSING' END AS RoleStatus
FROM dbo.SystemUsers su
LEFT JOIN sys.database_principals dp
    ON dp.name = 'role_' + su.UserRole
    AND dp.type = 'R';
GO


-- C3: role_ReadOnly CAN read a safe view
-- Expected: Rows returned successfully from vw_PropertyListing.
EXECUTE AS USER = 'jason.lim';          -- jason.lim is in role_ReadOnly
    SELECT TOP 5 PropertyID, PropertyName, City, Status
    FROM vw_PropertyListing;
REVERT;
GO


-- C4: role_ReadOnly is BLOCKED from a sensitive base table
-- Expected: Permission denied error (this proves least privilege works).
EXECUTE AS USER = 'jason.lim';          -- role_ReadOnly
    BEGIN TRY
        SELECT TOP 1 * FROM dbo.CommissionPayments;
        PRINT 'FAIL: ReadOnly user accessed CommissionPayments.';
    END TRY
    BEGIN CATCH
        PRINT 'PASS: Permission denied -> ' + ERROR_MESSAGE();
    END CATCH;
REVERT;
GO


-- C5: role_Analyst sees MASKED personal data (linked to Irfan's masking)
-- Expected: hakim.zulkifli (no UNMASK permission) sees masked NRIC,
-- ContactNumber and Email values, not the real ones.
EXECUTE AS USER = 'hakim.zulkifli';    -- role_Analyst
    SELECT TOP 5 ClientID, FullName, NRIC, ContactNumber, Email
    FROM vw_ClientDirectory;
REVERT;
GO


-- C6: role_Admin sees UNMASKED personal data (UNMASK permission granted)
-- Expected: farid.rahman sees the real NRIC and Email values.
EXECUTE AS USER = 'farid.rahman';      -- role_Admin
    SELECT TOP 5 ClientID, FullName, NRIC, Email
    FROM dbo.Clients;
REVERT;
GO


-- C7: role_DBA has full access, including unmasked data
-- Expected: arun.kumar sees real values in both Clients and CommissionPayments.
EXECUTE AS USER = 'arun.kumar';        -- role_DBA
    SELECT TOP 5 ClientID, FullName, NRIC, Email FROM dbo.Clients;
    SELECT TOP 3 CommissionID, CommissionAmount FROM dbo.CommissionPayments;
REVERT;
GO


-- C8: role_PropMgmtDev can insert a property THROUGH the procedure
-- Expected: usp_ManageProperty runs successfully.
EXECUTE AS USER = 'kelvin.ong';        -- role_PropMgmtDev
    EXEC dbo.usp_ManageProperty
        @PropertyName = 'Test Location',
        @Address      = 'Test Address',
        @City         = 'Kuala Lumpur',
        @State        = 'Kuala Lumpur',
        @PostalCode   = '57000',
        @PropertyType = 'Residential',
        @Bedrooms     = 3,
        @Bathrooms    = 2,
        @SizeSqft     = 1400,
        @Price        = 650000,
        @Status       = 'Available';
REVERT;
GO


-- C9: role_PropMgmtDev is BLOCKED from writing directly to CommissionPayments
-- Expected: Direct INSERT is denied (they must go through approved procedures
-- only).
EXECUTE AS USER = 'kelvin.ong';        -- role_PropMgmtDev
    BEGIN TRY
        INSERT INTO dbo.CommissionPayments
            (TransactionID, AgentID, CommissionRate, CommissionAmount, PaymentStatus)
        VALUES (1, 1, 2.5, 5000, 'Unpaid');
        PRINT 'FAIL: PropMgmtDev wrote to CommissionPayments.';
    END TRY
    BEGIN CATCH
        PRINT 'PASS: Permission denied -> ' + ERROR_MESSAGE();
    END CATCH;
REVERT;
GO


-- C10: role_ClientPortalDev can create a client THROUGH the procedure
-- Expected: New client row is inserted successfully.
EXECUTE AS USER = 'vijay.menon';       -- role_ClientPortalDev
    EXEC dbo.usp_ManageClient
        @FullName      = 'Test Client',
        @NRIC          = '123456789001',
        @ContactNumber = '0123400099',
        @Email         = 'test@example.com',
        @Address       = 'Test Address',
        @ClientType    = 'Individual';
REVERT;
GO


-- C11: Stored procedure rejects bad input
-- Expected: usp_UpdatePropertyStatus raises an error for a status value that
-- isn't allowed (e.g.
BEGIN TRY
    EXEC dbo.usp_UpdatePropertyStatus
        @PropertyID = 1,
        @NewStatus  = 'Invalid-Status';
    PRINT 'FAIL: Invalid status was accepted.';
END TRY
BEGIN CATCH
    PRINT 'PASS: Validation error -> ' + ERROR_MESSAGE();
END CATCH;
GO


-- C12: role_Analyst can read reporting/summary views
-- Expected: Both views return data rows successfully.
EXECUTE AS USER = 'hakim.zulkifli';   -- role_Analyst
    SELECT * FROM vw_MonthlySalesSummary;
    SELECT TOP 5 AgentName, TotalSales, TotalTransactionValue
    FROM vw_AgentPerformance
    ORDER BY TotalTransactionValue DESC;
REVERT;
GO


-- C13: role_Analyst CANNOT run a write procedure
-- Expected: EXECUTE permission on usp_ManageProperty is denied.
EXECUTE AS USER = 'hakim.zulkifli';   -- role_Analyst
    BEGIN TRY
        EXEC dbo.usp_ManageProperty
            @PropertyName = 'Hack Tower', @Address = 'x',
            @City = 'x', @State = 'x', @PropertyType = 'Residential',
            @Price = 1;
        PRINT 'FAIL: Analyst executed a write procedure.';
    END TRY
    BEGIN CATCH
        PRINT 'PASS: Execute denied -> ' + ERROR_MESSAGE();
    END CATCH;
REVERT;
GO


-- C14: usp_ProvisionUser successfully adds a new user
-- Expected: Login, database user, and role membership are all created.
EXEC dbo.usp_ProvisionUser
    @LoginName = 'test.newstaff',
    @Password  = 'Test@NewStaff#2026',
    @RoleName  = 'role_Analyst';
GO


-- C15: usp_DeprovisionUser successfully removes that user
-- Expected: test.newstaff is removed from roles, database user dropped, and
-- login dropped - nothing left behind.
EXEC dbo.usp_DeprovisionUser @LoginName = 'test.newstaff';
GO


-- C16: usp_ProvisionUser rejects a missing/NULL password
-- Expected: 'PASS: NULL parameter rejected -> ...' is printed.
BEGIN TRY
    EXEC dbo.usp_ProvisionUser
        @LoginName = 'test.incomplete',
        @Password  = NULL,             -- password not supplied on purpose
        @RoleName  = 'role_ReadOnly';
    PRINT 'FAIL: NULL parameter was accepted.';
END TRY
BEGIN CATCH
    PRINT 'PASS: NULL parameter rejected -> ' + ERROR_MESSAGE();
END CATCH;
GO


-- C17: usp_ProvisionUser resists SQL injection
-- Expected: 'PASS' - the login name is rejected by the character whitelist
-- before any dynamic SQL is built, and dbo.Clients is untouched.
DECLARE @ClientsBefore INT = (SELECT COUNT(*) FROM dbo.Clients);

BEGIN TRY
    EXEC dbo.usp_ProvisionUser
        @LoginName = 'evil];DROP TABLE dbo.Clients--',
        @Password  = 'Injected@Password2026',
        @RoleName  = 'role_ReadOnly';
    PRINT 'FAIL: injected login name was accepted.';
END TRY
BEGIN CATCH
    PRINT 'PASS: injection rejected -> ' + ERROR_MESSAGE();
END CATCH;

-- The table must still be there with the same number of rows.
IF OBJECT_ID('dbo.Clients', 'U') IS NULL
    PRINT 'FAIL: dbo.Clients was dropped!';
ELSE IF (SELECT COUNT(*) FROM dbo.Clients) = @ClientsBefore
    PRINT 'PASS: dbo.Clients intact, row count unchanged.';
ELSE
    PRINT 'FAIL: dbo.Clients row count changed.';
GO


-- C18: A short password is rejected
-- Expected: 'PASS' - the procedure enforces a 12-character minimum before it
-- ever reaches CREATE LOGIN.
BEGIN TRY
    EXEC dbo.usp_ProvisionUser
        @LoginName = 'test.shortpw',
        @Password  = 'abc123',
        @RoleName  = 'role_ReadOnly';
    PRINT 'FAIL: short password was accepted.';
END TRY
BEGIN CATCH
    PRINT 'PASS: short password rejected -> ' + ERROR_MESSAGE();
END CATCH;
GO


-- C19: Provisioning is a DBA duty, not a business-Admin duty
-- Expected: 'PASS' - farid.rahman (role_Admin) has no EXECUTE on
-- usp_ProvisionUser.
EXECUTE AS USER = 'farid.rahman';      -- role_Admin
    BEGIN TRY
        EXEC dbo.usp_ProvisionUser
            @LoginName = 'test.escalation',
            @Password  = 'Escalate@Test2026',
            @RoleName  = 'role_DBA';
        PRINT 'FAIL: role_Admin provisioned a DBA account.';
    END TRY
    BEGIN CATCH
        PRINT 'PASS: provisioning denied to role_Admin -> ' + ERROR_MESSAGE();
    END CATCH;
REVERT;
GO


-- C20: Full permission matrix dump for the report
-- Expected: One row per explicit GRANT/DENY per role.
SELECT
    pr.name                             AS RoleName,
    dp.state_desc                       AS GrantOrDeny,
    dp.permission_name                  AS Permission,
    CASE dp.class
        WHEN 0 THEN 'DATABASE'
        WHEN 1 THEN ISNULL(OBJECT_SCHEMA_NAME(dp.major_id) + '.', '')
                    + ISNULL(OBJECT_NAME(dp.major_id), '(object)')
        WHEN 25 THEN 'CERTIFICATE'
        WHEN 24 THEN 'SYMMETRIC KEY'
        ELSE dp.class_desc
    END                                 AS SecurableName,
    CASE
        WHEN dp.class = 1 AND o.type_desc IS NOT NULL THEN o.type_desc
        ELSE dp.class_desc
    END                                 AS SecurableType,
    c.name                              AS ColumnName
FROM sys.database_permissions AS dp
JOIN sys.database_principals  AS pr ON pr.principal_id = dp.grantee_principal_id
LEFT JOIN sys.objects        AS o  ON o.object_id = dp.major_id AND dp.class = 1
LEFT JOIN sys.columns        AS c  ON c.object_id = dp.major_id
                                  AND c.column_id = dp.minor_id
                                  AND dp.minor_id > 0
WHERE pr.type = 'R'
  AND pr.name LIKE 'role[_]%'
ORDER BY pr.name, SecurableName, dp.permission_name;
GO


-- AUDIT EVIDENCE TESTS (TEST 1-12) Green Acres Realty Sdn Bhd - EMS Database
-- Security CT069-3-3 Database Security Assignment Purpose: Screenshot-friendly
-- test cases for Documentation Section 4. Run DDL.sql, then Sections 1-6 of
-- this file, before these tests.

USE GreenAcresEMS;
GO

-- TEST 1: AuditLog table exists
-- Expected: One row showing dbo.AuditLog.
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

-- TEST 2: Audit triggers exist on important tables
-- Expected: 8 trigger rows, all enabled.
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

-- TEST 3: UPDATE client data and prove AuditLog records it
-- Expected: 1. Client Email changes.
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

-- TEST 4: INSERT transaction and prove trigger audit works
-- Expected: 1. New transaction is inserted.
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

-- TEST 5: ReadOnly user cannot read AuditLog
-- Expected: PASS message with permission denied.
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

-- TEST 6: SQL Server Audit is enabled
-- Expected: Server audit and database audit specification both show enabled.
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

-- TEST 7: Read SQL Server Audit file
-- Expected: Audit rows appear after SELECT/UPDATE/permission tests.
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

-- TEST 8: Audit specifications contain the required actions
-- Expected: Result grids show login, principal, permission, role, schema,
-- sensitive-object and audit-evidence actions.
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

-- TEST 9: Multi-row updates create one history row per changed row
-- Expected: RowsAffected = AuditRowsCreated and TestResult = PASS.
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

-- TEST 10: Generate permission, role, principal and schema events.
-- Expected: the audit specification captures each one; the test objects are
-- removed before the batch completes.
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

-- TEST 11: History retention moves old rows to the archive
-- Expected: ArchivedRows = 1 and TestResult = PASS.
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

-- TEST 12: Login audit evidence (LGIF = failed login, LGIS = successful).
-- Expected: LGIF rows after you open a second SSMS connection with SQL Server
-- Authentication, enter a real login with a wrong password, then re-run this.
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


/* ========================================================================
   SECTION D: BACKUP, RECOVERY & AVAILABILITY
   Goal: Prove the Availability side of CIA.
   ======================================================================== */

USE master;
GO

-- D1: The recovery model still allows point-in-time recovery
-- Expected: recovery_model_desc = FULL.
SELECT
    name AS DatabaseName,
    recovery_model_desc,
    log_reuse_wait_desc,
    state_desc
FROM sys.databases
WHERE name IN ('GreenAcresEMS', 'GreenAcresEMS_Restore');
GO


-- D2: All three backup types were actually taken
-- Expected: One row each for Full, Differential and Transaction Log, all for
-- GreenAcresEMS, all with is_damaged = 0.
SELECT
    CASE bs.type
        WHEN 'D' THEN 'Full'
        WHEN 'I' THEN 'Differential'
        WHEN 'L' THEN 'Transaction Log'
        ELSE bs.type
    END                                              AS BackupType,
    bs.backup_start_date,
    bs.backup_finish_date,
    CAST(bs.backup_size / 1048576.0 AS DECIMAL(10,2)) AS BackupSize_MB,
    bs.is_damaged,
    bs.has_backup_checksums,
    bs.is_copy_only,
    bmf.physical_device_name
FROM msdb.dbo.backupset AS bs
JOIN msdb.dbo.backupmediafamily AS bmf
     ON bmf.media_set_id = bs.media_set_id
WHERE bs.database_name = 'GreenAcresEMS'
ORDER BY bs.backup_start_date DESC;
GO


-- D3: The backup files are readable and not corrupt
-- Expected: "The backup set on file 1 is valid." for each file.
RESTORE VERIFYONLY FROM DISK = 'C:\EMS_Backups\GreenAcresEMS_FULL.bak' WITH CHECKSUM;
GO
RESTORE VERIFYONLY FROM DISK = 'C:\EMS_Backups\GreenAcresEMS_DIFF.bak' WITH CHECKSUM;
GO
RESTORE VERIFYONLY FROM DISK = 'C:\EMS_Backups\GreenAcresEMS_LOG.trn'  WITH CHECKSUM;
GO


-- D4: The KEY MATERIAL was backed up too
-- Expected: All three files exist (FileExists = 1).
DECLARE @Info TABLE (
    Label       NVARCHAR(60),
    FilePath    NVARCHAR(300),
    FileExists  INT,
    IsDirectory INT,
    ParentDirExists INT
);

INSERT INTO @Info (FileExists, IsDirectory, ParentDirExists)
EXEC master.dbo.xp_fileexist 'C:\EMS_Backups\Keys\EMS_DataProtectionCertificate.cer';
UPDATE @Info SET Label = 'Certificate (public .cer)',
                 FilePath = 'C:\EMS_Backups\Keys\EMS_DataProtectionCertificate.cer'
WHERE Label IS NULL;

INSERT INTO @Info (FileExists, IsDirectory, ParentDirExists)
EXEC master.dbo.xp_fileexist 'C:\EMS_Backups\Keys\EMS_DataProtectionCertificate.pvk';
UPDATE @Info SET Label = 'Certificate private key (.pvk)',
                 FilePath = 'C:\EMS_Backups\Keys\EMS_DataProtectionCertificate.pvk'
WHERE Label IS NULL;

INSERT INTO @Info (FileExists, IsDirectory, ParentDirExists)
EXEC master.dbo.xp_fileexist 'C:\EMS_Backups\Keys\EMS_MasterKey.key';
UPDATE @Info SET Label = 'Database Master Key (.key)',
                 FilePath = 'C:\EMS_Backups\Keys\EMS_MasterKey.key'
WHERE Label IS NULL;

SELECT Label AS KeyMaterial, FilePath, FileExists
FROM @Info;
GO


-- D5: The restore rehearsal produced a usable database
-- Expected: LiveRows = RestoredRows for every table.
IF DB_ID('GreenAcresEMS_Restore') IS NULL
BEGIN
    PRINT 'SKIP: GreenAcresEMS_Restore does not exist - run the restore section first.';
END
ELSE
BEGIN
    SELECT 'Properties' AS TableName,
           (SELECT COUNT(*) FROM GreenAcresEMS.dbo.Properties)         AS LiveRows,
           (SELECT COUNT(*) FROM GreenAcresEMS_Restore.dbo.Properties) AS RestoredRows
    UNION ALL
    SELECT 'Clients',
           (SELECT COUNT(*) FROM GreenAcresEMS.dbo.Clients),
           (SELECT COUNT(*) FROM GreenAcresEMS_Restore.dbo.Clients)
    UNION ALL
    SELECT 'Transactions',
           (SELECT COUNT(*) FROM GreenAcresEMS.dbo.Transactions),
           (SELECT COUNT(*) FROM GreenAcresEMS_Restore.dbo.Transactions)
    UNION ALL
    SELECT 'LeaseAgreements',
           (SELECT COUNT(*) FROM GreenAcresEMS.dbo.LeaseAgreements),
           (SELECT COUNT(*) FROM GreenAcresEMS_Restore.dbo.LeaseAgreements)
    UNION ALL
    SELECT 'CommissionPayments',
           (SELECT COUNT(*) FROM GreenAcresEMS.dbo.CommissionPayments),
           (SELECT COUNT(*) FROM GreenAcresEMS_Restore.dbo.CommissionPayments)
    UNION ALL
    SELECT 'AuditLog',
           (SELECT COUNT(*) FROM GreenAcresEMS.dbo.AuditLog),
           (SELECT COUNT(*) FROM GreenAcresEMS_Restore.dbo.AuditLog);
END;
GO


-- D6: The audit trail survived the restore
-- Expected: The restored copy still carries its AuditLog history.
IF DB_ID('GreenAcresEMS_Restore') IS NOT NULL
BEGIN
    SELECT TOP 5
        AuditID, EventTime, TableName, OperationType, ChangedBy
    FROM GreenAcresEMS_Restore.dbo.AuditLog
    ORDER BY AuditID DESC;
END;
GO


-- D7: Encrypted data is STILL encrypted in the restored copy
-- Expected: Ciphertext, not readable text - and no way to decrypt it there,
-- because the restored database has no certificate of its own.
IF DB_ID('GreenAcresEMS_Restore') IS NOT NULL
BEGIN
    SELECT TOP 3
        ClientID,
        FullName,
        NRIC_Encrypted AS CiphertextAfterRestore
    FROM GreenAcresEMS_Restore.dbo.Clients;
END;
GO


-- D8: No corrupt pages anywhere
-- Expected: ZERO rows. Any row here means SQL Server has met a damaged page and
-- the backup chain is about to be needed for real.
SELECT * FROM msdb.dbo.suspect_pages;
GO


-- D9: Integrity check of the live database
-- Expected: "CHECKDB found 0 allocation errors and 0 consistency errors in
-- database 'GreenAcresEMS'."
DBCC CHECKDB ('GreenAcresEMS') WITH NO_INFOMSGS, ALL_ERRORMSGS;
GO


-- D10: How much data would we lose right now?
-- Expected: MinutesSinceLastLogBackup should be small.
SELECT
    MAX(CASE WHEN type = 'D' THEN backup_finish_date END) AS LastFullBackup,
    MAX(CASE WHEN type = 'I' THEN backup_finish_date END) AS LastDiffBackup,
    MAX(CASE WHEN type = 'L' THEN backup_finish_date END) AS LastLogBackup,
    DATEDIFF(MINUTE, MAX(CASE WHEN type = 'L' THEN backup_finish_date END), GETDATE())
        AS MinutesSinceLastLogBackup
FROM msdb.dbo.backupset
WHERE database_name = 'GreenAcresEMS';
GO


PRINT 'Backup and recovery test cases completed.';
GO


/* ========================================================================
   SECTION E: LOGIN AUDITING (UserLoginLog + LOGON TRIGGER)
   Goal: Prove that dbo.UserLoginLog is real, populated audit evidence rather
   than an empty table, and that it is protected from the roles it is meant to
   watch.
   ======================================================================== */

USE GreenAcresEMS;
GO

-- E1: The logon trigger exists and is enabled
-- Expected: One row, is_disabled = 0. If the row is missing, the build script
-- could not impersonate 'sa' and said so.
SELECT
    name        AS TriggerName,
    is_disabled AS IsDisabled,
    create_date
FROM sys.server_triggers
WHERE name = 'trg_ServerLogon_AuditLogin';
GO


-- E2: A successful application login is recorded
-- Expected: 'Login Successful' from the procedure, then a matching UserLoginLog
-- row with IsSuccessful = 1. (B7 already cleared irfan.hakim's forced-reset
-- flag; if this returns 'Password Change Required', run B7 first.)
EXEC dbo.usp_VerifySystemUserPassword
    @LoginName     = 'irfan.hakim',
    @PlainPassword = 'IrfanSecure@2026';
GO

SELECT TOP 5 LogID, LoginName, LoginTime, IsSuccessful, HostName, FailureReason
FROM dbo.UserLoginLog
ORDER BY LogID DESC;
GO


-- E3: A FAILED application login is recorded, with a reason
-- Expected: 'Invalid Login' from the procedure, and a new UserLoginLog row with
-- IsSuccessful = 0 and FailureReason = 'Incorrect password'.
EXEC dbo.usp_VerifySystemUserPassword
    @LoginName     = 'irfan.hakim',
    @PlainPassword = 'DefinitelyTheWrongPassword';
GO

SELECT TOP 5 LogID, LoginName, LoginTime, IsSuccessful, FailureReason
FROM dbo.UserLoginLog
ORDER BY LogID DESC;
GO


-- E4: An attempt on an unknown account is logged, but the error message gives
-- nothing away
-- Expected: The caller sees the same generic 'Invalid Login', while
-- UserLoginLog records 'Unknown or inactive account'.
EXEC dbo.usp_VerifySystemUserPassword
    @LoginName     = 'no.such.person',
    @PlainPassword = 'Whatever@2026';
GO

SELECT TOP 3 LogID, LoginName, IsSuccessful, FailureReason
FROM dbo.UserLoginLog
WHERE LoginName = 'no.such.person'
ORDER BY LogID DESC;
GO


-- E5: Brute-force detection
-- Expected: After the failures above, 'no.such.person' and/or 'irfan.hakim'
-- appear once the threshold is reached.
EXEC dbo.usp_ReportSuspiciousLogins
    @WindowMinutes = 60,
    @FailThreshold = 1;
GO


-- E6: Session length is tracked (login -> logout)
-- Expected: The chosen row shows a LogoutTime and a SessionMinutes value
-- instead of an open-ended session.
DECLARE @OpenLogID INT =
    (SELECT MAX(LogID) FROM dbo.UserLoginLog
     WHERE IsSuccessful = 1 AND LogoutTime IS NULL);

IF @OpenLogID IS NULL
    PRINT 'SKIP: no open successful session to close - run E2 first.';
ELSE
BEGIN
    EXEC dbo.usp_RecordLogout @LogID = @OpenLogID;

    SELECT LogID, LoginName, LoginTime, LogoutTime, SessionMinutes
    FROM dbo.vw_LoginHistory
    WHERE LogID = @OpenLogID;
END;
GO


-- E7: Login history joins cleanly to staff and department
-- Expected: FullName and DepartmentName are filled in for rows belonging to
-- known EMS staff.
SELECT TOP 10
    LogID, LoginName, FullName, DepartmentName, UserRole,
    LoginTime, IsSuccessful
FROM dbo.vw_LoginHistory
ORDER BY LogID DESC;
GO


-- E8: Login history is NOT readable by the watched roles
-- Expected: 'PASS' for both.
EXECUTE AS USER = 'hakim.zulkifli';    -- role_Analyst
    BEGIN TRY
        SELECT TOP 1 * FROM dbo.UserLoginLog;
        PRINT 'FAIL: Analyst read the login log.';
    END TRY
    BEGIN CATCH
        PRINT 'PASS: Login log denied -> ' + ERROR_MESSAGE();
    END CATCH;
REVERT;
GO

EXECUTE AS USER = 'jason.lim';         -- role_ReadOnly
    BEGIN TRY
        SELECT TOP 1 * FROM dbo.vw_LoginHistory;
        PRINT 'FAIL: ReadOnly read the login history view.';
    END TRY
    BEGIN CATCH
        PRINT 'PASS: Login history denied -> ' + ERROR_MESSAGE();
    END CATCH;
REVERT;
GO


-- E9: Forced password reset on the onboarding password
-- Expected: 'Password Change Required' - the password is CORRECT but the
-- account is still on the shared onboarding secret, so the login is not
-- completed until it is replaced.
SELECT TOP 5 LoginName, PasswordMustChange, PasswordLastUpdated
FROM dbo.SystemUsers
ORDER BY SystemUserID;
GO

DECLARE @TestLogin NVARCHAR(100) =
    (SELECT MIN(LoginName) FROM dbo.SystemUsers WHERE PasswordMustChange = 1);

IF @TestLogin IS NULL
    PRINT 'SKIP: every account has already changed its onboarding password.';
ELSE
BEGIN
    PRINT 'Testing forced reset for: ' + @TestLogin;
    EXEC dbo.usp_VerifySystemUserPassword
        @LoginName     = @TestLogin,
        @PlainPassword = 'TempPassword@2026';

    EXEC dbo.usp_UpdateSystemUserPassword
        @LoginName        = @TestLogin,
        @NewPlainPassword = 'ChangedByTestE9@2026';

    EXEC dbo.usp_VerifySystemUserPassword
        @LoginName     = @TestLogin,
        @PlainPassword = 'ChangedByTestE9@2026';
END;
GO


-- E10: Failed SERVER logins come from the audit file, not the logon trigger
-- Expected: LGIF rows for any wrong-password connection attempt.
SELECT TOP 20
    event_time,
    action_id,
    succeeded,
    server_principal_name,
    client_ip,
    application_name
FROM sys.fn_get_audit_file('C:\SQLAudit\GA_EMS_ServerAudit*.sqlaudit', DEFAULT, DEFAULT)
WHERE action_id IN ('LGIF', 'LGIS')
ORDER BY event_time DESC;
GO


PRINT 'Login auditing test cases completed.';
GO


/* ========================================================================
   END OF TEST_CASES.SQL
   ======================================================================== */

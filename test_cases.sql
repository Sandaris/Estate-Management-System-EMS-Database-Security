/* ================================================================
   TEST_CASES.SQL
   Green Acres Realty Sdn Bhd - Estate Management System (EMS)
   CT069-3-3 Database Security Assignment

   What this file is:
   All test cases from the group combined into ONE file, so we can
   run the whole test suite from top to bottom and hand in a single
   script alongside the report.

   Sections in this file:
     SECTION A - Auditing & Operational Triggers   (Sarvein)
     SECTION B - Data Protection (Masking/Encryption/Hashing) (Irfan)
     SECTION C - Access Control (Roles/Users/Views/Procedures) (Rama)

   How to run:
     1. Make sure the main build scripts have already been run first
        (table creation, triggers.sql, data protection script,
        access control script) - this file only TESTS them.
     2. Run this file top to bottom in SQL Server Management Studio.
     3. Read the comment above each test to see what result is
        expected, then compare it with what the query actually
        returns.
   ================================================================ */

USE GreenAcresEMS;
GO


/* ================================================================
   SECTION A: AUDITING & OPERATIONAL TRIGGERS
   Member: Sarvein
   Goal: Prove the audit triggers (log every INSERT/UPDATE/DELETE)
   and the operational triggers (auto-update statuses, auto-create
   commission/notification rows) work correctly.
   Run AFTER 08_triggers.sql.
   ================================================================ */

-- ----------------------------------------------------------------
-- A1: INSERT audit test
-- What we do   : Insert a new Client.
-- Expected     : A new row appears in AuditLog for this Client,
--                with OperationType = 'INSERT', NewValues filled in,
--                and OldValues empty (NULL) because nothing existed before.
-- ----------------------------------------------------------------
INSERT INTO dbo.Clients (FullName, NRIC, ContactNumber, Email, Address, ClientType)
VALUES ('Test Trigger Client', '999999999999', '0100000000', 'test.trigger@example.com', 'Test Address', 'Individual');

DECLARE @TestClientID INT = SCOPE_IDENTITY();

SELECT TOP 1 * FROM dbo.AuditLog
WHERE TableName = 'Clients' AND OperationType = 'INSERT' AND RecordID = CAST(@TestClientID AS NVARCHAR(50))
ORDER BY AuditID DESC;
GO


-- ----------------------------------------------------------------
-- A2: UPDATE audit test
-- What we do   : Update the Email of the Client we just created.
-- Expected     : A new AuditLog row with OperationType = 'UPDATE',
--                OldValues shows the previous email, NewValues shows the new one.
-- ----------------------------------------------------------------
DECLARE @TestClientID INT = (SELECT TOP 1 ClientID FROM dbo.Clients WHERE FullName = 'Test Trigger Client');

UPDATE dbo.Clients
SET Email = 'updated.trigger@example.com'
WHERE ClientID = @TestClientID;

SELECT TOP 1 * FROM dbo.AuditLog
WHERE TableName = 'Clients' AND OperationType = 'UPDATE' AND RecordID = CAST(@TestClientID AS NVARCHAR(50))
ORDER BY AuditID DESC;
GO


-- ----------------------------------------------------------------
-- A3: DELETE audit test
-- What we do   : Delete the test Client.
-- Expected     : A new AuditLog row with OperationType = 'DELETE',
--                OldValues filled in, NewValues empty (NULL).
-- ----------------------------------------------------------------
DECLARE @TestClientID INT = (SELECT TOP 1 ClientID FROM dbo.Clients WHERE FullName = 'Test Trigger Client');

DELETE FROM dbo.Clients WHERE ClientID = @TestClientID;

SELECT TOP 1 * FROM dbo.AuditLog
WHERE TableName = 'Clients' AND OperationType = 'DELETE' AND RecordID = CAST(@TestClientID AS NVARCHAR(50))
ORDER BY AuditID DESC;
GO


-- ----------------------------------------------------------------
-- A4: Multi-row audit test
-- What we do   : Run one UPDATE statement that touches MANY Agent rows at once.
-- Expected     : One AuditLog row is created PER row changed, not just
--                one row for the whole statement. AgentsUpdated should
--                equal AuditRowsAdded, and Result should say PASS.
-- ----------------------------------------------------------------
DECLARE @BeforeCount INT = (SELECT COUNT(*) FROM dbo.AuditLog WHERE TableName = 'Agents' AND OperationType = 'UPDATE');
DECLARE @AffectedRows INT = (SELECT COUNT(*) FROM dbo.Agents WHERE CommissionRate < 2.00);

UPDATE dbo.Agents SET CommissionRate = CommissionRate  -- no real change, just enough to fire the trigger
WHERE CommissionRate < 2.00;

DECLARE @AfterCount INT = (SELECT COUNT(*) FROM dbo.AuditLog WHERE TableName = 'Agents' AND OperationType = 'UPDATE');

SELECT @AffectedRows AS AgentsUpdated, (@AfterCount - @BeforeCount) AS AuditRowsAdded,
       CASE WHEN @AffectedRows = (@AfterCount - @BeforeCount) THEN 'PASS' ELSE 'FAIL' END AS Result;
GO


-- ----------------------------------------------------------------
-- A5: Operational trigger - Sale marks Property as Sold
-- What we do   : Insert a new Sale transaction for an Available property.
-- Expected     : That Property's Status automatically becomes 'Sold'.
-- ----------------------------------------------------------------
DECLARE @PropID INT = (SELECT TOP 1 PropertyID FROM dbo.Properties WHERE Status = 'Available');
DECLARE @ClientID INT = (SELECT TOP 1 ClientID FROM dbo.Clients);
DECLARE @AgentID INT = (SELECT TOP 1 AgentID FROM dbo.Agents);

INSERT INTO dbo.Transactions (PropertyID, ClientID, AgentID, TransactionType, Amount, PaymentStatus)
VALUES (@PropID, @ClientID, @AgentID, 'Sale', 500000.00, 'Completed');

SELECT PropertyID, Status FROM dbo.Properties WHERE PropertyID = @PropID;
-- Expected Status = 'Sold'
GO


-- ----------------------------------------------------------------
-- A6: Operational trigger - Transaction auto-creates Commission
-- What we do   : Look at the last Transaction inserted (from A5).
-- Expected     : A matching CommissionPayments row exists, and its
--                CommissionAmount = Transaction Amount x Agent's rate / 100.
--                Result column should say PASS.
-- ----------------------------------------------------------------
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


-- ----------------------------------------------------------------
-- A7: Operational trigger - Terminating a Lease frees up the Property
-- What we do   : Change an Active lease's status to 'Terminated'.
-- Expected     : The linked Property goes back to 'Available' (unless
--                it was already Sold), and exactly 1 new Notification is created.
-- ----------------------------------------------------------------
DECLARE @LeaseID INT = (SELECT TOP 1 LeaseID FROM dbo.LeaseAgreements WHERE LeaseStatus = 'Active');
DECLARE @LeasePropID INT = (SELECT PropertyID FROM dbo.LeaseAgreements WHERE LeaseID = @LeaseID);
DECLARE @NotifCountBefore INT = (SELECT COUNT(*) FROM dbo.Notifications WHERE RelatedTable = 'LeaseAgreements' AND RelatedRecordID = @LeaseID);

UPDATE dbo.LeaseAgreements SET LeaseStatus = 'Terminated' WHERE LeaseID = @LeaseID;

SELECT
    (SELECT Status FROM dbo.Properties WHERE PropertyID = @LeasePropID) AS PropertyStatusAfter,
    (SELECT COUNT(*) FROM dbo.Notifications WHERE RelatedTable = 'LeaseAgreements' AND RelatedRecordID = @LeaseID) - @NotifCountBefore AS NewNotifications;
-- Expected: PropertyStatusAfter = 'Available' (unless it was 'Sold'), NewNotifications = 1
GO


-- ----------------------------------------------------------------
-- A8: Operational trigger - Completing a maintenance request
-- What we do   : Mark a MaintenanceRequest (that has a Client attached)
--                as 'Completed'.
-- Expected     : CompletedDate gets filled in automatically, and
--                1 new Notification is created.
-- ----------------------------------------------------------------
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


-- ----------------------------------------------------------------
-- A9: Masking/encryption does not break the audit trigger
-- What we do   : Insert another test Client (encrypted/masked columns exist).
-- Expected     : NewValues in AuditLog still captures the encrypted
--                column as a Base64 string, with no errors - this works
--                because the trigger runs WITH EXECUTE AS OWNER, so it
--                can read the data even if the current user cannot.
-- ----------------------------------------------------------------
INSERT INTO dbo.Clients (FullName, NRIC, ContactNumber, Email, Address, ClientType)
VALUES ('Masking Test Client', '888888888888', '0111111111', 'masking.test@example.com', 'Masking Test Address', 'Individual');

SELECT TOP 1 NewValues FROM dbo.AuditLog
WHERE TableName = 'Clients' AND OperationType = 'INSERT'
ORDER BY AuditID DESC;

-- cleanup so this test can be re-run safely
DELETE FROM dbo.Clients WHERE FullName = 'Masking Test Client';
GO


-- ----------------------------------------------------------------
-- A10: Summary - everything the audit log has captured so far
-- ----------------------------------------------------------------
SELECT TableName, OperationType, COUNT(*) AS EventCount
FROM dbo.AuditLog
GROUP BY TableName, OperationType
ORDER BY TableName, OperationType;
GO



/* ================================================================
   SECTION B: DATA PROTECTION (MASKING / ENCRYPTION / HASHING)
   Member: Irfan
   Goal: Prove that sensitive data is masked for normal users,
   properly encrypted at rest, and passwords are stored as salted
   hashes instead of plain text.
   ================================================================ */

-- ----------------------------------------------------------------
-- B1: List every masked column that was set up
-- Expected: One row per masked column across all the listed tables.
-- ----------------------------------------------------------------
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


-- ----------------------------------------------------------------
-- B2: Confirm encrypted Client columns look unreadable
-- Expected: The *_Encrypted columns show random binary bytes,
--           not the plain NRIC/ContactNumber/Email/Address values.
-- ----------------------------------------------------------------
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


-- ----------------------------------------------------------------
-- B3: Decrypt Client data using the symmetric key
-- Expected: Once the key is opened, the Decrypted* columns show the
--           original readable values again.
-- ----------------------------------------------------------------
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


-- ----------------------------------------------------------------
-- B4: Confirm the lease document path is encrypted
-- Expected: AgreementDocPath_Encrypted shows binary, not the plain path.
-- ----------------------------------------------------------------
SELECT TOP 10
    LeaseID,
    TransactionID,
    AgreementDocPath,
    AgreementDocPath_Encrypted
FROM dbo.LeaseAgreements;
GO


-- ----------------------------------------------------------------
-- B5: Decrypt the lease document path
-- Expected: DecryptedAgreementDocPath matches the original plain path.
-- ----------------------------------------------------------------
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


-- ----------------------------------------------------------------
-- B6: Confirm passwords are never stored as plain text
-- Expected: PasswordSaltSecure and PasswordHashSecure show unreadable
--           binary values, never the actual password.
-- ----------------------------------------------------------------
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


-- ----------------------------------------------------------------
-- B7: Update a password and verify login works correctly
-- Expected: Correct password -> "Login Successful".
--           Wrong password   -> "Invalid Login".
-- ----------------------------------------------------------------
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


-- ----------------------------------------------------------------
-- B8: Final summary - which data protection features actually exist
-- Expected: Every SecurityFeature row shows a count greater than 0.
-- ----------------------------------------------------------------
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



/* ================================================================
   SECTION C: ACCESS CONTROL (ROLES / USERS / VIEWS / PROCEDURES)
   Member: Rama
   Goal: Prove that each database role only has the permissions it
   should have - no more, no less (principle of least privilege).

   Technique used:
     EXECUTE AS USER = '...'  -> temporarily "become" that user
     REVERT                  -> switch back to your own login
                                 (ALWAYS run this after each test)
   Run AFTER access_control.sql.
   ================================================================ */

-- ----------------------------------------------------------------
-- C1: Confirm all roles exist and have members
-- Expected: 6 roles listed (role_...), each with at least 1 member.
-- ----------------------------------------------------------------
SELECT r.name AS RoleName, m.name AS MemberName
FROM sys.database_role_members rm
JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
JOIN sys.database_principals m ON m.principal_id = rm.member_principal_id
WHERE r.name LIKE 'role_%'
ORDER BY RoleName, MemberName;
GO


-- ----------------------------------------------------------------
-- C2: Confirm every SystemUsers.UserRole has a matching database role
-- Expected: RoleStatus = 'EXISTS' for every distinct UserRole value.
-- ----------------------------------------------------------------
SELECT DISTINCT
    su.UserRole,
    'role_' + su.UserRole AS ExpectedRoleName,
    CASE WHEN dp.name IS NOT NULL THEN 'EXISTS' ELSE 'MISSING' END AS RoleStatus
FROM dbo.SystemUsers su
LEFT JOIN sys.database_principals dp
    ON dp.name = 'role_' + su.UserRole
    AND dp.type = 'R';
GO


-- ----------------------------------------------------------------
-- C3: role_ReadOnly CAN read a safe view
-- Expected: Rows returned successfully from vw_PropertyListing.
-- ----------------------------------------------------------------
EXECUTE AS USER = 'jason.lim';          -- jason.lim is in role_ReadOnly
    SELECT TOP 5 PropertyID, PropertyName, City, Status
    FROM vw_PropertyListing;
REVERT;
GO


-- ----------------------------------------------------------------
-- C4: role_ReadOnly is BLOCKED from a sensitive base table
-- Expected: Permission denied error (this proves least privilege works).
-- ----------------------------------------------------------------
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


-- ----------------------------------------------------------------
-- C5: role_Analyst sees MASKED personal data (linked to Irfan's masking)
-- Expected: hakim.zulkifli (no UNMASK permission) sees masked
--           NRIC, ContactNumber and Email values, not the real ones.
-- ----------------------------------------------------------------
EXECUTE AS USER = 'hakim.zulkifli';    -- role_Analyst
    SELECT TOP 5 ClientID, FullName, NRIC, ContactNumber, Email
    FROM vw_ClientDirectory;
REVERT;
GO


-- ----------------------------------------------------------------
-- C6: role_Admin sees UNMASKED personal data (UNMASK permission granted)
-- Expected: farid.rahman sees the real NRIC and Email values.
-- ----------------------------------------------------------------
EXECUTE AS USER = 'farid.rahman';      -- role_Admin
    SELECT TOP 5 ClientID, FullName, NRIC, Email
    FROM dbo.Clients;
REVERT;
GO


-- ----------------------------------------------------------------
-- C7: role_DBA has full access, including unmasked data
-- Expected: arun.kumar sees real values in both Clients and CommissionPayments.
-- ----------------------------------------------------------------
EXECUTE AS USER = 'arun.kumar';        -- role_DBA
    SELECT TOP 5 ClientID, FullName, NRIC, Email FROM dbo.Clients;
    SELECT TOP 3 CommissionID, CommissionAmount FROM dbo.CommissionPayments;
REVERT;
GO


-- ----------------------------------------------------------------
-- C8: role_PropMgmtDev can insert a property THROUGH the procedure
-- Expected: usp_ManageProperty runs successfully.
-- ----------------------------------------------------------------
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


-- ----------------------------------------------------------------
-- C9: role_PropMgmtDev is BLOCKED from writing directly to CommissionPayments
-- Expected: Direct INSERT is denied (they must go through approved procedures only).
-- ----------------------------------------------------------------
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


-- ----------------------------------------------------------------
-- C10: role_ClientPortalDev can create a client THROUGH the procedure
-- Expected: New client row is inserted successfully.
-- ----------------------------------------------------------------
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


-- ----------------------------------------------------------------
-- C11: Stored procedure rejects bad input
-- Expected: usp_UpdatePropertyStatus raises an error for a status
--           value that isn't allowed (e.g. 'Invalid-Status').
-- ----------------------------------------------------------------
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


-- ----------------------------------------------------------------
-- C12: role_Analyst can read reporting/summary views
-- Expected: Both views return data rows successfully.
-- ----------------------------------------------------------------
EXECUTE AS USER = 'hakim.zulkifli';   -- role_Analyst
    SELECT * FROM vw_MonthlySalesSummary;
    SELECT TOP 5 AgentName, TotalSales, TotalTransactionValue
    FROM vw_AgentPerformance
    ORDER BY TotalTransactionValue DESC;
REVERT;
GO


-- ----------------------------------------------------------------
-- C13: role_Analyst CANNOT run a write procedure
-- Expected: EXECUTE permission on usp_ManageProperty is denied.
-- ----------------------------------------------------------------
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


-- ----------------------------------------------------------------
-- C14: usp_ProvisionUser successfully adds a new user
-- Expected: Login, database user, and role membership are all created.
-- ----------------------------------------------------------------
EXEC dbo.usp_ProvisionUser
    @LoginName = 'test.newstaff',
    @Password  = 'Test@NewStaff#2026',
    @RoleName  = 'role_Analyst';
GO


-- ----------------------------------------------------------------
-- C15: usp_DeprovisionUser successfully removes that user
-- Expected: test.newstaff is removed from roles, database user
--           dropped, and login dropped - nothing left behind.
-- ----------------------------------------------------------------
EXEC dbo.usp_DeprovisionUser @LoginName = 'test.newstaff';
GO


-- ----------------------------------------------------------------
-- C16: usp_ProvisionUser rejects a missing/NULL password
-- Expected: 'PASS: NULL parameter rejected -> ...' is printed.
-- ----------------------------------------------------------------
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


/* ================================================================
   END OF TEST_CASES.SQL
   ================================================================ */
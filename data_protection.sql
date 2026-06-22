/* ============================================================
   07_data_protection.sql
   Green Acres Realty Sdn Bhd - EMS Database Security

   Focus Area:
   1. Dynamic Data Masking
   2. Column-Level Encryption
   3. Hashing with Salting

   Scope:
   This script only modifies existing EMS data/table structures.
   It does not create roles, users, permissions, audits, triggers,
   or backup logic because those are handled by other members.
   ============================================================ */

USE GreenAcresEMS;
GO


/* ============================================================
   BLOCK 1: DYNAMIC DATA MASKING - CLIENTS TABLE
   ------------------------------------------------------------
   Purpose:
   Protect client personally identifiable information (PII).
   These columns are already present in the current GitHub schema:
   - NRIC
   - ContactNumber
   - Email
   - Address
   ============================================================ */

IF NOT EXISTS (
    SELECT 1
    FROM sys.masked_columns
    WHERE object_id = OBJECT_ID('dbo.Clients')
      AND name = 'NRIC'
)
BEGIN
    ALTER TABLE dbo.Clients
    ALTER COLUMN NRIC ADD MASKED WITH (FUNCTION = 'partial(0, "XXXXXX", 4)');
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
    ALTER COLUMN ContactNumber ADD MASKED WITH (FUNCTION = 'partial(3, "XXXXXXX", 2)');
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
    ALTER COLUMN Email ADD MASKED WITH (FUNCTION = 'email()');
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
    ALTER COLUMN Address ADD MASKED WITH (FUNCTION = 'partial(8, "XXXXXXXXXX", 0)');
END;
GO


/* ============================================================
   BLOCK 2: DYNAMIC DATA MASKING - AGENTS TABLE
   ------------------------------------------------------------
   Purpose:
   Protect agent contact information and commission rate.
   These columns are already present in the current GitHub schema:
   - ContactNumber
   - Email
   - CommissionRate
   ============================================================ */

IF NOT EXISTS (
    SELECT 1
    FROM sys.masked_columns
    WHERE object_id = OBJECT_ID('dbo.Agents')
      AND name = 'ContactNumber'
)
BEGIN
    ALTER TABLE dbo.Agents
    ALTER COLUMN ContactNumber ADD MASKED WITH (FUNCTION = 'partial(3, "XXXXXXX", 2)');
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
    ALTER COLUMN Email ADD MASKED WITH (FUNCTION = 'email()');
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
    ALTER COLUMN CommissionRate ADD MASKED WITH (FUNCTION = 'default()');
END;
GO


/* ============================================================
   BLOCK 3: DYNAMIC DATA MASKING - PROPERTIES TABLE
   ------------------------------------------------------------
   Purpose:
   Protect property location and pricing information.
   These columns are already present in the current GitHub schema:
   - Address
   - Price
   ============================================================ */

IF NOT EXISTS (
    SELECT 1
    FROM sys.masked_columns
    WHERE object_id = OBJECT_ID('dbo.Properties')
      AND name = 'Address'
)
BEGIN
    ALTER TABLE dbo.Properties
    ALTER COLUMN Address ADD MASKED WITH (FUNCTION = 'partial(8, "XXXXXXXXXX", 0)');
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
    ALTER COLUMN Price ADD MASKED WITH (FUNCTION = 'random(100000, 1000000)');
END;
GO


/* ============================================================
   BLOCK 4: DYNAMIC DATA MASKING - TRANSACTIONS TABLE
   ------------------------------------------------------------
   Purpose:
   Protect financial transaction amount.
   This column is already present in the current GitHub schema:
   - Amount
   ============================================================ */

IF NOT EXISTS (
    SELECT 1
    FROM sys.masked_columns
    WHERE object_id = OBJECT_ID('dbo.Transactions')
      AND name = 'Amount'
)
BEGIN
    ALTER TABLE dbo.Transactions
    ALTER COLUMN Amount ADD MASKED WITH (FUNCTION = 'random(1000, 100000)');
END;
GO


/* ============================================================
   BLOCK 5: DYNAMIC DATA MASKING - MAINTENANCE REQUESTS TABLE
   ------------------------------------------------------------
   Purpose:
   Protect maintenance cost information.
   These columns are already present in the current GitHub schema:
   - EstimatedCost
   - ActualCost
   ============================================================ */

IF NOT EXISTS (
    SELECT 1
    FROM sys.masked_columns
    WHERE object_id = OBJECT_ID('dbo.MaintenanceRequests')
      AND name = 'EstimatedCost'
)
BEGIN
    ALTER TABLE dbo.MaintenanceRequests
    ALTER COLUMN EstimatedCost ADD MASKED WITH (FUNCTION = 'random(100, 10000)');
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
    ALTER COLUMN ActualCost ADD MASKED WITH (FUNCTION = 'random(100, 10000)');
END;
GO


/* ============================================================
   BLOCK 6: DYNAMIC DATA MASKING - SYSTEM USERS TABLE
   ------------------------------------------------------------
   Purpose:
   Protect internal staff/user email addresses.
   This column is already present in the current GitHub schema:
   - Email
   ============================================================ */

IF NOT EXISTS (
    SELECT 1
    FROM sys.masked_columns
    WHERE object_id = OBJECT_ID('dbo.SystemUsers')
      AND name = 'Email'
)
BEGIN
    ALTER TABLE dbo.SystemUsers
    ALTER COLUMN Email ADD MASKED WITH (FUNCTION = 'email()');
END;
GO


/* ============================================================
   BLOCK 7: DYNAMIC DATA MASKING - LEASE AGREEMENTS TABLE
   ------------------------------------------------------------
   Purpose:
   Protect rental financial details and agreement document path.
   These columns are already present in the current GitHub schema:
   - MonthlyRent
   - SecurityDeposit
   - AgreementDocPath
   ============================================================ */

IF NOT EXISTS (
    SELECT 1
    FROM sys.masked_columns
    WHERE object_id = OBJECT_ID('dbo.LeaseAgreements')
      AND name = 'MonthlyRent'
)
BEGIN
    ALTER TABLE dbo.LeaseAgreements
    ALTER COLUMN MonthlyRent ADD MASKED WITH (FUNCTION = 'random(1000, 10000)');
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
    ALTER COLUMN SecurityDeposit ADD MASKED WITH (FUNCTION = 'random(1000, 20000)');
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
    ALTER COLUMN AgreementDocPath ADD MASKED WITH (FUNCTION = 'partial(5, "XXXXXXXXXX", 4)');
END;
GO


/* ============================================================
   BLOCK 8: DYNAMIC DATA MASKING - COMMISSION PAYMENTS TABLE
   ------------------------------------------------------------
   Purpose:
   Protect agent commission payment details.
   These columns are already present in the current GitHub schema:
   - CommissionRate
   - CommissionAmount
   ============================================================ */

IF NOT EXISTS (
    SELECT 1
    FROM sys.masked_columns
    WHERE object_id = OBJECT_ID('dbo.CommissionPayments')
      AND name = 'CommissionRate'
)
BEGIN
    ALTER TABLE dbo.CommissionPayments
    ALTER COLUMN CommissionRate ADD MASKED WITH (FUNCTION = 'default()');
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
    ALTER COLUMN CommissionAmount ADD MASKED WITH (FUNCTION = 'random(100, 100000)');
END;
GO


/* ============================================================
   BLOCK 9: DYNAMIC DATA MASKING - MAINTENANCE STAFF TABLE
   ------------------------------------------------------------
   Purpose:
   Protect maintenance staff phone numbers.
   This column is already present in the current GitHub schema:
   - ContactNumber
   ============================================================ */

IF NOT EXISTS (
    SELECT 1
    FROM sys.masked_columns
    WHERE object_id = OBJECT_ID('dbo.MaintenanceStaff')
      AND name = 'ContactNumber'
)
BEGIN
    ALTER TABLE dbo.MaintenanceStaff
    ALTER COLUMN ContactNumber ADD MASKED WITH (FUNCTION = 'partial(3, "XXXXXXX", 2)');
END;
GO


/* ============================================================
   BLOCK 10: CREATE ENCRYPTION OBJECTS
   ------------------------------------------------------------
   Purpose:
   Create SQL Server encryption objects used to encrypt sensitive
   client data.

   Objects created:
   - Database Master Key
   - Certificate
   - Symmetric Key

   The symmetric key uses AES_256.
   ============================================================ */

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
    CREATE SYMMETRIC KEY EMS_ClientDataSymmetricKey
    WITH ALGORITHM = AES_256
    ENCRYPTION BY CERTIFICATE EMS_DataProtectionCertificate;
END;
GO


/* ============================================================
   BLOCK 11: ADD ENCRYPTED COLUMNS TO CLIENTS TABLE
   ------------------------------------------------------------
   Purpose:
   Store encrypted versions of highly sensitive client data.

   Existing sensitive columns:
   - NRIC
   - ContactNumber
   - Email
   - Address

   New encrypted columns:
   - NRIC_Encrypted
   - ContactNumber_Encrypted
   - Email_Encrypted
   - Address_Encrypted

   Original columns are kept for demo/testing because the current
   sample data already uses them.
   ============================================================ */

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


/* ============================================================
   BLOCK 12: ENCRYPT EXISTING CLIENT DATA
   ------------------------------------------------------------
   Purpose:
   Encrypt existing client sensitive data from the current sample
   records and store them in the encrypted columns.

   The encrypted values should appear as unreadable binary data.
   ============================================================ */

OPEN SYMMETRIC KEY EMS_ClientDataSymmetricKey
DECRYPTION BY CERTIFICATE EMS_DataProtectionCertificate;
GO

UPDATE dbo.Clients
SET
    NRIC_Encrypted = EncryptByKey(
        Key_GUID('EMS_ClientDataSymmetricKey'),
        CONVERT(VARBINARY(MAX), NRIC)
    ),
    ContactNumber_Encrypted = EncryptByKey(
        Key_GUID('EMS_ClientDataSymmetricKey'),
        CONVERT(VARBINARY(MAX), ContactNumber)
    ),
    Email_Encrypted = EncryptByKey(
        Key_GUID('EMS_ClientDataSymmetricKey'),
        CONVERT(VARBINARY(MAX), Email)
    ),
    Address_Encrypted = EncryptByKey(
        Key_GUID('EMS_ClientDataSymmetricKey'),
        CONVERT(VARBINARY(MAX), Address)
    )
WHERE
    NRIC_Encrypted IS NULL
    OR ContactNumber_Encrypted IS NULL
    OR Email_Encrypted IS NULL
    OR Address_Encrypted IS NULL;
GO

CLOSE SYMMETRIC KEY EMS_ClientDataSymmetricKey;
GO


/* ============================================================
   BLOCK 13: ADD ENCRYPTED COLUMNS TO LEASE AGREEMENTS TABLE
   ------------------------------------------------------------
   Purpose:
   Store encrypted versions of lease agreement document paths.
   The current table already contains AgreementDocPath.
   ============================================================ */

IF COL_LENGTH('dbo.LeaseAgreements', 'AgreementDocPath_Encrypted') IS NULL
BEGIN
    ALTER TABLE dbo.LeaseAgreements
    ADD AgreementDocPath_Encrypted VARBINARY(MAX) NULL;
END;
GO


/* ============================================================
   BLOCK 14: ENCRYPT LEASE AGREEMENT DOCUMENT PATHS
   ------------------------------------------------------------
   Purpose:
   Encrypt document paths because they may expose internal file
   structure or confidential agreement locations.
   ============================================================ */

OPEN SYMMETRIC KEY EMS_ClientDataSymmetricKey
DECRYPTION BY CERTIFICATE EMS_DataProtectionCertificate;
GO

UPDATE dbo.LeaseAgreements
SET AgreementDocPath_Encrypted = EncryptByKey(
    Key_GUID('EMS_ClientDataSymmetricKey'),
    CONVERT(VARBINARY(MAX), AgreementDocPath)
)
WHERE AgreementDocPath IS NOT NULL
  AND AgreementDocPath_Encrypted IS NULL;
GO

CLOSE SYMMETRIC KEY EMS_ClientDataSymmetricKey;
GO


/* ============================================================
   BLOCK 15: UPGRADE SYSTEM USERS HASHING WITH SECURE SALTING
   ------------------------------------------------------------
   Purpose:
   The current GitHub schema already has:
   - PasswordHash
   - PasswordSalt

   However, the inserted sample data uses visible fixed salts.
   This block adds improved secure columns using:
   - random binary salt
   - SHA2_512 hash
   - password update timestamp

   This avoids creating a new user table and improves the existing
   SystemUsers table directly.
   ============================================================ */

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


/* ============================================================
   BLOCK 16: GENERATE UNIQUE RANDOM SALTS FOR EXISTING USERS
   ------------------------------------------------------------
   Purpose:
   Generate a unique random salt for every existing SystemUsers row.

   Note:
   For assignment/demo purpose, this upgrades all current sample
   users using a temporary standard password value.
   In a real system, each user would reset their own password.
   ============================================================ */

UPDATE dbo.SystemUsers
SET PasswordSaltSecure = CRYPT_GEN_RANDOM(32)
WHERE PasswordSaltSecure IS NULL;
GO


/* ============================================================
   BLOCK 17: GENERATE SECURE HASHES FOR EXISTING USERS
   ------------------------------------------------------------
   Purpose:
   Create a SHA2_512 hash using:
   Temporary password + unique random salt

   The same temporary password will still produce different hashes
   because every user has a different salt.
   ============================================================ */

UPDATE dbo.SystemUsers
SET
    PasswordHashSecure = HASHBYTES(
        'SHA2_512',
        CONVERT(VARBINARY(MAX), N'TempPassword@2026') + PasswordSaltSecure
    ),
    PasswordHashAlgorithm = 'SHA2_512',
    PasswordLastUpdated = GETDATE()
WHERE PasswordHashSecure IS NULL;
GO


/* ============================================================
   BLOCK 18: CREATE PROCEDURE TO UPDATE USER PASSWORD SECURELY
   ------------------------------------------------------------
   Purpose:
   This procedure updates an existing SystemUsers password using:
   - New random salt
   - SHA2_512 salted hash

   This stores no plaintext password.
   ============================================================ */

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
        PasswordLastUpdated = GETDATE()
    WHERE LoginName = @LoginName;
END;
GO


/* ============================================================
   BLOCK 19: CREATE PROCEDURE TO VERIFY SYSTEM USER PASSWORD
   ------------------------------------------------------------
   Purpose:
   Verifies login by hashing the entered password with the stored
   salt and comparing it with the stored secure hash.

   This demonstrates how salted hashing is used during login.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.usp_VerifySystemUserPassword
    @LoginName NVARCHAR(100),
    @PlainPassword NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StoredSalt VARBINARY(32);
    DECLARE @StoredHash VARBINARY(64);
    DECLARE @InputHash VARBINARY(64);

    SELECT
        @StoredSalt = PasswordSaltSecure,
        @StoredHash = PasswordHashSecure
    FROM dbo.SystemUsers
    WHERE LoginName = @LoginName
      AND IsActive = 1;

    IF @StoredSalt IS NULL OR @StoredHash IS NULL
    BEGIN
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
        SELECT
            'Login Successful' AS LoginStatus,
            SystemUserID,
            FullName,
            LoginName,
            UserRole
        FROM dbo.SystemUsers
        WHERE LoginName = @LoginName;
    END
    ELSE
    BEGIN
        SELECT
            'Invalid Login' AS LoginStatus,
            @LoginName AS LoginName;
    END;
END;
GO


/* ============================================================
   BLOCK 20: TEST - VIEW MASKED COLUMNS CONFIGURATION
   ------------------------------------------------------------
   Purpose:
   Shows all masked columns created in this script.
   ============================================================ */

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


/* ============================================================
   BLOCK 21: TEST - VIEW ENCRYPTED CLIENT DATA
   ------------------------------------------------------------
   Purpose:
   Shows that encrypted columns are stored as unreadable binary.
   ============================================================ */

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


/* ============================================================
   BLOCK 22: TEST - DECRYPT CLIENT DATA
   ------------------------------------------------------------
   Purpose:
   Demonstrates that encrypted values can only be meaningfully read
   after opening the symmetric key.
   ============================================================ */

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


/* ============================================================
   BLOCK 23: TEST - VIEW ENCRYPTED LEASE DOCUMENT PATH
   ------------------------------------------------------------
   Purpose:
   Shows encrypted lease agreement document path.
   ============================================================ */

SELECT TOP 10
    LeaseID,
    TransactionID,
    AgreementDocPath,
    AgreementDocPath_Encrypted
FROM dbo.LeaseAgreements;
GO


/* ============================================================
   BLOCK 24: TEST - DECRYPT LEASE DOCUMENT PATH
   ------------------------------------------------------------
   Purpose:
   Demonstrates decryption of encrypted agreement path.
   ============================================================ */

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


/* ============================================================
   BLOCK 25: TEST - VIEW HASHED PASSWORD STORAGE
   ------------------------------------------------------------
   Purpose:
   Shows that passwords are not stored as plaintext.
   PasswordSaltSecure and PasswordHashSecure should appear as
   unreadable binary values.
   ============================================================ */

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


/* ============================================================
   BLOCK 26: TEST - UPDATE PASSWORD AND VERIFY LOGIN
   ------------------------------------------------------------
   Purpose:
   Demonstrates salted password update and login verification.

   Expected result:
   1. Correct password = Login Successful
   2. Wrong password = Invalid Login
   ============================================================ */

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


/* ============================================================
   BLOCK 27: FINAL CHECK - DATA PROTECTION IMPLEMENTATION STATUS
   ------------------------------------------------------------
   Purpose:
   Summarises whether the main data protection objects exist.
   ============================================================ */

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
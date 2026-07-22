-- ============================================================
--   access_control_testcases.sql
--   Green Acres Realty Sdn Bhd - EMS Database Security
--   CT069-3-3 Database Security Assignment
--
--   Member 2 (Rama)
--   Purpose    : Test cases proving Roles / Users / Views /
--                Stored Procedures work correctly. Run AFTER
--                access_control.sql.
--
--   Technique  : EXECUTE AS USER will assume a person from the particular role
--			    REVERT will reset your role (NECESSARY)
--                
--   ============================================================

USE GreenAcresEMS;
GO

-- ============================================================
--   TEST 1: Confirm all 6 roles were created and users assigned
--   Expected: 6 role_entries with at least 2 members
--   ============================================================
SELECT r.name AS RoleName, m.name AS MemberName
FROM sys.database_role_members rm
JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
JOIN sys.database_principals m ON m.principal_id = rm.member_principal_id
WHERE r.name LIKE 'role_%'
ORDER BY RoleName, MemberName;
GO


-- ============================================================
--   TEST 2: Confirm roles match UserRole values in SystemUsers
--   Expected: Every row returns a matching role_name
--   ============================================================
SELECT DISTINCT
    su.UserRole,
    'role_' + su.UserRole AS ExpectedRoleName,
    CASE WHEN dp.name IS NOT NULL THEN 'EXISTS' ELSE 'MISSING' END AS RoleStatus
FROM dbo.SystemUsers su
LEFT JOIN sys.database_principals dp
    ON dp.name = 'role_' + su.UserRole
    AND dp.type = 'R';
GO


-- ============================================================
--   TEST 3: role_ReadOnly can SELECT from a safe view
--   Expected: Rows returned from vw_PropertyListing (SUCCESS).
--   ============================================================
EXECUTE AS USER = 'jason.lim';          -- role_ReadOnly
    SELECT TOP 5 PropertyID, PropertyName, City, Status
    FROM vw_PropertyListing;
REVERT;
GO


-- ============================================================
--   TEST 4: role_ReadOnly is BLOCKED from base tables
--   Expected: SELECT on dbo.CommissionPayments raises a permission-denied error (proving least privilege)
--   ============================================================
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


-- ============================================================
--   TEST 5 (Linked to Irfan's part): DDM masking for role_Analyst
--   Expected: hakim.zulkifli (role_Analyst, no UNMASK) sees masked NRIC, ContactNumber and Email values
--   ============================================================
EXECUTE AS USER = 'hakim.zulkifli';    -- role_Analyst
    SELECT TOP 5 ClientID, FullName, NRIC, ContactNumber, Email
    FROM vw_ClientDirectory;
REVERT;
GO


-- ============================================================
--   TEST 6: role_Admin can see unmasked PII (UNMASK granted)
--   Expected: farid.rahman (role_Admin, UNMASK granted) sees real NRIC and Email values (not masked)
--   ============================================================
EXECUTE AS USER = 'farid.rahman';      -- role_Admin
    SELECT TOP 5 ClientID, FullName, NRIC, Email
    FROM dbo.Clients;
REVERT;
GO


-- ============================================================
--   TEST 7: role_DBA has full control including unmasked PII
--   Expected: arun.kumar (role_DBA, CONTROL = UNMASK) sees real values and can access all tables.
--   ============================================================
EXECUTE AS USER = 'arun.kumar';        -- role_DBA
    SELECT TOP 5 ClientID, FullName, NRIC, Email FROM dbo.Clients;
    SELECT TOP 3 CommissionID, CommissionAmount FROM dbo.CommissionPayments;
REVERT;
GO


-- ============================================================
--   TEST 8: PropMgmtDev inserts a property via procedure
--   Expected: usp_ManageProperty succeeds (no direct table INSERT is needed by this role)
--   ============================================================
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


-- ============================================================
--   TEST 9: PropMgmtDev is BLOCKED from writing CommissionPayments
--   Expected: Direct INSERT denied
--   ============================================================
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


-- ============================================================
--   TEST 10: ClientPortalDev creates a client via procedure
--   Expected: New client row inserted (Can be verified with SELECT)
--   ============================================================
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


-- ============================================================
--   TEST 11: Procedure validation rejects invalid input
--   Expected: usp_UpdatePropertyStatus raises an error for an unrecognised status value.
--   ============================================================
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


-- ============================================================
--   TEST 12: role_Analyst can read aggregate reporting views
--   Expected: Both reporting views return data rows.
--   ============================================================
EXECUTE AS USER = 'hakim.zulkifli';   -- role_Analyst
    SELECT * FROM vw_MonthlySalesSummary;
    SELECT TOP 5 AgentName, TotalSales, TotalTransactionValue
    FROM vw_AgentPerformance
    ORDER BY TotalTransactionValue DESC;
REVERT;
GO


-- ============================================================
--   TEST 13: role_Analyst CANNOT execute a write procedure
--   Expected: EXECUTE on usp_ManageProperty is denied.
--   ============================================================
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

-- EXTRA FUNCTION TESTCASE

-- ============================================================
--   TEST 14: usp_ProvisionUser - Successfully add a new user
--   Expected: All three steps complete and user appears in role_Analyst membership.
--   ============================================================ 
   EXEC dbo.usp_ProvisionUser
    @LoginName = 'test.newstaff',
    @Password  = 'Test@NewStaff#2026',
    @RoleName  = 'role_Analyst';
GO



-- ============================================================
--   TEST 15: usp_DeprovisionUser - Successfully remove user
--   Expected: All three steps complete (test.newstaff removed from roles, database user dropped, login dropped)
--   ============================================================

   EXEC dbo.usp_DeprovisionUser @LoginName = 'test.newstaff';
GO


-- ============================================================
-- Test 16: usp_ProvisionUser cannot proceed due to invalid Password
-- Expected: The correct error message of 'PASS: Null parameter rejected' is outputted
-- ============================================================

BEGIN TRY
    EXEC dbo.usp_ProvisionUser
        @LoginName = 'test.incomplete',
        @Password  = NULL,             -- password not supplied
        @RoleName  = 'role_ReadOnly';
    PRINT 'FAIL: NULL parameter was accepted.';
END TRY
BEGIN CATCH
    PRINT 'PASS: NULL parameter rejected -> ' + ERROR_MESSAGE();
END CATCH;
GO



-- ===========
--   END 
--   =========

# Auditing — Hands-On Walkthrough

Follow these steps in order in SQL Server Management Studio. Each step gives you code to run, the output you should see, and what it proves.

**Every output below was captured from a real run against `GreenAcresEMS`.**

> **Note on ID numbers:** your `AuditID` values will differ from the ones shown here — they depend on how many actions have already been logged. That is normal. What matters is the *pattern* of the result, not the exact numbers.

**Before starting:** open SSMS as Administrator, connect to `.\SQLEXPRESS` using Windows Authentication, and make sure the four setup scripts have already been run in order.

---

## Step 1 — Confirm you are on the right database

```sql
SELECT DB_NAME()      AS CurrentDatabase,
       SUSER_NAME()   AS LoginName,
       IS_SRVROLEMEMBER('sysadmin') AS IsSysadmin;
```

**Expected outcome**

```
CurrentDatabase   LoginName              IsSysadmin
GreenAcresEMS     SANDARIS-ZEPHER\User   1
```

**What this proves**

You are connected to the correct database with sysadmin rights. `IsSysadmin` must be `1` — reading SQL Server Audit files and creating test principals later both require it. If `CurrentDatabase` says `master`, run `USE GreenAcresEMS;` first.

---

## Step 2 — Inspect the AuditLog table structure

```sql
SELECT c.name AS ColumnName,
       t.name AS DataType,
       c.is_nullable
FROM sys.columns c
JOIN sys.types t ON t.user_type_id = c.user_type_id
WHERE c.object_id = OBJECT_ID('dbo.AuditLog')
ORDER BY c.column_id;
```

**Expected outcome — 10 rows**

```
ColumnName        DataType   is_nullable
AuditID           int        0
EventTime         datetime   0
TableName         nvarchar   0
OperationType     nvarchar   0
RecordID          nvarchar   0
ChangedBy         nvarchar   0
OldValues         nvarchar   1
NewValues         nvarchar   1
ApplicationName   nvarchar   1
HostName          nvarchar   1
```

**What this proves**

This is the evidence store. The six `NOT NULL` columns (`is_nullable = 0`) are the ones that must always be present — an audit record can never exist without a table, operation, record ID and actor.

`OldValues` and `NewValues` are nullable **by design**, because an `INSERT` has no "before" state and a `DELETE` has no "after" state. You will see this directly in Step 6.

---

## Step 3 — Confirm all eight triggers are enabled

```sql
SELECT t.name        AS TriggerName,
       OBJECT_NAME(t.parent_id) AS TableName,
       CASE WHEN t.is_disabled = 0 THEN 'Enabled' ELSE 'DISABLED' END AS Status
FROM sys.triggers t
WHERE t.name LIKE '%_Audit'
ORDER BY t.name;
```

**Expected outcome — 8 rows, all `Enabled`**

```
TriggerName                     TableName             Status
trg_Agents_Audit                Agents                Enabled
trg_Clients_Audit               Clients               Enabled
trg_CommissionPayments_Audit    CommissionPayments    Enabled
trg_LeaseAgreements_Audit       LeaseAgreements       Enabled
trg_MaintenanceRequests_Audit   MaintenanceRequests   Enabled
trg_Properties_Audit            Properties            Enabled
trg_SystemUsers_Audit           SystemUsers           Enabled
trg_Transactions_Audit          Transactions          Enabled
```

**What this proves**

All eight business-critical tables are covered. A trigger that exists but shows `DISABLED` would silently stop logging while still appearing in Object Explorer — which is why the status column matters, not just the row count.

---

## Step 4 — Confirm SQL Server Audit is running

```sql
USE master;
GO

SELECT a.name          AS AuditName,
       a.is_state_enabled,
       f.max_file_size AS MaxFileSizeMB,
       f.max_rollover_files,
       f.log_file_path
FROM sys.server_audits a
JOIN sys.server_file_audits f ON f.audit_id = a.audit_id;
GO
```

**Expected outcome**

```
AuditName            is_state_enabled  MaxFileSizeMB  max_rollover_files  log_file_path
GA_EMS_ServerAudit   1                 20             5                   C:\SQLAudit\
```

**What this proves**

The second audit layer is active and writing to disk. `is_state_enabled = 1` is the critical value. The 20 MB / 5-file rollover means old audit files are recycled automatically instead of filling the drive.

---

## Step 5 — Prove an UPDATE is captured

```sql
USE GreenAcresEMS;
GO

UPDATE dbo.Clients
SET Email = 'walkthrough.demo@example.com'
WHERE ClientID = 1;

SELECT TOP 1 AuditID, TableName, OperationType, RecordID,
             ChangedBy, ApplicationName, HostName
FROM dbo.AuditLog
ORDER BY AuditID DESC;
```

**Expected outcome**

```
AuditID  TableName  OperationType  RecordID  ChangedBy              ApplicationName  HostName
107      Clients    UPDATE         1         SANDARIS-ZEPHER\User   SQLCMD           SANDARIS-ZEPHER
```

(`ApplicationName` will show `Microsoft SQL Server Management Studio - Query` when you run it from SSMS instead of the command line.)

**What this proves**

You changed one column and the trigger fired automatically — no application code was involved and the user could not opt out.

`ChangedBy` is the important field. The trigger runs `WITH EXECUTE AS OWNER`, so a naive implementation using `USER_NAME()` would record `dbo` for every change and lose all accountability. These triggers use `ORIGINAL_LOGIN()`, which preserves the login that actually initiated the statement.

---

## Step 6 — See the before and after values

```sql
SELECT TOP 1
    JSON_VALUE(OldValues, '$.FullName') AS ClientName,
    JSON_VALUE(OldValues, '$.Email')    AS Email_Before,
    JSON_VALUE(NewValues, '$.Email')    AS Email_After
FROM dbo.AuditLog
WHERE TableName = 'Clients'
ORDER BY AuditID DESC;
```

**Expected outcome**

```
ClientName   Email_Before          Email_After
Ali Ahmad    ali.ahmad@gmail.com   walkthrough.demo@example.com
```

**What this proves**

This is the **history requirement** satisfied. The audit trail does not merely record that a change happened — it preserves the original value, so a wrong or malicious change can be identified and reversed.

`JSON_VALUE` pulls a single field out of the stored JSON. Use this in your demo instead of showing the raw JSON blob, which is too wide to read on screen.

---

## Step 7 — Prove INSERT and DELETE are captured

```sql
INSERT dbo.Clients (FullName, NRIC, ContactNumber, Email, Address, ClientType)
VALUES ('Temp Delete Demo', '990101011234', '0199999999',
        'temp@demo.com', 'Test Address', 'Individual');

DECLARE @id INT = SCOPE_IDENTITY();
DELETE FROM dbo.Clients WHERE ClientID = @id;

SELECT TOP 2 AuditID, OperationType, RecordID,
       JSON_VALUE(COALESCE(NewValues, OldValues), '$.FullName') AS NameInJson
FROM dbo.AuditLog
WHERE TableName = 'Clients'
ORDER BY AuditID DESC;
```

**Expected outcome — 2 rows**

```
AuditID  OperationType  RecordID  NameInJson
112      DELETE         52        Temp Delete Demo
111      INSERT         52        Temp Delete Demo
```

**What this proves**

All three operation types are covered, and the record survives its own deletion. The client row no longer exists in `dbo.Clients`, but `AuditID 112` still holds its full contents in `OldValues`.

That is the point of audit logging: **deleting the data does not delete the evidence.** Note both rows share `RecordID 52`, so the full life cycle of that record can be reconstructed.

`COALESCE(NewValues, OldValues)` is used because the `DELETE` row has no `NewValues` and the `INSERT` row has no `OldValues` — exactly as predicted in Step 2.

---

## Step 8 — Prove credentials are never logged

```sql
UPDATE dbo.SystemUsers
SET Email = 'newmail@greenacres.com'
WHERE SystemUserID = 1;

SELECT TOP 1 NewValues
FROM dbo.AuditLog
WHERE TableName = 'SystemUsers'
ORDER BY AuditID DESC;
```

**Expected outcome**

```json
{"SystemUserID":1,"DepartmentID":1,"FullName":"Farid Rahman",
 "LoginName":"farid.rahman","Email":"newmail@greenacres.com",
 "UserRole":"Admin","IsActive":true,"CreatedDate":"2026-07-30T13:48:41.983"}
```

**What this proves**

There is **no `PasswordHash` and no `PasswordSalt`** in that JSON, even though both columns exist in `dbo.SystemUsers`.

Every other trigger uses `SELECT i.*` to capture the whole row. The `SystemUsers` trigger deliberately lists columns individually so credential material is excluded. Without this, the audit log — a table many administrators can read — would become a second copy of every password hash in the system.

Run this to confirm it automatically:

```sql
SELECT TOP 1
    CASE WHEN NewValues LIKE '%PasswordHash%' OR NewValues LIKE '%PasswordSalt%'
         THEN 'FAIL - credentials leaked'
         ELSE 'PASS - no credential fields in audit JSON' END AS CredentialCheck
FROM dbo.AuditLog
WHERE TableName = 'SystemUsers'
ORDER BY AuditID DESC;
```

```
CredentialCheck
PASS - no credential fields in audit JSON
```

---

## Step 9 — Prove bulk updates cannot escape the audit

```sql
DECLARE @before INT = (SELECT COUNT(*) FROM dbo.AuditLog);

UPDATE dbo.Agents SET CommissionRate = CommissionRate;   -- touches every row

SELECT @@ROWCOUNT                                        AS RowsUpdated,
       (SELECT COUNT(*) FROM dbo.AuditLog) - @before     AS AuditRowsWritten;
```

**Expected outcome**

```
RowsUpdated   AuditRowsWritten
50            50
```

**What this proves**

**This is the strongest result in your whole section.** The two numbers must be equal.

A trigger fires *once per statement*, not once per row. Writing one audit row per firing is the classic mistake — a 50-row update would produce a single audit entry and 49 changes would vanish. An attacker who knew this could hide modifications by batching them into one statement.

These triggers `SELECT ... FROM inserted` (a set), so one row is written for every affected row. `50 = 50` proves bulk modification cannot evade the audit trail.

Lead with this in your demo video.

---

## Step 10 — Prove the audit log is protected

```sql
BEGIN TRY
    IF DATABASE_PRINCIPAL_ID('WalkthroughTestUser') IS NOT NULL
        DROP USER WalkthroughTestUser;
    CREATE USER WalkthroughTestUser WITHOUT LOGIN;
    ALTER ROLE role_ReadOnly ADD MEMBER WalkthroughTestUser;

    EXECUTE AS USER = 'WalkthroughTestUser';
        SELECT TOP 1 * FROM dbo.AuditLog;    -- should fail
    REVERT;
END TRY
BEGIN CATCH
    REVERT;
    SELECT 'PASS - blocked' AS Result, ERROR_MESSAGE() AS Detail;
END CATCH;

DROP USER WalkthroughTestUser;
```

**Expected outcome**

```
Result           Detail
PASS - blocked   The SELECT permission was denied on the object 'AuditLog',
                 database 'GreenAcresEMS', schema 'dbo'.
```

**What this proves**

> **An error message here is the CORRECT result.** Do not mistake it for a failure.

A `role_ReadOnly` member can read business data but is explicitly denied the audit log. If a low-privilege account could read the log it could identify what is being monitored; if it could write to the log it could erase its own tracks. The evidence is deliberately placed beyond the roles being audited.

The script cleans up after itself — the test user is dropped at the end.

---

## Step 11 — Prove the retention guard works

```sql
BEGIN TRY
    EXEC dbo.usp_ArchiveAuditLog @RetainDays = 10;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS ErrNum, ERROR_MESSAGE() AS ErrMsg;
END CATCH;
```

**Expected outcome**

```
ErrNum   ErrMsg
50001    RetainDays must be at least 30 days.
```

**What this proves**

Again, the error **is** the pass condition. The archive procedure refuses to accept a retention period under 30 days, so nobody can call it with `@RetainDays = 0` and flush the entire audit history under the appearance of routine maintenance.

Only `role_DBA` holds `EXECUTE` on this procedure, and it moves rows into `AuditLogArchive` inside a transaction rather than deleting them.

To run it legitimately: `EXEC dbo.usp_ArchiveAuditLog @RetainDays = 365;`

---

## Step 12 — Read the SQL Server Audit file

```sql
SELECT TOP 20 event_time, action_id, succeeded,
              server_principal_name, object_name, statement
FROM sys.fn_get_audit_file('C:\SQLAudit\*.sqlaudit', DEFAULT, DEFAULT)
ORDER BY event_time DESC;
```

**Expected outcome — a sample**

```
event_time                    action_id  succeeded  server_principal_name  object_name
2026-07-30 06:11:23.1200299   SL         1          SANDARIS-ZEPHER\User   AuditLog
2026-07-30 06:11:23.1172475   IN         1          SANDARIS-ZEPHER\User   AuditLog
```

**What this proves**

This is the second layer, and it captures what triggers cannot. Common `action_id` codes: `SL` = select, `IN` = insert, `UP` = update, `G` = grant, `CR` = create, `DR` = drop, `LGIS` = successful login.

Notice the audit specification recorded reads against `AuditLog` **itself** — the system audits access to its own evidence. If someone with legitimate rights inspects the audit log, that inspection is also recorded.

The `statement` column holds the full SQL text, so you can see exactly what was executed rather than only that something happened.

---

## Summary — what to show the marker

| Step | Demonstrates |
|---:|---|
| 3 | Coverage — all 8 tables audited |
| 5–6 | History requirement — before/after values preserved |
| 7 | Evidence survives deletion of the data |
| 8 | Security-aware design — credentials never logged |
| **9** | **Correctness — bulk updates cannot evade the audit** |
| 10 | Integrity — evidence protected from the audited roles |
| 11 | Retention cannot be abused to destroy history |
| 12 | Second layer — security events beyond table changes |

Steps 8, 9 and 10 are the ones that distinguish a working implementation from a well-designed one. Be ready to explain *why* each matters, not just that it passes.

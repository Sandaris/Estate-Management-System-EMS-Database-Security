# Auditing — Run and Verification Guide (Member 4)

How to deploy the auditing solution and verify it in SQL Server Management Studio.

---

## Part 1 — What auditing is implemented

The solution uses **two independent layers**. They answer different questions, and neither is sufficient alone.

### Layer 1 — DML triggers (data history)

Answers: *"What did this row look like before it was changed?"*

Eight `AFTER INSERT, UPDATE, DELETE` triggers write into the `AuditLog` table.

| Trigger | Table |
|---|---|
| `trg_Clients_Audit` | `Clients` |
| `trg_Properties_Audit` | `Properties` |
| `trg_Agents_Audit` | `Agents` |
| `trg_Transactions_Audit` | `Transactions` |
| `trg_CommissionPayments_Audit` | `CommissionPayments` |
| `trg_LeaseAgreements_Audit` | `LeaseAgreements` |
| `trg_MaintenanceRequests_Audit` | `MaintenanceRequests` |
| `trg_SystemUsers_Audit` | `SystemUsers` |

Each audit row records **who / what / when / where / before / after**:

- `ChangedBy` — uses `ORIGINAL_LOGIN()`, so the real login is kept even though the trigger runs `WITH EXECUTE AS OWNER`
- `OldValues` / `NewValues` — the full row as JSON
- `ApplicationName`, `HostName`, `EventTime`

Two design points worth knowing for your viva:

1. **The triggers are set-based.** One `UPDATE` affecting 50 rows writes 50 audit rows. Row-by-row trigger logic is the common mistake and silently loses evidence.
2. **`trg_SystemUsers_Audit` deliberately excludes `PasswordHash` and `PasswordSalt`**, so the audit trail never becomes a second source of credential material.

### Layer 2 — SQL Server Audit (security events)

Answers: *"What was done to the system?"* — things a table trigger physically cannot see.

| Object | Scope | Captures |
|---|---|---|
| `GA_EMS_ServerAudit` | Server | Writes to `C:\SQLAudit\`, 20 MB per file, 5 rollover files |
| `GA_EMS_ServerAuditSpec` | Server | 6 groups: successful + failed logins, server permission / principal / role changes, and `AUDIT_CHANGE_GROUP` |
| `GA_EMS_DatabaseAuditSpec` | Database | 22 actions: database principal / permission / role changes, schema changes, and `SELECT`/`UPDATE`/`DELETE` on `Clients`, `Transactions`, `CommissionPayments`, `AuditLog`, `AuditLogArchive` |

A trigger cannot detect a failed login, a `GRANT`, or someone disabling auditing. That is why this layer exists.

### Layer 3 — Protecting the evidence

An audit trail an attacker can read or delete is worthless, so the log is placed beyond the roles being audited:

- `role_DBA` and `role_Admin` — `SELECT` granted
- `role_PropMgmtDev`, `role_ClientPortalDev`, `role_Analyst`, `role_ReadOnly` — `SELECT`, `INSERT`, `UPDATE`, `DELETE` **denied**
- `usp_ArchiveAuditLog` — `EXECUTE` granted to `role_DBA` only; moves rows older than the retention period into `AuditLogArchive` inside a transaction

---

## Part 2 — Before you start

1. **Open SSMS as Administrator.** `CREATE SERVER AUDIT` requires sysadmin.
2. **Connect to** `.\SQLEXPRESS` using **Windows Authentication**.
3. **Confirm `C:\SQLAudit\` exists.** If SQL Server cannot write there, `08_auditing.sql` fails.

> **Warning:** Step 1 below drops and recreates `GreenAcresEMS`. Any data or screenshots you still need must be saved first.

---

## Part 3 — Run the scripts

Run these **in order**, as four separate files. Wait for each to finish before starting the next.

| Step | File | Creates |
|---:|---|---|
| 1 | `Compiled SQL file.sql` | Database, 13 tables, 7 views, 14 procedures, roles, users, permissions |
| 2 | `08_auditing.sql` | `AuditLog`, `AuditLogArchive`, retention procedure, audit access control, both audit specifications |
| 3 | `09_audit_triggers.sql` | The 8 row-history triggers |
| 4 | `auditing_testcases.sql` | Nothing — runs the 12 verification tests |

For each file: **File → Open → File…**, then press **F5**.

Scripts 1–3 should end with no red error text. Script 2 finishes with `Auditing setup completed.` and script 3 with `Eight row-history audit triggers created successfully.`

> **Important:** SSMS keeps running after a batch error and still looks like it succeeded. Always check the **Messages** tab for red text — do not judge by the script reaching the end. This is exactly how the broken-views bug went unnoticed.

---

## Part 4 — Read the test results

Script 4 returns one result grid per test in the **Results** pane. Switch to the grid view (`Ctrl` + `D`) and scroll through.

| Test | Checks | Expected |
|---:|---|---|
| 1 | `AuditLog` table exists | `PASS` |
| 2 | Audit triggers exist | 8 rows, all `Enabled` |
| 3 | `UPDATE` is recorded | `PASS`, before/after JSON visible |
| 4 | `INSERT` is recorded | `PASS`, new-row JSON visible |
| 5 | ReadOnly user blocked from `AuditLog` | `PASS` + permission-denied message |
| 6 | SQL Server Audit enabled | `PASS` |
| 7 | Audit file readable | ~25 rows of real audit events |
| 8 | Specifications contain required actions | 6 server + 22 database actions |
| 9 | **Multi-row correctness** | 50 rows updated → 50 audit rows → `PASS` |
| 10 | Permission / role / schema events captured | 8 event rows |
| 11 | Retention moves rows to archive | `PASS`, 365-day cutoff |
| 12 | Login audit evidence | Login events listed |

**Expected total: 10 `PASS` results, 0 `FAIL`.**

Test 5's evidence is the error message itself:

```
The SELECT permission was denied on the object 'AuditLog',
database 'GreenAcresEMS', schema 'dbo'.
```

That is a **passing** result — the user was correctly refused.

---

## Part 5 — Manual checks in SSMS

Useful for the demo video, where showing a live query is stronger than showing a script's own output.

**See the audit triggers in Object Explorer:**
`GreenAcresEMS` → Tables → `dbo.Clients` → Triggers → `trg_Clients_Audit`

**See the audit objects:**
`Security` → Audits → `GA_EMS_ServerAudit` (green arrow = enabled)
`Security` → Server Audit Specifications → `GA_EMS_ServerAuditSpec`
`GreenAcresEMS` → Security → Database Audit Specifications → `GA_EMS_DatabaseAuditSpec`

**Prove a change is captured — run this yourself and show the result:**

```sql
USE GreenAcresEMS;
GO

UPDATE dbo.Clients
SET Email = 'demo.viva@example.com'
WHERE ClientID = 1;
GO

SELECT TOP 5 AuditID, EventTime, TableName, OperationType,
             RecordID, ChangedBy, ApplicationName, HostName
FROM dbo.AuditLog
ORDER BY AuditID DESC;
GO
```

**Prove the multi-row behaviour — the strongest single demo:**

```sql
DECLARE @before INT = (SELECT COUNT(*) FROM dbo.AuditLog);

UPDATE dbo.Agents SET CommissionRate = CommissionRate;   -- touches every row

SELECT @@ROWCOUNT                                  AS RowsUpdated,
       (SELECT COUNT(*) FROM dbo.AuditLog) - @before AS AuditRowsWritten;
```

Both numbers must match. That proves a bulk update cannot slip past the audit trail.

**Read the SQL Server Audit file directly:**

```sql
SELECT TOP 20 event_time, action_id, succeeded,
              server_principal_name, object_name, statement
FROM sys.fn_get_audit_file('C:\SQLAudit\*.sqlaudit', DEFAULT, DEFAULT)
ORDER BY event_time DESC;
```

---

## Part 6 — Screenshots to capture

1. Object Explorer showing the 8 audit triggers
2. Test 2 grid — all triggers `Enabled`
3. Test 3 grid — the `UPDATE` with before/after JSON
4. Test 5 grid — the permission-denied result
5. Test 6 grid — `GA_EMS_ServerAudit` enabled
6. Test 8 grid — the audited-action list
7. **Test 9 grid — 50 rows → 50 audit rows**
8. Test 11 grid — the archive result
9. `sys.fn_get_audit_file` output
10. A failed-login attempt appearing in the audit file

---

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| `CREATE SERVER AUDIT` fails | Not sysadmin, or `C:\SQLAudit\` unwritable | Reopen SSMS as Administrator; create the folder |
| `Msg 1844 ... COMPRESSION` | Express Edition limitation | Already handled — the three `COMPRESSION` lines are commented out |
| `Msg 111 'CREATE VIEW' must be the first statement` | Missing `GO` separators | Fixed in commit `42d39d9`; make sure you have pulled it |
| Test 5 shows an error instead of `PASS` | Misreading the output | The permission-denied message **is** the pass condition |
| `AuditLog` is empty | Scripts run out of order | Re-run steps 2 → 3 → 4 in sequence |

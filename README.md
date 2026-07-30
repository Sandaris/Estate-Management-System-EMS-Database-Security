# Estate Management System (EMS) — Database Security

**Green Acres Realty Sdn Bhd** · CT069-3-3 Database Security · Group Assignment, 04-2026

Green Acres Realty had its Estate Management System built by an outside software house. One team wrote the front end, the back end, the database and the "security", which in practice meant access control, user privileges, auditing and data obfuscation were never considered at all. The company is now standing up its own IT division — property management development, client portal development, analytics, database administration — and migrating the EMS in-house.

This repository is the database-security solution for that migration. The clients are **developers in other IT departments, not end users**, so every control here is written on the assumption that the people connecting are technically capable and should still only reach what their job requires.

The original developer script (Appendix I of the brief) is five bare tables with no constraints, no roles, no auditing and no protection of any kind. What follows is built on top of it.

---

## Files

| File | Lines | What it is |
|---|---|---|
| **`Compiled_code.sql`** | 4,191 | The whole build, in dependency order — 19 numbered parts, run top to bottom. |
| **`test_cases.sql`** | 1,544 | The 77 test cases, run after the build. |
| `DBS Assignment Question.pdf` | — | The assignment brief. |

`Compiled_code.sql` builds the database in one forward pass, so nothing later in the file depends on something earlier being undone or redone: tables, then seed data (before any trigger exists, so the load fires nothing), then roles/users/permissions, then views and procedures, then the encrypted and hashed columns (encryption before masking, so it reads real values rather than the mask), then the audit objects and triggers, then backups last, once everything they'd capture already exists.

---

## Running it

### Prerequisites

1. **SQL Server 2019 or later** (2022+ unlocks column-level `UNMASK` — see [Known limitations](#known-limitations)). Developer, Enterprise or Standard edition; Express has no backup compression, so drop that option from the `BACKUP` statements if you must use it.
2. **Connect as `sysadmin`.** Non-negotiable, for four reasons: `CREATE SERVER AUDIT` and the `LOGON` trigger are server-scoped; `xp_create_subdir` needs it; and the encryption step reads plaintext through Dynamic Data Masking, which only an `UNMASK`-holding principal can do. Run it as a masked user and you will encrypt the string `XXXXXX1234`.
3. **Folders.** The script creates `C:\SQLAudit\`, `C:\EMS_Backups\` and `C:\EMS_Backups\Keys\` itself, via `xp_create_subdir` run as sysadmin — that's deliberate: a folder created this way, by the SQL Server service account, already has the write permission `CREATE SERVER AUDIT` and `BACKUP` need. A folder you create by hand in Explorer often does not, and the audit creation then fails with `Msg 33072: The audit log file path is invalid` while everything after it silently continues. If you'd rather create the folders yourself first, that's fine too — just make sure the service account has write access.

### Order

```
1.  Compiled_code.sql   -- the whole build, 19 parts, run top to bottom
2.  test_cases.sql      -- the 77 test cases
```

`Compiled_code.sql` **drops and recreates** the `GreenAcresEMS` database at the top. Running it again wipes the data, so re-run `test_cases.sql` afterwards too. The file is otherwise safely re-runnable — object creation is guarded, leftover logins from a previous run are cleaned up, and the key-material files (`.cer`/`.pvk`/`.key`) are deleted and re-exported each time, since `BACKUP CERTIFICATE`/`BACKUP MASTER KEY` refuse to overwrite an existing file and each run generates a genuinely new key pair anyway.

### If you get locked out

The `LOGON` trigger writes to `UserLoginLog`. Its body is wrapped in `TRY`/`CATCH` that swallows every error precisely so a logging failure can never deny a login — but if you ever need to kill it, connect with `sqlcmd -A` (admin connection, bypasses logon triggers) and run:

```sql
DISABLE TRIGGER trg_ServerLogon_AuditLogin ON ALL SERVER;
```

---

## Where each requirement is implemented

The brief lists twelve techniques. All twelve are implemented. Line numbers are in `Compiled_code.sql`.

| # | Requirement | What was built | Line |
|---|---|---|---|
| 1 | View | 9 views — 7 business + 2 login-audit | 1114, 3157 |
| 2 | Stored Procedure | 20 procedures | 1281, 2095, 2635 |
| 3 | Role | 6 roles | 898 |
| 4 | User | 12 named logins + users + memberships | 908 |
| 5 | Hash | SHA2_512 over a 32-byte `CRYPT_GEN_RANDOM` salt, per account | 1992 (columns), 2031 (load) |
| 6 | Encryption | Master key → certificate → AES-256 symmetric key; 5 encrypted columns; controlled decryption procedures | 1848 (keys), 1918 (load), 2635 (decryption) |
| 7 | Masking | 19 masked columns across 9 tables | 2280 |
| 8 | Backups | Full, differential, log, copy-only + **certificate and master-key export** + restore rehearsal + point-in-time procedure | 3778 |
| 9 | Server auditing | `GA_EMS_ServerAudit` + spec, 6 action groups | 3011 |
| 10 | Database auditing | `GA_EMS_DatabaseAuditSpec`, 5 groups + 16 object-level actions | 3050 |
| 11 | Trigger | 13 — 8 audit (3234), 4 operational (3656), 1 server `LOGON` (3101) | — |
| 12 | New/edited tables | 5 originals extended + 9 new tables | 65 (structure), 303 (seed data) |

Permissions are not a numbered requirement but carry a large share of Section 2's marks: line 1047 onwards for the database-, table-, view- and procedure-level `GRANT`/`DENY`.

---

## What's in the database

**14 tables.** The five from the brief (`Properties`, `Clients`, `Agents`, `Transactions`, `MaintenanceRequests`) extended with constraints, soft-delete flags and operational columns, plus nine new ones: `Departments`, `SystemUsers`, `UserLoginLog`, `AuditLog`, `AuditLogArchive`, `LeaseAgreements`, `CommissionPayments`, `MaintenanceStaff`, `Notifications`.

**467 seed rows** — 50 per table, except `LeaseAgreements` (17, one per rental transaction). Malaysian addresses, states, names and phone formats throughout.

**9 views**

`vw_PropertyListing` · `vw_ClientDirectory` · `vw_ActiveLeases` · `vw_AgentPerformance` · `vw_MonthlySalesSummary` · `vw_MaintenanceOverview` · `vw_CommissionSummary` · `vw_LoginHistory` · `vw_ServerLoginAudit`

**20 stored procedures**

- *Operational* — `usp_ManageClient`, `usp_DeactivateClient`, `usp_ReactivateClient`, `usp_ManageProperty`, `usp_UpdatePropertyStatus`, `usp_RecordTransaction`, `usp_UpdateTransactionStatus`, `usp_LogMaintenanceRequest`, `usp_AssignMaintenanceStaff`, `usp_GetAgentTransactions`
- *User provisioning* — `usp_ProvisionUser`, `usp_DeprovisionUser`
- *Credentials & login* — `usp_UpdateSystemUserPassword`, `usp_VerifySystemUserPassword`, `usp_RecordLogout`, `usp_ReportSuspiciousLogins`
- *Encryption* — `usp_GetClientSensitiveData`, `usp_GetLeaseDocumentPath`, `usp_EncryptClientPII`
- *Audit retention* — `usp_ArchiveAuditLog`

**13 triggers** — 8 row-history audit triggers writing before/after JSON to `AuditLog`; 4 operational (property status sync, auto-commission, lease-end handling, maintenance completion); 1 server `LOGON` trigger feeding `UserLoginLog`.

**19 masked columns** — `Clients` 4, `Agents` 3, `LeaseAgreements` 3, `Properties` 2, `CommissionPayments` 2, `MaintenanceRequests` 2, `Transactions` 1, `SystemUsers` 1, `MaintenanceStaff` 1.

---

## Roles and users

Six roles, twelve named accounts, two per role. Every person gets their **own** login with a **unique** password, so `ORIGINAL_LOGIN()` in the audit triggers can always name a single human. Passwords are in `Compiled_code.sql` from line 908.

| Role | Members | Scope |
|---|---|---|
| `role_DBA` | `arun.kumar`, `linda.tan` | `CONTROL` on the database; `ALTER ANY LOGIN` at server level; reads the audit trail; only role that can provision users or touch the key material directly |
| `role_Admin` | `farid.rahman`, `melissa.wong` | Business owner of the data. Read/write across operational tables, `UNMASK`, may decrypt client PII through the procedures. Cannot create logins. |
| `role_PropMgmtDev` | `kelvin.ong`, `aminah.salleh` | Property and maintenance domain. Explicitly **denied** commission data. |
| `role_ClientPortalDev` | `vijay.menon`, `sofia.aziz` | Client and transaction domain. No route to decrypted PII. |
| `role_Analyst` | `hakim.zulkifli`, `rachel.lee` | Read-only reporting. Gets real *numbers* via column-level `UNMASK` on financial columns; never gets identities. |
| `role_ReadOnly` | `jason.lim`, `nurul.huda` | Views only, no base-table access at all. |

`role_Admin` deliberately **cannot** run `usp_ProvisionUser`. Creating a login is a server-level act, and a business admin who could mint accounts could mint one in `role_DBA` and escalate. Test C19 proves the denial.

`test_cases.sql` test C20 dumps the live permission matrix straight from `sys.database_permissions` — use that output for the Authorization Matrix in the report rather than transcribing by hand.

---

## Layered data protection

Each control is one layer, never the whole answer:

| Layer | Applies to | Mechanism |
|---|---|---|
| **Permissions** | everything | Role-based least privilege, explicit `DENY` where intent matters |
| **Masking** | PII and financial columns | Dynamic Data Masking, 19 columns |
| **Encryption** | NRIC, contact, email, address, lease document path | AES-256 symmetric key under a certificate, read only through `EXECUTE AS OWNER` procedures |
| **Hashing** | passwords | SHA2_512 + per-account 32-byte random salt; forced reset on the onboarding password |
| **Auditing** | sensitive tables, logins, schema and permission changes | Server Audit + Database Audit Spec + 8 DML triggers + `UserLoginLog` |
| **Availability** | the database | Full recovery model, three backup types, exported key material, tested restore |

**The decryption path is the part worth reading.** Ciphertext with no way to read it isn't security, it's data loss. `usp_GetClientSensitiveData` is declared `WITH EXECUTE AS OWNER`, so the *procedure* opens the symmetric key — the caller never receives control of the certificate. Access is one client at a time, requires a stated reason, and writes a `DECRYPT_READ` event to `AuditLog` naming the real login before it returns anything. Test B12 proves a developer role can neither call the procedure nor open the key by hand.

**`AuditLog` is classified as sensitive in its own right.** Its `OldValues`/`NewValues` columns hold a JSON snapshot of the whole changed row, so client contact details land there in the clear — and a mask on `Clients.Email` does not follow the data into a JSON string. Reads are restricted to `role_DBA` and `role_Admin`, with an explicit `DENY` for everyone else. The `SystemUsers` trigger lists its columns one by one so no credential material is ever copied into the log.

---

## Test suite — 77 cases

All in `test_cases.sql`. Each case states its expected result in a comment above it; permission tests print `PASS`/`FAIL`.

| Block | Cases | Covers |
|---|---|---|
| **A** | A1–A10 | Audit triggers on insert/update/delete/multi-row; the 4 operational triggers |
| **B** | B1–B15 | Masked-column inventory; ciphertext unreadable; decryption through the procedures; decryption **denied** to developer roles; encryption covers newly added rows; no plaintext passwords; legacy credential columns gone; the masking aggregate limit; `UNMASK` grants |
| **C** | C1–C20 | Role membership; least privilege per role; masked vs unmasked reads; procedure-only writes; input validation; **SQL injection rejected**; password-length rule; privilege-escalation denied; full permission-matrix dump |
| **TEST** | 1–12 | Audit evidence for the documentation: trail exists, is populated, is protected, audit specs are on, retention works, login evidence |
| **D** | D1–D10 | Recovery model; all three backup types taken and verified; **key material exported**; restored copy matches row for row; audit trail survives; ciphertext still ciphertext; `CHECKDB`; RPO measurement |
| **E** | E1–E10 | Logon trigger live; successful and failed logins recorded; no user-name enumeration; brute-force detection; session length; login history denied to watched roles; forced password reset |

---

## Known limitations

Stated deliberately — each one is a defensible design decision, not an oversight, and each belongs in the report.

**Dynamic Data Masking is a presentation control, not a security boundary.** It masks a *column*, not an *expression* over that column, so `SELECT SUM(Amount) FROM Transactions` returns real figures to a user who sees `Amount` masked. `vw_MonthlySalesSummary` and `vw_AgentPerformance` both aggregate that column. Rather than leave an accidental bypass, `role_Analyst` is granted **explicit column-level `UNMASK`** on the financial columns only — the permission is now intentional, documented and auditable. Test B14 demonstrates the limit on purpose.

**Column-level `UNMASK` requires SQL Server 2022.** On 2019 the only alternative is database-wide `UNMASK`, which would also expose PII, so on 2019 nothing is granted and the aggregate limitation is accepted instead. The version check runs through `sp_executesql` so a 2019 parser never sees the 2022 syntax.

**Plaintext columns still sit beside their encrypted copies.** `Clients.NRIC` and `LeaseAgreements.AgreementDocPath` exist in both forms, because the masking requirement has to be demonstrable on the same tables. This makes the encryption defence-in-depth rather than true encryption-at-rest — the plain value is still on the data page. A ready-to-uncomment `DROP COLUMN` block sits in `Compiled_code.sql` at line 2781 along with the exact follow-on edits it forces (view, procedure, masking block, and tests B2/C5/C6/C7). Enable it if true encryption-at-rest is required.

**Passwords are in the script in clear text.** Unavoidable for a build script that has to be handed in and re-run by a marker. In production these would come from a secrets vault at run time, or the logins would be Windows/Entra ID authenticated. The same applies to the master-key and certificate-export passwords.

**`usp_ProvisionUser` must build dynamic SQL.** `CREATE LOGIN` cannot take a parameter. Every identifier is wrapped in `QUOTENAME()`, the login name is validated against a strict character whitelist, and the password is bound as a real `sp_executesql` parameter so it never becomes executable text. Test C17 fires `evil];DROP TABLE dbo.Clients--` at it and confirms the table survives.

**Not implemented:** Row-Level Security, Transparent Data Encryption, Always Encrypted, schema separation. All are bonus-mark territory rather than brief requirements. RLS was left out specifically because an untested filter predicate can silently strip rows from working procedures.

---

## Still outstanding

The brief asks for more than SQL. Not in this repository yet:

- **`Report_<group number>.pdf`** — introduction and data dictionary, Authorization Matrix, Data Classification Matrix, Database Security Audit Matrix, summary, references
- **`DBS_TestCases_<group number>.docx`** — the test cases with **documented outcomes**. `test_cases.sql` states the expected result for every case but records no actual ones; run it and capture what you actually get.
- **Demo video** — 5 to 15 minutes, presented as though to a real client. Captions optional; English subtitles required if narrated.

For the report, three things are easier to generate than to write by hand: the permission matrix (`test_cases.sql` test C20), the masked-column list (test B1), and the object inventory (`Compiled_code.sql` line 4125).

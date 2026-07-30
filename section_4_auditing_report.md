# 4. Auditing

## 4.1 Purpose of Auditing

Auditing is used to record important database activity. For Green Acres Realty Sdn Bhd, auditing helps answer five simple questions: who performed the action, what action was performed, when it happened, which data was affected, and where the action came from. This is important because the Estate Management System stores sensitive client, property, transaction, lease, commission, and staff information.

The previous system did not have strong auditing. This means suspicious activity, accidental changes, permission abuse, or data tampering could happen without clear evidence. The improved solution uses two audit layers:

1. `AuditLog` table with DML triggers for data history.
2. SQL Server Audit with a Database Audit Specification for security activity.

## 4.2 Database Security Audit Matrix

| No. | Threat / Requirement | Target Area | Event Audited | Audit Control | Evidence Stored | Security Purpose |
|---:|---|---|---|---|---|---|
| 1 | Unauthorized client data changes | `Clients` | `INSERT`, `UPDATE`, `DELETE` | `trg_Clients_Audit` | Before/after row JSON, original login, time, app and host | Preserves a history of changes to client PII, including NRIC, contact details and address. |
| 2 | Property record or status tampering | `Properties` | `INSERT`, `UPDATE`, `DELETE` | `trg_Properties_Audit` | Before/after property JSON and actor context | Identifies unauthorized price, ownership or availability changes. |
| 3 | Agent record or commission-rate manipulation | `Agents` | `INSERT`, `UPDATE`, `DELETE` | `trg_Agents_Audit` | Agent before/after JSON and actor context | Provides evidence when agent identity, status or commission rate is changed. |
| 4 | Transaction tampering | `Transactions` | `INSERT`, `UPDATE`, `DELETE` | `trg_Transactions_Audit` | Transaction before/after JSON and actor context | Protects financial, sale and rental transaction history. |
| 5 | Commission manipulation | `CommissionPayments` | `INSERT`, `UPDATE`, `DELETE` | `trg_CommissionPayments_Audit` | Commission rate, amount, payment status and actor context | Detects suspicious changes to agent payment information. |
| 6 | Lease agreement changes | `LeaseAgreements` | `INSERT`, `UPDATE`, `DELETE` | `trg_LeaseAgreements_Audit` | Lease before/after JSON and actor context | Maintains agreement history for disputes and investigations. |
| 7 | Maintenance request or cost changes | `MaintenanceRequests` | `INSERT`, `UPDATE`, `DELETE` | `trg_MaintenanceRequests_Audit` | Request, cost and status history with actor context | Tracks operational changes and suspicious maintenance-cost updates. |
| 8 | Internal user account tampering | `SystemUsers` | `INSERT`, `UPDATE`, `DELETE` | `trg_SystemUsers_Audit` | Non-credential user details and actor context | Detects internal account changes without copying password hashes or salts into the log. |
| 9 | Failed or suspicious login activity | SQL Server logins | `FAILED_LOGIN_GROUP`, `SUCCESSFUL_LOGIN_GROUP` | Server Audit Specification | Login, time, source and success status | Supports brute-force detection and login investigation. |
| 10 | Server login, permission or role abuse | Server principals and roles | Principal, permission and role-member changes | Server Audit Specification | Principal, action, statement, result and time | Detects server-level privilege escalation and account tampering. |
| 11 | Database user or permission abuse | Database principals and permissions | Principal, permission and object-permission changes | Database Audit Specification | User, permission statement, object, result and time | Tracks unauthorized database access changes. |
| 12 | Database role membership abuse | Database roles | `DATABASE_ROLE_MEMBER_CHANGE_GROUP` | Database Audit Specification | Role, member, statement, user and time | Shows who added or removed a user from a privileged role. |
| 13 | Schema tampering | Tables, views, procedures and triggers | `SCHEMA_OBJECT_CHANGE_GROUP` | Database Audit Specification | Object, DDL statement, user, result and time | Detects unauthorized structural changes or malicious trigger changes. |
| 14 | Sensitive data viewing or modification | `Clients`, `Transactions`, `CommissionPayments` | `SELECT`, `UPDATE`, `DELETE` | Object actions in Database Audit Specification | User, object, action, result, statement and time | Monitors access to confidential client and financial information. |
| 15 | Audit evidence viewing or tampering | `AuditLog`, `AuditLogArchive` | `SELECT`, `INSERT`, `UPDATE`, `DELETE` | Access control plus Database Audit Specification | Attempted action, user, statement, result and time | Protects audit evidence and records both successful and denied access attempts. |
| 16 | Audit configuration tampering | SQL Server Audit objects | `AUDIT_CHANGE_GROUP` | Server Audit Specification | Audit change, statement, user, result and time | Detects attempts to disable or weaken the auditing system. |

### 4.2.1 Key Points from the Matrix

The matrix applies defence in depth. DML triggers provide detailed row-level history for business data, whereas SQL Server Audit records events that table triggers cannot observe, such as failed logins, permission changes and audit configuration changes. The two layers therefore answer different questions and should be used together.

Each DML history record identifies who performed the action, what table and record were affected, when it happened, where the connection came from, and the before/after state. The triggers are set-based, so one `UPDATE` affecting many rows produces one history record for every affected row. For `SystemUsers`, credential hashes and salts are deliberately excluded to prevent the audit trail from becoming another source of credential material.

Audit evidence is separated from ordinary application access. Normal developer, analyst and read-only roles are explicitly denied access to the live and archived audit tables. SQL Server Audit also monitors access attempts against those tables. Older live history can be moved to `AuditLogArchive` through a controlled DBA procedure, allowing the organisation to retain evidence without leaving the operational table to grow without control.

## 4.3 Implemented Audit Solutions

The first implemented solution is the `AuditLog` table. This table stores database change history for important EMS tables. It records the table name, operation type, affected record ID, event time, original login, old values, new values, application name and host name. An index on `EventTime` supports incident and date-range searches.

The second implemented solution is DML audit triggers. The database uses audit triggers on `Clients`, `Agents`, `Transactions`, `LeaseAgreements`, `CommissionPayments`, `SystemUsers`, `MaintenanceRequests`, and `Properties`. These triggers run automatically after `INSERT`, `UPDATE`, or `DELETE`. For an update, each affected row stores both the old row and new row as JSON. The triggers use `ORIGINAL_LOGIN()` so that the initiating login is retained even though the trigger executes as the database owner. The `SystemUsers` trigger records account metadata but excludes `PasswordHash` and `PasswordSalt`.

The third implemented solution is SQL Server Audit. The server audit captures successful and failed logins, audit changes, server-principal changes, server-permission changes and server-role membership changes. Audit files roll over at 20 MB, with five rollover files retained. This layer is necessary because DML triggers cannot capture login or server-level security events.

The fourth implemented solution is the Database Audit Specification for `GreenAcresEMS`. It captures database-principal changes, database and object permission changes, database role membership changes, schema changes, sensitive-table activity and access to both audit tables. This supports accountability because the audit file records the statement, responsible principal, target object, result and time.

The fifth implemented solution is audit log access control. Only `role_DBA` and `role_Admin` are granted direct read access to `AuditLog` and `AuditLogArchive`. Other roles such as `role_PropMgmtDev`, `role_ClientPortalDev`, `role_Analyst`, and `role_ReadOnly` are denied direct access. Only `role_DBA` can run `usp_ArchiveAuditLog`, which moves records older than a selected retention period from the live log into the archive within a transaction.

### 4.3.1 Mapping of Solutions to Threats

The five solutions are not independent. Each one covers a different group of threats from the matrix in Section 4.2, and together they close the gaps that any single control would leave open.

| Solution | Matrix Threats Addressed | Requirement Fulfilled |
|---|---|---|
| 1. `AuditLog` table | 1–8 | Central, queryable store of data-change history |
| 2. DML audit triggers | 1–8 | Row-level before/after history with actor, time, application and host |
| 3. SQL Server Audit (server) | 9, 10, 16 | Login activity, server privilege abuse and audit tampering |
| 4. Database Audit Specification | 11–15 | Permission, role, schema and sensitive-data activity |
| 5. Audit log access control | 15 | Protects the integrity of the evidence itself |

Solutions 1 and 2 answer *what the data used to be*, which is the history requirement. Solutions 3 and 4 answer *what was done to the system*, which is the security auditing requirement. Triggers alone would be insufficient, because a trigger cannot observe a failed login, a permission grant, or an attempt to disable auditing; SQL Server Audit alone would also be insufficient, because it records that a statement ran without preserving the prior values of the affected rows. Solution 5 exists because an audit trail that an attacker can read or delete provides no assurance, so the evidence is placed beyond the reach of the roles being audited.

## 4.4 Testing and Evidence

The audit solution was tested by executing `auditing_testcases.sql` against the deployed database. The script returns screenshot-friendly result grids for object existence, trigger status, row-level history, access denial, multi-row correctness, audit specification contents, permission and schema events, retention/archive behaviour and audit-file records.

### 4.4.1 Test Environment

| Item | Value |
|---|---|
| Database engine | Microsoft SQL Server 2022 (RTM) 16.0.1000.6, Express Edition (64-bit) |
| Instance | `.\SQLEXPRESS` |
| Database | `GreenAcresEMS` |
| Audit file location | `C:\SQLAudit\` |
| Execution order | `Compiled SQL file.sql` → `08_auditing.sql` → `09_audit_triggers.sql` → `auditing_testcases.sql` |
| Date executed | 30 July 2026 |

All four scripts completed with zero errors.

### 4.4.2 Test Results

Every test returned `PASS`. The final tally was **10 PASS, 0 FAIL**.

| No. | Test | Observed Result | Outcome |
|---:|---|---|---|
| 1 | `AuditLog` table exists | `dbo.AuditLog` present | PASS |
| 2 | Audit triggers enabled | 8 of 8 triggers `Enabled` | PASS |
| 3 | `UPDATE` recorded with history | `Clients` row 1 email change captured with before/after JSON, `ORIGINAL_LOGIN()`, application and host | PASS |
| 4 | `INSERT` recorded with history | `Transactions` row 51 captured with full new-row JSON | PASS |
| 5 | Audit evidence protected | Direct `SELECT` blocked: *"The SELECT permission was denied on the object 'AuditLog', database 'GreenAcresEMS', schema 'dbo'."* | PASS |
| 6 | Server audit enabled | `GA_EMS_ServerAudit`, target `FILE`, enabled | PASS |
| 7 | Server audit specification enabled | `GA_EMS_ServerAuditSpec`, 6 audited action groups | PASS |
| 8 | Database audit specification enabled | `GA_EMS_DatabaseAuditSpec`, 22 audited actions | PASS |
| 9 | Multi-row trigger correctness | 50 rows updated → 50 audit rows written | PASS |
| 10 | Retention and archive | 1 row archived, 365-day cutoff, executed within a transaction | PASS |

### 4.4.3 Key Evidence Points

Test 9 is the most important correctness result. A common defect in audit triggers is row-by-row logic that writes only one history record even when a statement affects many rows, silently losing evidence. The implemented triggers are set-based, so a single `UPDATE` affecting 50 `Agents` rows produced exactly 50 corresponding `AuditLog` rows. This confirms that the audit trail cannot be evaded by modifying many records in one statement.

Test 5 confirms the separation of audit evidence from ordinary access. The denial message is itself the evidence: the account was refused, and the refusal was recorded rather than passing silently.

Querying `sys.fn_get_audit_file` returned 25 audit records covering trigger creation, audit-specification creation, permission grants and revokes, role membership changes, table creation and drops, and successful logins. This demonstrates that the SQL Server Audit layer captures the server- and schema-level events that DML triggers cannot observe.

Screenshots for the report should be captured from the result grids of the ten tests above, plus the `sys.fn_get_audit_file` output and one controlled failed-login demonstration.

## 4.5 Limitations

The audit design is suitable for assignment and demonstration purposes, but it has limitations. SQL Server Audit requires administrator permission, and the SQL Server service account must be able to write to `C:\SQLAudit\`. The implemented archive procedure provides a controlled history-retention mechanism, but an organisation must still define its approved retention period, backup the audit archive, restrict the Windows audit directory and test restoration. Auditing every `SELECT` on sensitive tables can also produce many audit records, so a production system should review audit volume and tune the monitored objects without removing critical security events.

Edition constraints were also observed during deployment. SQL Server Audit, including both the server audit specification and the database audit specification, was confirmed to work on Express Edition, so the full audit matrix is demonstrable on the free edition. However, backup compression is not available: `BACKUP DATABASE ... WITH COMPRESSION` raises `Msg 1844` on Express Edition. Because audit evidence is only as durable as the backups protecting it, an organisation retaining audit history for compliance should run Standard or Enterprise Edition, where compression reduces both the storage cost and the backup window for a growing `AuditLogArchive`.

Finally, the audit trail records the login that performed each action through `ORIGINAL_LOGIN()`, but it cannot by itself prove that the login was used by the person it belongs to. Auditing therefore supports accountability only when combined with the access control, authentication and password policies described in the other sections of this report.

## 4.6 Conclusion

The auditing solution improves accountability for the Green Acres EMS database. DML triggers provide row-level history for important data changes, while SQL Server Audit captures security events such as failed logins, permission changes, role changes, schema changes and sensitive data access. Together, these controls help detect suspicious activity, support investigation, and protect the integrity of the database.

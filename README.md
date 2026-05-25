# Estate Management System (EMS) Database Security Assignment

This repository contains the implementation work for the **CT069-3-3 Database Security Group Assignment**.

The project is based on the case study of **Green Acres Realty Sdn Bhd**, a real estate company that is migrating its existing Estate Management System (EMS) into an in-house IT environment.

The original EMS database was functional, but it was weak in security. It did not properly consider access control, user privileges, auditing, data masking, encryption, backup, and secure database operations.

This repository provides a database security solution for the EMS migration.

---

## Project Purpose

The purpose of this project is to improve the security of the existing Estate Management System database.

The solution focuses on:

- Creating secure database objects
- Managing user access using roles and permissions
- Protecting sensitive data
- Maintaining confidentiality, integrity, and availability
- Implementing auditing and logging
- Using views and stored procedures to control data access
- Applying hashing, encryption, masking, triggers, and backups

This project is designed for **internal IT departments and developers**, not public end users.

---

## Case Study Background

Green Acres Realty Sdn Bhd previously hired a software house to develop its Estate Management System.

The original developers handled the full system development, including:

- Front-end development
- Back-end development
- Database design
- Security deployment

However, because the same team handled everything, several important database security areas were not properly implemented.

The original system lacked:

- Proper role-based access control
- Proper user privilege separation
- Data masking
- Data encryption
- Security auditing
- Database activity logging
- Backup and recovery planning
- Triggers for audit and operational control

The company has now expanded and wants to build its own IT division. Therefore, the database needs to be redesigned with stronger security controls.

---

## Technologies Used

- Microsoft SQL Server
- T-SQL
- SQL Server Management Studio
- SQL Server Roles and Users
- SQL Server Views
- SQL Server Stored Procedures
- SQL Server Triggers
- SQL Server Audit
- SQL Server Backup and Restore

---

## Original Database Tables

The original database contains the following tables:

| Table | Description |
|---|---|
| `Properties` | Stores property details such as name, address, city, state, price, and status |
| `Clients` | Stores client information such as name, contact number, email, and address |
| `Agents` | Stores real estate agent information such as name, contact number, email, and commission rate |
| `Transactions` | Stores sale or rental transaction records |
| `MaintenanceRequests` | Stores property maintenance requests |

---

## Improved Security Features

### 1. Role-Based Access Control

Role-based access control is implemented to ensure that users only access the data they need.

Example roles:

| Role | Purpose |
|---|---|
| `db_admin_role` | Full database administration access |
| `property_management_role` | Manage property and maintenance data |
| `client_portal_role` | Access limited client-related data |
| `analytics_role` | Read-only access for reports and analysis |
| `audit_role` | Access audit logs and security records |
| `developer_role` | Limited development and testing access |

Permissions are assigned to roles instead of directly assigning permissions to individual users.

This makes access control cleaner and easier to manage.

---

### 2. User Management

Different users are created for different internal IT departments.

Example users:

```sql
CREATE USER PropertyDeveloper WITHOUT LOGIN;
CREATE USER ClientPortalDeveloper WITHOUT LOGIN;
CREATE USER AnalyticsDeveloper WITHOUT LOGIN;
CREATE USER AuditOfficer WITHOUT LOGIN;
```

Users are assigned to roles based on their responsibilities.

```sql
ALTER ROLE property_management_role ADD MEMBER PropertyDeveloper;
ALTER ROLE client_portal_role ADD MEMBER ClientPortalDeveloper;
ALTER ROLE analytics_role ADD MEMBER AnalyticsDeveloper;
ALTER ROLE audit_role ADD MEMBER AuditOfficer;
```

This supports the principle of least privilege.

---

### 3. Views

Views are used to control what data each department can see.

Instead of giving users direct access to base tables, users access filtered or masked data through views.

Example views:

| View | Purpose |
|---|---|
| `vw_PropertySummary` | Shows basic property information |
| `vw_ClientMaskedInfo` | Shows client information with sensitive data masked |
| `vw_AgentPublicInfo` | Shows limited agent information |
| `vw_TransactionAnalytics` | Shows transaction data for reporting |
| `vw_MaintenanceStatus` | Shows maintenance request status |

Views help reduce the risk of exposing sensitive data.

---

### 4. Stored Procedures

Stored procedures are used to control database operations.

Users should not directly insert, update, or delete important records from base tables. Instead, they should use stored procedures.

Example stored procedures:

| Stored Procedure | Purpose |
|---|---|
| `sp_AddProperty` | Adds a new property |
| `sp_UpdatePropertyStatus` | Updates property status |
| `sp_RegisterClient` | Registers a new client |
| `sp_CreateTransaction` | Creates a sale or rental transaction |
| `sp_SubmitMaintenanceRequest` | Creates a maintenance request |
| `sp_UpdateMaintenanceStatus` | Updates maintenance request progress |

Stored procedures help enforce business rules, validation, and security restrictions.

---

### 5. Data Protection

Sensitive data is protected using different methods.

Protection methods include:

- Data masking
- Encryption
- Hashing
- Restricted views
- Permission control
- Controlled stored procedures

Sensitive fields include:

| Table | Sensitive Data |
|---|---|
| `Clients` | Full name, contact number, email, address |
| `Agents` | Contact number, email, commission rate |
| `Transactions` | Transaction amount, client ID, agent ID |
| `Properties` | Address and property price |

---

### 6. Hashing

Hashing is used for data that does not need to be decrypted.

For example, if the system includes passwords or verification values, they should be stored as hashes instead of plain text.

Example:

```sql
HASHBYTES('SHA2_256', @Password)
```

Hashing improves security because the original value cannot be directly recovered from the hash.

---

### 7. Encryption

Encryption is used to protect confidential data that may need to be decrypted later.

Example data that may require encryption:

- Client email
- Client contact number
- Client address
- Transaction-related sensitive information

Encryption helps protect sensitive data even if unauthorized users gain access to the database files.

---

### 8. Data Masking

Data masking is used to hide part of sensitive information from users who do not need full access.

Example:

```sql
ALTER TABLE Clients
ALTER COLUMN Email ADD MASKED WITH (FUNCTION = 'email()');
```

Masked data allows users to work with records without seeing full confidential details.

---

### 9. Auditing

Auditing is implemented to track important database activities.

Audit logs may record:

- Login attempts
- Failed access attempts
- Insert operations
- Update operations
- Delete operations
- Permission changes
- User and role changes
- Backup and restore activities
- Changes to sensitive data

Auditing supports accountability and helps detect suspicious activity.

---

### 10. Triggers

Triggers are used for both auditing and operational control.

Example trigger purposes:

- Log updates to client data
- Log changes to transaction records
- Prevent invalid property status updates
- Track deleted records
- Store old and new values after updates
- Automatically update timestamps

Example:

```sql
CREATE TRIGGER trg_AuditClientUpdate
ON Clients
AFTER UPDATE
AS
BEGIN
    INSERT INTO ClientAuditLog
    (
        ClientID,
        ActionType,
        ActionDate
    )
    SELECT
        ClientID,
        'UPDATE',
        GETDATE()
    FROM inserted;
END;
```

Triggers help monitor important database changes.

---

### 11. Backup and Recovery

Backup scripts are included to support database availability.

Backup types may include:

- Full database backup
- Differential backup
- Transaction log backup

Example:

```sql
BACKUP DATABASE EMS_DB
TO DISK = 'C:\Backup\EMS_DB_Full.bak'
WITH INIT, NAME = 'EMS_DB Full Backup';
```

A backup is useless if it is never tested. The restore process should also be tested.

---

## Repository Structure

The recommended repository structure is:

```text
.
├── README.md
├── scripts/
│   ├── 01_create_database.sql
│   ├── 02_create_tables.sql
│   ├── 03_insert_sample_data.sql
│   ├── 04_create_views.sql
│   ├── 05_create_stored_procedures.sql
│   ├── 06_create_roles_users_permissions.sql
│   ├── 07_data_protection.sql
│   ├── 08_auditing.sql
│   ├── 09_triggers.sql
│   ├── 10_backup_restore.sql
│   └── 99_full_implementation.sql
│
├── test-cases/
│   └── DBS_TestCases_<group_number>.docx
│
├── documentation/
│   └── Report_<group_number>.pdf
│
├── demo/
│   └── demo_video_link.txt
│
└── submission/
    └── Implementation_<group_number>.zip
```

---

## How to Run the Project

### Prerequisites

Before running the project, make sure you have:

- Microsoft SQL Server installed
- SQL Server Management Studio installed
- Permission to create databases
- Permission to create users and roles
- Permission to create audits
- Permission to perform backup and restore

---

### Setup Steps

Run the SQL scripts in the following order:

```text
01_create_database.sql
02_create_tables.sql
03_insert_sample_data.sql
04_create_views.sql
05_create_stored_procedures.sql
06_create_roles_users_permissions.sql
07_data_protection.sql
08_auditing.sql
09_triggers.sql
10_backup_restore.sql
```

Alternatively, run:

```text
99_full_implementation.sql
```

Only use the full implementation script if it has already been tested from a clean database state.

---

## Testing

Test cases are stored in:

```text
test-cases/DBS_TestCases_<group_number>.docx
```

The test cases should verify:

- Users can only access permitted data
- Unauthorized users cannot access restricted tables
- Views return the correct filtered data
- Sensitive data is masked correctly
- Stored procedures work correctly
- Invalid operations are rejected
- Audit logs are created
- Triggers work correctly
- Backup scripts run successfully
- Restore process is valid

Example test:

```sql
EXECUTE AS USER = 'AnalyticsDeveloper';

SELECT * FROM vw_TransactionAnalytics;

SELECT * FROM Clients;
-- Expected result: Permission denied

REVERT;
```

---

## Documentation

The final report should be saved as:

```text
documentation/Report_<group_number>.pdf
```

The report should include:

1. Introduction
2. Team workload matrix
3. Updated data dictionary
4. Authorization matrix
5. User and permission management solution
6. Data classification matrix
7. Data protection solution
8. Database security audit matrix
9. Auditing solution
10. Summary
11. References

---

## Demo Video

The demo video should demonstrate the system workflow and security features.

The video should cover:

- Database setup
- Table creation
- Sample data insertion
- Role and user creation
- Permission testing
- View testing
- Stored procedure testing
- Data masking demonstration
- Hashing or encryption demonstration
- Trigger demonstration
- Audit log demonstration
- Backup demonstration

The video should be between **5 and 15 minutes**.

---

## Suggested Demo Flow

1. Introduce the original EMS security problem
2. Show the improved database structure
3. Show created roles and users
4. Demonstrate allowed access
5. Demonstrate denied access
6. Show masked sensitive data
7. Run stored procedures
8. Trigger an audit event
9. Show audit log records
10. Run backup script
11. Summarize how the solution improves database security

---

## Security Design Principles

This project applies the following security principles:

### Confidentiality

Sensitive data is protected using masking, encryption, views, and permissions.

### Integrity

Data accuracy is protected using constraints, stored procedures, triggers, and controlled update operations.

### Availability

Database availability is supported through backup and recovery planning.

### Least Privilege

Users only receive the minimum permissions required for their tasks.

### Separation of Duties

Different departments have different access rights based on their responsibilities.

### Accountability

Auditing and triggers are used to track user activity and database changes.

---

## Group Members

| Name | Student ID | Contribution |
|---|---:|---:|
| Member 1 | TPXXXXXX | 25% |
| Member 2 | TPXXXXXX | 25% |
| Member 3 | TPXXXXXX | 25% |
| Member 4 | TPXXXXXX | 25% |

Update this table before submission.

Do not leave fake placeholders in the final version.

---

## Submission Checklist

Before submitting, make sure the project includes:

- [ ] Complete SQL implementation scripts
- [ ] Inline comments in SQL scripts
- [ ] Sufficient sample data
- [ ] Views
- [ ] Stored procedures
- [ ] Roles
- [ ] Users
- [ ] Permission management
- [ ] Hashing
- [ ] Encryption
- [ ] Data masking
- [ ] Backup scripts
- [ ] Server auditing
- [ ] Database auditing
- [ ] Audit triggers
- [ ] Operational triggers
- [ ] Updated test cases document
- [ ] Final report PDF
- [ ] Demo video or demo video link
- [ ] Implementation ZIP file

---

## Limitations

This project is created for academic purposes.

Some limitations may include:

- Sample data may not represent real business data
- Authentication may be simplified for assignment demonstration
- Encryption key management may be simplified
- Backup paths may need to be changed depending on the machine
- SQL Server Audit may require administrator permission
- The project may require further hardening before real production use

---

## Final Note

This repository exists to show that the original EMS database was not only recreated, but improved with proper database security controls.

A basic CRUD database is not enough for this assignment. The marks are in the security design, permission model, data protection, auditing, testing, and documentation.

Build it cleanly. Test it properly. Document it clearly.

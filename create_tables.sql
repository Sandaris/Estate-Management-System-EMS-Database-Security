-- ============================================================
-- Green Acres Realty Sdn Bhd
-- Estate Management System (EMS) - Full Database Schema
-- CT069-3-3 Database Security Assignment
-- =========================================================                ===
-- Covers:
--   * All original tables (Properties, Clients, Agents,
--     Transactions, MaintenanceRequests) - enhanced
--   * New tables: Departments, SystemUsers, UserLoginLog,
--     AuditLog, PropertyImages, LeaseAgreements,
--     CommissionPayments, MaintenanceStaff, Notifications
-- ============================================================

USE master;
GO

-- Drop and recreate the database for a clean setup
IF EXISTS (SELECT name FROM sys.databases WHERE name = 'GreenAcresEMS')
    DROP DATABASE GreenAcresEMS;
GO

CREATE DATABASE GreenAcresEMS;
GO

USE GreenAcresEMS;
GO

-- ============================================================
-- SECTION 1: CORE / ORIGINAL TABLES (Enhanced)
-- ============================================================

-- ------------------------------------------------------------
-- 1. Properties
--    Enhanced: added PropertyType, Bedrooms, Bathrooms,
--    Sizesqft, IsActive for richer operational data.
-- ------------------------------------------------------------
CREATE TABLE Properties (
    PropertyID      INT             IDENTITY(1,1)   PRIMARY KEY,
    PropertyName    NVARCHAR(150)   NOT NULL,
    Address         NVARCHAR(255)   NOT NULL,
    City            NVARCHAR(100)   NOT NULL,
    State           NVARCHAR(100)   NOT NULL,
    PostalCode      NVARCHAR(10),
    PropertyType    NVARCHAR(50)    NOT NULL        -- 'Residential', 'Commercial', 'Industrial'
        CONSTRAINT CK_Properties_Type CHECK (PropertyType IN ('Residential','Commercial','Industrial','Land')),
    Bedrooms        TINYINT         NULL,
    Bathrooms       TINYINT         NULL,
    SizeSqft        DECIMAL(10,2)   NULL,
    Price           DECIMAL(18,2)   NOT NULL,
    Status          NVARCHAR(50)    NOT NULL        DEFAULT 'Available'
        CONSTRAINT CK_Properties_Status CHECK (Status IN ('Available','Sold','Rented','Under Maintenance','Reserved')),
    IsActive        BIT             NOT NULL        DEFAULT 1,  -- soft-delete flag
    CreatedDate     DATETIME        NOT NULL        DEFAULT GETDATE(),
);
GO
SELECT * FROM Properties

-- ------------------------------------------------------------
-- 2. Clients
--    Enhanced: added NRIC (for encryption later), ClientType,
--    IsActive. Sensitive PII columns flagged in comments.
-- ------------------------------------------------------------
CREATE TABLE Clients (
    ClientID        INT             IDENTITY(1,1)   PRIMARY KEY,
    FullName        NVARCHAR(100)   NOT NULL,
    NRIC            NVARCHAR(20)    NULL,           -- [SENSITIVE - will be encrypted]
    ContactNumber   NVARCHAR(20)    NOT NULL,       -- [SENSITIVE - will be masked]
    Email           NVARCHAR(100)   NOT NULL,       -- [SENSITIVE - will be masked]
    Address         NVARCHAR(255)   NULL,
    ClientType      NVARCHAR(50)    NOT NULL        DEFAULT 'Individual'
        CONSTRAINT CK_Clients_Type CHECK (ClientType IN ('Individual','Corporate')),
    IsActive        BIT             NOT NULL        DEFAULT 1,
    RegisteredDate  DATETIME        NOT NULL        DEFAULT GETDATE(),
);
GO
SELECT * FROM Clients
-- ------------------------------------------------------------
-- 3. Agents
--    Enhanced: added DepartmentID (FK), LicenseNumber,
--    IsActive. CommissionRate is sensitive financial data.
-- ------------------------------------------------------------
CREATE TABLE Agents (
    AgentID         INT             IDENTITY(1,1)   PRIMARY KEY,
    FullName        NVARCHAR(100)   NOT NULL,
    ContactNumber   NVARCHAR(20)    NOT NULL,       -- [SENSITIVE - will be masked]
    Email           NVARCHAR(100)   NOT NULL,
    LicenseNumber   NVARCHAR(50)    NULL,           -- real-estate agent license
    CommissionRate  DECIMAL(5,2)    NOT NULL        DEFAULT 2.50, -- [SENSITIVE]
        CONSTRAINT CK_Agents_CommRate CHECK (CommissionRate BETWEEN 0 AND 100),
    IsActive        BIT             NOT NULL        DEFAULT 1,
    JoinedDate      DATETIME        NOT NULL        DEFAULT GETDATE(),
);
GO
SELECT * FROM Agents
-- ------------------------------------------------------------
-- 4. Transactions
--    Enhanced: added RentEndDate, PaymentStatus,
--    PaymentMethod for lease/sale lifecycle tracking.
-- ------------------------------------------------------------
CREATE TABLE Transactions (
    TransactionID   INT             IDENTITY(1,1)   PRIMARY KEY,
    PropertyID      INT             NOT NULL
        CONSTRAINT FK_Trans_Property FOREIGN KEY REFERENCES Properties(PropertyID),
    ClientID        INT             NOT NULL
        CONSTRAINT FK_Trans_Client  FOREIGN KEY REFERENCES Clients(ClientID),
    AgentID         INT             NOT NULL
        CONSTRAINT FK_Trans_Agent   FOREIGN KEY REFERENCES Agents(AgentID),
    TransactionType NVARCHAR(50)    NOT NULL
        CONSTRAINT CK_Trans_Type CHECK (TransactionType IN ('Sale','Rent')),
    TransactionDate DATETIME        NOT NULL        DEFAULT GETDATE(),
    Amount          DECIMAL(18,2)   NOT NULL,       -- [SENSITIVE - financial]
    RentStartDate   DATE            NULL,           -- populated for Rent transactions
    RentEndDate     DATE            NULL,
    PaymentStatus   NVARCHAR(50)    NOT NULL        DEFAULT 'Pending'
        CONSTRAINT CK_Trans_PayStatus CHECK (PaymentStatus IN ('Pending','Completed','Cancelled','Refunded')),
    PaymentMethod   NVARCHAR(50)    NULL            -- 'Cash','Bank Transfer','Cheque'
);
GO

SELECT * FROM Transactions
-- ------------------------------------------------------------
-- 5. MaintenanceRequests
--    Enhanced: added AssignedStaffID, Priority, CompletedDate,
--    EstimatedCost, ActualCost for full work-order tracking.
-- ------------------------------------------------------------
CREATE TABLE MaintenanceRequests (
    RequestID       INT             IDENTITY(1,1)   PRIMARY KEY,
    PropertyID      INT             NOT NULL
        CONSTRAINT FK_Maint_Property FOREIGN KEY REFERENCES Properties(PropertyID),
    RequestedByClientID INT         NULL            -- NULL = internal/owner request
        CONSTRAINT FK_Maint_Client   FOREIGN KEY REFERENCES Clients(ClientID),
    RequestDetails  NVARCHAR(MAX)   NOT NULL,
    Priority        NVARCHAR(20)    NOT NULL        DEFAULT 'Medium'
        CONSTRAINT CK_Maint_Priority CHECK (Priority IN ('Low','Medium','High','Critical')),
    RequestDate     DATETIME        NOT NULL        DEFAULT GETDATE(),
    Status          NVARCHAR(50)    NOT NULL        DEFAULT 'Pending'
        CONSTRAINT CK_Maint_Status CHECK (Status IN ('Pending','In Progress','Completed','Cancelled')),
    EstimatedCost   DECIMAL(18,2)   NULL,
    ActualCost      DECIMAL(18,2)   NULL,           -- [SENSITIVE - financial]
    CompletedDate   DATETIME        NULL
);
GO

SELECT * FROM MaintenanceRequests

-- ============================================================
-- SECTION 2: NEW SUPPORTING TABLES
-- ============================================================

-- ------------------------------------------------------------
-- 6. Departments
--    Represents the IT and business departments formed during
--    the company's expansion. Used to scope roles/users.
-- ------------------------------------------------------------
CREATE TABLE Departments (
    DepartmentID    INT             IDENTITY(1,1)   PRIMARY KEY,
    DepartmentName  NVARCHAR(100)   NOT NULL        UNIQUE,
    Description     NVARCHAR(255)   NULL,
    IsActive        BIT             NOT NULL        DEFAULT 1,
    CreatedDate     DATETIME        NOT NULL        DEFAULT GETDATE()
);
GO

SELECT * FROM Departments

-- ------------------------------------------------------------
-- 7. SystemUsers
--    Internal IT/staff users who access the EMS database
--    (developers, DBAs, analysts). NOT end-user clients.
--    Passwords stored as hashes (applied later by Irfan).
--    Linked to SQL Server logins via LoginName.
-- ------------------------------------------------------------
CREATE TABLE SystemUsers (
    SystemUserID    INT             IDENTITY(1,1)   PRIMARY KEY,
    DepartmentID    INT             NOT NULL
        CONSTRAINT FK_SysUser_Dept  FOREIGN KEY REFERENCES Departments(DepartmentID),
    FullName        NVARCHAR(100)   NOT NULL,
    LoginName       NVARCHAR(100)   NOT NULL        UNIQUE, -- matches SQL Server login
    Email           NVARCHAR(100)   NOT NULL,               -- [SENSITIVE - will be masked]
    PasswordHash    VARBINARY(64)   NULL,                   -- [SENSITIVE - SHA-256 hash]
    PasswordSalt    NVARCHAR(50)    NULL,                   -- salt for hashing
    UserRole        NVARCHAR(50)    NOT NULL
        CONSTRAINT CK_SysUser_Role CHECK (UserRole IN (
            'DBA','PropMgmtDev','ClientPortalDev','Analyst','ReadOnly','Admin'
        )),
    IsActive        BIT             NOT NULL        DEFAULT 1,
    CreatedDate     DATETIME        NOT NULL        DEFAULT GETDATE(),
);
GO
SELECT * FROM SystemUsers

-- ------------------------------------------------------------
-- 8. UserLoginLog
--    Tracks every login attempt (success + failure) against
--    the EMS. Supports both server-level and DB-level audit.
--    Populated by a trigger + SQL Server Audit (Kai Wen).
-- ------------------------------------------------------------ -- NO VALUE HAS BEEN  INSERTED YET AS PER REQUEST
CREATE TABLE UserLoginLog (
    LogID           INT             IDENTITY(1,1)   PRIMARY KEY,
    SystemUserID    INT             NULL            -- NULL if login name not matched
        CONSTRAINT FK_LoginLog_User FOREIGN KEY REFERENCES SystemUsers(SystemUserID),
    LoginName       NVARCHAR(100)   NOT NULL,
    LoginTime       DATETIME        NOT NULL        DEFAULT GETDATE(),
    LogoutTime      DATETIME        NULL,
    IsSuccessful    BIT             NOT NULL,
    IPAddress       NVARCHAR(50)    NULL,
    HostName        NVARCHAR(100)   NULL,
    FailureReason   NVARCHAR(255)   NULL            -- populated on failed attempts
);
GO

SELECT * FROM UserLoginLog

-- ------------------------------------------------------------
-- 9. AuditLog
--    Central audit trail for all DML events (INSERT, UPDATE,
--    DELETE) across sensitive tables. Populated by triggers
--    (Sarvein). Schema mirrors a generic change-capture table.
-- ------------------------------------------------------------ --NO VALUE HAS BEEN  INSERTED YET AS PER REQUEST
CREATE TABLE AuditLog (
    AuditID         INT             IDENTITY(1,1)   PRIMARY KEY,
    EventTime       DATETIME        NOT NULL        DEFAULT GETDATE(),
    TableName       NVARCHAR(128)   NOT NULL,
    OperationType   NVARCHAR(10)    NOT NULL
        CONSTRAINT CK_Audit_Op CHECK (OperationType IN ('INSERT','UPDATE','DELETE')),
    RecordID        NVARCHAR(50)    NOT NULL,       -- PK value of affected row (stored as string)
    ChangedBy       NVARCHAR(100)   NOT NULL        DEFAULT SYSTEM_USER,
    OldValues       NVARCHAR(MAX)   NULL,           -- JSON snapshot of old row
    NewValues       NVARCHAR(MAX)   NULL,           -- JSON snapshot of new row
    ApplicationName NVARCHAR(128)   NULL,
    HostName        NVARCHAR(128)   NULL
);
GO

SELECT * FROM AuditLog


-- ------------------------------------------------------------CHECK with SARVEIN with the output 
-- 10. LeaseAgreements
--     Formalises rental agreements between clients and
--     properties. Supports the rental lifecycle (active,
--     expired, terminated). Linked to a Transaction.
--     Security note: AgreementDocPath may point to an
--     encrypted document blob.
-- ------------------------------------------------------------
CREATE TABLE LeaseAgreements (
    LeaseID             INT             IDENTITY(1,1)   PRIMARY KEY,
    TransactionID       INT             NOT NULL        UNIQUE  -- 1 lease per rental transaction
        CONSTRAINT FK_Lease_Trans   FOREIGN KEY REFERENCES Transactions(TransactionID),
    PropertyID          INT             NOT NULL
        CONSTRAINT FK_Lease_Prop    FOREIGN KEY REFERENCES Properties(PropertyID),
    ClientID            INT             NOT NULL
        CONSTRAINT FK_Lease_Client  FOREIGN KEY REFERENCES Clients(ClientID),
    LeaseStartDate      DATE            NOT NULL,
    LeaseEndDate        DATE            NOT NULL,
    MonthlyRent         DECIMAL(18,2)   NOT NULL,   -- [SENSITIVE - financial]
    SecurityDeposit     DECIMAL(18,2)   NOT NULL,   -- [SENSITIVE - financial]
    LeaseStatus         NVARCHAR(50)    NOT NULL    DEFAULT 'Active'
        CONSTRAINT CK_Lease_Status CHECK (LeaseStatus IN ('Active','Expired','Terminated','Renewed')),
    AgreementDocPath    NVARCHAR(500)   NULL,       -- path to signed agreement document
    SignedDate          DATE            NULL,
    CreatedDate         DATETIME        NOT NULL    DEFAULT GETDATE()
);
GO



-- ------------------------------------------------------------
-- 11. CommissionPayments
--     Tracks commission earned and paid to agents per
--     transaction. Required for financial integrity and
--     analytics. Sensitive financial data; access restricted.
-- ------------------------------------------------------------
CREATE TABLE CommissionPayments (
    CommissionID    INT             IDENTITY(1,1)   PRIMARY KEY,
    TransactionID   INT             NOT NULL
        CONSTRAINT FK_Comm_Trans    FOREIGN KEY REFERENCES Transactions(TransactionID),
    AgentID         INT             NOT NULL
        CONSTRAINT FK_Comm_Agent    FOREIGN KEY REFERENCES Agents(AgentID),
    CommissionRate  DECIMAL(5,2)    NOT NULL,       -- rate at time of transaction (snapshot)
    CommissionAmount DECIMAL(18,2)  NOT NULL,       -- [SENSITIVE - financial]
    PaymentStatus   NVARCHAR(50)    NOT NULL        DEFAULT 'Unpaid'
        CONSTRAINT CK_Comm_Status CHECK (PaymentStatus IN ('Unpaid','Paid','Disputed')),
    PaymentDate     DATETIME        NULL,
    Remarks         NVARCHAR(255)   NULL
);
GO

SELECT * FROM CommissionPayments
SELECT * FROM Transactions
-- ------------------------------------------------------------
-- 12. MaintenanceStaff
--     Tracks in-house or contracted maintenance workers.
--     Linked to MaintenanceRequests for job assignment.
-- ------------------------------------------------------------
CREATE TABLE MaintenanceStaff (
    StaffID         INT             IDENTITY(1,1)   PRIMARY KEY,
    FullName        NVARCHAR(100)   NOT NULL,
    ContactNumber   NVARCHAR(20)    NOT NULL,       -- [SENSITIVE - will be masked]
    Specialisation  NVARCHAR(100)   NULL,           -- 'Plumbing','Electrical','General', etc.
    IsContractor    BIT             NOT NULL        DEFAULT 0,  -- 0=in-house, 1=external
    IsActive        BIT             NOT NULL        DEFAULT 1,
    JoinedDate      DATETIME        NOT NULL        DEFAULT GETDATE()
);
GO

SELECT * FROM MaintenanceStaff

-- Add FK back to MaintenanceRequests for assigned staff
ALTER TABLE MaintenanceRequests
    ADD AssignedStaffID INT NULL
        CONSTRAINT FK_Maint_Staff FOREIGN KEY REFERENCES MaintenanceStaff(StaffID);
GO

-- ------------------------------------------------------------
-- 13. Notifications
--     Stores system notifications sent to clients or agents
--     (lease expiry reminders, maintenance updates, etc.).
--     Supports the operational trigger work (Sarvein).
-- ------------------------------------------------------------
CREATE TABLE Notifications (
    NotificationID  INT             IDENTITY(1,1)   PRIMARY KEY,
    RecipientType   NVARCHAR(20)    NOT NULL
        CONSTRAINT CK_Notif_RecipType CHECK (RecipientType IN ('Client','Agent','SystemUser')),
    RecipientID     INT             NOT NULL,       -- FK resolved via RecipientType at app layer
    Subject         NVARCHAR(200)   NOT NULL,
    MessageBody     NVARCHAR(MAX)   NOT NULL,
    Channel         NVARCHAR(50)    NOT NULL        DEFAULT 'Email'
        CONSTRAINT CK_Notif_Channel CHECK (Channel IN ('Email','SMS','InApp')),
    IsSent          BIT             NOT NULL        DEFAULT 0,
    SentAt          DATETIME        NULL,
    CreatedAt       DATETIME        NOT NULL        DEFAULT GETDATE(),
    RelatedTable    NVARCHAR(128)   NULL,           -- e.g. 'LeaseAgreements'
    RelatedRecordID INT             NULL            -- e.g. LeaseID
);
GO


-- ------------------------------------------------------------
-- INSERTING VALUES
---------------------------------------------------------------
-- 1. Properties
-- residential, commercial, industrial and land properties.
-- Data includes multiple Malaysian states and operational
-- property statuses for EMS system testing and reporting.
-- ------------------------------------------------------------


INSERT INTO Properties
(PropertyName, Address, City, State, PostalCode, PropertyType, Bedrooms, Bathrooms, SizeSqft, Price, Status)
VALUES
('Seri Mutiara Residence', 'No. 12, Jalan Ampang Indah 3/2, Taman Ampang Indah', 'Kuala Lumpur', 'Kuala Lumpur', '50450', 'Residential', 4, 3, 2100, 980000, 'Available'),
('Cyber Heights Condo', 'Unit A-18-03, Persiaran Multimedia, Cyber Heights', 'Cyberjaya', 'Selangor', '63000', 'Residential', 3, 2, 1450, 620000, 'Sold'),
('Sunway Business Hub', 'Lot 22, Jalan PJS 11/15, Bandar Sunway', 'Subang Jaya', 'Selangor', '47500', 'Commercial', NULL, 4, 5000, 2500000, 'Available'),
('Penang Pearl Villa', 'No. 8, Jalan Tanjung Tokong 5, Seri Tanjung', 'George Town', 'Penang', '10470', 'Residential', 5, 4, 3200, 1850000, 'Reserved'),
('Johor Industrial Park', 'Lot 1187, Jalan Kempas Lama Industrial Zone', 'Johor Bahru', 'Johor', '81200', 'Industrial', NULL, 2, 10000, 4800000, 'Rented'),
('Lakeview Apartment', 'Unit B-12-08, Jalan Kuching Perdana', 'Kuala Lumpur', 'Kuala Lumpur', '51200', 'Residential', 2, 2, 980, 420000, 'Available'),
('Melaka Heritage Suites', 'No. 15, Jalan Banda Kaba 2', 'Melaka City', 'Melaka', '75000', 'Residential', 3, 2, 1550, 690000, 'Under Maintenance'),
('Borneo Green Estate', 'No. 6, Jalan Lintas Jaya 4', 'Kota Kinabalu', 'Sabah', '88300', 'Residential', 4, 3, 2400, 1100000, 'Available'),
('Kuching Riverside Homes', 'No. 18, Lorong Pending 8A', 'Kuching', 'Sarawak', '93450', 'Residential', 4, 3, 2200, 870000, 'Reserved'),
('Damansara Executive Tower', 'Suite 21-05, Damansara Perdana Corporate Centre', 'Petaling Jaya', 'Selangor', '47820', 'Commercial', NULL, 6, 8000, 6200000, 'Available'),
('Bukit Jalil Sky Condo', 'Unit C-20-11, Jalan Jalil Perkasa 1', 'Kuala Lumpur', 'Kuala Lumpur', '57000', 'Residential', 3, 2, 1350, 760000, 'Sold'),
('Ipoh Garden Terrace', 'No. 24, Jalan Sultan Azlan Shah Utama', 'Ipoh', 'Perak', '31400', 'Residential', 4, 3, 2100, 580000, 'Available'),
('Nilai Tech Park', 'Lot 778, Persiaran Teknologi Nilai', 'Nilai', 'Negeri Sembilan', '71800', 'Industrial', NULL, 3, 12000, 5100000, 'Available'),
('Setia Alam Villa', 'No. 3, Persiaran Setia Alam Impian', 'Shah Alam', 'Selangor', '40170', 'Residential', 5, 4, 3500, 2200000, 'Reserved'),
('KLCC Platinum Suites', 'Unit 28-09, Jalan Sultan Ismail Platinum Suites', 'Kuala Lumpur', 'Kuala Lumpur', '50250', 'Residential', 2, 2, 1150, 1400000, 'Rented'),
('Muar Commercial Square', 'Lot 55, Jalan Sulaiman Business Centre', 'Muar', 'Johor', '84000', 'Commercial', NULL, 3, 6200, 1800000, 'Available'),
('Langkawi Beach Resort Land', 'Lot 901, Pantai Cenang Coastal Area', 'Langkawi', 'Kedah', '07000', 'Land', NULL, NULL, 20000, 3500000, 'Reserved'),
('Tropicana Heights', 'No. 19, Persiaran Tropicana Heights', 'Petaling Jaya', 'Selangor', '47410', 'Residential', 4, 3, 2600, 1750000, 'Available'),
('Sibu Central Offices', 'Suite 11-02, Jalan Wong Nai Siong Commercial Hub', 'Sibu', 'Sarawak', '96000', 'Commercial', NULL, 5, 7000, 2900000, 'Under Maintenance'),
('Kuantan Waterfront Condo', 'Unit A-09-06, Jalan Beserah Waterfront', 'Kuantan', 'Pahang', '25300', 'Residential', 3, 2, 1500, 670000, 'Sold'),
('Putrajaya Lake Suites', 'No. 9, Presint 5 Lakeview Residences', 'Putrajaya', 'Putrajaya', '62200', 'Residential', 4, 3, 2300, 1250000, 'Available'),
('Alor Setar Industrial Hub', 'Lot 3321, Jalan Kuala Kedah Industrial Estate', 'Alor Setar', 'Kedah', '06600', 'Industrial', NULL, 2, 15000, 5300000, 'Available'),
('Cheras Business Centre', 'Suite 8-01, Jalan Cheras Business Avenue', 'Kuala Lumpur', 'Kuala Lumpur', '56100', 'Commercial', NULL, 4, 4500, 2700000, 'Rented'),
('Bangi Smart Homes', 'No. 11, Jalan Seksyen 9/4', 'Bangi', 'Selangor', '43650', 'Residential', 4, 3, 2150, 890000, 'Available'),
('Taiping Green Park', 'No. 31, Jalan Tupai Hijau', 'Taiping', 'Perak', '34000', 'Residential', 3, 2, 1450, 490000, 'Reserved'),
('Puchong Financial Tower', 'Suite 17-03, Bandar Puteri Financial Centre', 'Puchong', 'Selangor', '47100', 'Commercial', NULL, 6, 9000, 7200000, 'Available'),
('Batu Pahat Family Villa', 'No. 88, Jalan Rugayah Perdana', 'Batu Pahat', 'Johor', '83000', 'Residential', 5, 4, 3000, 1350000, 'Sold'),
('Sandakan Palm Estate', 'Lot 2301, Jalan Labuk Palm Estate', 'Sandakan', 'Sabah', '90000', 'Land', NULL, NULL, 35000, 4400000, 'Available'),
('Sri Hartamas Residency', 'Unit D-15-02, Jalan Dutamas Raya', 'Kuala Lumpur', 'Kuala Lumpur', '50480', 'Residential', 3, 2, 1600, 980000, 'Available'),
('Port Dickson Holiday Condo', 'Unit B-07-11, Batu 4 Jalan Pantai', 'Port Dickson', 'Negeri Sembilan', '71050', 'Residential', 2, 2, 1200, 560000, 'Reserved'),
('Bintulu Industrial Centre', 'Lot 509, Jalan Tanjung Kidurong Industrial Zone', 'Bintulu', 'Sarawak', '97000', 'Industrial', NULL, 3, 18000, 6500000, 'Rented'),
('Kajang Prima Homes', 'No. 22, Jalan Reko Prima 2', 'Kajang', 'Selangor', '43000', 'Residential', 4, 3, 2250, 780000, 'Available'),
('Seremban Trade Square', 'Suite 10-08, Jalan Dato Bandar Tunggal', 'Seremban', 'Negeri Sembilan', '70000', 'Commercial', NULL, 4, 5200, 2400000, 'Under Maintenance'),
('Rawang Eco Residence', 'No. 5, Bandar Country Homes Eco Park', 'Rawang', 'Selangor', '48000', 'Residential', 4, 3, 2450, 820000, 'Available'),
('Pasir Gudang Logistic Hub', 'Lot 712, Jalan Gudang Nenas Logistics Park', 'Pasir Gudang', 'Johor', '81700', 'Industrial', NULL, 4, 25000, 8900000, 'Available'),
('Bukit Bintang Suites', 'Unit 19-06, Jalan Bukit Bintang Residences', 'Kuala Lumpur', 'Kuala Lumpur', '55100', 'Residential', 2, 2, 980, 1300000, 'Sold'),
('Miri Coastal Villas', 'No. 7, Jalan Marina Bay Residences', 'Miri', 'Sarawak', '98000', 'Residential', 5, 4, 3300, 1950000, 'Available'),
('Shah Alam Commerce Hub', 'Suite 12-01, Seksyen 13 Commerce Square', 'Shah Alam', 'Selangor', '40100', 'Commercial', NULL, 5, 6800, 3600000, 'Reserved'),
('Kelana Jaya Condominium', 'Unit A-10-09, SS6 Kelana Heights', 'Petaling Jaya', 'Selangor', '47301', 'Residential', 3, 2, 1400, 720000, 'Available'),
('Terengganu Beach Land', 'Lot 822, Jalan Pantai Batu Buruk Coastal Area', 'Kuala Terengganu', 'Terengganu', '20400', 'Land', NULL, NULL, 40000, 5000000, 'Reserved'),
('Segamat Townhouses', 'No. 17, Jalan Genuang Prima', 'Segamat', 'Johor', '85000', 'Residential', 4, 3, 2000, 640000, 'Available'),
('Ampang Waterfront Condo', 'Unit C-08-03, Jalan Memanda Waterfront', 'Ampang', 'Selangor', '68000', 'Residential', 3, 2, 1500, 880000, 'Rented'),
('Kota Bharu Trade Centre', 'Suite 9-11, Jalan Sultan Yahya Petra Business Centre', 'Kota Bharu', 'Kelantan', '15150', 'Commercial', NULL, 4, 6000, 2100000, 'Available'),
('Sepang Aeropolis Hub', 'Lot 1555, Jalan KLIA Aeropolis Industrial Park', 'Sepang', 'Selangor', '64000', 'Industrial', NULL, 5, 30000, 9800000, 'Available'),
('Bayan Lepas Tech Offices', 'Suite 14-02, Jalan Sultan Azlan Shah Tech Park', 'Bayan Lepas', 'Penang', '11900', 'Commercial', NULL, 5, 8500, 4500000, 'Sold'),
('TTDI Luxury Residence', 'No. 2, Jalan Tun Mohd Fuad Luxury Heights', 'Kuala Lumpur', 'Kuala Lumpur', '60000', 'Residential', 5, 5, 4000, 3200000, 'Available'),
('Klang Sentral Warehouse', 'Lot 2020, Jalan Kapar Industrial Estate', 'Klang', 'Selangor', '41400', 'Industrial', NULL, 3, 22000, 7600000, 'Under Maintenance'),
('Jasin Eco Farm Land', 'Lot 88, Jalan Air Baruk Agricultural Zone', 'Jasin', 'Melaka', '77000', 'Land', NULL, NULL, 50000, 2900000, 'Available'),
('Mont Kiara Executive Suites', 'Unit E-22-05, Jalan Kiara Executive Residences', 'Kuala Lumpur', 'Kuala Lumpur', '50480', 'Residential', 4, 3, 2500, 2100000, 'Reserved'),
('Iskandar Puteri Smart Offices', 'Suite 25-01, Medini Smart Business Tower', 'Iskandar Puteri', 'Johor', '79250', 'Commercial', NULL, 6, 11000, 8300000, 'Available');

-- ------------------------------------------------------------
-- 2. Clients
-- Data includes individual and corporate clients for EMS
-- testing, encryption, masking and reporting.
-- ------------------------------------------------------------

INSERT INTO Clients
(FullName, NRIC, ContactNumber, Email, Address, ClientType)
VALUES
('Ali Ahmad', '900101145555', '0123456789', 'ali.ahmad@gmail.com', 'No. 12, Jalan Melati 3, Shah Alam, Selangor', 'Individual'),
('Siti Nurhaliza', '920202105555', '0139876543', 'siti.nur@gmail.com', 'Unit A-12-08, Jalan Cheras Perdana, Kuala Lumpur', 'Individual'),
('John Tan Wei Ming', '880303085555', '0145566778', 'john.tan@gmail.com', 'No. 45, Jalan SS15/4, Subang Jaya, Selangor', 'Individual'),
('Meena Raj', '950404145555', '0162223344', 'meena.raj@gmail.com', 'No. 8, Jalan Reko 2, Kajang, Selangor', 'Individual'),
('Daniel Lim', '910505105555', '0173334455', 'daniel.lim@gmail.com', 'Unit B-09-06, Jalan Bukit Bintang, Kuala Lumpur', 'Individual'),
('GreenTech Solutions Sdn Bhd', 'BRN100001', '0322118899', 'contact@greentech.com.my', 'Suite 12-01, Menara Axis, Petaling Jaya, Selangor', 'Corporate'),
('Nur Aina', '960606145555', '0184445566', 'aina.nur@gmail.com', 'No. 21, Jalan Gombak Setia, Gombak, Selangor', 'Individual'),
('Kumar Ravi', '870707085555', '0195556677', 'kumar.ravi@gmail.com', 'No. 17, Jalan Serdang Raya, Seri Kembangan, Selangor', 'Individual'),
('Michelle Lee', '930808105555', '0116667788', 'michelle.lee@gmail.com', 'Unit C-15-03, Bangsar South, Kuala Lumpur', 'Individual'),
('Farah Zain', '970909145555', '0127778899', 'farah.zain@gmail.com', 'No. 9, Jalan Genting Klang, Setapak, Kuala Lumpur', 'Individual'),
('Jason Wong', '891010085555', '0138889900', 'jason.wong@gmail.com', 'Unit D-20-10, Jalan Ampang, Kuala Lumpur', 'Individual'),
('Priya Devi', '941111105555', '0149990011', 'priya.devi@gmail.com', 'No. 28, Jalan Tun Sambanthan, Brickfields, Kuala Lumpur', 'Individual'),
('Hafiz Rahman', '901212145555', '0151112233', 'hafiz.rahman@gmail.com', 'No. 33, Jalan Damansara Utama, Petaling Jaya, Selangor', 'Individual'),
('Alicia Tan', '980101085555', '0162223345', 'alicia.tan@gmail.com', 'Unit E-18-05, Mont Kiara, Kuala Lumpur', 'Individual'),
('Rajesh Kumar', '860202105555', '0173334456', 'rajesh.kumar@gmail.com', 'No. 19, Jalan Sentul Pasar, Kuala Lumpur', 'Individual'),
('Nadia Sofia', '990303145555', '0184445567', 'nadia.sofia@gmail.com', 'Unit F-11-02, Cyber Heights, Cyberjaya, Selangor', 'Individual'),
('Brandon Lee', '890404085555', '0191112233', 'brandon.lee@gmail.com', 'No. 71, Jalan Kapar, Klang, Selangor', 'Individual'),
('Sara Lim', '970505105555', '0112223344', 'sara.lim@gmail.com', 'No. 6, Jalan Rawang Perdana, Rawang, Selangor', 'Individual'),
('Viknesh Rao', '880606145555', '0123334455', 'viknesh.rao@gmail.com', 'No. 4, Jalan Ampang Jaya, Ampang, Selangor', 'Individual'),
('Amira Hassan', '960707085555', '0134445566', 'amira.hassan@gmail.com', 'No. 25, Jalan Selayang Baru, Selayang, Selangor', 'Individual'),
('MegaBuild Holdings Sdn Bhd', 'BRN100002', '0377881122', 'admin@megabuild.com.my', 'Suite 15-03, Menara UOA, Bangsar, Kuala Lumpur', 'Corporate'),
('Leon Tan', '930808145555', '0145556677', 'leon.tan@gmail.com', 'Unit A-07-12, Kelana Jaya, Petaling Jaya, Selangor', 'Individual'),
('Anita Wong', '920909105555', '0156667788', 'anita.wong@gmail.com', 'No. 14, Jalan Kepong Baru, Kuala Lumpur', 'Individual'),
('Ravi Chandran', '871010085555', '0167778899', 'ravi.chandran@gmail.com', 'No. 51, Jalan Seri Kembangan 5, Selangor', 'Individual'),
('Nurul Izzah', '951111145555', '0178889900', 'nurul.izzah@gmail.com', 'Unit B-19-01, Wangsa Maju, Kuala Lumpur', 'Individual'),
('Marcus Chan', '901212105555', '0189990011', 'marcus.chan@gmail.com', 'Unit C-08-07, Bukit Jalil, Kuala Lumpur', 'Individual'),
('Deepa Nair', '940101085555', '0190001122', 'deepa.nair@gmail.com', 'No. 30, Jalan Taman Desa, Kuala Lumpur', 'Individual'),
('Adam Zaki', '990202145555', '0111011122', 'adam.zaki@gmail.com', 'Suite 9-06, KL Sentral, Kuala Lumpur', 'Individual'),
('Chloe Ng', '980303105555', '0122022233', 'chloe.ng@gmail.com', 'Unit D-22-08, Damansara Perdana, Selangor', 'Individual'),
('Mohan Krishnan', '860404085555', '0133033344', 'mohan.krishnan@gmail.com', 'No. 10, Old Klang Road, Kuala Lumpur', 'Individual'),
('UrbanEdge Properties Sdn Bhd', 'BRN100003', '0344556677', 'info@urbanedge.com.my', 'Lot 18, Jalan Puchong Business Park, Puchong, Selangor', 'Corporate'),
('Yasmin Ali', '970505145555', '0144044455', 'yasmin.ali@gmail.com', 'No. 16, Jalan Batu Caves, Gombak, Selangor', 'Individual'),
('Steven Goh', '880606105555', '0155055566', 'steven.goh@gmail.com', 'Unit A-16-11, Kota Damansara, Selangor', 'Individual'),
('Liyana Aziz', '950707085555', '0166066677', 'liyana.aziz@gmail.com', 'No. 3, Jalan Setia Alam 7, Shah Alam, Selangor', 'Individual'),
('Kevin Yap', '910808145555', '0177077788', 'kevin.yap@gmail.com', 'No. 26, Persiaran Tropicana, Petaling Jaya, Selangor', 'Individual'),
('Shalini Devi', '940909105555', '0188088899', 'shalini.devi@gmail.com', 'No. 44, Jalan Sri Petaling, Kuala Lumpur', 'Individual'),
('Irfan Hakim', '961010085555', '0199099900', 'irfan.hakim@gmail.com', 'Unit B-13-09, Cyberjaya, Selangor', 'Individual'),
('Grace Lim', '981111145555', '0110101010', 'grace.lim@gmail.com', 'Unit C-21-04, Bangsar South, Kuala Lumpur', 'Individual'),
('Arjun Menon', '891212105555', '0121212121', 'arjun.menon@gmail.com', 'No. 73, Jalan USJ 11, Subang Jaya, Selangor', 'Individual'),
('Dina Rahman', '930101085555', '0132323232', 'dina.rahman@gmail.com', 'No. 29, Jalan Seksyen 13, Shah Alam, Selangor', 'Individual'),
('Prima Asset Management Sdn Bhd', 'BRN100004', '0366778899', 'support@primaasset.com.my', 'Suite 20-05, KL Eco City, Kuala Lumpur', 'Corporate'),
('Nicholas Teo', '920202145555', '0143434343', 'nicholas.teo@gmail.com', 'Unit E-10-06, Mont Kiara, Kuala Lumpur', 'Individual'),
('Kavitha Raman', '900303105555', '0154545454', 'kavitha.raman@gmail.com', 'No. 7, Jalan Cheras Mutiara, Kuala Lumpur', 'Individual'),
('Raymond Low', '870404085555', '0165656565', 'raymond.low@gmail.com', 'Unit A-25-01, KLCC, Kuala Lumpur', 'Individual'),
('Aisyah Kamarul', '990505145555', '0176767676', 'aisyah.kamarul@gmail.com', 'No. 13, Jalan Kajang Perdana, Kajang, Selangor', 'Individual'),
('Jonathan Ho', '880606105555', '0187878787', 'jonathan.ho@gmail.com', 'No. 56, Bandar Puteri, Puchong, Selangor', 'Individual'),
('Lavanya Siva', '950707085555', '0198989898', 'lavanya.siva@gmail.com', 'No. 22, Jalan Brickfields, Kuala Lumpur', 'Individual'),
('Syafiq Azman', '960808145555', '0119090909', 'syafiq.azman@gmail.com', 'Unit B-06-03, Sentul, Kuala Lumpur', 'Individual'),
('Janice Foo', '970909105555', '0128989898', 'janice.foo@gmail.com', 'Unit C-14-07, Bangsar, Kuala Lumpur', 'Individual'),
('Vimal Raj', '920202145555', '0173434343', 'vimal.raj@gmail.com', 'No. 18, Jalan Ipoh, Kuala Lumpur', 'Individual');

-- ------------------------------------------------------------
-- 3. Agents
-- including contact details, license numbers and commission
-- rates for EMS operational, reporting and security testing.
-- ------------------------------------------------------------

INSERT INTO Agents
(FullName, ContactNumber, Email, LicenseNumber, CommissionRate)
VALUES
('Farid Rahman', '0123456701', 'farid.rahman@ems.com.my', 'REN45821', 2.50),
('Melissa Wong', '0134567802', 'melissa.wong@ems.com.my', 'REN45822', 3.00),
('Arun Kumar', '0145678903', 'arun.kumar@ems.com.my', 'REN45823', 2.80),
('Linda Tan', '0156789004', 'linda.tan@ems.com.my', 'REN45824', 3.20),
('Hakim Zulkifli', '0167890105', 'hakim.zulkifli@ems.com.my', 'REN45825', 2.70),
('Rachel Lee', '0178901206', 'rachel.lee@ems.com.my', 'REN45826', 2.90),
('Vijay Menon', '0189012307', 'vijay.menon@ems.com.my', 'REN45827', 3.10),
('Sofia Aziz', '0190123408', 'sofia.aziz@ems.com.my', 'REN45828', 2.60),
('Kelvin Ong', '0111234509', 'kelvin.ong@ems.com.my', 'REN45829', 3.50),
('Aminah Salleh', '0122345610', 'aminah.salleh@ems.com.my', 'REN45830', 2.75),
('Jason Lim', '0133456721', 'jason.lim@ems.com.my', 'REN45831', 3.00),
('Nurul Huda', '0144567832', 'nurul.huda@ems.com.my', 'REN45832', 2.80),
('Brandon Lee', '0155678943', 'brandon.lee@ems.com.my', 'REN45833', 2.95),
('Priya Devi', '0166789054', 'priya.devi@ems.com.my', 'REN45834', 3.25),
('Marcus Chan', '0177890165', 'marcus.chan@ems.com.my', 'REN45835', 2.85),
('Diana Wong', '0188901276', 'diana.wong@ems.com.my', 'REN45836', 3.15),
('Rajesh Kumar', '0199012387', 'rajesh.kumar@ems.com.my', 'REN45837', 2.90),
('Sarah Lim', '0110123498', 'sarah.lim@ems.com.my', 'REN45838', 3.40),
('Nicholas Teo', '0121234501', 'nicholas.teo@ems.com.my', 'REN45839', 2.70),
('Aisyah Rahman', '0132345612', 'aisyah.rahman@ems.com.my', 'REN45840', 2.65),
('Leonard Goh', '0143456723', 'leonard.goh@ems.com.my', 'REN45841', 3.30),
('Shalini Devi', '0154567834', 'shalini.devi@ems.com.my', 'REN45842', 2.95),
('Irfan Hakim', '0165678945', 'irfan.hakim@ems.com.my', 'REN45843', 3.00),
('Grace Tan', '0176789056', 'grace.tan@ems.com.my', 'REN45844', 2.85),
('Kevin Yap', '0187890167', 'kevin.yap@ems.com.my', 'REN45845', 3.10),
('Michelle Chong', '0198901278', 'michelle.chong@ems.com.my', 'REN45846', 2.90),
('Adam Zaki', '0119012389', 'adam.zaki@ems.com.my', 'REN45847', 2.75),
('Janice Foo', '0120123490', 'janice.foo@ems.com.my', 'REN45848', 3.20),
('Vimal Raj', '0131234502', 'vimal.raj@ems.com.my', 'REN45849', 2.80),
('Chloe Ng', '0142345613', 'chloe.ng@ems.com.my', 'REN45850', 3.00),
('Syafiq Azman', '0153456724', 'syafiq.azman@ems.com.my', 'REN45851', 2.95),
('Alicia Tan', '0164567835', 'alicia.tan@ems.com.my', 'REN45852', 3.40),
('Jonathan Ho', '0175678946', 'jonathan.ho@ems.com.my', 'REN45853', 2.60),
('Kavitha Raman', '0186789057', 'kavitha.raman@ems.com.my', 'REN45854', 2.85),
('Raymond Low', '0197890168', 'raymond.low@ems.com.my', 'REN45855', 3.15),
('Dina Rahman', '0118901279', 'dina.rahman@ems.com.my', 'REN45856', 2.90),
('Steven Goh', '0129012380', 'steven.goh@ems.com.my', 'REN45857', 3.25),
('Lavanya Siva', '0130123491', 'lavanya.siva@ems.com.my', 'REN45858', 2.70),
('Marcus Lim', '0141234503', 'marcus.lim@ems.com.my', 'REN45859', 2.95),
('Yasmin Ali', '0152345614', 'yasmin.ali@ems.com.my', 'REN45860', 3.05),
('Daniel Wong', '0163456725', 'daniel.wong@ems.com.my', 'REN45861', 2.85),
('Meera Nair', '0174567836', 'meera.nair@ems.com.my', 'REN45862', 3.10),
('Haziq Iskandar', '0185678947', 'haziq.iskandar@ems.com.my', 'REN45863', 2.75),
('Ashley Lee', '0196789058', 'ashley.lee@ems.com.my', 'REN45864', 3.00),
('Harith Azlan', '0117890169', 'harith.azlan@ems.com.my', 'REN45865', 2.95),
('Nadia Karim', '0128901270', 'nadia.karim@ems.com.my', 'REN45866', 3.20),
('Ben Chan', '0139012381', 'ben.chan@ems.com.my', 'REN45867', 2.65),
('Samantha Goh', '0140123492', 'samantha.goh@ems.com.my', 'REN45868', 2.85),
('Ruben Pillai', '0151234504', 'ruben.pillai@ems.com.my', 'REN45869', 3.35),
('Farzana Malik', '0162345615', 'farzana.malik@ems.com.my', 'REN45870', 2.90);


-- ------------------------------------------------------------
-- 4. Transactions
-- records linked to different properties, clients and agents.
-- Data avoids simple sequential matching to better reflect
-- ------------------------------------------------------------

INSERT INTO Transactions
(PropertyID, ClientID, AgentID, TransactionType, Amount, RentStartDate, RentEndDate, PaymentStatus, PaymentMethod)
VALUES
(1, 5, 2, 'Sale', 980000.00, NULL, NULL, 'Completed', 'Bank Transfer'),
(2, 8, 2, 'Rent', 3200.00, '2026-01-01', '2027-01-01', 'Completed', 'Bank Transfer'),
(3, 12, 7, 'Sale', 2500000.00, NULL, NULL, 'Pending', 'Cheque'),
(4, 1, 3, 'Sale', 1850000.00, NULL, NULL, 'Completed', 'Cash'),
(5, 20, 1, 'Rent', 12000.00, '2026-02-15', '2028-02-15', 'Completed', 'Bank Transfer'),
(6, 14, 6, 'Rent', 1800.00, '2026-03-01', '2027-03-01', 'Pending', 'Cash'),
(7, 3, 4, 'Sale', 690000.00, NULL, NULL, 'Completed', 'Bank Transfer'),
(8, 25, 8, 'Sale', 1100000.00, NULL, NULL, 'Completed', 'Cheque'),
(9, 17, 9, 'Rent', 4500.00, '2026-01-10', '2027-01-10', 'Completed', 'Bank Transfer'),
(10, 30, 10, 'Sale', 6200000.00, NULL, NULL, 'Pending', 'Cheque'),
(11, 2, 2, 'Sale', 760000.00, NULL, NULL, 'Completed', 'Cash'),
(12, 35, 7, 'Rent', 2800.00, '2026-04-01', '2027-04-01', 'Completed', 'Bank Transfer'),
(13, 18, 5, 'Sale', 5100000.00, NULL, NULL, 'Completed', 'Bank Transfer'),
(14, 44, 3, 'Sale', 2200000.00, NULL, NULL, 'Pending', 'Cheque'),
(15, 6, 1, 'Rent', 5500.00, '2026-05-01', '2027-05-01', 'Completed', 'Cash'),
(16, 28, 4, 'Sale', 1800000.00, NULL, NULL, 'Completed', 'Bank Transfer'),
(17, 9, 6, 'Sale', 3500000.00, NULL, NULL, 'Cancelled', 'Cheque'),
(18, 40, 8, 'Rent', 4800.00, '2026-02-01', '2027-02-01', 'Completed', 'Bank Transfer'),
(19, 13, 10, 'Sale', 2900000.00, NULL, NULL, 'Pending', 'Cash'),
(20, 31, 2, 'Sale', 670000.00, NULL, NULL, 'Completed', 'Bank Transfer'),
(21, 22, 7, 'Rent', 5200.00, '2026-03-15', '2028-03-15', 'Completed', 'Bank Transfer'),
(22, 4, 5, 'Sale', 5300000.00, NULL, NULL, 'Completed', 'Cheque'),
(23, 37, 9, 'Sale', 2700000.00, NULL, NULL, 'Pending', 'Bank Transfer'),
(24, 11, 3, 'Rent', 3500.00, '2026-06-01', '2027-06-01', 'Completed', 'Cash'),
(25, 19, 1, 'Sale', 490000.00, NULL, NULL, 'Completed', 'Bank Transfer'),
(26, 46, 4, 'Sale', 7200000.00, NULL, NULL, 'Completed', 'Cheque'),
(27, 7, 6, 'Rent', 6500.00, '2026-01-20', '2028-01-20', 'Pending', 'Bank Transfer'),
(28, 33, 8, 'Sale', 4400000.00, NULL, NULL, 'Completed', 'Cash'),
(29, 15, 10, 'Sale', 980000.00, NULL, NULL, 'Completed', 'Bank Transfer'),
(30, 41, 2, 'Rent', 2500.00, '2026-04-10', '2027-04-10', 'Completed', 'Cheque'),
(31, 24, 7, 'Sale', 6500000.00, NULL, NULL, 'Pending', 'Bank Transfer'),
(32, 10, 5, 'Sale', 780000.00, NULL, NULL, 'Completed', 'Cash'),
(33, 39, 9, 'Rent', 4200.00, '2026-07-01', '2027-07-01', 'Completed', 'Bank Transfer'),
(34, 16, 3, 'Sale', 820000.00, NULL, NULL, 'Completed', 'Cheque'),
(35, 48, 1, 'Sale', 8900000.00, NULL, NULL, 'Pending', 'Bank Transfer'),
(36, 21, 4, 'Rent', 7000.00, '2026-02-05', '2028-02-05', 'Completed', 'Cash'),
(37, 32, 6, 'Sale', 1950000.00, NULL, NULL, 'Completed', 'Bank Transfer'),
(38, 45, 8, 'Sale', 3600000.00, NULL, NULL, 'Refunded', 'Cheque'),
(39, 26, 10, 'Rent', 3100.00, '2026-05-15', '2027-05-15', 'Completed', 'Bank Transfer'),
(40, 38, 2, 'Sale', 5000000.00, NULL, NULL, 'Completed', 'Cash'),
(41, 29, 7, 'Sale', 640000.00, NULL, NULL, 'Pending', 'Bank Transfer'),
(42, 43, 5, 'Rent', 3900.00, '2026-03-10', '2027-03-10', 'Completed', 'Cheque'),
(43, 34, 9, 'Sale', 2100000.00, NULL, NULL, 'Completed', 'Bank Transfer'),
(44, 23, 3, 'Sale', 9800000.00, NULL, NULL, 'Pending', 'Cash'),
(45, 47, 1, 'Rent', 8300.00, '2026-06-20', '2028-06-20', 'Completed', 'Bank Transfer'),
(46, 27, 4, 'Sale', 3200000.00, NULL, NULL, 'Completed', 'Cheque'),
(47, 36, 6, 'Sale', 7600000.00, NULL, NULL, 'Completed', 'Bank Transfer'),
(48, 50, 8, 'Rent', 2700.00, '2026-01-25', '2027-01-25', 'Completed', 'Cash'),
(49, 42, 10, 'Sale', 2100000.00, NULL, NULL, 'Pending', 'Bank Transfer'),
(50, 49, 2, 'Sale', 8300000.00, NULL, NULL, 'Completed', 'Cheque');

-- ------------------------------------------------------------
-- 5. MaintenanceRequests
-- Added 50 realistic maintenance request records covering
-- plumbing, electrical, structural and facility maintenance.
-- Includes request priorities, costs and maintenance statuses
-- for EMS operational and maintenance workflow testing.
-- ------------------------------------------------------------

INSERT INTO MaintenanceRequests
(PropertyID, RequestedByClientID, RequestDetails, Priority, RequestDate, Status, EstimatedCost, ActualCost, CompletedDate)
VALUES
(1, 5, 'Water leakage detected in master bedroom ceiling.', 'High', '2026-01-10', 'Completed', 1200.00, 1350.00, '2026-01-15'),
(2, 8, 'Air conditioning unit not functioning properly.', 'Medium', '2026-02-01', 'In Progress', 800.00, NULL, NULL),
(3, NULL, 'Routine inspection for commercial electrical wiring.', 'Low', '2026-02-05', 'Pending', 2500.00, NULL, NULL),
(4, 1, 'Broken kitchen cabinet hinges requiring replacement.', 'Low', '2026-01-28', 'Completed', 450.00, 420.00, '2026-02-02'),
(5, 20, 'Warehouse roller shutter malfunction.', 'Critical', '2026-02-12', 'In Progress', 5500.00, NULL, NULL),
(6, 14, 'Bathroom sink pipe leakage reported.', 'Medium', '2026-01-25', 'Completed', 300.00, 280.00, '2026-01-28'),
(7, 3, 'Cracked wall tiles in living room area.', 'Low', '2026-02-14', 'Pending', 700.00, NULL, NULL),
(8, 25, 'Roof water seepage during heavy rain.', 'High', '2026-02-28', 'Completed', 3200.00, 3500.00, '2026-03-05'),
(9, 17, 'Main gate access system failure.', 'Critical', '2026-03-01', 'In Progress', 4500.00, NULL, NULL),
(10, NULL, 'Scheduled fire safety maintenance inspection.', 'Medium', '2026-02-10', 'Completed', 1800.00, 1750.00, '2026-02-18'),
(11, 2, 'Bedroom power socket not working.', 'Medium', '2026-01-18', 'Completed', 250.00, 230.00, '2026-01-22'),
(12, 35, 'Water heater replacement required.', 'Medium', '2026-03-02', 'Pending', 950.00, NULL, NULL),
(13, NULL, 'Industrial ventilation system servicing.', 'High', '2026-03-04', 'In Progress', 6200.00, NULL, NULL),
(14, 44, 'Broken glass panel at balcony area.', 'High', '2026-03-07', 'Completed', 1500.00, 1480.00, '2026-03-11'),
(15, 6, 'Condominium lift experiencing intermittent faults.', 'Critical', '2026-03-08', 'Pending', 12000.00, NULL, NULL),
(16, 28, 'Termite treatment required for wooden flooring.', 'High', '2026-02-20', 'Completed', 2400.00, 2550.00, '2026-02-25'),
(17, 9, 'Parking bay repainting request.', 'Low', '2026-01-26', 'Completed', 600.00, 580.00, '2026-01-30'),
(18, 40, 'Water pressure issue affecting multiple units.', 'High', '2026-02-22', 'In Progress', 3200.00, NULL, NULL),
(19, NULL, 'Commercial building CCTV maintenance.', 'Medium', '2026-02-25', 'Completed', 1800.00, 1900.00, '2026-03-02'),
(20, 31, 'Mold growth detected in bathroom ceiling.', 'Medium', '2026-03-01', 'Pending', 900.00, NULL, NULL),
(21, 22, 'Swimming pool filtration system servicing.', 'Medium', '2026-02-03', 'Completed', 3500.00, 3400.00, '2026-02-08'),
(22, NULL, 'Industrial warehouse lighting replacement.', 'High', '2026-01-12', 'Completed', 2700.00, 2850.00, '2026-01-19'),
(23, 37, 'Office air ventilation not functioning.', 'High', '2026-03-03', 'In Progress', 2200.00, NULL, NULL),
(24, 11, 'Kitchen sink blockage reported.', 'Medium', '2026-02-09', 'Completed', 180.00, 200.00, '2026-02-12'),
(25, 19, 'Exterior wall repainting request.', 'Low', '2026-03-05', 'Pending', 4500.00, NULL, NULL),
(26, NULL, 'Commercial elevator maintenance service.', 'Critical', '2026-03-09', 'Completed', 8500.00, 8700.00, '2026-03-15'),
(27, 7, 'Toilet flush system malfunction.', 'Medium', '2026-01-14', 'Completed', 350.00, 320.00, '2026-01-17'),
(28, 33, 'Drainage overflow issue after rainfall.', 'High', '2026-02-27', 'In Progress', 1700.00, NULL, NULL),
(29, 15, 'Loose electrical wiring detected in kitchen.', 'Critical', '2026-02-21', 'Completed', 1200.00, 1150.00, '2026-02-27'),
(30, 41, 'Air conditioning gas refill required.', 'Low', '2026-01-24', 'Completed', 400.00, 420.00, '2026-01-29'),
(31, NULL, 'Factory smoke extraction system inspection.', 'High', '2026-03-06', 'Pending', 6200.00, NULL, NULL),
(32, 10, 'Wooden door lock replacement.', 'Low', '2026-02-01', 'Completed', 250.00, 240.00, '2026-02-06'),
(33, 39, 'Office restroom plumbing repair.', 'Medium', '2026-02-23', 'Completed', 900.00, 950.00, '2026-03-01'),
(34, 16, 'Broken balcony railing replacement.', 'Critical', '2026-03-04', 'In Progress', 3200.00, NULL, NULL),
(35, NULL, 'Warehouse roof structural inspection.', 'High', '2026-03-08', 'Pending', 7800.00, NULL, NULL),
(36, 21, 'Apartment hallway lighting malfunction.', 'Medium', '2026-01-20', 'Completed', 650.00, 620.00, '2026-01-24'),
(37, 32, 'Window frame replacement due to corrosion.', 'Medium', '2026-02-15', 'Completed', 1400.00, 1450.00, '2026-02-20'),
(38, 45, 'Commercial office internet cabling upgrade.', 'Low', '2026-03-07', 'Pending', 2100.00, NULL, NULL),
(39, 26, 'Main water tank cleaning and servicing.', 'Medium', '2026-03-01', 'Completed', 3000.00, 2900.00, '2026-03-07'),
(40, NULL, 'Beachfront land drainage assessment.', 'Low', '2026-02-11', 'Cancelled', 1800.00, NULL, NULL),
(41, 29, 'Broken bedroom ceiling fan replacement.', 'Medium', '2026-01-15', 'Completed', 280.00, 300.00, '2026-01-20'),
(42, 43, 'Condominium access card reader malfunction.', 'High', '2026-03-02', 'In Progress', 2400.00, NULL, NULL),
(43, 34, 'Commercial pantry sink leakage.', 'Low', '2026-02-10', 'Completed', 350.00, 340.00, '2026-02-14'),
(44, NULL, 'Industrial loading dock maintenance.', 'Critical', '2026-03-10', 'Pending', 9500.00, NULL, NULL),
(45, 47, 'Air conditioning compressor replacement.', 'High', '2026-03-05', 'Completed', 2800.00, 3000.00, '2026-03-10'),
(46, 27, 'Luxury residence marble flooring crack repair.', 'Medium', '2026-02-16', 'Completed', 2200.00, 2100.00, '2026-02-22'),
(47, 36, 'Warehouse pest control treatment.', 'Medium', '2026-01-26', 'Completed', 1700.00, 1750.00, '2026-01-31'),
(48, 50, 'Farm land irrigation pipe replacement.', 'Low', '2026-03-06', 'Pending', 1300.00, NULL, NULL),
(49, 42, 'Executive suite smart lock malfunction.', 'High', '2026-03-08', 'In Progress', 2600.00, NULL, NULL),
(50, 49, 'Commercial office carpet water damage repair.', 'Medium', '2026-03-06', 'Completed', 1800.00, 1850.00, '2026-03-12');
  
-- ------------------------------------------------------------
-- 6. Departments
-- representing operational, administrative and technical
-- divisions used for EMS user and role management.
-- ------------------------------------------------------------

INSERT INTO Departments
(DepartmentName, Description)
VALUES
('Information Technology', 'Handles system infrastructure, software and database operations.'),
('Cybersecurity', 'Manages security policies, monitoring and access control.'),
('Human Resources', 'Responsible for recruitment, staffing and employee welfare.'),
('Finance', 'Handles financial operations, budgeting and reporting.'),
('Sales', 'Manages property sales and customer acquisition activities.'),
('Marketing', 'Responsible for branding, promotions and digital marketing campaigns.'),
('Property Management', 'Oversees property operations and tenant management.'),
('Maintenance Operations', 'Handles maintenance scheduling and repair coordination.'),
('Customer Service', 'Manages customer support and complaint handling.'),
('Legal Affairs', 'Handles legal documentation and compliance matters.'),
('Audit and Compliance', 'Conducts internal audits and regulatory compliance reviews.'),
('Business Development', 'Explores partnerships and expansion opportunities.'),
('Procurement', 'Manages purchasing and vendor coordination.'),
('Administration', 'Handles daily office administration and operations.'),
('Facilities Management', 'Maintains office facilities and workplace operations.'),
('Data Analytics', 'Performs reporting, analytics and business intelligence tasks.'),
('Cloud Infrastructure', 'Manages cloud servers, hosting and virtualization.'),
('Technical Support', 'Provides technical assistance for staff and systems.'),
('Training and Development', 'Coordinates employee learning and training programs.'),
('Corporate Communications', 'Handles public relations and corporate communications.'),
('Investment Management', 'Manages company investments and portfolio analysis.'),
('Risk Management', 'Assesses operational and financial risks.'),
('Operations Management', 'Oversees company-wide operational activities.'),
('Quality Assurance', 'Ensures quality standards and service compliance.'),
('Research and Innovation', 'Conducts innovation and business improvement initiatives.'),
('Tenant Relations', 'Handles tenant communication and relationship management.'),
('Asset Management', 'Tracks and manages company property assets.'),
('Database Administration', 'Maintains database performance and security.'),
('Network Operations', 'Handles network infrastructure and connectivity.'),
('Digital Transformation', 'Leads automation and digitalization initiatives.'),
('Mobile Application Team', 'Develops and maintains mobile applications.'),
('Software Development', 'Handles software system development and enhancements.'),
('Project Management Office', 'Coordinates organizational projects and implementation.'),
('Strategic Planning', 'Handles long-term corporate planning and strategy.'),
('Environmental Compliance', 'Ensures environmental and sustainability compliance.'),
('Security Operations', 'Monitors operational and physical security activities.'),
('Vendor Management', 'Manages supplier and contractor relationships.'),
('Client Relationship Management', 'Maintains client engagement and communication.'),
('Payroll Management', 'Handles employee salary and payroll processing.'),
('Records Management', 'Maintains organizational records and documentation.'),
('Internal Communications', 'Coordinates communication between departments.'),
('Application Support', 'Supports enterprise systems and business applications.'),
('Enterprise Architecture', 'Designs organizational system architecture and integration.'),
('Business Intelligence', 'Handles dashboards and executive reporting systems.'),
('Disaster Recovery', 'Manages backup, recovery and business continuity planning.'),
('Innovation Lab', 'Researches emerging technologies and operational improvements.'),
('Corporate Strategy', 'Develops corporate growth and investment strategies.'),
('Operations Support', 'Provides support for operational activities and logistics.'),
('Technical Operations', 'Handles technical infrastructure operations and monitoring.'),
('Compliance Monitoring', 'Tracks compliance adherence and reporting activities.');

-- ------------------------------------------------------------
-- 7. SystemUsers
-- IT, operational and administrative personnel.
-- Data includes department assignments, login credentials,
-- SHA-256 password hashing and randomized password salts.
-- ------------------------------------------------------------



INSERT INTO SystemUsers
(DepartmentID, FullName, LoginName, Email, PasswordHash, PasswordSalt, UserRole)
VALUES
(1, 'Farid Rahman', 'farid.rahman', 'farid.rahman@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Farid@123', 'X7@pL9')), 'X7@pL9', 'Admin'),
(2, 'Melissa Wong', 'melissa.wong', 'melissa.wong@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Melissa@123', 'K2$vQ1')), 'K2$vQ1', 'Admin'),
(28, 'Arun Kumar', 'arun.kumar', 'arun.kumar@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Arun@123', 'M8!tR5')), 'M8!tR5', 'DBA'),
(28, 'Linda Tan', 'linda.tan', 'linda.tan@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Linda@123', 'P4#sD2')), 'P4#sD2', 'DBA'),
(16, 'Hakim Zulkifli', 'hakim.zulkifli', 'hakim.zulkifli@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Hakim@123', 'N9@uK3')), 'N9@uK3', 'Analyst'),
(16, 'Rachel Lee', 'rachel.lee', 'rachel.lee@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Rachel@123', 'B6!xY8')), 'B6!xY8', 'Analyst'),
(31, 'Vijay Menon', 'vijay.menon', 'vijay.menon@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Vijay@123', 'L3#rT7')), 'L3#rT7', 'ClientPortalDev'),
(31, 'Sofia Aziz', 'sofia.aziz', 'sofia.aziz@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Sofia@123', 'Q1@wE5')), 'Q1@wE5', 'ClientPortalDev'),
(32, 'Kelvin Ong', 'kelvin.ong', 'kelvin.ong@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Kelvin@123', 'H7!mN2')), 'H7!mN2', 'PropMgmtDev'),
(32, 'Aminah Salleh', 'aminah.salleh', 'aminah.salleh@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Aminah@123', 'Z8#kL4')), 'Z8#kL4', 'PropMgmtDev'),
(11, 'Jason Lim', 'jason.lim', 'jason.lim@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Jason@123', 'T5@vB1')), 'T5@vB1', 'ReadOnly'),
(11, 'Nurul Huda', 'nurul.huda', 'nurul.huda@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Nurul@123', 'G2!pS6')), 'G2!pS6', 'ReadOnly'),
(42, 'Brandon Lee', 'brandon.lee', 'brandon.lee@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Brandon@123', 'R4#jF8')), 'R4#jF8', 'ReadOnly'),
(42, 'Priya Devi', 'priya.devi', 'priya.devi@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Priya@123', 'Y9@xD3')), 'Y9@xD3', 'ReadOnly'),
(1, 'Marcus Chan', 'marcus.chan', 'marcus.chan@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Marcus@123', 'C6!nQ7')), 'C6!nQ7', 'Admin'),
(2, 'Diana Wong', 'diana.wong', 'diana.wong@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Diana@123', 'V1#tK5')), 'V1#tK5', 'Admin'),
(28, 'Rajesh Kumar', 'rajesh.kumar', 'rajesh.kumar@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Rajesh@123', 'U8@bM2')), 'U8@bM2', 'DBA'),
(28, 'Sarah Lim', 'sarah.lim', 'sarah.lim@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Sarah@123', 'J5!yR4')), 'J5!yR4', 'DBA'),
(31, 'Nicholas Teo', 'nicholas.teo', 'nicholas.teo@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Nicholas@123', 'F2#zP9')), 'F2#zP9', 'ClientPortalDev'),
(32, 'Aisyah Rahman', 'aisyah.rahman', 'aisyah.rahman@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Aisyah@123', 'D7@qL1')), 'D7@qL1', 'PropMgmtDev'),
(16, 'Leonard Goh', 'leonard.goh', 'leonard.goh@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Leonard@123', 'S4!wT6')), 'S4!wT6', 'Analyst'),
(16, 'Shalini Devi', 'shalini.devi', 'shalini.devi@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Shalini@123', 'K9#vN3')), 'K9#vN3', 'Analyst'),
(28, 'Irfan Hakim', 'irfan.hakim', 'irfan.hakim@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Irfan@123', 'P6@mX8')), 'P6@mX8', 'DBA'),
(1, 'Grace Tan', 'grace.tan', 'grace.tan@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Grace@123', 'L1!rD5')), 'L1!rD5', 'Admin'),
(31, 'Kevin Yap', 'kevin.yap', 'kevin.yap@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Kevin@123', 'W8#kS2')), 'W8#kS2', 'ClientPortalDev'),
(32, 'Michelle Chong', 'michelle.chong', 'michelle.chong@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Michelle@123', 'R8@qT4')), 'R8@qT4', 'PropMgmtDev'),
(16, 'Adam Zaki', 'adam.zaki', 'adam.zaki@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Adam@123', 'M2!vP7')), 'M2!vP7', 'Analyst'),
(11, 'Janice Foo', 'janice.foo', 'janice.foo@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Janice@123', 'H5#xL1')), 'H5#xL1', 'ReadOnly'),
(28, 'Vimal Raj', 'vimal.raj', 'vimal.raj@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Vimal@123', 'T9@kN6')), 'T9@kN6', 'DBA'),
(2, 'Chloe Ng', 'chloe.ng', 'chloe.ng@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Chloe@123', 'B4!sD8')), 'B4!sD8', 'Admin'),
(31, 'Syafiq Azman', 'syafiq.azman', 'syafiq.azman@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Syafiq@123', 'W6#rF2')), 'W6#rF2', 'ClientPortalDev'),
(32, 'Alicia Tan', 'alicia.tan', 'alicia.tan@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Alicia@123', 'K3@mY9')), 'K3@mY9', 'PropMgmtDev'),
(16, 'Jonathan Ho', 'jonathan.ho', 'jonathan.ho@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Jonathan@123', 'N7!pQ5')), 'N7!pQ5', 'Analyst'),
(11, 'Kavitha Raman', 'kavitha.raman', 'kavitha.raman@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Kavitha@123', 'P1#zC4')), 'P1#zC4', 'ReadOnly'),
(28, 'Raymond Low', 'raymond.low', 'raymond.low@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Raymond@123', 'D8@vL2')), 'D8@vL2', 'DBA'),
(1, 'Dina Rahman', 'dina.rahman', 'dina.rahman@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Dina@123', 'Y5!tM7')), 'Y5!tM7', 'Admin'),
(31, 'Steven Goh', 'steven.goh', 'steven.goh@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Steven@123', 'L9#qR1')), 'L9#qR1', 'ClientPortalDev'),
(32, 'Lavanya Siva', 'lavanya.siva', 'lavanya.siva@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Lavanya@123', 'C2@xN6')), 'C2@xN6', 'PropMgmtDev'),
(16, 'Marcus Lim', 'marcus.lim', 'marcus.lim@ems.com.my', HASHBYTES('SHA2_256', CONCAT('MarcusL@123', 'F7!kP3')), 'F7!kP3', 'Analyst'),
(11, 'Yasmin Ali', 'yasmin.ali', 'yasmin.ali@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Yasmin@123', 'V4#mD8')), 'V4#mD8', 'ReadOnly'),
(28, 'Daniel Wong', 'daniel.wong', 'daniel.wong@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Daniel@123', 'Q6@rT2')), 'Q6@rT2', 'DBA'),
(1, 'Meera Nair', 'meera.nair', 'meera.nair@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Meera@123', 'J1!vS9')), 'J1!vS9', 'Admin'),
(31, 'Haziq Iskandar', 'haziq.iskandar', 'haziq.iskandar@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Haziq@123', 'Z3#pL5')), 'Z3#pL5', 'ClientPortalDev'),
(32, 'Ashley Lee', 'ashley.lee', 'ashley.lee@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Ashley@123', 'G8@nX4')), 'G8@nX4', 'PropMgmtDev'),
(16, 'Harith Azlan', 'harith.azlan', 'harith.azlan@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Harith@123', 'S2!kQ7')), 'S2!kQ7', 'Analyst'),
(11, 'Nadia Karim', 'nadia.karim', 'nadia.karim@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Nadia@123', 'X9#tB1')), 'X9#tB1', 'ReadOnly'),
(28, 'Ben Chan', 'ben.chan', 'ben.chan@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Ben@123', 'U5@vM6')), 'U5@vM6', 'DBA'),
(1, 'Samantha Goh', 'samantha.goh', 'samantha.goh@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Samantha@123', 'A7!rD3')), 'A7!rD3', 'Admin'),
(31, 'Ruben Pillai', 'ruben.pillai', 'ruben.pillai@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Ruben@123', 'E4#xK8')), 'E4#xK8', 'ClientPortalDev'),
(32, 'Farzana Malik', 'farzana.malik', 'farzana.malik@ems.com.my', HASHBYTES('SHA2_256', CONCAT('Farzana@123', 'O1@mH5')), 'O1@mH5', 'PropMgmtDev');

-- ------------------------------------------------------------
-- 10. LeaseAgreements
-- Added realistic Malaysian lease agreement records linked
-- only to rental transactions from the Transactions table.
-- Data includes lease periods, monthly rent, security deposits
-- and document paths for rental agreement tracking.
-- ------------------------------------------------------------

INSERT INTO LeaseAgreements
(TransactionID, PropertyID, ClientID, LeaseStartDate, LeaseEndDate, MonthlyRent, SecurityDeposit, LeaseStatus, AgreementDocPath, SignedDate)
VALUES
(2, 2, 8, '2026-01-01', '2027-01-01', 3200.00, 6400.00, 'Active', 'docs/leases/LA-TR002.pdf', '2025-12-28'),
(5, 5, 20, '2026-02-15', '2028-02-15', 12000.00, 24000.00, 'Active', 'docs/leases/LA-TR005.pdf', '2026-02-10'),
(6, 6, 14, '2026-03-01', '2027-03-01', 1800.00, 3600.00, 'Active', 'docs/leases/LA-TR006.pdf', '2026-02-25'),
(9, 9, 17, '2026-01-10', '2027-01-10', 4500.00, 9000.00, 'Active', 'docs/leases/LA-TR009.pdf', '2026-01-05'),
(12, 12, 35, '2026-04-01', '2027-04-01', 2800.00, 5600.00, 'Active', 'docs/leases/LA-TR012.pdf', '2026-03-28'),
(15, 15, 6, '2026-05-01', '2027-05-01', 5500.00, 11000.00, 'Active', 'docs/leases/LA-TR015.pdf', '2026-04-26'),
(18, 18, 40, '2026-02-01', '2027-02-01', 4800.00, 9600.00, 'Active', 'docs/leases/LA-TR018.pdf', '2026-01-27'),
(21, 21, 22, '2026-03-15', '2028-03-15', 5200.00, 10400.00, 'Active', 'docs/leases/LA-TR021.pdf', '2026-03-10'),
(24, 24, 11, '2026-06-01', '2027-06-01', 3500.00, 7000.00, 'Active', 'docs/leases/LA-TR024.pdf', '2026-05-27'),
(27, 27, 7, '2026-01-20', '2028-01-20', 6500.00, 13000.00, 'Active', 'docs/leases/LA-TR027.pdf', '2026-01-16'),
(30, 30, 41, '2026-04-10', '2027-04-10', 2500.00, 5000.00, 'Active', 'docs/leases/LA-TR030.pdf', '2026-04-05'),
(33, 33, 39, '2026-07-01', '2027-07-01', 4200.00, 8400.00, 'Active', 'docs/leases/LA-TR033.pdf', '2026-06-25'),
(36, 36, 21, '2026-02-05', '2028-02-05', 7000.00, 14000.00, 'Active', 'docs/leases/LA-TR036.pdf', '2026-02-01'),
(39, 39, 26, '2026-05-15', '2027-05-15', 3100.00, 6200.00, 'Active', 'docs/leases/LA-TR039.pdf', '2026-05-10'),
(42, 42, 43, '2026-03-10', '2027-03-10', 3900.00, 7800.00, 'Active', 'docs/leases/LA-TR042.pdf', '2026-03-06'),
(45, 45, 47, '2026-06-20', '2028-06-20', 8300.00, 16600.00, 'Active', 'docs/leases/LA-TR045.pdf', '2026-06-15'),
(48, 48, 50, '2026-01-25', '2027-01-25', 2700.00, 5400.00, 'Active', 'docs/leases/LA-TR048.pdf', '2026-01-21');

-- ------------------------------------------------------------
-- 11. CommissionPayments
-- linked to existing transactions and agents.
-- Data includes commission rates, calculated commission
-- amounts, payment statuses and payment tracking details.
-- ------------------------------------------------------------

INSERT INTO CommissionPayments
(TransactionID, AgentID, CommissionRate, CommissionAmount, PaymentStatus, PaymentDate, Remarks)
VALUES
(1, 2, 2.50, 24500.00, 'Paid', '2026-05-08', 'Commission paid for completed sale transaction.'),
(2, 2, 1.00, 32.00, 'Paid', '2026-01-10', 'Monthly rental commission paid.'),
(3, 7, 2.80, 70000.00, 'Unpaid', NULL, 'Commission pending until payment completion.'),
(4, 3, 2.50, 46250.00, 'Paid', '2026-04-18', 'Commission paid after sale confirmation.'),
(5, 1, 1.20, 144.00, 'Paid', '2026-02-20', 'Rental commission paid for lease transaction.'),
(6, 6, 1.00, 18.00, 'Unpaid', NULL, 'Rental commission pending.'),
(7, 4, 2.60, 17940.00, 'Paid', '2026-03-01', 'Commission paid for property sale.'),
(8, 8, 2.75, 30250.00, 'Paid', '2026-03-05', 'Commission settled through finance department.'),
(9, 9, 1.10, 49.50, 'Paid', '2026-01-15', 'Monthly rental commission processed.'),
(10, 10, 2.50, 155000.00, 'Unpaid', NULL, 'Large transaction commission awaiting approval.'),
(11, 2, 2.40, 18240.00, 'Paid', '2026-04-12', 'Commission paid for sale transaction.'),
(12, 7, 1.00, 28.00, 'Paid', '2026-04-08', 'Rental commission paid.'),
(13, 5, 2.70, 137700.00, 'Paid', '2026-04-20', 'Commission released after full payment received.'),
(14, 3, 2.50, 55000.00, 'Unpaid', NULL, 'Commission pending due to incomplete transaction payment.'),
(15, 1, 1.00, 55.00, 'Paid', '2026-05-08', 'Rental commission paid.'),
(16, 4, 2.60, 46800.00, 'Paid', '2026-04-25', 'Commission paid for sale deal.'),
(17, 6, 2.50, 87500.00, 'Disputed', NULL, 'Commission disputed due to cancelled transaction.'),
(18, 8, 1.00, 48.00, 'Paid', '2026-02-10', 'Rental commission processed.'),
(19, 10, 2.50, 72500.00, 'Unpaid', NULL, 'Commission pending management approval.'),
(20, 2, 2.40, 16080.00, 'Paid', '2026-04-28', 'Commission paid for completed sale.'),
(21, 7, 1.00, 52.00, 'Paid', '2026-03-20', 'Rental commission paid.'),
(22, 5, 2.70, 143100.00, 'Paid', '2026-05-02', 'Commission released after bank transfer cleared.'),
(23, 9, 2.60, 70200.00, 'Unpaid', NULL, 'Commission pending until transaction is completed.'),
(24, 3, 1.00, 35.00, 'Paid', '2026-06-06', 'Rental commission paid.'),
(25, 1, 2.50, 12250.00, 'Paid', '2026-04-10', 'Commission paid for property sale.'),
(26, 4, 2.60, 187200.00, 'Paid', '2026-05-15', 'Commission approved and paid.'),
(27, 6, 1.20, 78.00, 'Unpaid', NULL, 'Rental commission pending.'),
(28, 8, 2.75, 121000.00, 'Paid', '2026-04-22', 'Commission settled after cash payment confirmation.'),
(29, 10, 2.50, 24500.00, 'Paid', '2026-04-30', 'Commission paid.'),
(30, 2, 1.00, 25.00, 'Paid', '2026-04-16', 'Rental commission paid.'),
(31, 7, 2.80, 182000.00, 'Unpaid', NULL, 'Commission pending for sale transaction.'),
(32, 5, 2.70, 21060.00, 'Paid', '2026-05-06', 'Commission paid after transaction completion.'),
(33, 9, 1.00, 42.00, 'Paid', '2026-07-07', 'Rental commission processed.'),
(34, 3, 2.50, 20500.00, 'Paid', '2026-05-10', 'Commission paid through finance department.'),
(35, 1, 2.50, 222500.00, 'Unpaid', NULL, 'Commission awaiting transaction settlement.'),
(36, 4, 1.00, 70.00, 'Paid', '2026-02-12', 'Rental commission paid.'),
(37, 6, 2.50, 48750.00, 'Paid', '2026-05-18', 'Commission released after final verification.'),
(38, 8, 2.75, 99000.00, 'Disputed', NULL, 'Commission disputed due to refunded transaction.'),
(39, 10, 1.00, 31.00, 'Paid', '2026-05-20', 'Rental commission paid.'),
(40, 2, 2.40, 120000.00, 'Paid', '2026-05-22', 'Commission paid for completed sale.'),
(41, 7, 2.80, 17920.00, 'Unpaid', NULL, 'Commission pending.'),
(42, 5, 1.00, 39.00, 'Paid', '2026-03-16', 'Rental commission processed.'),
(43, 9, 2.60, 54600.00, 'Paid', '2026-05-25', 'Commission paid for sale transaction.'),
(44, 3, 2.50, 245000.00, 'Unpaid', NULL, 'High-value transaction commission pending.'),
(45, 1, 1.20, 99.60, 'Paid', '2026-06-28', 'Rental commission paid.'),
(46, 4, 2.60, 83200.00, 'Paid', '2026-05-30', 'Commission paid after cheque clearance.'),
(47, 6, 2.50, 190000.00, 'Paid', '2026-06-05', 'Commission approved by finance.'),
(48, 8, 1.00, 27.00, 'Paid', '2026-02-02', 'Rental commission paid.'),
(49, 10, 2.50, 52500.00, 'Unpaid', NULL, 'Commission pending transaction completion.'),
(50, 2, 2.40, 199200.00, 'Paid', '2026-06-10', 'Commission settled for completed sale.');

-- ------------------------------------------------------------
-- 12. MaintenanceStaff
-- covering in-house and contractor-based maintenance teams.
-- Data includes staff specialisations, employment types and
-- operational workforce tracking for EMS maintenance services.
-- ------------------------------------------------------------

INSERT INTO MaintenanceStaff
(FullName, ContactNumber, Specialisation, IsContractor, JoinedDate)
VALUES
('Ahmad Firdaus', '012-6812345', 'Electrical', 0, '2022-03-15'),
('Jason Tan', '017-5523412', 'Plumbing', 0, '2021-07-10'),
('Ravi Kumar', '016-7789123', 'General Maintenance', 1, '2023-01-22'),
('Mohd Azlan', '018-3456712', 'Air Conditioning', 0, '2020-11-05'),
('Daniel Lee', '013-9871234', 'Painting', 1, '2022-08-18'),
('Farhan Ismail', '014-7823411', 'Electrical', 0, '2021-04-09'),
('Suresh Maniam', '012-9934123', 'Plumbing', 1, '2023-06-12'),
('Kelvin Goh', '011-8823412', 'General Maintenance', 0, '2022-09-25'),
('Hakim Rosli', '019-6612345', 'Roofing', 1, '2024-01-15'),
('Marcus Lim', '017-3345122', 'Landscaping', 0, '2021-12-01'),
('Aiman Hakim', '016-4412789', 'Electrical', 0, '2020-06-17'),
('Raj Pillai', '012-5567821', 'Air Conditioning', 1, '2023-03-14'),
('Vincent Chua', '018-7745123', 'General Maintenance', 0, '2022-10-20'),
('Harith Zain', '013-6623417', 'Plumbing', 0, '2021-01-30'),
('Ben Wong', '014-1198234', 'Painting', 1, '2024-02-11'),
('Shafiq Rahman', '017-7723412', 'Electrical', 0, '2020-09-09'),
('Arun Prakash', '016-2334781', 'General Maintenance', 1, '2022-05-23'),
('Syed Imran', '019-4556721', 'Roofing', 0, '2023-08-16'),
('Eugene Tan', '012-6643217', 'Air Conditioning', 1, '2021-11-03'),
('Faizal Karim', '018-7812344', 'Landscaping', 0, '2020-07-27'),
('Kumaravel Ravi', '013-9098231', 'Plumbing', 1, '2023-04-18'),
('Zulhilmi Musa', '017-6611223', 'Electrical', 0, '2022-06-29'),
('Adrian Yap', '016-7745128', 'General Maintenance', 0, '2021-02-15'),
('Nizam Yusof', '014-2245671', 'Painting', 1, '2024-01-05'),
('Samuel Lee', '011-9812374', 'Roofing', 0, '2022-12-09'),
('Mohan Raj', '019-7734122', 'Plumbing', 1, '2023-09-12'),
('Fikri Hamdan', '012-6678123', 'Electrical', 0, '2021-05-08'),
('Jonathan Goh', '017-3349871', 'General Maintenance', 0, '2020-10-14'),
('Irfan Azmi', '018-6612783', 'Air Conditioning', 1, '2024-03-20'),
('Desmond Chia', '013-9912345', 'Painting', 0, '2022-07-11'),
('Khairul Nizam', '014-8876123', 'Landscaping', 1, '2023-02-27'),
('Viknesh Kumar', '016-2233445', 'Electrical', 0, '2021-08-24'),
('Amirul Hadi', '012-1199887', 'General Maintenance', 0, '2020-04-19'),
('Patrick Lim', '019-4432112', 'Roofing', 1, '2022-11-28'),
('Roshan Singh', '017-7712349', 'Plumbing', 0, '2023-05-06'),
('Taufiq Rahman', '018-6612455', 'Air Conditioning', 1, '2024-02-01'),
('Edwin Tan', '013-5523411', 'Electrical', 0, '2021-03-10'),
('Hafizuddin Noor', '014-8812376', 'General Maintenance', 0, '2020-12-21'),
('Gavin Lee', '016-6677881', 'Painting', 1, '2022-09-03'),
('Shankar Ravi', '012-3399112', 'Roofing', 0, '2023-10-15'),
('Azrul Hakim', '017-9923412', 'Plumbing', 1, '2024-04-08'),
('Nicholas Ong', '019-6655443', 'Electrical', 0, '2021-06-13'),
('Faris Iskandar', '011-2288771', 'Landscaping', 0, '2020-08-04'),
('Andrew Chua', '013-6644221', 'Air Conditioning', 1, '2022-01-18'),
('Mageshwaran Pillai', '018-7766554', 'General Maintenance', 0, '2023-07-07'),
('Syamil Zulkarnain', '014-1188234', 'Painting', 1, '2024-05-11'),
('Calvin Teh', '016-4433221', 'Roofing', 0, '2021-09-29'),
('Rizal Fahmi', '012-8899776', 'Electrical', 0, '2020-05-16'),
('Terrence Goh', '017-1122334', 'Plumbing', 1, '2022-03-01'),
('Navin Raj', '019-7766123', 'General Maintenance', 0, '2023-11-19');




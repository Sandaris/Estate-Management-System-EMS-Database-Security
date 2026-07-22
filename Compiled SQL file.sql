-- ============================================================
-- MEMBER 1 (create_tables.sql)
-- Green Acres Realty Sdn Bhd
-- Estate Management System (EMS) - Full Database Schema
-- CT069-3-3 Database Security Assignment
-- =========================================================        
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

SELECT * FROM LeaseAgreements

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

SELECT * FROM Notifications

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



-- ============================================================
--   MEMBER 2
--   access_control.sql (Roles, users, views, stored procedures)
--
--	 Green Acres Realty Sdn Bhd
--	 Estate Management System (EMS) - Full Database Schema
--   CT069-3-3 Database Security Assignment
--
--   Assigned Roles (Based on existing roles from SystemUsers table):
--   'DBA'				[role_DBA]
--   'PropMgmtDev'		[role_PropMgmtDev]
--   'ClientPortalDev'	[role_ClientPortalDev]
--   'Analyst'			[role_Analyst]
--   'ReadOnly'			[role_ReadOnly]
--   'Admin'			[role_Admin]
--
--   ============================================================

USE GreenAcresEMS;
GO


-- ============================================================
--   SECTION 1: Database Roles
--   ------------------------------------------------------------
--   One role per UserRole value from SystemUsers table.
--   Permissions are granted based on the role (PoLP - Principle of Least Privilege).
--
--   role_DBA			  : Database administrators (Full Control on Database)
--   role_Admin			  : System administrators with broad operational read/write (but not full Database control)
--   role_PropMgmtDev	  : Property & maintenance developers
--   role_ClientPortalDev : Client-facing portal developers
--   role_Analyst         : Analytics/reporting (Read-only aggregates)
--   role_ReadOnly        : General staff (Read via safe views only)
--   ============================================================ 

-- Remove members before dropping roles
DECLARE @RoleName   NVARCHAR(128);
DECLARE @MemberName NVARCHAR(128);
DECLARE @sql        NVARCHAR(500);

-- Remove members one at a time until none remain
WHILE EXISTS (
    SELECT 1
    FROM sys.database_role_members rm
    JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
    WHERE r.name IN (
        'role_Admin', 'role_DBA', 'role_PropMgmtDev',
        'role_ClientPortalDev', 'role_Analyst', 'role_ReadOnly'
    )
)
BEGIN
    SELECT TOP 1
        @RoleName   = r.name,
        @MemberName = m.name
    FROM sys.database_role_members rm
    JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
    JOIN sys.database_principals m ON m.principal_id = rm.member_principal_id
    WHERE r.name IN (
        'role_Admin', 'role_DBA', 'role_PropMgmtDev',
        'role_ClientPortalDev', 'role_Analyst', 'role_ReadOnly'
    );

    SET @sql = 'ALTER ROLE [' + @RoleName + '] DROP MEMBER [' + @MemberName + ']';
    EXEC(@sql);
END;

-- All roles are now empty so safe to drop
IF DATABASE_PRINCIPAL_ID('role_Admin')           IS NOT NULL DROP ROLE role_Admin;
IF DATABASE_PRINCIPAL_ID('role_DBA')             IS NOT NULL DROP ROLE role_DBA;
IF DATABASE_PRINCIPAL_ID('role_PropMgmtDev')     IS NOT NULL DROP ROLE role_PropMgmtDev;
IF DATABASE_PRINCIPAL_ID('role_ClientPortalDev') IS NOT NULL DROP ROLE role_ClientPortalDev;
IF DATABASE_PRINCIPAL_ID('role_Analyst')         IS NOT NULL DROP ROLE role_Analyst;
IF DATABASE_PRINCIPAL_ID('role_ReadOnly')        IS NOT NULL DROP ROLE role_ReadOnly;

PRINT 'All roles removed successfully.';
GO

-- Create the 6 necessary roles
CREATE ROLE role_Admin;
CREATE ROLE role_DBA;
CREATE ROLE role_PropMgmtDev;
CREATE ROLE role_ClientPortalDev;
CREATE ROLE role_Analyst;
CREATE ROLE role_ReadOnly;
GO

-- ============================================================
--   SECTION 2: Logins And Database Users (Create two login acc per role)
--   ============================================================

----------------------------------------------------------------
-- 2.1  DBA users  (Database Administration)
----------------------------------------------------------------
IF SUSER_ID('arun.kumar') IS NULL
    CREATE LOGIN [arun.kumar] WITH PASSWORD = 'Dba@Strong#2026',
        CHECK_POLICY = ON;
GO
IF USER_ID('arun.kumar') IS NULL
    CREATE USER [arun.kumar] FOR LOGIN [arun.kumar];
GO
ALTER ROLE role_DBA ADD MEMBER [arun.kumar];
GO

IF SUSER_ID('linda.tan') IS NULL
    CREATE LOGIN [linda.tan] WITH PASSWORD = 'Dba@Strong#2026',
        CHECK_POLICY = ON;
GO
IF USER_ID('linda.tan') IS NULL
    CREATE USER [linda.tan] FOR LOGIN [linda.tan];
GO
ALTER ROLE role_DBA ADD MEMBER [linda.tan];
GO

----------------------------------------------------------------
-- 2.2  Admin users  (IT dept / Cybersecurity managers)
----------------------------------------------------------------
IF SUSER_ID('farid.rahman') IS NULL
    CREATE LOGIN [farid.rahman] WITH PASSWORD = 'Admin@Strong#2026',
        CHECK_POLICY = ON;
GO
IF USER_ID('farid.rahman') IS NULL
    CREATE USER [farid.rahman] FOR LOGIN [farid.rahman];
GO
ALTER ROLE role_Admin ADD MEMBER [farid.rahman];
GO

IF SUSER_ID('melissa.wong') IS NULL
    CREATE LOGIN [melissa.wong] WITH PASSWORD = 'Admin@Strong#2026',
        CHECK_POLICY = ON;
GO
IF USER_ID('melissa.wong') IS NULL
    CREATE USER [melissa.wong] FOR LOGIN [melissa.wong];
GO
ALTER ROLE role_Admin ADD MEMBER [melissa.wong];
GO



----------------------------------------------------------------
-- 2.3  Property Management developers
----------------------------------------------------------------
IF SUSER_ID('kelvin.ong') IS NULL
    CREATE LOGIN [kelvin.ong] WITH PASSWORD = 'Prop@Strong#2026',
        CHECK_POLICY = ON;
GO
IF USER_ID('kelvin.ong') IS NULL
    CREATE USER [kelvin.ong] FOR LOGIN [kelvin.ong];
GO
ALTER ROLE role_PropMgmtDev ADD MEMBER [kelvin.ong];
GO

IF SUSER_ID('aminah.salleh') IS NULL
    CREATE LOGIN [aminah.salleh] WITH PASSWORD = 'Prop@Strong#2026',
        CHECK_POLICY = ON;
GO
IF USER_ID('aminah.salleh') IS NULL
    CREATE USER [aminah.salleh] FOR LOGIN [aminah.salleh];
GO
ALTER ROLE role_PropMgmtDev ADD MEMBER [aminah.salleh];
GO

----------------------------------------------------------------
-- 2.4  Client Portal developers
----------------------------------------------------------------
IF SUSER_ID('vijay.menon') IS NULL
    CREATE LOGIN [vijay.menon] WITH PASSWORD = 'Portal@Strong#2026',
        CHECK_POLICY = ON;
GO
IF USER_ID('vijay.menon') IS NULL
    CREATE USER [vijay.menon] FOR LOGIN [vijay.menon];
GO
ALTER ROLE role_ClientPortalDev ADD MEMBER [vijay.menon];
GO

IF SUSER_ID('sofia.aziz') IS NULL
    CREATE LOGIN [sofia.aziz] WITH PASSWORD = 'Portal@Strong#2026',
        CHECK_POLICY = ON;
GO
IF USER_ID('sofia.aziz') IS NULL
    CREATE USER [sofia.aziz] FOR LOGIN [sofia.aziz];
GO
ALTER ROLE role_ClientPortalDev ADD MEMBER [sofia.aziz];
GO

----------------------------------------------------------------
-- 2.5  Analysts  (Data Analytics department)
----------------------------------------------------------------
IF SUSER_ID('hakim.zulkifli') IS NULL
    CREATE LOGIN [hakim.zulkifli] WITH PASSWORD = 'Analyst@Strong#2026',
        CHECK_POLICY = ON;
GO
IF USER_ID('hakim.zulkifli') IS NULL
    CREATE USER [hakim.zulkifli] FOR LOGIN [hakim.zulkifli];
GO
ALTER ROLE role_Analyst ADD MEMBER [hakim.zulkifli];
GO

IF SUSER_ID('rachel.lee') IS NULL
    CREATE LOGIN [rachel.lee] WITH PASSWORD = 'Analyst@Strong#2026',
        CHECK_POLICY = ON;
GO
IF USER_ID('rachel.lee') IS NULL
    CREATE USER [rachel.lee] FOR LOGIN [rachel.lee];
GO
ALTER ROLE role_Analyst ADD MEMBER [rachel.lee];
GO

----------------------------------------------------------------
-- 2.6  Read-only staff  (Audit, Application Support, etc.)
----------------------------------------------------------------
IF SUSER_ID('jason.lim') IS NULL
    CREATE LOGIN [jason.lim] WITH PASSWORD = 'Read@Strong#2026',
        CHECK_POLICY = ON;
GO
IF USER_ID('jason.lim') IS NULL
    CREATE USER [jason.lim] FOR LOGIN [jason.lim];
GO
ALTER ROLE role_ReadOnly ADD MEMBER [jason.lim];
GO

IF SUSER_ID('nurul.huda') IS NULL
    CREATE LOGIN [nurul.huda] WITH PASSWORD = 'Read@Strong#2026',
        CHECK_POLICY = ON;
GO
IF USER_ID('nurul.huda') IS NULL
    CREATE USER [nurul.huda] FOR LOGIN [nurul.huda];
GO
ALTER ROLE role_ReadOnly ADD MEMBER [nurul.huda];
GO


-- ============================================================
--   SECTION 3: Permissions 
--   ------------------------------------------------------------
--     role_DBA           = Full control on the database (full access including UNMASK)
--     role_Admin         = Broad read/write on all operational tables (UNMASK granted to see real PII when needed & no DB structural control)
--     role_PropMgmtDev   = Property & maintenance domain only (Writes are funnelled through procedures)
--     role_ClientPortalDev = Client & transaction domain (Denied encrypted blob columns and financials)
--     role_Analyst       = SELECT on views only (NOT granted UNMASK)
--     role_ReadOnly      = SELECT on safe views only (no base table access at all)

--	   UNMASK/ CONTROL will make sure DDM shows the real values (Information will be masked for non-UNMASK roles)
--   ============================================================ 

----------------------------------------------------------------
-- 3.1  DBA: Full control (UNMASK + Alter any information)
----------------------------------------------------------------
GRANT CONTROL ON DATABASE::GreenAcresEMS TO role_DBA;
GO

----------------------------------------------------------------
-- 3.2  Admin: Broad operational read/write + UNMASK for PII
--      (They need to resolve client queries)
----------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE ON dbo.Properties          TO role_Admin;
GRANT SELECT, INSERT, UPDATE ON dbo.Clients             TO role_Admin;
GRANT SELECT, INSERT, UPDATE ON dbo.Agents              TO role_Admin;
GRANT SELECT, INSERT, UPDATE ON dbo.Transactions        TO role_Admin;
GRANT SELECT, INSERT, UPDATE ON dbo.MaintenanceRequests TO role_Admin;
GRANT SELECT, INSERT, UPDATE ON dbo.LeaseAgreements     TO role_Admin;
GRANT SELECT, INSERT, UPDATE ON dbo.CommissionPayments  TO role_Admin;
GRANT SELECT, INSERT, UPDATE ON dbo.SystemUsers         TO role_Admin;
GRANT SELECT, INSERT, UPDATE ON dbo.Departments         TO role_Admin;
GRANT SELECT, INSERT, UPDATE ON dbo.Notifications       TO role_Admin;
GRANT SELECT, INSERT, UPDATE ON dbo.MaintenanceStaff    TO role_Admin;
-- Admin can see real PII values
GRANT UNMASK TO role_Admin;
GO

----------------------------------------------------------------
-- 3.3  Property Management developer:
--      Property + maintenance domain & read on supporting tables
----------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE ON dbo.Properties          TO role_PropMgmtDev;
GRANT SELECT, INSERT, UPDATE ON dbo.MaintenanceRequests TO role_PropMgmtDev;
GRANT SELECT, INSERT, UPDATE ON dbo.MaintenanceStaff    TO role_PropMgmtDev;
GRANT SELECT                  ON dbo.Clients            TO role_PropMgmtDev;
GRANT SELECT                  ON dbo.Agents             TO role_PropMgmtDev;
GRANT SELECT                  ON dbo.Departments        TO role_PropMgmtDev;
-- PropMgmtDev cannot see commission data
DENY  SELECT ON dbo.CommissionPayments                  TO role_PropMgmtDev;
GO

----------------------------------------------------------------
-- 3.4  Client Portal developer:
--      Client & transaction domain
----------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE ON dbo.Clients             TO role_ClientPortalDev;
GRANT SELECT                  ON dbo.Properties         TO role_ClientPortalDev;
GRANT SELECT, INSERT, UPDATE ON dbo.Transactions        TO role_ClientPortalDev;
GRANT SELECT, INSERT, UPDATE ON dbo.LeaseAgreements     TO role_ClientPortalDev;
GRANT SELECT                  ON dbo.Agents             TO role_ClientPortalDev;

----------------------------------------------------------------
-- 3.5  Analyst: Read-only reporting via views only. (Not granted UNMASK so analysts see anonymised PII)
----------------------------------------------------------------
GRANT SELECT ON dbo.Properties          TO role_Analyst;
GRANT SELECT ON dbo.Transactions        TO role_Analyst;
GRANT SELECT ON dbo.MaintenanceRequests TO role_Analyst;
GRANT SELECT ON dbo.Agents              TO role_Analyst;
GRANT SELECT ON dbo.Departments         TO role_Analyst;




-- ============================================================
--   SECTION 4: VIEWS
--   ------------------------------------------------------------
--   Give selective column and information viewing (So that base tables cannot be accessed directly.)
--
--   Views created:
--     1. vw_PropertyListing       - Public-safe property catalogue
--     2. vw_ClientDirectory       - Client list without PII blobs
--     3. vw_ActiveLeases          - Active lease summary
--     4. vw_AgentPerformance      - Per-agent transaction summary
--     5. vw_MonthlySalesSummary   - Monthly revenue roll-up
--     6. vw_MaintenanceOverview   - Maintenance workload overview
--     7. vw_CommissionSummary     - Commission roll-up
--   ============================================================

----------------------------------------------------------------
-- 4.1  Property listing (List of Properties with their information & status)
----------------------------------------------------------------
CREATE OR ALTER VIEW vw_PropertyListing
AS
    SELECT
        PropertyID,
        PropertyName,
        City,
        State,
        PostalCode,
        PropertyType,
        Bedrooms,
        Bathrooms,
        SizeSqft,
        Price,       -- Masked for non-UNMASK roles
        Status
    FROM dbo.Properties
    WHERE IsActive = 1;
GO

SELECT * FROM vw_PropertyListing;

----------------------------------------------------------------
-- 4.2  Client directory (List of clients and their respective information)
----------------------------------------------------------------
CREATE OR ALTER VIEW vw_ClientDirectory
AS
    SELECT
        ClientID,
        FullName,
        NRIC,            -- Masked for non-UNMASK roles
        ContactNumber,   -- Masked for non-UNMASK roles
        Email,           -- Masked for non-UNMASK roles
        ClientType,
        IsActive,
        RegisteredDate
    FROM dbo.Clients;
GO

SELECT * FROM vw_ClientDirectory;

----------------------------------------------------------------
-- 4.3  Active leases (List of properties that still have Active lease status)
----------------------------------------------------------------
CREATE OR ALTER VIEW vw_ActiveLeases
AS
    SELECT
        l.LeaseID,
        p.PropertyName,
        p.City,
        c.FullName          AS ClientName,
        l.LeaseStartDate,
        l.LeaseEndDate,
        l.MonthlyRent,      -- Masked for non-UNMASK roles
        l.LeaseStatus
    FROM dbo.LeaseAgreements l
    INNER JOIN dbo.Properties p ON p.PropertyID = l.PropertyID
    INNER JOIN dbo.Clients    c ON c.ClientID   = l.ClientID
    WHERE l.LeaseStatus = 'Active';
GO

SELECT * FROM vw_ActiveLeases;

----------------------------------------------------------------
-- 4.4  Agent performance (List of Agents with their compiled sales/ performance and their values)
----------------------------------------------------------------
CREATE OR ALTER VIEW vw_AgentPerformance
AS
    SELECT
        a.AgentID,
        a.FullName              AS AgentName,
        a.LicenseNumber,
        COUNT(t.TransactionID)  AS TotalTransactions,
        SUM(CASE WHEN t.TransactionType = 'Sale' THEN 1 ELSE 0 END) AS TotalSales,
        SUM(CASE WHEN t.TransactionType = 'Rent' THEN 1 ELSE 0 END) AS TotalRentals,
        SUM(t.Amount)           AS TotalTransactionValue
    FROM dbo.Agents a
    LEFT JOIN dbo.Transactions t ON t.AgentID = a.AgentID
    WHERE a.IsActive = 1
    GROUP BY a.AgentID, a.FullName, a.LicenseNumber;
GO

SELECT * FROM vw_AgentPerformance;

----------------------------------------------------------------
-- 4.5  Monthly sales summary (Revenue summary of rent and sale transactions based on sales year and month - For analytics)
----------------------------------------------------------------
CREATE OR ALTER VIEW vw_MonthlySalesSummary
AS
    SELECT
        YEAR(t.TransactionDate)     AS SalesYear,
        MONTH(t.TransactionDate)    AS SalesMonth,
        t.TransactionType,
        COUNT(t.TransactionID)      AS NumberOfTransactions,
        SUM(t.Amount)               AS TotalAmount
    FROM dbo.Transactions t
    WHERE t.PaymentStatus = 'Completed'
    GROUP BY
        YEAR(t.TransactionDate),
        MONTH(t.TransactionDate),
        t.TransactionType;
GO

SELECT * FROM vw_MonthlySalesSummary;

----------------------------------------------------------------
-- 4.6  Maintenance overview (List of properties with Maintenance works and their respective details/progress)
----------------------------------------------------------------
CREATE OR ALTER VIEW vw_MaintenanceOverview
AS
    SELECT
        m.RequestID,
        p.PropertyName,
        p.City,
        m.Priority,
        m.Status,
        m.RequestDate,
        m.CompletedDate,
        s.FullName          AS AssignedStaff
    FROM dbo.MaintenanceRequests m
    INNER JOIN dbo.Properties p       ON p.PropertyID = m.PropertyID
    LEFT  JOIN dbo.MaintenanceStaff s ON s.StaffID    = m.AssignedStaffID;
GO

SELECT * FROM vw_MaintenanceOverview;

----------------------------------------------------------------
-- 4.7  Commission summary (List of Agents and their commission details & history)
----------------------------------------------------------------
CREATE OR ALTER VIEW vw_CommissionSummary
AS
    SELECT
        cp.CommissionID,
        a.FullName          AS AgentName,
        t.TransactionType,
        cp.CommissionRate,  -- masked for non-UNMASK roles
        cp.CommissionAmount,-- masked for non-UNMASK roles
        cp.PaymentStatus,
        cp.PaymentDate
    FROM dbo.CommissionPayments cp
    INNER JOIN dbo.Agents       a ON a.AgentID       = cp.AgentID
    INNER JOIN dbo.Transactions t ON t.TransactionID = cp.TransactionID;
GO

SELECT * FROM vw_CommissionSummary;

-- ------------------------------------------------------------
--   4.8  View-Level Permission Grants
--   ------------------------------------------------------------
--   Read-only and Analyst roles get SELECT on views only. (role_ReadOnly gets data without any base-table permission.)
--   ------------------------------------------------------------

-- role_Admin: All views (Direct table access)
GRANT SELECT ON vw_PropertyListing     TO role_Admin;
GRANT SELECT ON vw_ClientDirectory     TO role_Admin;
GRANT SELECT ON vw_ActiveLeases        TO role_Admin;
GRANT SELECT ON vw_AgentPerformance    TO role_Admin;
GRANT SELECT ON vw_MonthlySalesSummary TO role_Admin;
GRANT SELECT ON vw_MaintenanceOverview TO role_Admin;
GRANT SELECT ON vw_CommissionSummary   TO role_Admin;
GO

-- role_PropMgmtDev: Property & maintenance views
GRANT SELECT ON vw_PropertyListing     TO role_PropMgmtDev;
GRANT SELECT ON vw_MaintenanceOverview TO role_PropMgmtDev;
GO

-- role_ClientPortalDev: Client, property & lease views
GRANT SELECT ON vw_PropertyListing     TO role_ClientPortalDev;
GRANT SELECT ON vw_ClientDirectory     TO role_ClientPortalDev;
GRANT SELECT ON vw_ActiveLeases        TO role_ClientPortalDev;
GO

-- role_Analyst: Reporting / analytical views (including financial)
GRANT SELECT ON vw_PropertyListing     TO role_Analyst;
GRANT SELECT ON vw_AgentPerformance    TO role_Analyst;
GRANT SELECT ON vw_MonthlySalesSummary TO role_Analyst;
GRANT SELECT ON vw_MaintenanceOverview TO role_Analyst;
GRANT SELECT ON vw_CommissionSummary   TO role_Analyst;
GRANT SELECT ON vw_ClientDirectory	   TO role_Analyst;
GO

-- role_ReadOnly: Operational non-financial views
GRANT SELECT ON vw_PropertyListing     TO role_ReadOnly;
GRANT SELECT ON vw_ClientDirectory     TO role_ReadOnly;
GRANT SELECT ON vw_ActiveLeases        TO role_ReadOnly;
GRANT SELECT ON vw_MaintenanceOverview TO role_ReadOnly;
GO

-- ============================================================
--   SECTION 5: STORED PROCEDURES
--   ------------------------------------------------------------
--     Client Management
--       1. usp_ManageClient         
--       2. usp_DeactivateClient
--       3. usp_ReactivateClient 

--     Property Management
--       4. usp_ManageProperty       
--       5. usp_UpdatePropertyStatus 

--     Transaction / Operations
--       6. usp_RecordTransaction 
--       7. usp_UpdateTransactionStatus
--       8. usp_LogMaintenanceRequest 
--       9. usp_AssignMaintenanceStaff 

--     Reporting
--       10. usp_GetAgentTransactions

--     User Access Management (Extra)
--       11. usp_ProvisionUser 
--       12. usp_DeprovisionUser 
--   ============================================================

----------------------------------------------------------------
-- 5.1  usp_ManageClient (Adding a new client)
--      When ClientID is NULL = INSERT new client
--      When ClientID is Non-NULL= UPDATE info (Only selected details)
----------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.usp_ManageClient
    @ClientID      INT            = NULL,
    @FullName      NVARCHAR(100)  = NULL,
    @NRIC          NVARCHAR(20)   = NULL,
    @ContactNumber NVARCHAR(20)   = NULL,
    @Email         NVARCHAR(100)  = NULL,
    @Address       NVARCHAR(255)  = NULL,
    @ClientType    NVARCHAR(50)   = 'Individual'
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- INSERT: New client
        IF @ClientID IS NULL
        BEGIN
            IF @FullName IS NULL OR @ContactNumber IS NULL OR @Email IS NULL
            BEGIN
                RAISERROR('FullName, ContactNumber and Email are mandatory for a new client.', 16, 1);
                RETURN;
            END;

            INSERT INTO dbo.Clients
                (FullName, NRIC, ContactNumber, Email, Address, ClientType)
            VALUES
                (@FullName, @NRIC, @ContactNumber, @Email, @Address, @ClientType);

            PRINT 'New client created with ID: ' + CAST(SCOPE_IDENTITY() AS VARCHAR(10));
        END
        -- UPDATE: Existing client (Only non-NULL info change)
        ELSE
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.Clients WHERE ClientID = @ClientID)
            BEGIN
                RAISERROR('Client ID not found.', 16, 1);
                RETURN;
            END;

            UPDATE dbo.Clients
            SET
                FullName      = ISNULL(@FullName,      FullName),
                NRIC          = ISNULL(@NRIC,          NRIC),
                ContactNumber = ISNULL(@ContactNumber, ContactNumber),
                Email         = ISNULL(@Email,         Email),
                Address       = ISNULL(@Address,       Address),
                ClientType    = ISNULL(@ClientType,    ClientType)
            WHERE ClientID = @ClientID;

            PRINT 'Client record updated.';
        END;
    END TRY
    BEGIN CATCH
        RAISERROR('Client operation failed. Please contact the DBA.', 16, 1);
    END CATCH;
END;
GO

----------------------------------------------------------------
-- 5.2  usp_DeactivateClient  (Deactivating an existing client - Soft delete)
----------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.usp_DeactivateClient
    @ClientID INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Clients WHERE ClientID = @ClientID)
    BEGIN
        RAISERROR('Client ID not found.', 16, 1);
        RETURN;
    END;

    UPDATE dbo.Clients
    SET IsActive = 0
    WHERE ClientID = @ClientID;

    PRINT 'Client deactivated.';
END;
GO

----------------------------------------------------------------
-- 5.3  usp_ReactivateClient  (Undo - Reactivating a deactivated client)
----------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.usp_ReactivateClient
    @ClientID INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Check if client record exists
    IF NOT EXISTS (SELECT 1 FROM dbo.Clients WHERE ClientID = @ClientID)
    BEGIN
        RAISERROR('Client ID not found.', 16, 1);
        RETURN;
    END;

    -- Check if client is actually deactivated 
    IF NOT EXISTS (SELECT 1 FROM dbo.Clients WHERE ClientID = @ClientID AND IsActive = 0)
    BEGIN
        RAISERROR('Client is already active. No changes made.', 16, 1);
        RETURN;
    END;

    UPDATE dbo.Clients
    SET IsActive = 1
    WHERE ClientID = @ClientID;

    PRINT 'Client reactivated successfully.';
END;
GO

----------------------------------------------------------------
-- 5.4  usp_ManageProperty (Adding a new property & Updating an existing property)
----------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.usp_ManageProperty
    @PropertyID   INT            = NULL,
    @PropertyName NVARCHAR(150)  = NULL,
    @Address      NVARCHAR(255)  = NULL,
    @City         NVARCHAR(100)  = NULL,
    @State        NVARCHAR(100)  = NULL,
    @PostalCode   NVARCHAR(10)   = NULL,
    @PropertyType NVARCHAR(50)   = NULL,
    @Bedrooms     TINYINT        = NULL,
    @Bathrooms    TINYINT        = NULL,
    @SizeSqft     DECIMAL(10,2)  = NULL,
    @Price        DECIMAL(18,2)  = NULL,
    @Status       NVARCHAR(50)   = 'Available'
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF @PropertyID IS NULL
        BEGIN
            IF @PropertyName IS NULL OR @Address IS NULL OR @City IS NULL
               OR @State IS NULL OR @PropertyType IS NULL OR @Price IS NULL
            BEGIN
                RAISERROR('Name, Address, City, State, PropertyType and Price are mandatory.', 16, 1);
                RETURN;
            END;

            INSERT INTO dbo.Properties
                (PropertyName, Address, City, State, PostalCode,
                 PropertyType, Bedrooms, Bathrooms, SizeSqft, Price, Status)
            VALUES
                (@PropertyName, @Address, @City, @State, @PostalCode,
                 @PropertyType, @Bedrooms, @Bathrooms, @SizeSqft, @Price, @Status);

            PRINT 'New property created with ID: ' + CAST(SCOPE_IDENTITY() AS VARCHAR(10));
        END
        ELSE
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.Properties WHERE PropertyID = @PropertyID)
            BEGIN
                RAISERROR('Property ID not found.', 16, 1);
                RETURN;
            END;

            UPDATE dbo.Properties
            SET
                PropertyName = ISNULL(@PropertyName, PropertyName),
                Address      = ISNULL(@Address,      Address),
                City         = ISNULL(@City,         City),
                State        = ISNULL(@State,        State),
                PostalCode   = ISNULL(@PostalCode,   PostalCode),
                PropertyType = ISNULL(@PropertyType, PropertyType),
                Bedrooms     = ISNULL(@Bedrooms,     Bedrooms),
                Bathrooms    = ISNULL(@Bathrooms,    Bathrooms),
                SizeSqft     = ISNULL(@SizeSqft,     SizeSqft),
                Price        = ISNULL(@Price,        Price),
                Status       = ISNULL(@Status,       Status)
            WHERE PropertyID = @PropertyID;

            PRINT 'Property record updated.';
        END;
    END TRY
    BEGIN CATCH
        RAISERROR('Property operation failed. Please contact the DBA.', 16, 1);
    END CATCH;
END;
GO

----------------------------------------------------------------
-- 5.5  usp_UpdatePropertyStatus  (Changing status of existing property - Cannot be other than predetermined status)
----------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.usp_UpdatePropertyStatus
    @PropertyID INT,
    @NewStatus  NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    IF @NewStatus NOT IN ('Available','Sold','Rented','Under Maintenance','Reserved')
    BEGIN
        RAISERROR('Invalid status. Allowed: Available, Sold, Rented, Under Maintenance, Reserved.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (SELECT 1 FROM dbo.Properties WHERE PropertyID = @PropertyID)
    BEGIN
        RAISERROR('Property ID not found.', 16, 1);
        RETURN;
    END;

    UPDATE dbo.Properties
    SET Status = @NewStatus
    WHERE PropertyID = @PropertyID;

    PRINT 'Property status updated to: ' + @NewStatus;
END;
GO

----------------------------------------------------------------
-- 5.6  usp_RecordTransaction  (Adding a new sale/rent transaction record - Makes sure all info are available)
----------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.usp_RecordTransaction
    @PropertyID      INT,
    @ClientID        INT,
    @AgentID         INT,
    @TransactionType NVARCHAR(50),
    @Amount          DECIMAL(18,2),
    @RentStartDate   DATE         = NULL,
    @RentEndDate     DATE         = NULL,
    @PaymentMethod   NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.Properties WHERE PropertyID = @PropertyID)
            BEGIN RAISERROR('Property not found.', 16, 1); RETURN; END;

        IF NOT EXISTS (SELECT 1 FROM dbo.Clients WHERE ClientID = @ClientID AND IsActive = 1)
            BEGIN RAISERROR('Client not found or inactive.', 16, 1); RETURN; END;

        IF NOT EXISTS (SELECT 1 FROM dbo.Agents WHERE AgentID = @AgentID AND IsActive = 1)
            BEGIN RAISERROR('Agent not found or inactive.', 16, 1); RETURN; END;

        IF @TransactionType NOT IN ('Sale','Rent')
            BEGIN RAISERROR('TransactionType must be Sale or Rent.', 16, 1); RETURN; END;

        INSERT INTO dbo.Transactions
            (PropertyID, ClientID, AgentID, TransactionType, Amount,
             RentStartDate, RentEndDate, PaymentStatus, PaymentMethod)
        VALUES
            (@PropertyID, @ClientID, @AgentID, @TransactionType, @Amount,
             @RentStartDate, @RentEndDate, 'Pending', @PaymentMethod);

        PRINT 'Transaction recorded with ID: ' + CAST(SCOPE_IDENTITY() AS VARCHAR(10));
    END TRY
    BEGIN CATCH
        RAISERROR('Transaction failed. Please contact the DBA.', 16, 1);
    END CATCH;
END;
GO

----------------------------------------------------------------
-- 5.7  usp_UpdateTransactionStatus  (Update payment status of existing transaction)
----------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.usp_UpdateTransactionStatus
    @TransactionID INT,
    @PaymentStatus NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    -- Check if transaction exists
    IF NOT EXISTS (SELECT 1 FROM dbo.Transactions WHERE TransactionID = @TransactionID)
    BEGIN
        RAISERROR('Transaction ID not found.', 16, 1);
        RETURN;
    END;

    -- Make sure status not invalid
    IF @PaymentStatus NOT IN ('Pending', 'Completed')
    BEGIN
        RAISERROR('PaymentStatus must be Pending or Completed.', 16, 1);
        RETURN;
    END;

    UPDATE dbo.Transactions
    SET PaymentStatus = @PaymentStatus
    WHERE TransactionID = @TransactionID;

    PRINT 'Transaction ' + CAST(@TransactionID AS VARCHAR(10)) + ' status updated to ' + @PaymentStatus + '.';
END;
GO


----------------------------------------------------------------
-- 5.8  usp_LogMaintenanceRequest (Raise a new Maintenance Request)
----------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.usp_LogMaintenanceRequest
    @PropertyID          INT,
    @RequestedByClientID INT           = NULL,
    @RequestDetails      NVARCHAR(MAX),
    @Priority            NVARCHAR(20)  = 'Medium',
    @EstimatedCost       DECIMAL(18,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Properties WHERE PropertyID = @PropertyID)
        BEGIN RAISERROR('Property not found.', 16, 1); RETURN; END;

    IF @Priority NOT IN ('Low','Medium','High','Critical')
        BEGIN RAISERROR('Invalid priority. Allowed: Low, Medium, High, Critical.', 16, 1); RETURN; END;

    INSERT INTO dbo.MaintenanceRequests
        (PropertyID, RequestedByClientID, RequestDetails,
         Priority, Status, EstimatedCost)
    VALUES
        (@PropertyID, @RequestedByClientID, @RequestDetails,
         @Priority, 'Pending', @EstimatedCost);

    PRINT 'Maintenance request logged with ID: ' + CAST(SCOPE_IDENTITY() AS VARCHAR(10));
END;
GO

----------------------------------------------------------------
-- 5.9  usp_AssignMaintenanceStaff  (Assigning a respective Maintenance Staff and changing status of request to In Progress)
----------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.usp_AssignMaintenanceStaff
    @RequestID INT,
    @StaffID   INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.MaintenanceRequests WHERE RequestID = @RequestID)
        BEGIN RAISERROR('Maintenance request not found.', 16, 1); RETURN; END;

    IF NOT EXISTS (SELECT 1 FROM dbo.MaintenanceStaff WHERE StaffID = @StaffID AND IsActive = 1)
        BEGIN RAISERROR('Maintenance staff not found or inactive.', 16, 1); RETURN; END;

    UPDATE dbo.MaintenanceRequests
    SET AssignedStaffID = @StaffID,
        Status          = 'In Progress'
    WHERE RequestID = @RequestID;

    PRINT 'Staff assigned and request status set to In Progress.';
END;
GO

----------------------------------------------------------------
-- 5.10  usp_GetAgentTransactions  (Full list of per-Agent transactions and history based on Agent ID)
----------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.usp_GetAgentTransactions
    @AgentID INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Agents WHERE AgentID = @AgentID)
        BEGIN RAISERROR('Agent not found.', 16, 1); RETURN; END;

    SELECT
        t.TransactionID,
        p.PropertyName,
        c.FullName          AS ClientName,
        t.TransactionType,
        t.Amount,           -- Masked for non-UNMASK roles
        t.TransactionDate,
        t.PaymentStatus
    FROM dbo.Transactions t
    INNER JOIN dbo.Properties p ON p.PropertyID = t.PropertyID
    INNER JOIN dbo.Clients    c ON c.ClientID   = t.ClientID
    WHERE t.AgentID = @AgentID
    ORDER BY t.TransactionDate DESC;
END;
GO

-- =============================
--   EXTRA FUNCTIONS/ STORED PROCEDURES
-- ===========================

----------------------------------------------------------------
-- 5.11: usp_ProvisionUser (User Provisioning - Add new user access) 
----------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.usp_ProvisionUser
    @LoginName NVARCHAR(100),
    @Password  NVARCHAR(128),
    @RoleName  NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
 
    -- Match role name against the 6 defined roles
    IF @RoleName NOT IN (
        'role_Admin', 'role_DBA', 'role_PropMgmtDev',
        'role_ClientPortalDev', 'role_Analyst', 'role_ReadOnly'
    )
    BEGIN
        RAISERROR('Invalid role name.', 16, 1);
        RETURN;
    END;

	-- Make sure no empty information is given
	IF @LoginName IS NULL OR @Password IS NULL OR @RoleName IS NULL
        BEGIN
            RAISERROR('LoginName, Password and RoleName are needed and cannot be empty.', 16, 1);
            RETURN;
        END;
 
    -- Check if login already exist
    IF SUSER_ID(@LoginName) IS NOT NULL
    BEGIN
        RAISERROR('Login already exists.', 16, 1);
        RETURN;
    END;
 
    -- Step 1: Create server-level login with password policy
    EXEC('CREATE LOGIN [' + @LoginName + '] WITH PASSWORD = N''' + @Password + ''', CHECK_POLICY = ON;');
    PRINT 'Step 1: Server login created for ' + @LoginName;
 
    -- Step 2: Create database user mapped to the login
    EXEC('CREATE USER [' + @LoginName + '] FOR LOGIN [' + @LoginName + '];');
    PRINT 'Step 2: Database user created.';
 
    -- Step 3: Assign user to the specified role
    EXEC('ALTER ROLE [' + @RoleName + '] ADD MEMBER [' + @LoginName + '];');
    PRINT 'Step 3: ' + @LoginName + ' assigned to ' + @RoleName;
 
    PRINT @LoginName + ' added successfully.';
END;
GO


----------------------------------------------------------------
-- 5.12: usp_DeprovisionUser (User De-provisioning - Remove user access)
----------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.usp_DeprovisionUser
    @LoginName NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
 
    -- Check if login actually exists
    IF SUSER_ID(@LoginName) IS NULL
    BEGIN
        RAISERROR('Login not found. No action taken.', 16, 1);
        RETURN;
    END;
 
    DECLARE @RoleName NVARCHAR(128);
 
    -- Step 1: Remove user from every role they exist in
    WHILE EXISTS (
        SELECT 1 FROM sys.database_role_members rm
        JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
        JOIN sys.database_principals m ON m.principal_id = rm.member_principal_id
        WHERE m.name = @LoginName
    )
    BEGIN
        SELECT TOP 1 @RoleName = r.name
        FROM sys.database_role_members rm
        JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
        JOIN sys.database_principals m ON m.principal_id = rm.member_principal_id
        WHERE m.name = @LoginName;
 

        EXEC('ALTER ROLE [' + @RoleName + '] DROP MEMBER [' + @LoginName + '];');
    END;
    PRINT 'Step 1: ' + @LoginName + ' removed from all roles.';
 
    -- Step 2: Drop the database-level user
    IF USER_ID(@LoginName) IS NOT NULL
        EXEC('DROP USER [' + @LoginName + '];');
    PRINT 'Step 2: Database user dropped.';
 
    -- Step 3: Drop the server-level login
    EXEC('DROP LOGIN [' + @LoginName + '];');
    PRINT 'Step 3: Server login dropped.';
 
    PRINT @LoginName + ' fully removed.';
END;
GO


-- ------------------------------------------------------------
--   5.13  Procedure-Level Execute Grants
--   (Roles receive EXECUTE only on procedures relevant to their job function)
--   ------------------------------------------------------------

-- Admin: All procedures (Full operational scope)
GRANT EXECUTE ON dbo.usp_ManageClient           TO role_Admin;
GRANT EXECUTE ON dbo.usp_DeactivateClient       TO role_Admin;
GRANT EXECUTE ON dbo.usp_ReactivateClient		TO role_Admin;
GRANT EXECUTE ON dbo.usp_ManageProperty         TO role_Admin;
GRANT EXECUTE ON dbo.usp_UpdatePropertyStatus   TO role_Admin;
GRANT EXECUTE ON dbo.usp_RecordTransaction      TO role_Admin;
GRANT EXECUTE ON dbo.usp_UpdateTransactionStatus TO role_Admin;
GRANT EXECUTE ON dbo.usp_LogMaintenanceRequest  TO role_Admin;
GRANT EXECUTE ON dbo.usp_AssignMaintenanceStaff TO role_Admin;
GRANT EXECUTE ON dbo.usp_GetAgentTransactions   TO role_Admin;
GRANT EXECUTE ON dbo.usp_ProvisionUser			TO role_Admin;
GRANT EXECUTE ON dbo.usp_DeprovisionUser		TO role_Admin;
GO

-- PropMgmtDev: Property & Maintenance procedures only
GRANT EXECUTE ON dbo.usp_ManageProperty         TO role_PropMgmtDev;
GRANT EXECUTE ON dbo.usp_UpdatePropertyStatus   TO role_PropMgmtDev;
GRANT EXECUTE ON dbo.usp_LogMaintenanceRequest  TO role_PropMgmtDev;
GRANT EXECUTE ON dbo.usp_AssignMaintenanceStaff TO role_PropMgmtDev;
GO

-- ClientPortalDev: Client & Transaction procedures
GRANT EXECUTE ON dbo.usp_ManageClient           TO role_ClientPortalDev;
GRANT EXECUTE ON dbo.usp_DeactivateClient       TO role_ClientPortalDev;
GRANT EXECUTE ON dbo.usp_ReactivateClient		TO role_ClientPortalDev;
GRANT EXECUTE ON dbo.usp_RecordTransaction      TO role_ClientPortalDev;
GRANT EXECUTE ON dbo.usp_UpdateTransactionStatus TO role_ClientPortalDev;
GO

-- Analyst: Read-only reporting access
GRANT EXECUTE ON dbo.usp_GetAgentTransactions   TO role_Analyst;
GO



-- ============================================================
--   SECTION 6: VERIFICATION (To test if everything is working accordingly)
--   ============================================================

-- Roles created
SELECT name FROM sys.database_principals WHERE type = 'R' AND name LIKE 'role_%';

-- Role membership list (Confirms each RoleName and MemberName)
SELECT r.name AS RoleName, m.name AS MemberName
FROM sys.database_role_members rm
JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
JOIN sys.database_principals m ON m.principal_id = rm.member_principal_id
WHERE r.name LIKE 'role_%' ORDER BY RoleName;

-- Views created
SELECT name FROM sys.views WHERE name LIKE 'vw_%';

-- Procedures created
SELECT name FROM sys.procedures WHERE name LIKE 'usp_%';



/* ============================================================
   MEMBER 3
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
   Member 4
   Triggers
   Green Acres Realty Sdn Bhd - EMS Database Security
   CT069-3-3 Database Security Assignment

   Purpose    : Triggers - both AUDITING and OPERATIONAL.

   Scope:
   SECTION A - Auditing triggers
       One combined AFTER INSERT/UPDATE/DELETE trigger per
       sensitive table. Every DML change is written to
       dbo.AuditLog as a before/after JSON snapshot.

   SECTION B - Operational triggers
       Business-process automation that keeps related tables in
       sync without relying on the application layer to remember
       every step (property status sync, lease expiry handling,
       maintenance completion timestamps, auto commission calc).
   ============================================================ */

USE GreenAcresEMS;
GO


/* ============================================================
   SECTION A: AUDITING TRIGGERS
   ============================================================ */

-- ------------------------------------------------------------
-- A1. Clients
-- ------------------------------------------------------------
CREATE OR ALTER TRIGGER trg_Clients_Audit
ON dbo.Clients
WITH EXECUTE AS OWNER          
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. UPDATE Condition
    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, OperationType, RecordID, ChangedBy, OldValues, NewValues, ApplicationName, HostName)
        SELECT 'Clients', 'UPDATE', CAST(i.ClientID AS NVARCHAR(50)), ORIGINAL_LOGIN(),
               (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               APP_NAME(), HOST_NAME()
        FROM inserted i
        JOIN deleted d ON d.ClientID = i.ClientID;
    END
    -- 2. INSERT Condition
    ELSE IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, OperationType, RecordID, ChangedBy, NewValues, ApplicationName, HostName)
        SELECT 'Clients', 'INSERT', CAST(i.ClientID AS NVARCHAR(50)), ORIGINAL_LOGIN(),
               (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               APP_NAME(), HOST_NAME()
        FROM inserted i;
    END
    -- 3. DELETE Condition
    ELSE IF EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, OperationType, RecordID, ChangedBy, OldValues, ApplicationName, HostName)
        SELECT 'Clients', 'DELETE', CAST(d.ClientID AS NVARCHAR(50)), ORIGINAL_LOGIN(),
               (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               APP_NAME(), HOST_NAME()
        FROM deleted d;
    END
END;
GO

-- ------------------------------------------------------------
-- A2. Agents
-- ------------------------------------------------------------
CREATE OR ALTER TRIGGER trg_Agents_Audit
ON dbo.Agents
WITH EXECUTE AS OWNER
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, OperationType, RecordID, ChangedBy, OldValues, NewValues, ApplicationName, HostName)
        SELECT 'Agents', 'UPDATE', CAST(i.AgentID AS NVARCHAR(50)), ORIGINAL_LOGIN(),
               (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               APP_NAME(), HOST_NAME()
        FROM inserted i
        JOIN deleted d ON d.AgentID = i.AgentID;
    END
    ELSE IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, OperationType, RecordID, ChangedBy, NewValues, ApplicationName, HostName)
        SELECT 'Agents', 'INSERT', CAST(i.AgentID AS NVARCHAR(50)), ORIGINAL_LOGIN(),
               (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               APP_NAME(), HOST_NAME()
        FROM inserted i;
    END
    ELSE IF EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, OperationType, RecordID, ChangedBy, OldValues, ApplicationName, HostName)
        SELECT 'Agents', 'DELETE', CAST(d.AgentID AS NVARCHAR(50)), ORIGINAL_LOGIN(),
               (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               APP_NAME(), HOST_NAME()
        FROM deleted d;
    END
END;
GO

-- ------------------------------------------------------------
-- A3. Transactions
-- ------------------------------------------------------------
CREATE OR ALTER TRIGGER trg_Transactions_Audit
ON dbo.Transactions
WITH EXECUTE AS OWNER
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, OperationType, RecordID, ChangedBy, OldValues, NewValues, ApplicationName, HostName)
        SELECT 'Transactions', 'UPDATE', CAST(i.TransactionID AS NVARCHAR(50)), ORIGINAL_LOGIN(),
               (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               APP_NAME(), HOST_NAME()
        FROM inserted i
        JOIN deleted d ON d.TransactionID = i.TransactionID;
    END
    ELSE IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, OperationType, RecordID, ChangedBy, NewValues, ApplicationName, HostName)
        SELECT 'Transactions', 'INSERT', CAST(i.TransactionID AS NVARCHAR(50)), ORIGINAL_LOGIN(),
               (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               APP_NAME(), HOST_NAME()
        FROM inserted i;
    END
    ELSE IF EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, OperationType, RecordID, ChangedBy, OldValues, ApplicationName, HostName)
        SELECT 'Transactions', 'DELETE', CAST(d.TransactionID AS NVARCHAR(50)), ORIGINAL_LOGIN(),
               (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               APP_NAME(), HOST_NAME()
        FROM deleted d;
    END
END;
GO

-- ------------------------------------------------------------
-- A4. LeaseAgreements
-- ------------------------------------------------------------
CREATE OR ALTER TRIGGER trg_LeaseAgreements_Audit
ON dbo.LeaseAgreements
WITH EXECUTE AS OWNER
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, OperationType, RecordID, ChangedBy, OldValues, NewValues, ApplicationName, HostName)
        SELECT 'LeaseAgreements', 'UPDATE', CAST(i.LeaseID AS NVARCHAR(50)), ORIGINAL_LOGIN(),
               (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               APP_NAME(), HOST_NAME()
        FROM inserted i
        JOIN deleted d ON d.LeaseID = i.LeaseID;
    END
    ELSE IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, OperationType, RecordID, ChangedBy, NewValues, ApplicationName, HostName)
        SELECT 'LeaseAgreements', 'INSERT', CAST(i.LeaseID AS NVARCHAR(50)), ORIGINAL_LOGIN(),
               (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               APP_NAME(), HOST_NAME()
        FROM inserted i;
    END
    ELSE IF EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, OperationType, RecordID, ChangedBy, OldValues, ApplicationName, HostName)
        SELECT 'LeaseAgreements', 'DELETE', CAST(d.LeaseID AS NVARCHAR(50)), ORIGINAL_LOGIN(),
               (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               APP_NAME(), HOST_NAME()
        FROM deleted d;
    END
END;
GO

-- ------------------------------------------------------------
-- A5. CommissionPayments
-- ------------------------------------------------------------
CREATE OR ALTER TRIGGER trg_CommissionPayments_Audit
ON dbo.CommissionPayments
WITH EXECUTE AS OWNER
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, OperationType, RecordID, ChangedBy, OldValues, NewValues, ApplicationName, HostName)
        SELECT 'CommissionPayments', 'UPDATE', CAST(i.CommissionID AS NVARCHAR(50)), ORIGINAL_LOGIN(),
               (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               APP_NAME(), HOST_NAME()
        FROM inserted i
        JOIN deleted d ON d.CommissionID = i.CommissionID;
    END
    ELSE IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, OperationType, RecordID, ChangedBy, NewValues, ApplicationName, HostName)
        SELECT 'CommissionPayments', 'INSERT', CAST(i.CommissionID AS NVARCHAR(50)), ORIGINAL_LOGIN(),
               (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               APP_NAME(), HOST_NAME()
        FROM inserted i;
    END
    ELSE IF EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, OperationType, RecordID, ChangedBy, OldValues, ApplicationName, HostName)
        SELECT 'CommissionPayments', 'DELETE', CAST(d.CommissionID AS NVARCHAR(50)), ORIGINAL_LOGIN(),
               (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               APP_NAME(), HOST_NAME()
        FROM deleted d;
    END
END;
GO

-- ------------------------------------------------------------
-- A6. SystemUsers
-- ------------------------------------------------------------
CREATE OR ALTER TRIGGER trg_SystemUsers_Audit
ON dbo.SystemUsers
WITH EXECUTE AS OWNER
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, OperationType, RecordID, ChangedBy, OldValues, NewValues, ApplicationName, HostName)
        SELECT 'SystemUsers', 'UPDATE', CAST(i.SystemUserID AS NVARCHAR(50)), ORIGINAL_LOGIN(),
               (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               APP_NAME(), HOST_NAME()
        FROM inserted i
        JOIN deleted d ON d.SystemUserID = i.SystemUserID;
    END
    ELSE IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, OperationType, RecordID, ChangedBy, NewValues, ApplicationName, HostName)
        SELECT 'SystemUsers', 'INSERT', CAST(i.SystemUserID AS NVARCHAR(50)), ORIGINAL_LOGIN(),
               (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               APP_NAME(), HOST_NAME()
        FROM inserted i;
    END
    ELSE IF EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, OperationType, RecordID, ChangedBy, OldValues, ApplicationName, HostName)
        SELECT 'SystemUsers', 'DELETE', CAST(d.SystemUserID AS NVARCHAR(50)), ORIGINAL_LOGIN(),
               (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               APP_NAME(), HOST_NAME()
        FROM deleted d;
    END
END;
GO

-- ------------------------------------------------------------
-- A7. MaintenanceRequests
-- ------------------------------------------------------------
CREATE OR ALTER TRIGGER trg_MaintenanceRequests_Audit
ON dbo.MaintenanceRequests
WITH EXECUTE AS OWNER
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, OperationType, RecordID, ChangedBy, OldValues, NewValues, ApplicationName, HostName)
        SELECT 'MaintenanceRequests', 'UPDATE', CAST(i.RequestID AS NVARCHAR(50)), ORIGINAL_LOGIN(),
               (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               APP_NAME(), HOST_NAME()
        FROM inserted i
        JOIN deleted d ON d.RequestID = i.RequestID;
    END
    ELSE IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, OperationType, RecordID, ChangedBy, NewValues, ApplicationName, HostName)
        SELECT 'MaintenanceRequests', 'INSERT', CAST(i.RequestID AS NVARCHAR(50)), ORIGINAL_LOGIN(),
               (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               APP_NAME(), HOST_NAME()
        FROM inserted i;
    END
    ELSE IF EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, OperationType, RecordID, ChangedBy, OldValues, ApplicationName, HostName)
        SELECT 'MaintenanceRequests', 'DELETE', CAST(d.RequestID AS NVARCHAR(50)), ORIGINAL_LOGIN(),
               (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               APP_NAME(), HOST_NAME()
        FROM deleted d;
    END
END;
GO

-- ------------------------------------------------------------
-- A8. Properties
-- ------------------------------------------------------------
CREATE OR ALTER TRIGGER trg_Properties_Audit
ON dbo.Properties
WITH EXECUTE AS OWNER
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, OperationType, RecordID, ChangedBy, OldValues, NewValues, ApplicationName, HostName)
        SELECT 'Properties', 'UPDATE', CAST(i.PropertyID AS NVARCHAR(50)), ORIGINAL_LOGIN(),
               (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               APP_NAME(), HOST_NAME()
        FROM inserted i
        JOIN deleted d ON d.PropertyID = i.PropertyID;
    END
    ELSE IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, OperationType, RecordID, ChangedBy, NewValues, ApplicationName, HostName)
        SELECT 'Properties', 'INSERT', CAST(i.PropertyID AS NVARCHAR(50)), ORIGINAL_LOGIN(),
               (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               APP_NAME(), HOST_NAME()
        FROM inserted i;
    END
    ELSE IF EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, OperationType, RecordID, ChangedBy, OldValues, ApplicationName, HostName)
        SELECT 'Properties', 'DELETE', CAST(d.PropertyID AS NVARCHAR(50)), ORIGINAL_LOGIN(),
               (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
               APP_NAME(), HOST_NAME()
        FROM deleted d;
    END
END;
GO


/* ============================================================
   SECTION B: OPERATIONAL TRIGGERS
   ============================================================ */

-- ------------------------------------------------------------
-- B1. New Transaction -> keep Property.Status in sync
--     'Sale' closes the property out as Sold; 'Rent' marks it
--     Rented. Saves every dev team from having to remember to
--     do this manually in application code.
-- ------------------------------------------------------------
CREATE OR ALTER TRIGGER trg_Transactions_UpdatePropertyStatus
ON dbo.Transactions
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE p
    SET p.Status = CASE i.TransactionType
                        WHEN 'Sale' THEN 'Sold'
                        WHEN 'Rent' THEN 'Rented'
                        ELSE p.Status
                   END
    FROM dbo.Properties p
    JOIN inserted i ON i.PropertyID = p.PropertyID
    WHERE i.TransactionType IN ('Sale', 'Rent');
END;
GO

-- ------------------------------------------------------------
-- B2. New Transaction -> auto-generate the CommissionPayments
--     row using the agent's current CommissionRate (snapshot),
--     so DBAs/finance don't have to insert it separately.
-- ------------------------------------------------------------
CREATE OR ALTER TRIGGER trg_Transactions_AutoCommission
ON dbo.Transactions
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.CommissionPayments (TransactionID, AgentID, CommissionRate, CommissionAmount, PaymentStatus, Remarks)
    SELECT i.TransactionID,
           i.AgentID,
           a.CommissionRate,
           ROUND(i.Amount * a.CommissionRate / 100.0, 2),
           'Unpaid',
           'Auto-generated by trg_Transactions_AutoCommission'
    FROM inserted i
    JOIN dbo.Agents a ON a.AgentID = i.AgentID
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.CommissionPayments cp WHERE cp.TransactionID = i.TransactionID
    );
END;
GO

-- ------------------------------------------------------------
-- B3. Lease ends (Expired/Terminated) -> free up the Property
--     and notify the client. Only reverts status if no other
--     Active lease exists on the same property.
-- ------------------------------------------------------------
CREATE OR ALTER TRIGGER trg_LeaseAgreements_StatusChange
ON dbo.LeaseAgreements
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT UPDATE(LeaseStatus)
        RETURN;

    -- Free up the property when a lease ends, unless another
    -- active lease is still keeping it occupied.
    UPDATE p
    SET p.Status = 'Available'
    FROM dbo.Properties p
    JOIN inserted i ON i.PropertyID = p.PropertyID
    JOIN deleted d ON d.LeaseID = i.LeaseID
    WHERE i.LeaseStatus IN ('Expired', 'Terminated')
      AND d.LeaseStatus <> i.LeaseStatus
      AND p.Status <> 'Sold'
      AND NOT EXISTS (
            SELECT 1 FROM dbo.LeaseAgreements la
            WHERE la.PropertyID = p.PropertyID
              AND la.LeaseStatus = 'Active'
              AND la.LeaseID <> i.LeaseID
      );

    -- Notify the client their lease has ended.
    INSERT INTO dbo.Notifications (RecipientType, RecipientID, Subject, MessageBody, Channel, RelatedTable, RelatedRecordID)
    SELECT 'Client', i.ClientID,
           'Lease ' + i.LeaseStatus,
           'Your lease agreement (LeaseID ' + CAST(i.LeaseID AS NVARCHAR(20)) + ') is now ' + i.LeaseStatus + '.',
           'Email', 'LeaseAgreements', i.LeaseID
    FROM inserted i
    JOIN deleted d ON d.LeaseID = i.LeaseID
    WHERE i.LeaseStatus IN ('Expired', 'Terminated')
      AND d.LeaseStatus <> i.LeaseStatus;
END;
GO

-- ------------------------------------------------------------
-- B4. Maintenance request marked Completed -> auto-stamp
--     CompletedDate and notify the requesting client.
--     Direct trigger recursion is off by default in SQL Server,
--     so the self-UPDATE below will not re-fire this trigger.
-- ------------------------------------------------------------
CREATE OR ALTER TRIGGER trg_MaintenanceRequests_AutoComplete
ON dbo.MaintenanceRequests
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT UPDATE(Status)
        RETURN;

    UPDATE mr
    SET mr.CompletedDate = GETDATE()
    FROM dbo.MaintenanceRequests mr
    JOIN inserted i ON i.RequestID = mr.RequestID
    WHERE i.Status = 'Completed'
      AND mr.CompletedDate IS NULL;

    INSERT INTO dbo.Notifications (RecipientType, RecipientID, Subject, MessageBody, Channel, RelatedTable, RelatedRecordID)
    SELECT 'Client', i.RequestedByClientID,
           'Maintenance Request Completed',
           'Your maintenance request (RequestID ' + CAST(i.RequestID AS NVARCHAR(20)) + ') has been completed.',
           'Email', 'MaintenanceRequests', i.RequestID
    FROM inserted i
    JOIN deleted d ON d.RequestID = i.RequestID
    WHERE i.Status = 'Completed'
      AND d.Status <> 'Completed'
      AND i.RequestedByClientID IS NOT NULL;
END;
GO


PRINT 'All triggers (auditing + operational) created successfully.';
GO

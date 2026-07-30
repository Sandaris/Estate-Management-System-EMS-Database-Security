

USE master;
GO

-- Remove the logon trigger from any previous run FIRST.
-- It reads GreenAcresEMS.dbo.SystemUsers, so leaving it in place while the
-- database is being dropped and rebuilt is asking for confusing errors.
-- (Its own TRY/CATCH means it could never actually block a login, but a
-- clean build should not depend on that safety net.)
IF EXISTS (SELECT 1 FROM sys.server_triggers WHERE name = 'trg_ServerLogon_AuditLogin')
BEGIN
    DROP TRIGGER trg_ServerLogon_AuditLogin ON ALL SERVER;
    PRINT 'Removed logon trigger from previous run.';
END;
GO

-- Kick any leftover sessions off the database, otherwise DROP DATABASE fails
-- with "database is currently in use" when someone still has a query window
-- open against GreenAcresEMS.
IF EXISTS (SELECT name FROM sys.databases WHERE name = 'GreenAcresEMS')
BEGIN
    ALTER DATABASE GreenAcresEMS SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
END;
GO

-- Drop and recreate the database for a clean setup
IF EXISTS (SELECT name FROM sys.databases WHERE name = 'GreenAcresEMS')
    DROP DATABASE GreenAcresEMS;
GO

CREATE DATABASE GreenAcresEMS;
GO

USE GreenAcresEMS;
GO


--    Enhanced: added PropertyType, Bedrooms, Bathrooms,
--    Sizesqft, IsActive for richer operational data.

/* ========================================================================
   REQUIREMENT 12: ADD NEW TABLE OR EDIT EXISTING TABLE
   ======================================================================== */
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
    CreatedDate     DATETIME        NOT NULL        DEFAULT GETDATE()
);
GO

--    Enhanced: added NRIC (for encryption later), ClientType,
--    IsActive. Sensitive PII columns flagged in comments.
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
    RegisteredDate  DATETIME        NOT NULL        DEFAULT GETDATE()
);
GO
--    Enhanced: added DepartmentID (FK), LicenseNumber,
--    IsActive. CommissionRate is sensitive financial data.
CREATE TABLE Agents (
    AgentID         INT             IDENTITY(1,1)   PRIMARY KEY,
    FullName        NVARCHAR(100)   NOT NULL,
    ContactNumber   NVARCHAR(20)    NOT NULL,       -- [SENSITIVE - will be masked]
    Email           NVARCHAR(100)   NOT NULL,
    LicenseNumber   NVARCHAR(50)    NULL,           -- real-estate agent license
    CommissionRate  DECIMAL(5,2)    NOT NULL        DEFAULT 2.50, -- [SENSITIVE]
        CONSTRAINT CK_Agents_CommRate CHECK (CommissionRate BETWEEN 0 AND 100),
    IsActive        BIT             NOT NULL        DEFAULT 1,
    JoinedDate      DATETIME        NOT NULL        DEFAULT GETDATE()
);
GO
--    Enhanced: added RentEndDate, PaymentStatus,
--    PaymentMethod for lease/sale lifecycle tracking.
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

--    Enhanced: added AssignedStaffID, Priority, CompletedDate,
--    EstimatedCost, ActualCost for full work-order tracking.
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



--    Represents the IT and business departments formed during
--    the company's expansion. Used to scope roles/users.
CREATE TABLE Departments (
    DepartmentID    INT             IDENTITY(1,1)   PRIMARY KEY,
    DepartmentName  NVARCHAR(100)   NOT NULL        UNIQUE,
    Description     NVARCHAR(255)   NULL,
    IsActive        BIT             NOT NULL        DEFAULT 1,
    CreatedDate     DATETIME        NOT NULL        DEFAULT GETDATE()
);
GO


--    Internal IT/staff users who access the EMS database
--    (developers, DBAs, analysts). NOT end-user clients.
--    Passwords stored as hashes (applied later by Irfan).
--    Linked to SQL Server logins via LoginName.
CREATE TABLE SystemUsers (
    SystemUserID    INT             IDENTITY(1,1)   PRIMARY KEY,
    DepartmentID    INT             NOT NULL
        CONSTRAINT FK_SysUser_Dept  FOREIGN KEY REFERENCES Departments(DepartmentID),
    FullName        NVARCHAR(100)   NOT NULL,
    LoginName       NVARCHAR(100)   NOT NULL        UNIQUE, -- matches SQL Server login
    Email           NVARCHAR(100)   NOT NULL,               -- [SENSITIVE - will be masked]
    -- LEGACY, INHERITED FROM THE ORIGINAL DEVELOPERS. These two columns are
    -- created and populated only so the migration can be shown end to end;
    -- the hashing section later replaces them with PasswordHashSecure /
    -- PasswordSaltSecure (SHA2_512 over a 32-byte random salt) and then
    -- DROPS them. They must not appear in the final data dictionary.
    PasswordHash    VARBINARY(64)   NULL,                   -- [DEPRECATED - weak SHA2_256]
    PasswordSalt    NVARCHAR(50)    NULL,                   -- [DEPRECATED - salt in plain text]
    UserRole        NVARCHAR(50)    NOT NULL
        CONSTRAINT CK_SysUser_Role CHECK (UserRole IN (
            'DBA','PropMgmtDev','ClientPortalDev','Analyst','ReadOnly','Admin'
        )),
    IsActive        BIT             NOT NULL        DEFAULT 1,
    CreatedDate     DATETIME        NOT NULL        DEFAULT GETDATE()
);
GO

--    Tracks every login attempt (success + failure) against
--    the EMS. Supports both server-level and DB-level audit.
--    Populated by a trigger + SQL Server Audit (Kai Wen).
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


--    Central audit trail for all DML events (INSERT, UPDATE,
--    DELETE) across sensitive tables. Populated by triggers
--    (Sarvein). Schema mirrors a generic change-capture table.
CREATE TABLE AuditLog (
    AuditID         INT             IDENTITY(1,1)   PRIMARY KEY,
    EventTime       DATETIME        NOT NULL        DEFAULT GETDATE(),
    TableName       NVARCHAR(128)   NOT NULL,
    OperationType   NVARCHAR(10)    NOT NULL
        CONSTRAINT CK_Audit_Op CHECK (OperationType IN ('INSERT','UPDATE','DELETE','SELECT')),
    RecordID        NVARCHAR(50)    NOT NULL,       -- PK value of affected row (stored as string)
    ChangedBy       NVARCHAR(100)   NOT NULL        DEFAULT SYSTEM_USER,
    OldValues       NVARCHAR(MAX)   NULL,           -- JSON snapshot of old row
    NewValues       NVARCHAR(MAX)   NULL,           -- JSON snapshot of new row
    ApplicationName NVARCHAR(128)   NULL,
    HostName        NVARCHAR(128)   NULL
);
GO


-- 10. LeaseAgreements
--     Formalises rental agreements between clients and
--     properties. Supports the rental lifecycle (active,
--     expired, terminated). Linked to a Transaction.
--     Security note: AgreementDocPath may point to an
--     encrypted document blob.
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


-- 11. CommissionPayments
--     Tracks commission earned and paid to agents per
--     transaction. Required for financial integrity and
--     analytics. Sensitive financial data; access restricted.
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


-- 12. MaintenanceStaff
--     Tracks in-house or contracted maintenance workers.
--     Linked to MaintenanceRequests for job assignment.
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


-- Add FK back to MaintenanceRequests for assigned staff
ALTER TABLE MaintenanceRequests
    ADD AssignedStaffID INT NULL
        CONSTRAINT FK_Maint_Staff FOREIGN KEY REFERENCES MaintenanceStaff(StaffID);
GO

-- 13. Notifications
--     Stores system notifications sent to clients or agents
--     (lease expiry reminders, maintenance updates, etc.).
--     Supports the operational trigger work (Sarvein).
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


-- INSERTING VALUES
-- residential, commercial, industrial and land properties.
-- Data includes multiple Malaysian states and operational
-- property statuses for EMS system testing and reporting.

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

-- Data includes individual and corporate clients for EMS
-- testing, encryption, masking and reporting.

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

-- including contact details, license numbers and commission
-- rates for EMS operational, reporting and security testing.

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

-- records linked to different properties, clients and agents.
-- Data avoids simple sequential matching to better reflect

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

-- Added 50 realistic maintenance request records covering
-- plumbing, electrical, structural and facility maintenance.
-- Includes request priorities, costs and maintenance statuses
-- for EMS operational and maintenance workflow testing.

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
  
-- representing operational, administrative and technical
-- divisions used for EMS user and role management.

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

-- IT, operational and administrative personnel.
-- Data includes department assignments, login credentials,
-- SHA-256 password hashing and randomized password salts.


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

-- 10. LeaseAgreements
-- Added realistic Malaysian lease agreement records linked
-- only to rental transactions from the Transactions table.
-- Data includes lease periods, monthly rent, security deposits
-- and document paths for rental agreement tracking.

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

-- 11. CommissionPayments
-- linked to existing transactions and agents.
-- Data includes commission rates, calculated commission
-- amounts, payment statuses and payment tracking details.

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

-- 12. MaintenanceStaff
-- covering in-house and contractor-based maintenance teams.
-- Data includes staff specialisations, employment types and
-- operational workforce tracking for EMS maintenance services.

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



USE GreenAcresEMS;
GO



-- ------------------------------------------------------------------------
-- Clean-up before creating principals
--
-- Database-scoped principals (roles + users) do NOT need to be dropped
-- here: the DROP DATABASE / CREATE DATABASE at the very top of this script
-- already destroyed every role and user that lived inside GreenAcresEMS.
--
-- Server-scoped LOGINS survive DROP DATABASE, so re-running this script on
-- the same instance leaves the 12 EMS logins behind as orphans. We drop
-- them here so the script is fully repeatable. Each DROP is wrapped in
-- TRY/CATCH because a login cannot be dropped while it still owns objects
-- or has an open session - in that case we report it and carry on instead
-- of aborting the whole build.
-- ------------------------------------------------------------------------
DECLARE @EmsLogins TABLE (LoginName SYSNAME);

INSERT INTO @EmsLogins (LoginName)
VALUES ('arun.kumar'), ('linda.tan'), ('farid.rahman'), ('melissa.wong'),
       ('kelvin.ong'), ('aminah.salleh'), ('vijay.menon'), ('sofia.aziz'),
       ('hakim.zulkifli'), ('rachel.lee'), ('jason.lim'), ('nurul.huda');

DECLARE @LoginName SYSNAME;
DECLARE @sql       NVARCHAR(500);

DECLARE login_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT LoginName FROM @EmsLogins;

OPEN login_cursor;
FETCH NEXT FROM login_cursor INTO @LoginName;

WHILE @@FETCH_STATUS = 0
BEGIN
    IF SUSER_ID(@LoginName) IS NOT NULL
    BEGIN
        BEGIN TRY
            -- QUOTENAME protects the identifier even though these names are
            -- hard-coded here (defence in depth / consistent style).
            SET @sql = N'DROP LOGIN ' + QUOTENAME(@LoginName) + N';';
            EXEC sys.sp_executesql @sql;
            PRINT 'Dropped orphaned login: ' + @LoginName;
        END TRY
        BEGIN CATCH
            PRINT 'Could not drop login ' + @LoginName + ' -> ' + ERROR_MESSAGE();
        END CATCH;
    END;

    FETCH NEXT FROM login_cursor INTO @LoginName;
END;

CLOSE login_cursor;
DEALLOCATE login_cursor;

PRINT 'Login clean-up finished. Ready to create roles and users.';
GO

-- Create the 6 necessary roles

/* ========================================================================
   REQUIREMENT 3: ROLE
   ======================================================================== */
CREATE ROLE role_Admin;
CREATE ROLE role_DBA;
CREATE ROLE role_PropMgmtDev;
CREATE ROLE role_ClientPortalDev;
CREATE ROLE role_Analyst;
CREATE ROLE role_ReadOnly;
GO


/* ========================================================================
   REQUIREMENT 4: USER (AND PERMISSIONS)

   Every IT staff member gets their OWN login with a UNIQUE password, so
   that the audit trail (ORIGINAL_LOGIN()) can attribute every change to a
   single named person. Shared accounts would destroy accountability.

   CHECK_POLICY     = ON -> Windows complexity rules are enforced.
   CHECK_EXPIRATION = ON -> the login is subject to the password-age policy.

   NOTE FOR MARKING: the passwords below are written in clear text only
   because this is a build script that has to be handed in and re-run by
   the lecturer. In production these would be supplied at run time from a
   secrets vault (or the logins would be Windows/Entra ID authenticated),
   never committed to a script file.
   ======================================================================== */
IF SUSER_ID('arun.kumar') IS NULL
    CREATE LOGIN [arun.kumar] WITH PASSWORD = 'Dba#Arun!7fK2026',
        CHECK_POLICY = ON,       -- enforce Windows password complexity
        CHECK_EXPIRATION = ON;   -- subject the login to the password-age policy
GO
IF USER_ID('arun.kumar') IS NULL
    CREATE USER [arun.kumar] FOR LOGIN [arun.kumar];
GO
ALTER ROLE role_DBA ADD MEMBER [arun.kumar];
GO

IF SUSER_ID('linda.tan') IS NULL
    CREATE LOGIN [linda.tan] WITH PASSWORD = 'Dba#Linda!3qM2026',
        CHECK_POLICY = ON,       -- enforce Windows password complexity
        CHECK_EXPIRATION = ON;   -- subject the login to the password-age policy
GO
IF USER_ID('linda.tan') IS NULL
    CREATE USER [linda.tan] FOR LOGIN [linda.tan];
GO
ALTER ROLE role_DBA ADD MEMBER [linda.tan];
GO

IF SUSER_ID('farid.rahman') IS NULL
    CREATE LOGIN [farid.rahman] WITH PASSWORD = 'Adm#Farid!8xR2026',
        CHECK_POLICY = ON,       -- enforce Windows password complexity
        CHECK_EXPIRATION = ON;   -- subject the login to the password-age policy
GO
IF USER_ID('farid.rahman') IS NULL
    CREATE USER [farid.rahman] FOR LOGIN [farid.rahman];
GO
ALTER ROLE role_Admin ADD MEMBER [farid.rahman];
GO

IF SUSER_ID('melissa.wong') IS NULL
    CREATE LOGIN [melissa.wong] WITH PASSWORD = 'Adm#Melissa!5tW2026',
        CHECK_POLICY = ON,       -- enforce Windows password complexity
        CHECK_EXPIRATION = ON;   -- subject the login to the password-age policy
GO
IF USER_ID('melissa.wong') IS NULL
    CREATE USER [melissa.wong] FOR LOGIN [melissa.wong];
GO
ALTER ROLE role_Admin ADD MEMBER [melissa.wong];
GO


IF SUSER_ID('kelvin.ong') IS NULL
    CREATE LOGIN [kelvin.ong] WITH PASSWORD = 'Prp#Kelvin!9bL2026',
        CHECK_POLICY = ON,       -- enforce Windows password complexity
        CHECK_EXPIRATION = ON;   -- subject the login to the password-age policy
GO
IF USER_ID('kelvin.ong') IS NULL
    CREATE USER [kelvin.ong] FOR LOGIN [kelvin.ong];
GO
ALTER ROLE role_PropMgmtDev ADD MEMBER [kelvin.ong];
GO

IF SUSER_ID('aminah.salleh') IS NULL
    CREATE LOGIN [aminah.salleh] WITH PASSWORD = 'Prp#Aminah!4nS2026',
        CHECK_POLICY = ON,       -- enforce Windows password complexity
        CHECK_EXPIRATION = ON;   -- subject the login to the password-age policy
GO
IF USER_ID('aminah.salleh') IS NULL
    CREATE USER [aminah.salleh] FOR LOGIN [aminah.salleh];
GO
ALTER ROLE role_PropMgmtDev ADD MEMBER [aminah.salleh];
GO

IF SUSER_ID('vijay.menon') IS NULL
    CREATE LOGIN [vijay.menon] WITH PASSWORD = 'Ptl#Vijay!6vD2026',
        CHECK_POLICY = ON,       -- enforce Windows password complexity
        CHECK_EXPIRATION = ON;   -- subject the login to the password-age policy
GO
IF USER_ID('vijay.menon') IS NULL
    CREATE USER [vijay.menon] FOR LOGIN [vijay.menon];
GO
ALTER ROLE role_ClientPortalDev ADD MEMBER [vijay.menon];
GO

IF SUSER_ID('sofia.aziz') IS NULL
    CREATE LOGIN [sofia.aziz] WITH PASSWORD = 'Ptl#Sofia!2zG2026',
        CHECK_POLICY = ON,       -- enforce Windows password complexity
        CHECK_EXPIRATION = ON;   -- subject the login to the password-age policy
GO
IF USER_ID('sofia.aziz') IS NULL
    CREATE USER [sofia.aziz] FOR LOGIN [sofia.aziz];
GO
ALTER ROLE role_ClientPortalDev ADD MEMBER [sofia.aziz];
GO

IF SUSER_ID('hakim.zulkifli') IS NULL
    CREATE LOGIN [hakim.zulkifli] WITH PASSWORD = 'Anl#Hakim!7hJ2026',
        CHECK_POLICY = ON,       -- enforce Windows password complexity
        CHECK_EXPIRATION = ON;   -- subject the login to the password-age policy
GO
IF USER_ID('hakim.zulkifli') IS NULL
    CREATE USER [hakim.zulkifli] FOR LOGIN [hakim.zulkifli];
GO
ALTER ROLE role_Analyst ADD MEMBER [hakim.zulkifli];
GO

IF SUSER_ID('rachel.lee') IS NULL
    CREATE LOGIN [rachel.lee] WITH PASSWORD = 'Anl#Rachel!1cP2026',
        CHECK_POLICY = ON,       -- enforce Windows password complexity
        CHECK_EXPIRATION = ON;   -- subject the login to the password-age policy
GO
IF USER_ID('rachel.lee') IS NULL
    CREATE USER [rachel.lee] FOR LOGIN [rachel.lee];
GO
ALTER ROLE role_Analyst ADD MEMBER [rachel.lee];
GO

IF SUSER_ID('jason.lim') IS NULL
    CREATE LOGIN [jason.lim] WITH PASSWORD = 'Ro#Jason!5yT2026',
        CHECK_POLICY = ON,       -- enforce Windows password complexity
        CHECK_EXPIRATION = ON;   -- subject the login to the password-age policy
GO
IF USER_ID('jason.lim') IS NULL
    CREATE USER [jason.lim] FOR LOGIN [jason.lim];
GO
ALTER ROLE role_ReadOnly ADD MEMBER [jason.lim];
GO

IF SUSER_ID('nurul.huda') IS NULL
    CREATE LOGIN [nurul.huda] WITH PASSWORD = 'Ro#Nurul!8kQ2026',
        CHECK_POLICY = ON,       -- enforce Windows password complexity
        CHECK_EXPIRATION = ON;   -- subject the login to the password-age policy
GO
IF USER_ID('nurul.huda') IS NULL
    CREATE USER [nurul.huda] FOR LOGIN [nurul.huda];
GO
ALTER ROLE role_ReadOnly ADD MEMBER [nurul.huda];
GO



GRANT CONTROL ON DATABASE::GreenAcresEMS TO role_DBA;
GO

-- ------------------------------------------------------------------------
-- Server-level permission for the DBA logins.
--
-- CONTROL ON DATABASE (above) covers everything INSIDE GreenAcresEMS, but
-- creating or dropping a LOGIN is a server-level action. Without this the
-- DBAs would get "permission denied" the moment they ran usp_ProvisionUser,
-- which is exactly the job we built that procedure for.
--
-- ALTER ANY LOGIN is granted instead of adding them to the securityadmin
-- fixed server role, because securityadmin can also GRANT server-level
-- permissions to itself and is effectively a path to sysadmin.
-- ------------------------------------------------------------------------
USE master;
GO

GRANT ALTER ANY LOGIN TO [arun.kumar];
GRANT ALTER ANY LOGIN TO [linda.tan];
GO

-- VIEW ANY DEFINITION lets the DBAs inspect object definitions across the
-- instance when troubleshooting, without any data access.
GRANT VIEW ANY DEFINITION TO [arun.kumar];
GRANT VIEW ANY DEFINITION TO [linda.tan];
GO

USE GreenAcresEMS;
GO

--      (They need to resolve client queries)
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

--      Property + maintenance domain & read on supporting tables
GRANT SELECT, INSERT, UPDATE ON dbo.Properties          TO role_PropMgmtDev;
GRANT SELECT, INSERT, UPDATE ON dbo.MaintenanceRequests TO role_PropMgmtDev;
GRANT SELECT, INSERT, UPDATE ON dbo.MaintenanceStaff    TO role_PropMgmtDev;
GRANT SELECT                  ON dbo.Clients            TO role_PropMgmtDev;
GRANT SELECT                  ON dbo.Agents             TO role_PropMgmtDev;
GRANT SELECT                  ON dbo.Departments        TO role_PropMgmtDev;
-- PropMgmtDev cannot see commission data
DENY  SELECT ON dbo.CommissionPayments                  TO role_PropMgmtDev;
GO

--      Client & transaction domain
GRANT SELECT, INSERT, UPDATE ON dbo.Clients             TO role_ClientPortalDev;
GRANT SELECT                  ON dbo.Properties         TO role_ClientPortalDev;
GRANT SELECT, INSERT, UPDATE ON dbo.Transactions        TO role_ClientPortalDev;
GRANT SELECT, INSERT, UPDATE ON dbo.LeaseAgreements     TO role_ClientPortalDev;
GRANT SELECT                  ON dbo.Agents             TO role_ClientPortalDev;
GO

--      Read-only across the reporting domain
GRANT SELECT ON dbo.Properties          TO role_Analyst;
GRANT SELECT ON dbo.Transactions        TO role_Analyst;
GRANT SELECT ON dbo.MaintenanceRequests TO role_Analyst;
GRANT SELECT ON dbo.Agents              TO role_Analyst;
GRANT SELECT ON dbo.Departments         TO role_Analyst;
GO


/* ========================================================================
   REQUIREMENT 1: VIEW
   ======================================================================== */
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


--   4.8  View-Level Permission Grants
--   Read-only and Analyst roles get SELECT on views only. (role_ReadOnly gets data without any base-table permission.)

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


--      When ClientID is NULL = INSERT new client
--      When ClientID is Non-NULL= UPDATE info (Only selected details)


/* ========================================================================
   REQUIREMENT 2: STORED PROCEDURE
   ======================================================================== */
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



-- ------------------------------------------------------------------------
-- usp_ProvisionUser
--
-- Single, auditable entry point for onboarding a new IT staff member:
-- creates the login, the database user and the role membership in one step.
--
-- SECURITY NOTES
--   1. CREATE LOGIN / CREATE USER / ALTER ROLE cannot be parameterised, so
--      dynamic SQL is unavoidable here. Every identifier is therefore
--      wrapped in QUOTENAME() and @LoginName is validated against a strict
--      whitelist first, which closes the SQL-injection hole that plain
--      string concatenation would leave open.
--   2. The password IS passed as a real parameter to sp_executesql, so it
--      never becomes part of the executable SQL text and cannot break out
--      of its quotes.
--   3. Dynamic SQL breaks ownership chaining, so the CALLER (not the
--      procedure owner) needs the underlying permissions. The caller must
--      hold server-level ALTER ANY LOGIN plus ALTER ANY USER in this
--      database. That is why EXECUTE is granted to role_DBA only, and why
--      the two DBA logins are granted ALTER ANY LOGIN further down.
-- ------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.usp_ProvisionUser
    @LoginName NVARCHAR(100),
    @Password  NVARCHAR(128),
    @RoleName  NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    -- Make sure no empty information is given (checked FIRST, because
    -- "NULL NOT IN (...)" evaluates to UNKNOWN and would fall through the
    -- role check below without ever raising an error).
    IF @LoginName IS NULL OR LTRIM(RTRIM(@LoginName)) = ''
       OR @Password IS NULL OR @Password = ''
       OR @RoleName IS NULL OR LTRIM(RTRIM(@RoleName)) = ''
    BEGIN
        RAISERROR('LoginName, Password and RoleName are needed and cannot be empty.', 16, 1);
        RETURN;
    END;

    -- Match role name against the 6 defined roles
    IF @RoleName NOT IN (
        'role_Admin', 'role_DBA', 'role_PropMgmtDev',
        'role_ClientPortalDev', 'role_Analyst', 'role_ReadOnly'
    )
    BEGIN
        RAISERROR('Invalid role name.', 16, 1);
        RETURN;
    END;

    -- Whitelist the login name: letters, digits, dot, underscore and hyphen
    -- only. This rejects brackets, quotes, semicolons and comment markers,
    -- so an injected payload such as  x];DROP TABLE dbo.Clients--
    -- can never reach the dynamic SQL below.
    IF @LoginName LIKE '%[^a-zA-Z0-9._-]%'
    BEGIN
        RAISERROR('LoginName may only contain letters, digits, dot, underscore or hyphen.', 16, 1);
        RETURN;
    END;

    IF LEN(@Password) < 12
    BEGIN
        RAISERROR('Password must be at least 12 characters long.', 16, 1);
        RETURN;
    END;

    -- Check if login already exist
    IF SUSER_ID(@LoginName) IS NOT NULL
    BEGIN
        RAISERROR('Login already exists.', 16, 1);
        RETURN;
    END;

    DECLARE @sql NVARCHAR(MAX);

    BEGIN TRY
        -- Step 1: Create server-level login with password policy.
        --         @Password travels as a bound parameter, not as text.
        SET @sql = N'CREATE LOGIN ' + QUOTENAME(@LoginName)
                 + N' WITH PASSWORD = @pwd, CHECK_POLICY = ON, CHECK_EXPIRATION = ON;';
        EXEC sys.sp_executesql @sql, N'@pwd NVARCHAR(128)', @pwd = @Password;
        PRINT 'Step 1: Server login created for ' + @LoginName;

        -- Step 2: Create database user mapped to the login
        SET @sql = N'CREATE USER ' + QUOTENAME(@LoginName)
                 + N' FOR LOGIN ' + QUOTENAME(@LoginName) + N';';
        EXEC sys.sp_executesql @sql;
        PRINT 'Step 2: Database user created.';

        -- Step 3: Assign user to the specified role
        SET @sql = N'ALTER ROLE ' + QUOTENAME(@RoleName)
                 + N' ADD MEMBER ' + QUOTENAME(@LoginName) + N';';
        EXEC sys.sp_executesql @sql;
        PRINT 'Step 3: ' + @LoginName + ' assigned to ' + @RoleName;

        PRINT @LoginName + ' added successfully.';
    END TRY
    BEGIN CATCH
        -- Surface the real reason (usually "permission denied" when the
        -- caller is not a sysadmin / has no ALTER ANY LOGIN).
        DECLARE @msg NVARCHAR(2048) = N'usp_ProvisionUser failed: ' + ERROR_MESSAGE();
        RAISERROR(@msg, 16, 1);
    END CATCH;
END;
GO


-- ------------------------------------------------------------------------
-- usp_DeprovisionUser
--
-- Offboarding counterpart to usp_ProvisionUser: strips role membership,
-- drops the database user, then drops the server login - in that order,
-- because SQL Server refuses to drop a login that still has a mapped user.
-- Same QUOTENAME hardening and same caller-permission requirement as above.
-- ------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.usp_DeprovisionUser
    @LoginName NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    IF @LoginName IS NULL OR LTRIM(RTRIM(@LoginName)) = ''
    BEGIN
        RAISERROR('LoginName is required.', 16, 1);
        RETURN;
    END;

    -- Same whitelist as usp_ProvisionUser - never build dynamic SQL from an
    -- unvalidated identifier.
    IF @LoginName LIKE '%[^a-zA-Z0-9._-]%'
    BEGIN
        RAISERROR('LoginName may only contain letters, digits, dot, underscore or hyphen.', 16, 1);
        RETURN;
    END;

    -- Check if login actually exists
    IF SUSER_ID(@LoginName) IS NULL
    BEGIN
        RAISERROR('Login not found. No action taken.', 16, 1);
        RETURN;
    END;

    DECLARE @RoleName NVARCHAR(128);
    DECLARE @sql      NVARCHAR(MAX);

    BEGIN TRY
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

            SET @sql = N'ALTER ROLE ' + QUOTENAME(@RoleName)
                     + N' DROP MEMBER ' + QUOTENAME(@LoginName) + N';';
            EXEC sys.sp_executesql @sql;
        END;
        PRINT 'Step 1: ' + @LoginName + ' removed from all roles.';

        -- Step 2: Drop the database-level user
        IF USER_ID(@LoginName) IS NOT NULL
        BEGIN
            SET @sql = N'DROP USER ' + QUOTENAME(@LoginName) + N';';
            EXEC sys.sp_executesql @sql;
        END;
        PRINT 'Step 2: Database user dropped.';

        -- Step 3: Drop the server-level login
        SET @sql = N'DROP LOGIN ' + QUOTENAME(@LoginName) + N';';
        EXEC sys.sp_executesql @sql;
        PRINT 'Step 3: Server login dropped.';

        PRINT @LoginName + ' fully removed.';
    END TRY
    BEGIN CATCH
        DECLARE @msg NVARCHAR(2048) = N'usp_DeprovisionUser failed: ' + ERROR_MESSAGE();
        RAISERROR(@msg, 16, 1);
    END CATCH;
END;
GO

--   5.13  Procedure-Level Execute Grants
--   (Roles receive EXECUTE only on procedures relevant to their job function)

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
-- User provisioning is a DBA duty, not a business-admin duty, so EXECUTE on
-- the two provisioning procedures goes to role_DBA only. (Creating a login
-- is a server-level act; letting a business Admin do it would let them mint
-- accounts in any role, including role_DBA, and quietly escalate privilege.)
GRANT EXECUTE ON dbo.usp_ProvisionUser			TO role_DBA;
GRANT EXECUTE ON dbo.usp_DeprovisionUser		TO role_DBA;
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



USE GreenAcresEMS;
GO



IF NOT EXISTS (
    SELECT 1
    FROM sys.masked_columns
    WHERE object_id = OBJECT_ID('dbo.Clients')
      AND name = 'NRIC'
)
BEGIN
    ALTER TABLE dbo.Clients
    ALTER COLUMN NRIC 
/* ========================================================================
   REQUIREMENT 7: MASKING
   ======================================================================== */
ADD MASKED WITH (FUNCTION = 'partial(0, "XXXXXX", 4)');
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
    ALTER COLUMN ContactNumber 
/* ========================================================================
   REQUIREMENT 7: MASKING
   ======================================================================== */
ADD MASKED WITH (FUNCTION = 'partial(3, "XXXXXXX", 2)');
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
    ALTER COLUMN Email 
/* ========================================================================
   REQUIREMENT 7: MASKING
   ======================================================================== */
ADD MASKED WITH (FUNCTION = 'email()');
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
    ALTER COLUMN Address 
/* ========================================================================
   REQUIREMENT 7: MASKING
   ======================================================================== */
ADD MASKED WITH (FUNCTION = 'partial(8, "XXXXXXXXXX", 0)');
END;
GO



IF NOT EXISTS (
    SELECT 1
    FROM sys.masked_columns
    WHERE object_id = OBJECT_ID('dbo.Agents')
      AND name = 'ContactNumber'
)
BEGIN
    ALTER TABLE dbo.Agents
    ALTER COLUMN ContactNumber 
/* ========================================================================
   REQUIREMENT 7: MASKING
   ======================================================================== */
ADD MASKED WITH (FUNCTION = 'partial(3, "XXXXXXX", 2)');
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
    ALTER COLUMN Email 
/* ========================================================================
   REQUIREMENT 7: MASKING
   ======================================================================== */
ADD MASKED WITH (FUNCTION = 'email()');
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
    ALTER COLUMN CommissionRate 
/* ========================================================================
   REQUIREMENT 7: MASKING
   ======================================================================== */
ADD MASKED WITH (FUNCTION = 'default()');
END;
GO



IF NOT EXISTS (
    SELECT 1
    FROM sys.masked_columns
    WHERE object_id = OBJECT_ID('dbo.Properties')
      AND name = 'Address'
)
BEGIN
    ALTER TABLE dbo.Properties
    ALTER COLUMN Address 
/* ========================================================================
   REQUIREMENT 7: MASKING
   ======================================================================== */
ADD MASKED WITH (FUNCTION = 'partial(8, "XXXXXXXXXX", 0)');
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
    ALTER COLUMN Price 
/* ========================================================================
   REQUIREMENT 7: MASKING
   ======================================================================== */
ADD MASKED WITH (FUNCTION = 'random(100000, 1000000)');
END;
GO



IF NOT EXISTS (
    SELECT 1
    FROM sys.masked_columns
    WHERE object_id = OBJECT_ID('dbo.Transactions')
      AND name = 'Amount'
)
BEGIN
    ALTER TABLE dbo.Transactions
    ALTER COLUMN Amount 
/* ========================================================================
   REQUIREMENT 7: MASKING
   ======================================================================== */
ADD MASKED WITH (FUNCTION = 'random(1000, 100000)');
END;
GO



IF NOT EXISTS (
    SELECT 1
    FROM sys.masked_columns
    WHERE object_id = OBJECT_ID('dbo.MaintenanceRequests')
      AND name = 'EstimatedCost'
)
BEGIN
    ALTER TABLE dbo.MaintenanceRequests
    ALTER COLUMN EstimatedCost 
/* ========================================================================
   REQUIREMENT 7: MASKING
   ======================================================================== */
ADD MASKED WITH (FUNCTION = 'random(100, 10000)');
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
    ALTER COLUMN ActualCost 
/* ========================================================================
   REQUIREMENT 7: MASKING
   ======================================================================== */
ADD MASKED WITH (FUNCTION = 'random(100, 10000)');
END;
GO



IF NOT EXISTS (
    SELECT 1
    FROM sys.masked_columns
    WHERE object_id = OBJECT_ID('dbo.SystemUsers')
      AND name = 'Email'
)
BEGIN
    ALTER TABLE dbo.SystemUsers
    ALTER COLUMN Email 
/* ========================================================================
   REQUIREMENT 7: MASKING
   ======================================================================== */
ADD MASKED WITH (FUNCTION = 'email()');
END;
GO



IF NOT EXISTS (
    SELECT 1
    FROM sys.masked_columns
    WHERE object_id = OBJECT_ID('dbo.LeaseAgreements')
      AND name = 'MonthlyRent'
)
BEGIN
    ALTER TABLE dbo.LeaseAgreements
    ALTER COLUMN MonthlyRent 
/* ========================================================================
   REQUIREMENT 7: MASKING
   ======================================================================== */
ADD MASKED WITH (FUNCTION = 'random(1000, 10000)');
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
    ALTER COLUMN SecurityDeposit 
/* ========================================================================
   REQUIREMENT 7: MASKING
   ======================================================================== */
ADD MASKED WITH (FUNCTION = 'random(1000, 20000)');
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
    ALTER COLUMN AgreementDocPath 
/* ========================================================================
   REQUIREMENT 7: MASKING
   ======================================================================== */
ADD MASKED WITH (FUNCTION = 'partial(5, "XXXXXXXXXX", 4)');
END;
GO



IF NOT EXISTS (
    SELECT 1
    FROM sys.masked_columns
    WHERE object_id = OBJECT_ID('dbo.CommissionPayments')
      AND name = 'CommissionRate'
)
BEGIN
    ALTER TABLE dbo.CommissionPayments
    ALTER COLUMN CommissionRate 
/* ========================================================================
   REQUIREMENT 7: MASKING
   ======================================================================== */
ADD MASKED WITH (FUNCTION = 'default()');
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
    ALTER COLUMN CommissionAmount 
/* ========================================================================
   REQUIREMENT 7: MASKING
   ======================================================================== */
ADD MASKED WITH (FUNCTION = 'random(100, 100000)');
END;
GO



IF NOT EXISTS (
    SELECT 1
    FROM sys.masked_columns
    WHERE object_id = OBJECT_ID('dbo.MaintenanceStaff')
      AND name = 'ContactNumber'
)
BEGIN
    ALTER TABLE dbo.MaintenanceStaff
    ALTER COLUMN ContactNumber
/* ========================================================================
   REQUIREMENT 7: MASKING
   ======================================================================== */
ADD MASKED WITH (FUNCTION = 'partial(3, "XXXXXXX", 2)');
END;
GO



/* ========================================================================
   REQUIREMENT 7 (continued): MASKING - KNOWN LIMIT + ANALYST EXCEPTION

   IMPORTANT LIMITATION, stated deliberately for the report:
   Dynamic Data Masking is a PRESENTATION control, not a security boundary.
   It masks the *column* in the output, but it does NOT mask the result of
   an expression computed over that column. A user with no UNMASK permission
   can therefore still recover real values, for example:

       SELECT SUM(Amount) FROM dbo.Transactions;      -- returns REAL total
       SELECT COUNT(*) FROM dbo.Clients WHERE Email = 'known@x.com';

   Our own reporting views vw_MonthlySalesSummary and vw_AgentPerformance
   aggregate Transactions.Amount, so the totals they return are real figures
   even for roles that see Amount masked when they read the base table.

   We handle this in two ways rather than pretending it does not happen:
     1. DDM is layered BEHIND permissions (roles only reach the tables and
        views their job needs) and behind auditing (SELECT on the sensitive
        tables is captured by the Database Audit Specification). DDM is the
        last layer, never the only one.
     2. role_Analyst legitimately needs true financial figures - that is the
        analytics department's entire job - so instead of leaving them with
        an accidental bypass we grant them EXPLICIT, COLUMN-LEVEL UNMASK on
        just the financial columns, and leave every PII column masked.
        The permission is now intentional, documented and auditable.

   Column-level UNMASK (GRANT UNMASK ON OBJECT::t(c)) requires SQL Server
   2022 (major version 16) or Azure SQL. On SQL Server 2019 the only option
   is database-wide UNMASK, which would also expose PII - so on 2019 we
   deliberately grant nothing and accept the aggregate limitation instead.
   ======================================================================== */
-- The GRANT statements are issued through sp_executesql on purpose. Written
-- inline, the column-level UNMASK syntax would have to be PARSED by every
-- version of SQL Server that runs this script - and a SQL Server 2019 parser
-- would reject the whole batch before the version check below ever executed.
-- Dynamic SQL defers parsing until we already know the version is 2022+.
IF CAST(SERVERPROPERTY('ProductMajorVersion') AS INT) >= 16
BEGIN
    PRINT 'SQL Server 2022+ detected: applying column-level UNMASK for role_Analyst.';

    -- Financial columns the analytics team reports on:
    EXEC sys.sp_executesql N'GRANT UNMASK ON dbo.Transactions(Amount)                TO role_Analyst;';
    EXEC sys.sp_executesql N'GRANT UNMASK ON dbo.Properties(Price)                   TO role_Analyst;';
    EXEC sys.sp_executesql N'GRANT UNMASK ON dbo.CommissionPayments(CommissionAmount) TO role_Analyst;';
    EXEC sys.sp_executesql N'GRANT UNMASK ON dbo.CommissionPayments(CommissionRate)   TO role_Analyst;';
    EXEC sys.sp_executesql N'GRANT UNMASK ON dbo.LeaseAgreements(MonthlyRent)         TO role_Analyst;';

    -- NOTE what is deliberately NOT granted: Clients.NRIC, Clients.Email,
    -- Clients.ContactNumber, Clients.Address, Agents.ContactNumber,
    -- Agents.Email, SystemUsers.Email, MaintenanceStaff.ContactNumber.
    -- Analysts get numbers, never identities.
END
ELSE
BEGIN
    PRINT 'SQL Server 2019 or older detected: column-level UNMASK is not available.';
    PRINT 'role_Analyst keeps masked columns; the aggregate limitation above is accepted and documented.';
END;
GO



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
    
/* ========================================================================
   REQUIREMENT 5 & 6: HASH & ENCRYPTION
   ======================================================================== */
CREATE SYMMETRIC KEY EMS_ClientDataSymmetricKey
    WITH ALGORITHM = AES_256
    ENCRYPTION BY CERTIFICATE EMS_DataProtectionCertificate;
END;
GO



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



-- ------------------------------------------------------------------------
-- Populate the ciphertext columns from the existing plain values.
--
-- IMPORTANT ORDERING NOTE: this runs AFTER Dynamic Data Masking has been
-- applied to the same table. That is safe only because this script is
-- executed by a sysadmin / the database owner, who is implicitly exempt
-- from masking. If a user WITHOUT the UNMASK permission ran this block,
-- EncryptByKey would faithfully encrypt the MASKED strings ("XXXXXX1234")
-- and the real data would be lost. Anyone re-running this must therefore
-- connect as sysadmin, db_owner, or a login holding UNMASK.
-- ------------------------------------------------------------------------
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



IF COL_LENGTH('dbo.LeaseAgreements', 'AgreementDocPath_Encrypted') IS NULL
BEGIN
    ALTER TABLE dbo.LeaseAgreements
    ADD AgreementDocPath_Encrypted VARBINARY(MAX) NULL;
END;
GO



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



UPDATE dbo.SystemUsers
SET PasswordSaltSecure = CRYPT_GEN_RANDOM(32)
WHERE PasswordSaltSecure IS NULL;
GO



-- Every account is seeded with the SAME temporary password and is expected
-- to change it at first login (see PasswordMustChange below). A shared
-- onboarding secret that must be replaced immediately is standard practice;
-- what would NOT be acceptable is leaving it in place, which is why the
-- verification procedure refuses to complete a login until it is changed.
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

-- Forced-reset flag: 1 = still on the onboarding password.
IF COL_LENGTH('dbo.SystemUsers', 'PasswordMustChange') IS NULL
BEGIN
    ALTER TABLE dbo.SystemUsers
    ADD PasswordMustChange BIT NOT NULL CONSTRAINT DF_SysUser_MustChange DEFAULT 1;
END;
GO


/* ------------------------------------------------------------------------
   REMOVING THE OLD, WEAKER CREDENTIAL STORE

   The original developers stored credentials in two columns:
       PasswordHash VARBINARY(64) -- HASHBYTES('SHA2_256', password + salt)
       PasswordSalt NVARCHAR(50)  -- the salt, in PLAIN TEXT

   Both are now superseded by PasswordHashSecure / PasswordSaltSecure, and
   leaving them in place would be a real weakness, not just clutter:

     * the salt sat next to the hash in a readable NVARCHAR column, so
       anyone with SELECT on SystemUsers had everything needed to run an
       offline dictionary attack;
     * SHA2_256 over a short salt is far cheaper to brute-force than the
       SHA2_512 over a 32-byte CRYPT_GEN_RANDOM salt we use now;
     * two credential stores for one account means an attacker simply
       attacks the weaker one.

   So we drop them. The DEFAULT constraint has to go first, and the columns
   are dropped only after the secure hashes above have been generated.
   ------------------------------------------------------------------------ */
IF COL_LENGTH('dbo.SystemUsers', 'PasswordHash') IS NOT NULL
BEGIN
    ALTER TABLE dbo.SystemUsers DROP COLUMN PasswordHash;
    PRINT 'Dropped legacy column SystemUsers.PasswordHash (SHA2_256).';
END;
GO

IF COL_LENGTH('dbo.SystemUsers', 'PasswordSalt') IS NOT NULL
BEGIN
    ALTER TABLE dbo.SystemUsers DROP COLUMN PasswordSalt;
    PRINT 'Dropped legacy column SystemUsers.PasswordSalt (plain-text salt).';
END;
GO



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
        PasswordLastUpdated = GETDATE(),
        PasswordMustChange = 0      -- the onboarding password is now replaced
    WHERE LoginName = @LoginName;

    PRINT 'Password updated for ' + @LoginName + '.';
END;
GO



-- ------------------------------------------------------------------------
-- usp_VerifySystemUserPassword
--
-- Verifies an application-level login by re-hashing the supplied password
-- with the stored per-user salt and comparing the digests. The stored hash
-- is never reversed and the plain password is never written anywhere.
--
-- Every attempt - successful OR failed - is now recorded in
-- dbo.UserLoginLog, which is what turns that table into real audit
-- evidence instead of an empty schema object. Failed SERVER logins (wrong
-- SQL Server password at connect time) are captured separately by the
-- FAILED_LOGIN_GROUP action in the Server Audit Specification; this
-- procedure covers logins performed by the EMS application itself.
-- ------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.usp_VerifySystemUserPassword
    @LoginName NVARCHAR(100),
    @PlainPassword NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StoredSalt   VARBINARY(32);
    DECLARE @StoredHash   VARBINARY(64);
    DECLARE @InputHash    VARBINARY(64);
    DECLARE @SystemUserID INT;

    SELECT
        @SystemUserID = SystemUserID,
        @StoredSalt   = PasswordSaltSecure,
        @StoredHash   = PasswordHashSecure
    FROM dbo.SystemUsers
    WHERE LoginName = @LoginName
      AND IsActive = 1;

    IF @StoredSalt IS NULL OR @StoredHash IS NULL
    BEGIN
        -- Unknown or deactivated account. We log the attempt but return the
        -- same generic message as a wrong password, so an attacker cannot
        -- use the error text to enumerate valid user names.
        INSERT INTO dbo.UserLoginLog
            (SystemUserID, LoginName, IsSuccessful, HostName, FailureReason)
        VALUES
            (@SystemUserID, @LoginName, 0, HOST_NAME(),
             'Unknown or inactive account');

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
        INSERT INTO dbo.UserLoginLog
            (SystemUserID, LoginName, IsSuccessful, HostName, FailureReason)
        VALUES
            (@SystemUserID, @LoginName, 1, HOST_NAME(), NULL);

        DECLARE @LogID INT = SCOPE_IDENTITY();

        -- Correct password, but still the shared onboarding secret: the
        -- credential is valid yet must not be usable for real work until
        -- the account owner replaces it.
        IF EXISTS (SELECT 1 FROM dbo.SystemUsers
                   WHERE LoginName = @LoginName AND PasswordMustChange = 1)
        BEGIN
            SELECT
                'Password Change Required' AS LoginStatus,
                @LogID                     AS LogID,
                SystemUserID,
                FullName,
                LoginName,
                UserRole
            FROM dbo.SystemUsers
            WHERE LoginName = @LoginName;
            RETURN;
        END;

        SELECT
            'Login Successful' AS LoginStatus,
            @LogID             AS LogID,   -- pass to usp_RecordLogout later
            SystemUserID,
            FullName,
            LoginName,
            UserRole
        FROM dbo.SystemUsers
        WHERE LoginName = @LoginName;
    END
    ELSE
    BEGIN
        INSERT INTO dbo.UserLoginLog
            (SystemUserID, LoginName, IsSuccessful, HostName, FailureReason)
        VALUES
            (@SystemUserID, @LoginName, 0, HOST_NAME(), 'Incorrect password');

        SELECT
            'Invalid Login' AS LoginStatus,
            @LoginName AS LoginName;
    END;
END;
GO



-- ------------------------------------------------------------------------
-- usp_RecordLogout
--
-- Closes off a session row in UserLoginLog so the audit trail shows how
-- long each account was connected, not just when it arrived.
-- ------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.usp_RecordLogout
    @LogID INT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.UserLoginLog
    SET LogoutTime = GETDATE()
    WHERE LogID = @LogID
      AND LogoutTime IS NULL;

    IF @@ROWCOUNT = 0
        PRINT 'No open session found for that LogID (already closed or invalid).';
    ELSE
        PRINT 'Logout recorded.';
END;
GO



-- ------------------------------------------------------------------------
-- usp_ReportSuspiciousLogins
--
-- Detection query for the DBA: any account with 3 or more failed attempts
-- inside a rolling window is reported as a possible brute-force attempt.
-- ------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.usp_ReportSuspiciousLogins
    @WindowMinutes  INT = 60,
    @FailThreshold  INT = 3
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        LoginName,
        COUNT(*)        AS FailedAttempts,
        MIN(LoginTime)  AS FirstAttempt,
        MAX(LoginTime)  AS LastAttempt,
        MAX(HostName)   AS LastHostName
    FROM dbo.UserLoginLog
    WHERE IsSuccessful = 0
      AND LoginTime >= DATEADD(MINUTE, -@WindowMinutes, GETDATE())
    GROUP BY LoginName
    HAVING COUNT(*) >= @FailThreshold
    ORDER BY FailedAttempts DESC;
END;
GO



/* ========================================================================
   REQUIREMENT 6 (continued): CONTROLLED DECRYPTION PATH

   Encrypting the data is only half the job - the business still has to be
   able to READ it. Without the objects below, nothing except the database
   owner could ever decrypt these columns, which would break Availability
   (the "A" in CIA) for the sake of Confidentiality.

   Design decision: the procedures are declared WITH EXECUTE AS OWNER.
   That means the *procedure* opens the symmetric key using the certificate,
   so we never have to hand CONTROL of the certificate to the calling role.
   A caller who is granted EXECUTE can read the decrypted values through
   this one narrow, auditable door and cannot use the key for anything else.

   The audit triggers use ORIGINAL_LOGIN() rather than SYSTEM_USER, so
   EXECUTE AS OWNER does NOT hide who the real caller was.
   ======================================================================== */

-- ------------------------------------------------------------------------
-- usp_GetClientSensitiveData
--
-- Returns decrypted client PII for ONE client at a time. Deliberately not
-- a view and deliberately not bulk: a caller must name the ClientID they
-- have a business reason to look at, and every call is captured by the
-- Database Audit Specification on dbo.Clients.
-- ------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.usp_GetClientSensitiveData
    @ClientID INT,
    @Reason   NVARCHAR(200) = NULL   -- purpose-of-access, written to AuditLog
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    IF @ClientID IS NULL
    BEGIN
        RAISERROR('ClientID is required.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (SELECT 1 FROM dbo.Clients WHERE ClientID = @ClientID)
    BEGIN
        RAISERROR('Client ID not found.', 16, 1);
        RETURN;
    END;

    -- Record WHO asked for decrypted PII and WHY, before handing it over.
    -- ORIGINAL_LOGIN() survives EXECUTE AS OWNER, so this names the human.
    INSERT INTO dbo.AuditLog
        (TableName, OperationType, RecordID, ChangedBy,
         NewValues, ApplicationName, HostName)
    VALUES
        ('Clients', 'SELECT', CONVERT(NVARCHAR(50), @ClientID), ORIGINAL_LOGIN(),
         (SELECT 'DECRYPT_READ'                AS Action,
                 ISNULL(@Reason, 'not stated') AS Reason
          FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
         APP_NAME(), HOST_NAME());

    OPEN SYMMETRIC KEY EMS_ClientDataSymmetricKey
        DECRYPTION BY CERTIFICATE EMS_DataProtectionCertificate;

    SELECT
        c.ClientID,
        c.FullName,
        CONVERT(NVARCHAR(20),  DecryptByKey(c.NRIC_Encrypted))          AS NRIC,
        CONVERT(NVARCHAR(20),  DecryptByKey(c.ContactNumber_Encrypted)) AS ContactNumber,
        CONVERT(NVARCHAR(100), DecryptByKey(c.Email_Encrypted))         AS Email,
        CONVERT(NVARCHAR(255), DecryptByKey(c.Address_Encrypted))       AS Address,
        c.ClientType,
        c.IsActive
    FROM dbo.Clients AS c
    WHERE c.ClientID = @ClientID;

    CLOSE SYMMETRIC KEY EMS_ClientDataSymmetricKey;
END;
GO



-- ------------------------------------------------------------------------
-- usp_GetLeaseDocumentPath
--
-- Same pattern for the encrypted lease-document location.
-- ------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.usp_GetLeaseDocumentPath
    @LeaseID INT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.LeaseAgreements WHERE LeaseID = @LeaseID)
    BEGIN
        RAISERROR('Lease ID not found.', 16, 1);
        RETURN;
    END;

    OPEN SYMMETRIC KEY EMS_ClientDataSymmetricKey
        DECRYPTION BY CERTIFICATE EMS_DataProtectionCertificate;

    SELECT
        l.LeaseID,
        l.ClientID,
        l.PropertyID,
        CONVERT(NVARCHAR(500), DecryptByKey(l.AgreementDocPath_Encrypted))
            AS AgreementDocPath,
        l.LeaseStatus
    FROM dbo.LeaseAgreements AS l
    WHERE l.LeaseID = @LeaseID;

    CLOSE SYMMETRIC KEY EMS_ClientDataSymmetricKey;
END;
GO



-- ------------------------------------------------------------------------
-- usp_EncryptClientPII
--
-- Re-encrypts the sensitive columns for a client after an INSERT/UPDATE.
-- Without this, any row created through usp_ManageClient after the initial
-- build would have plain values but EMPTY ciphertext columns, and the
-- encryption would silently stop covering new data.
-- ------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.usp_EncryptClientPII
    @ClientID INT = NULL       -- NULL = refresh every row that needs it
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    OPEN SYMMETRIC KEY EMS_ClientDataSymmetricKey
        DECRYPTION BY CERTIFICATE EMS_DataProtectionCertificate;

    UPDATE dbo.Clients
    SET
        NRIC_Encrypted = EncryptByKey(
            Key_GUID('EMS_ClientDataSymmetricKey'), CONVERT(VARBINARY(MAX), NRIC)),
        ContactNumber_Encrypted = EncryptByKey(
            Key_GUID('EMS_ClientDataSymmetricKey'), CONVERT(VARBINARY(MAX), ContactNumber)),
        Email_Encrypted = EncryptByKey(
            Key_GUID('EMS_ClientDataSymmetricKey'), CONVERT(VARBINARY(MAX), Email)),
        Address_Encrypted = EncryptByKey(
            Key_GUID('EMS_ClientDataSymmetricKey'), CONVERT(VARBINARY(MAX), Address))
    WHERE (@ClientID IS NULL OR ClientID = @ClientID)
      AND (
            NRIC_Encrypted IS NULL
         OR ContactNumber_Encrypted IS NULL
         OR Email_Encrypted IS NULL
         OR Address_Encrypted IS NULL
         OR @ClientID IS NOT NULL      -- explicit refresh for one client
          );

    DECLARE @Rows INT = @@ROWCOUNT;

    CLOSE SYMMETRIC KEY EMS_ClientDataSymmetricKey;

    PRINT 'Rows re-encrypted: ' + CAST(@Rows AS VARCHAR(10));
END;
GO



-- ------------------------------------------------------------------------
-- Who may decrypt?
--
-- role_Admin  - business owners of client data, needed for daily service.
-- role_DBA    - needed for data-recovery and key-rotation duties.
-- Everyone else (PropMgmtDev, ClientPortalDev, Analyst, ReadOnly) has NO
-- route to plaintext at all: they were never granted EXECUTE, and the
-- ciphertext columns are meaningless without the key.
-- ------------------------------------------------------------------------
GRANT EXECUTE ON dbo.usp_GetClientSensitiveData TO role_Admin;
GRANT EXECUTE ON dbo.usp_GetClientSensitiveData TO role_DBA;
GRANT EXECUTE ON dbo.usp_GetLeaseDocumentPath   TO role_Admin;
GRANT EXECUTE ON dbo.usp_GetLeaseDocumentPath   TO role_DBA;
GRANT EXECUTE ON dbo.usp_EncryptClientPII       TO role_Admin;
GRANT EXECUTE ON dbo.usp_EncryptClientPII       TO role_DBA;
GRANT EXECUTE ON dbo.usp_RecordLogout           TO role_Admin;
GRANT EXECUTE ON dbo.usp_ReportSuspiciousLogins TO role_DBA;
GO

-- Explicit DENY on the decryption doors for the developer/reporting roles.
-- They have no EXECUTE anyway, but an explicit DENY documents the intent in
-- sys.database_permissions and cannot be undone by a future role grant.
DENY EXECUTE ON dbo.usp_GetClientSensitiveData TO role_PropMgmtDev;
DENY EXECUTE ON dbo.usp_GetClientSensitiveData TO role_ClientPortalDev;
DENY EXECUTE ON dbo.usp_GetClientSensitiveData TO role_Analyst;
DENY EXECUTE ON dbo.usp_GetClientSensitiveData TO role_ReadOnly;
DENY EXECUTE ON dbo.usp_GetLeaseDocumentPath   TO role_Analyst;
DENY EXECUTE ON dbo.usp_GetLeaseDocumentPath   TO role_ReadOnly;
GO

-- ------------------------------------------------------------------------
-- Ad-hoc key access for DBAs only.
--
-- The procedures above are the normal route. A DBA also needs to be able to
-- open the key directly during a disaster-recovery or key-rotation exercise,
-- which requires VIEW DEFINITION on the key and CONTROL on the certificate
-- that protects it. This is granted to role_DBA and to nobody else.
-- ------------------------------------------------------------------------
GRANT VIEW DEFINITION ON SYMMETRIC KEY::EMS_ClientDataSymmetricKey TO role_DBA;
GRANT CONTROL ON CERTIFICATE::EMS_DataProtectionCertificate        TO role_DBA;
GO

PRINT 'Controlled decryption path created (procedures + grants).';
GO



/* ========================================================================
   OPTIONAL HARDENING - REMOVING THE PLAINTEXT DUPLICATES

   Right now each protected column exists TWICE: the readable original
   (protected by masking) and the ciphertext copy (protected by the key).
   That is intentional in this submission, because the masking requirement
   has to be demonstrable on the same tables - but it does mean the
   encryption is defence-in-depth rather than true encryption-at-rest,
   since the plain value is still on the data page and still lands in the
   AuditLog JSON.

   If the requirement is TRUE encryption-at-rest, un-comment the block
   below. Run it only AFTER the encryption UPDATE above has populated the
   ciphertext, and note the follow-on work it forces:
     - vw_ClientDirectory must stop selecting NRIC
     - usp_ManageClient must call usp_EncryptClientPII instead of writing
       the plain column
     - the masking block for Clients.NRIC / LeaseAgreements.AgreementDocPath
       becomes redundant and should be deleted
     - test cases B2, C5, C6, C7 must select ContactNumber/Email instead
       of NRIC
   ------------------------------------------------------------------------
   ALTER TABLE dbo.Clients         DROP COLUMN NRIC;
   ALTER TABLE dbo.LeaseAgreements DROP COLUMN AgreementDocPath;
   GO
   ======================================================================== */



USE master;
GO


ALTER DATABASE GreenAcresEMS SET RECOVERY FULL;
GO

-- Create the backup directory on disk (requires xp_cmdshell OR
-- do this manually in Windows Explorer). Optional helper:
EXEC master.dbo.xp_create_subdir 'C:\EMS_Backups';
GO

-- Separate folder for key material. In production this would live on
-- different media with different access control from the .bak files - if an
-- attacker steals one folder they must not automatically get the other.
EXEC master.dbo.xp_create_subdir 'C:\EMS_Backups\Keys';
GO


/* ========================================================================
   REQUIREMENT 8 (part 1): BACKING UP THE KEY MATERIAL

   THIS IS THE STEP THAT MOST BACKUP PLANS FORGET.

   Clients.NRIC_Encrypted and the other ciphertext columns can only be read
   with the certificate EMS_DataProtectionCertificate, which is itself
   protected by the Database Master Key. Restore GreenAcresEMS_FULL.bak onto
   a DIFFERENT instance and the certificate does not exist there - the
   restored ciphertext is permanently unreadable. A backup you cannot
   decrypt is not a backup.

   So we export three things, and they must be kept SAFE and SEPARATE from
   the database backups:
     1. the certificate (public part)     -> .cer
     2. its private key                   -> .pvk, protected by a password
     3. the database master key            -> .key, protected by a password

   RECOVERY ON A NEW INSTANCE - the order matters:
     RESTORE DATABASE GreenAcresEMS FROM DISK = '...FULL.bak' WITH ...;
     USE GreenAcresEMS;
     -- if the master key did not come across, restore it first:
     RESTORE MASTER KEY FROM FILE = 'C:\EMS_Backups\Keys\EMS_MasterKey.key'
         DECRYPTION BY PASSWORD = '<the export password below>'
         ENCRYPTION BY PASSWORD = '<new DMK password>';
     OPEN MASTER KEY DECRYPTION BY PASSWORD = '<new DMK password>';
     -- then the certificate, if it is missing:
     CREATE CERTIFICATE EMS_DataProtectionCertificate
         FROM FILE = 'C:\EMS_Backups\Keys\EMS_DataProtectionCertificate.cer'
         WITH PRIVATE KEY (
             FILE = 'C:\EMS_Backups\Keys\EMS_DataProtectionCertificate.pvk',
             DECRYPTION BY PASSWORD = '<the export password below>');
   ======================================================================== */
USE GreenAcresEMS;
GO

-- The master key must be open before it can be exported.
OPEN MASTER KEY DECRYPTION BY PASSWORD = 'EMS_MasterKey_StrongPassword_2026!';
GO

-- 1 + 2. Export the certificate together with its private key.
--        Without the private key the .cer file cannot decrypt anything.
BACKUP CERTIFICATE EMS_DataProtectionCertificate
    TO FILE = 'C:\EMS_Backups\Keys\EMS_DataProtectionCertificate.cer'
    WITH PRIVATE KEY (
        FILE = 'C:\EMS_Backups\Keys\EMS_DataProtectionCertificate.pvk',
        ENCRYPTION BY PASSWORD = 'CertPrivateKey_Export_2026!'
    );
GO

-- 3. Export the Database Master Key itself.
BACKUP MASTER KEY
    TO FILE = 'C:\EMS_Backups\Keys\EMS_MasterKey.key'
    ENCRYPTION BY PASSWORD = 'MasterKey_Export_2026!';
GO

CLOSE MASTER KEY;
GO

PRINT 'Certificate, private key and database master key exported to C:\EMS_Backups\Keys.';
PRINT 'REMINDER: store these off-site and NOT in the same folder as the .bak files.';
GO

USE master;
GO


/* ========================================================================
   REQUIREMENT 8 (part 2): DATABASE BACKUPS
   ======================================================================== */
BACKUP DATABASE GreenAcresEMS
TO DISK = 'C:\EMS_Backups\GreenAcresEMS_FULL.bak'
WITH
    FORMAT,                         -- overwrite / create a fresh media set
    INIT,                           -- overwrite existing backup sets
    NAME = 'GreenAcresEMS-Full Database Backup',
    DESCRIPTION = 'Weekly full baseline backup of the EMS database',
    COMPRESSION,                    -- smaller backup file (Standard/Enterprise)
    CHECKSUM,                       -- detect I/O corruption during backup
    STATS = 10;                     -- progress reported every 10%
GO


/* ========================================================================
   REQUIREMENT 8 (part 2 continued): DIFFERENTIAL BACKUP
   Captures only what changed since the last FULL backup, so the daily
   window stays short. Restoring needs FULL + the latest DIFFERENTIAL.
   ======================================================================== */
BACKUP DATABASE GreenAcresEMS
TO DISK = 'C:\EMS_Backups\GreenAcresEMS_DIFF.bak'
WITH
    DIFFERENTIAL,
    INIT,
    NAME = 'GreenAcresEMS-Differential Backup',
    DESCRIPTION = 'Daily differential backup (changes since last full)',
    COMPRESSION,
    CHECKSUM,
    STATS = 10;
GO



BACKUP LOG GreenAcresEMS
TO DISK = 'C:\EMS_Backups\GreenAcresEMS_LOG.trn'
WITH
    INIT,
    NAME = 'GreenAcresEMS-Transaction Log Backup',
    DESCRIPTION = 'Hourly transaction log backup for point-in-time recovery',
    COMPRESSION,
    CHECKSUM,
    STATS = 10;
GO



RESTORE VERIFYONLY
FROM DISK = 'C:\EMS_Backups\GreenAcresEMS_FULL.bak'
WITH CHECKSUM;
GO

-- Inspect header / contents of a backup file:
RESTORE HEADERONLY  FROM DISK = 'C:\EMS_Backups\GreenAcresEMS_FULL.bak';
RESTORE FILELISTONLY FROM DISK = 'C:\EMS_Backups\GreenAcresEMS_FULL.bak';
GO

-- Review backup history from the system tables:
SELECT
    bs.database_name,
    bs.backup_start_date,
    bs.backup_finish_date,
    CASE bs.type
        WHEN 'D' THEN 'Full'
        WHEN 'I' THEN 'Differential'
        WHEN 'L' THEN 'Transaction Log'
    END AS BackupType,
    CAST(bs.backup_size / 1048576.0 AS DECIMAL(10,2)) AS BackupSize_MB,
    bmf.physical_device_name
FROM msdb.dbo.backupset bs
JOIN msdb.dbo.backupmediafamily bmf
     ON bs.media_set_id = bmf.media_set_id
WHERE bs.database_name = 'GreenAcresEMS'
ORDER BY bs.backup_start_date DESC;
GO


/* ========================================================================
   REQUIREMENT 8 (part 3): PROVING THE RESTORE ACTUALLY WORKS

   An untested backup is only a hope. This section performs a real recovery
   so the client can see the Availability side of CIA being met.

   SAFETY: we restore into a SEPARATE copy of the database called
   GreenAcresEMS_Restore, using WITH MOVE to place its files in the same
   data folder under new names. The live GreenAcresEMS is never touched, so
   this can be demonstrated on camera without risk.

   The chain must be applied in this exact order:
       FULL  (NORECOVERY)  ->  DIFFERENTIAL (NORECOVERY)  ->  LOG (RECOVERY)
   NORECOVERY leaves the database "restoring" so more backups can be added.
   Only the final step brings it online.
   ======================================================================== */
USE master;
GO

-- Discover where this instance keeps its data files, so the MOVE below works
-- on any machine instead of a hard-coded C:\Program Files\... path.
DECLARE @DataPath NVARCHAR(500) = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(500));
DECLARE @LogPath  NVARCHAR(500) = CAST(SERVERPROPERTY('InstanceDefaultLogPath')  AS NVARCHAR(500));
PRINT 'Data path : ' + ISNULL(@DataPath, '(unknown)');
PRINT 'Log path  : ' + ISNULL(@LogPath,  '(unknown)');
PRINT 'Use the logical/physical names listed by RESTORE FILELISTONLY above.';
GO

-- Remove a previous rehearsal copy if one is left over.
IF DB_ID('GreenAcresEMS_Restore') IS NOT NULL
BEGIN
    ALTER DATABASE GreenAcresEMS_Restore SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE GreenAcresEMS_Restore;
    PRINT 'Dropped previous GreenAcresEMS_Restore copy.';
END;
GO

-- ------------------------------------------------------------------------
-- Step 1 of 3: restore the FULL backup, leaving the copy offline
--              (NORECOVERY) so the differential can follow.
--
-- The two MOVE clauses are built dynamically from the default data/log
-- paths, so this runs unchanged on the lecturer's machine. The logical file
-- names 'GreenAcresEMS' and 'GreenAcresEMS_log' are the SQL Server defaults
-- for a database created with a bare CREATE DATABASE, as ours was - confirm
-- them with RESTORE FILELISTONLY if the restore complains.
-- ------------------------------------------------------------------------
DECLARE @DataPath NVARCHAR(500) = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(500));
DECLARE @LogPath  NVARCHAR(500) = CAST(SERVERPROPERTY('InstanceDefaultLogPath')  AS NVARCHAR(500));
DECLARE @sql      NVARCHAR(MAX);

SET @sql = N'
RESTORE DATABASE GreenAcresEMS_Restore
FROM DISK = ''C:\EMS_Backups\GreenAcresEMS_FULL.bak''
WITH
    MOVE ''GreenAcresEMS''     TO ''' + @DataPath + N'GreenAcresEMS_Restore.mdf'',
    MOVE ''GreenAcresEMS_log'' TO ''' + @LogPath  + N'GreenAcresEMS_Restore_log.ldf'',
    NORECOVERY,
    REPLACE,
    STATS = 10;';

PRINT @sql;
EXEC sys.sp_executesql @sql;
GO

-- ------------------------------------------------------------------------
-- Step 2 of 3: apply the DIFFERENTIAL, still NORECOVERY.
-- ------------------------------------------------------------------------
RESTORE DATABASE GreenAcresEMS_Restore
FROM DISK = 'C:\EMS_Backups\GreenAcresEMS_DIFF.bak'
WITH NORECOVERY, STATS = 10;
GO

-- ------------------------------------------------------------------------
-- Step 3 of 3: apply the LOG and bring the database online.
--
-- WITH RECOVERY = "no more backups are coming, open the database".
-- ------------------------------------------------------------------------
RESTORE LOG GreenAcresEMS_Restore
FROM DISK = 'C:\EMS_Backups\GreenAcresEMS_LOG.trn'
WITH RECOVERY, STATS = 10;
GO

PRINT 'Restore rehearsal complete: GreenAcresEMS_Restore is online.';
GO

-- ------------------------------------------------------------------------
-- Post-restore verification: does the recovered copy actually hold the
-- data? Compare row counts side by side. Every pair must match.
-- ------------------------------------------------------------------------
SELECT 'Properties'  AS TableName,
       (SELECT COUNT(*) FROM GreenAcresEMS.dbo.Properties)          AS LiveRows,
       (SELECT COUNT(*) FROM GreenAcresEMS_Restore.dbo.Properties)  AS RestoredRows
UNION ALL
SELECT 'Clients',
       (SELECT COUNT(*) FROM GreenAcresEMS.dbo.Clients),
       (SELECT COUNT(*) FROM GreenAcresEMS_Restore.dbo.Clients)
UNION ALL
SELECT 'Transactions',
       (SELECT COUNT(*) FROM GreenAcresEMS.dbo.Transactions),
       (SELECT COUNT(*) FROM GreenAcresEMS_Restore.dbo.Transactions)
UNION ALL
SELECT 'LeaseAgreements',
       (SELECT COUNT(*) FROM GreenAcresEMS.dbo.LeaseAgreements),
       (SELECT COUNT(*) FROM GreenAcresEMS_Restore.dbo.LeaseAgreements)
UNION ALL
SELECT 'CommissionPayments',
       (SELECT COUNT(*) FROM GreenAcresEMS.dbo.CommissionPayments),
       (SELECT COUNT(*) FROM GreenAcresEMS_Restore.dbo.CommissionPayments);
GO

-- Confirm the encrypted data survived the restore as ciphertext.
-- (It cannot be DECRYPTED in the copy until the certificate is available
-- there - which is exactly why the key backup section above exists.)
SELECT TOP 3
    ClientID,
    FullName,
    NRIC_Encrypted AS StillEncryptedAfterRestore
FROM GreenAcresEMS_Restore.dbo.Clients;
GO


/* ========================================================================
   POINT-IN-TIME RECOVERY (the "someone deleted the wrong rows" scenario)

   FULL recovery model + log backups let us roll forward to a specific
   second, stopping just BEFORE a mistake. Run these one block at a time.

   1. Note the time now - this is our "known good" point:
          SELECT GETDATE() AS KnownGoodTime;

   2. Simulate the accident on the live database, e.g.
          UPDATE dbo.Properties SET Price = 1 WHERE PropertyID <= 5;

   3. Take a tail-log backup so nothing committed is lost:
          BACKUP LOG GreenAcresEMS
          TO DISK = 'C:\EMS_Backups\GreenAcresEMS_TAIL.trn'
          WITH NORECOVERY, NAME = 'Tail-log before point-in-time recovery';

   4. Restore the full backup with NORECOVERY (as in Step 1 above), then
      roll the log forward only as far as the known-good time:
          RESTORE LOG GreenAcresEMS_Restore
          FROM DISK = 'C:\EMS_Backups\GreenAcresEMS_LOG.trn'
          WITH STOPAT = '2026-07-30 14:35:00', RECOVERY;

   5. Verify the rows are back to their pre-accident values, then copy the
      corrected rows across, or rename the databases to swap them.

   Written out rather than executed because STOPAT needs a real timestamp
   from the demo, and because step 3 deliberately takes the live database
   offline - not something a build script should ever do on its own.
   ======================================================================== */

-- COPY_ONLY backup: an ad-hoc backup (before a risky deployment, say) that
-- does NOT reset the differential base, so the scheduled backup chain above
-- keeps working normally.
BACKUP DATABASE GreenAcresEMS
TO DISK = 'C:\EMS_Backups\GreenAcresEMS_COPYONLY.bak'
WITH COPY_ONLY, INIT, CHECKSUM, COMPRESSION,
     NAME = 'GreenAcresEMS-Ad-hoc copy-only backup',
     DESCRIPTION = 'Taken before a change; does not break the differential chain';
GO

-- Corruption watch: this table should always be EMPTY. Any row here means
-- SQL Server met a damaged page and the backups need to be relied on.
SELECT * FROM msdb.dbo.suspect_pages;
GO

-- Confirm the recovery model is still FULL. In SIMPLE recovery, log backups
-- are impossible and point-in-time recovery cannot be offered at all.
SELECT
    name             AS DatabaseName,
    recovery_model_desc,
    log_reuse_wait_desc
FROM sys.databases
WHERE name IN ('GreenAcresEMS', 'GreenAcresEMS_Restore');
GO


PRINT 'Backup and recovery objects/steps set up successfully.';
GO



USE GreenAcresEMS;
GO

-- 08_auditing.sql
-- Green Acres Realty Sdn Bhd - EMS Database Security
-- CT069-3-3 Database Security Assignment
-- Purpose:
--   1. Create the central AuditLog table if it does not exist.
--   2. Create an archive and controlled retention procedure for history.
--   3. Protect audit evidence from normal developer roles.
--   4. Create SQL Server Audit objects for security events.
--   5. Create a Database Audit Specification for GreenAcresEMS.
--   Run this AFTER the database, tables, roles, users and permissions
--   have been created.
--   Before running this script, create this Windows folder manually:
--       C:\SQLAudit\
--   SQL Server must have permission to write into that folder.
--   If CREATE SERVER AUDIT fails, run SSMS as administrator or ask
--   your lecturer/lab admin for sysadmin permission.

USE GreenAcresEMS;
GO

IF OBJECT_ID('dbo.AuditLog', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.AuditLog (
        AuditID         INT IDENTITY(1,1) PRIMARY KEY,
        EventTime       DATETIME NOT NULL DEFAULT GETDATE(),
        TableName       NVARCHAR(128) NOT NULL,
        OperationType   NVARCHAR(10) NOT NULL
            CONSTRAINT CK_Audit_Op CHECK (OperationType IN ('INSERT','UPDATE','DELETE','SELECT')),
        RecordID        NVARCHAR(50) NOT NULL,
        ChangedBy       NVARCHAR(100) NOT NULL DEFAULT SYSTEM_USER,
        OldValues       NVARCHAR(MAX) NULL,
        NewValues       NVARCHAR(MAX) NULL,
        ApplicationName NVARCHAR(128) NULL,
        HostName        NVARCHAR(128) NULL
    );
END;
GO

-- Index used by incident-history and date-range searches.
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.AuditLog')
      AND name = 'IX_AuditLog_EventTime'
)
BEGIN
    CREATE INDEX IX_AuditLog_EventTime
        ON dbo.AuditLog (EventTime DESC)
        INCLUDE (TableName, OperationType, RecordID, ChangedBy);
END;
GO

-- Older audit rows are moved here instead of being permanently deleted.
IF OBJECT_ID('dbo.AuditLogArchive', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.AuditLogArchive (
        AuditID         INT NOT NULL PRIMARY KEY,
        EventTime       DATETIME NOT NULL,
        TableName       NVARCHAR(128) NOT NULL,
        OperationType   NVARCHAR(10) NOT NULL,
        RecordID        NVARCHAR(50) NOT NULL,
        ChangedBy       NVARCHAR(100) NOT NULL,
        OldValues       NVARCHAR(MAX) NULL,
        NewValues       NVARCHAR(MAX) NULL,
        ApplicationName NVARCHAR(128) NULL,
        HostName        NVARCHAR(128) NULL,
        ArchivedAt      DATETIME2(0) NOT NULL
            CONSTRAINT DF_AuditLogArchive_ArchivedAt DEFAULT SYSUTCDATETIME()
    );

    CREATE INDEX IX_AuditLogArchive_EventTime
        ON dbo.AuditLogArchive (EventTime DESC)
        INCLUDE (TableName, OperationType, RecordID, ChangedBy);
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_ArchiveAuditLog
    @RetainDays INT = 365
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @RetainDays < 30
        THROW 50001, 'RetainDays must be at least 30 days.', 1;

    DECLARE @Cutoff DATETIME = DATEADD(DAY, -@RetainDays, GETDATE());
    DECLARE @RowsArchived INT;

    BEGIN TRANSACTION;

    DELETE FROM dbo.AuditLog
    OUTPUT
        deleted.AuditID,
        deleted.EventTime,
        deleted.TableName,
        deleted.OperationType,
        deleted.RecordID,
        deleted.ChangedBy,
        deleted.OldValues,
        deleted.NewValues,
        deleted.ApplicationName,
        deleted.HostName
    INTO dbo.AuditLogArchive (
        AuditID,
        EventTime,
        TableName,
        OperationType,
        RecordID,
        ChangedBy,
        OldValues,
        NewValues,
        ApplicationName,
        HostName
    )
    WHERE EventTime < @Cutoff;

    SET @RowsArchived = @@ROWCOUNT;
    COMMIT TRANSACTION;

    SELECT
        @RowsArchived AS RowsArchived,
        @Cutoff AS CutoffDate,
        @RetainDays AS RetainDays;
END;
GO

-- ------------------------------------------------------------------------
-- Only DBA/Admin should read the audit trail directly.
-- Normal developer roles should not be able to change or delete audit
-- evidence.
--
-- CLASSIFY THE AUDIT LOG AS SENSITIVE DATA IN ITS OWN RIGHT.
-- The OldValues / NewValues columns hold a JSON snapshot of the whole
-- changed row, so a client's contact number and address are written into
-- AuditLog in the clear, and Dynamic Data Masking does NOT follow them
-- there - a mask protects Clients.Email, not a JSON string that happens to
-- contain the same characters. AuditLog is therefore at least as sensitive
-- as the tables it watches, and it is deliberately readable only by
-- role_DBA and role_Admin (both of which already hold UNMASK anyway), with
-- an explicit DENY for every other role below.
--
-- The SystemUsers trigger goes further and lists its columns explicitly so
-- that credential material is never copied into the log at all.
-- ------------------------------------------------------------------------
IF DATABASE_PRINCIPAL_ID('role_DBA') IS NOT NULL
BEGIN
    GRANT SELECT ON dbo.AuditLog TO role_DBA;
    GRANT SELECT ON dbo.AuditLogArchive TO role_DBA;
    GRANT EXECUTE ON dbo.usp_ArchiveAuditLog TO role_DBA;
END;
GO

IF DATABASE_PRINCIPAL_ID('role_Admin') IS NOT NULL
BEGIN
    GRANT SELECT ON dbo.AuditLog TO role_Admin;
    GRANT SELECT ON dbo.AuditLogArchive TO role_Admin;
END;
GO

IF DATABASE_PRINCIPAL_ID('role_PropMgmtDev') IS NOT NULL
BEGIN
    DENY SELECT, INSERT, UPDATE, DELETE ON dbo.AuditLog TO role_PropMgmtDev;
    DENY SELECT, INSERT, UPDATE, DELETE ON dbo.AuditLogArchive TO role_PropMgmtDev;
END;
GO

IF DATABASE_PRINCIPAL_ID('role_ClientPortalDev') IS NOT NULL
BEGIN
    DENY SELECT, INSERT, UPDATE, DELETE ON dbo.AuditLog TO role_ClientPortalDev;
    DENY SELECT, INSERT, UPDATE, DELETE ON dbo.AuditLogArchive TO role_ClientPortalDev;
END;
GO

IF DATABASE_PRINCIPAL_ID('role_Analyst') IS NOT NULL
BEGIN
    DENY SELECT, INSERT, UPDATE, DELETE ON dbo.AuditLog TO role_Analyst;
    DENY SELECT, INSERT, UPDATE, DELETE ON dbo.AuditLogArchive TO role_Analyst;
END;
GO

IF DATABASE_PRINCIPAL_ID('role_ReadOnly') IS NOT NULL
BEGIN
    DENY SELECT, INSERT, UPDATE, DELETE ON dbo.AuditLog TO role_ReadOnly;
    DENY SELECT, INSERT, UPDATE, DELETE ON dbo.AuditLogArchive TO role_ReadOnly;
END;
GO

USE GreenAcresEMS;
GO

-- Drop the database audit specification first if this script is re-run.
-- SQL Server will not allow the server audit to be dropped while a database
-- audit specification is still using it.
IF EXISTS (SELECT 1 FROM sys.database_audit_specifications WHERE name = 'GA_EMS_DatabaseAuditSpec')
BEGIN
    ALTER DATABASE AUDIT SPECIFICATION GA_EMS_DatabaseAuditSpec WITH (STATE = OFF);
    DROP DATABASE AUDIT SPECIFICATION GA_EMS_DatabaseAuditSpec;
END;
GO

USE master;
GO

IF EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'GA_EMS_ServerAuditSpec')
BEGIN
    ALTER SERVER AUDIT SPECIFICATION GA_EMS_ServerAuditSpec WITH (STATE = OFF);
    DROP SERVER AUDIT SPECIFICATION GA_EMS_ServerAuditSpec;
END;
GO

IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'GA_EMS_ServerAudit')
BEGIN
    ALTER SERVER AUDIT GA_EMS_ServerAudit WITH (STATE = OFF);
    DROP SERVER AUDIT GA_EMS_ServerAudit;
END;
GO


/* ========================================================================
   REQUIREMENT 9 & 10: SERVER & DATABASE AUDITING
   ======================================================================== */
CREATE SERVER AUDIT GA_EMS_ServerAudit
TO FILE (
    FILEPATH = 'C:\SQLAudit\',
    MAXSIZE = 20 MB,
    MAX_ROLLOVER_FILES = 5,
    RESERVE_DISK_SPACE = OFF
)
WITH (
    QUEUE_DELAY = 1000,
    ON_FAILURE = CONTINUE
);
GO

CREATE SERVER AUDIT SPECIFICATION GA_EMS_ServerAuditSpec
FOR SERVER AUDIT GA_EMS_ServerAudit
    ADD (FAILED_LOGIN_GROUP),
    ADD (SUCCESSFUL_LOGIN_GROUP),
    ADD (AUDIT_CHANGE_GROUP),
    ADD (SERVER_PRINCIPAL_CHANGE_GROUP),
    ADD (SERVER_PERMISSION_CHANGE_GROUP),
    ADD (SERVER_ROLE_MEMBER_CHANGE_GROUP);
GO

ALTER SERVER AUDIT GA_EMS_ServerAudit WITH (STATE = ON);
GO

ALTER SERVER AUDIT SPECIFICATION GA_EMS_ServerAuditSpec WITH (STATE = ON);
GO

USE GreenAcresEMS;
GO

IF EXISTS (SELECT 1 FROM sys.database_audit_specifications WHERE name = 'GA_EMS_DatabaseAuditSpec')
BEGIN
    ALTER DATABASE AUDIT SPECIFICATION GA_EMS_DatabaseAuditSpec WITH (STATE = OFF);
    DROP DATABASE AUDIT SPECIFICATION GA_EMS_DatabaseAuditSpec;
END;
GO

CREATE DATABASE AUDIT SPECIFICATION GA_EMS_DatabaseAuditSpec
FOR SERVER AUDIT GA_EMS_ServerAudit
    ADD (DATABASE_PRINCIPAL_CHANGE_GROUP),
    ADD (DATABASE_PERMISSION_CHANGE_GROUP),
    ADD (DATABASE_ROLE_MEMBER_CHANGE_GROUP),
    ADD (SCHEMA_OBJECT_PERMISSION_CHANGE_GROUP),
    ADD (SCHEMA_OBJECT_CHANGE_GROUP),
    ADD (SELECT ON OBJECT::dbo.Clients BY public),
    ADD (UPDATE ON OBJECT::dbo.Clients BY public),
    ADD (DELETE ON OBJECT::dbo.Clients BY public),
    ADD (SELECT ON OBJECT::dbo.Transactions BY public),
    ADD (UPDATE ON OBJECT::dbo.Transactions BY public),
    ADD (DELETE ON OBJECT::dbo.Transactions BY public),
    ADD (SELECT ON OBJECT::dbo.CommissionPayments BY public),
    ADD (UPDATE ON OBJECT::dbo.CommissionPayments BY public),
    ADD (DELETE ON OBJECT::dbo.CommissionPayments BY public),
    ADD (SELECT ON OBJECT::dbo.AuditLog BY public),
    ADD (INSERT ON OBJECT::dbo.AuditLog BY public),
    ADD (UPDATE ON OBJECT::dbo.AuditLog BY public),
    ADD (DELETE ON OBJECT::dbo.AuditLog BY public),
    ADD (SELECT ON OBJECT::dbo.AuditLogArchive BY public),
    ADD (INSERT ON OBJECT::dbo.AuditLogArchive BY public),
    ADD (UPDATE ON OBJECT::dbo.AuditLogArchive BY public),
    ADD (DELETE ON OBJECT::dbo.AuditLogArchive BY public);
GO

ALTER DATABASE AUDIT SPECIFICATION GA_EMS_DatabaseAuditSpec WITH (STATE = ON);
GO

-- D. Quick status check for screenshot evidence
SELECT
    name AS ServerAuditName,
    is_state_enabled AS IsEnabled,
    type_desc AS AuditTarget
FROM sys.server_audits
WHERE name = 'GA_EMS_ServerAudit';
GO

SELECT
    name AS DatabaseAuditSpecification,
    is_state_enabled AS IsEnabled
FROM sys.database_audit_specifications
WHERE name = 'GA_EMS_DatabaseAuditSpec';
GO


/* ========================================================================
   REQUIREMENT 9 & 10 (continued): LOGIN HISTORY IN dbo.UserLoginLog

   The Server Audit above writes to .sqlaudit FILES, which are excellent
   tamper-resistant evidence but awkward to query from the application and
   impossible to join to our own SystemUsers table. dbo.UserLoginLog is the
   in-database companion: queryable, joinable, and reportable.

   Two feeds populate it:
     a) usp_VerifySystemUserPassword - application-level EMS logins
        (already wired up in the hashing section above).
     b) the LOGON trigger below      - real SQL Server connections.

   WHY A LOGON TRIGGER NEEDS CARE:
   A logon trigger runs for EVERY connection to the instance. If it throws
   an unhandled error, SQL Server denies the login - including yours - and
   you are locked out of your own server. This implementation is therefore
   defensive:
     * the whole body sits inside TRY/CATCH, and the CATCH block does
       nothing, so a logging failure can never block a login;
     * it only writes a row for logins the EMS actually knows about, so it
       adds no measurable cost to other connections;
     * it is created WITH EXECUTE AS 'sa' because the connecting principal
       will not have INSERT permission on GreenAcresEMS.dbo.UserLoginLog.

   IF YOU DO GET LOCKED OUT: start sqlcmd with the -A switch (admin
   connection), which bypasses logon triggers, then run
       DISABLE TRIGGER trg_ServerLogon_AuditLogin ON ALL SERVER;
   ======================================================================== */
USE master;
GO

-- Drop first so this script stays re-runnable.
IF EXISTS (SELECT 1 FROM sys.server_triggers WHERE name = 'trg_ServerLogon_AuditLogin')
BEGIN
    DROP TRIGGER trg_ServerLogon_AuditLogin ON ALL SERVER;
    PRINT 'Existing logon trigger dropped.';
END;
GO

-- Only create the trigger if we can impersonate 'sa' to do the write.
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'sa' AND type = 'S')
BEGIN
    EXEC('
    CREATE TRIGGER trg_ServerLogon_AuditLogin
    ON ALL SERVER
    WITH EXECUTE AS ''sa''
    FOR LOGON
    AS
    BEGIN
        SET NOCOUNT ON;

        BEGIN TRY
            DECLARE @LoginName NVARCHAR(100) = ORIGINAL_LOGIN();

            -- Only log principals that belong to the EMS. Everything else
            -- (sa, service accounts, the lecturer''s own login) is ignored
            -- so this trigger stays cheap and quiet.
            IF EXISTS (
                SELECT 1
                FROM GreenAcresEMS.dbo.SystemUsers
                WHERE LoginName = @LoginName
            )
            BEGIN
                INSERT INTO GreenAcresEMS.dbo.UserLoginLog
                    (SystemUserID, LoginName, LoginTime, IsSuccessful,
                     IPAddress, HostName, FailureReason)
                SELECT
                    su.SystemUserID,
                    @LoginName,
                    GETDATE(),
                    1,                       -- a logon trigger only fires on success
                    CONVERT(NVARCHAR(50), CONNECTIONPROPERTY(''client_net_address'')),
                    HOST_NAME(),
                    NULL
                FROM GreenAcresEMS.dbo.SystemUsers su
                WHERE su.LoginName = @LoginName;
            END;
        END TRY
        BEGIN CATCH
            -- Deliberately swallowed. Never block a login because auditing
            -- failed; the Server Audit file remains the primary evidence.
            -- (This also keeps logins working while GreenAcresEMS is being
            -- dropped, restored or taken offline.)
            DECLARE @Ignored NVARCHAR(4000) = ERROR_MESSAGE();
        END CATCH;
    END;
    ');
    PRINT 'Logon trigger trg_ServerLogon_AuditLogin created.';
END
ELSE
BEGIN
    PRINT 'WARNING: login ''sa'' not found - logon trigger NOT created.';
    PRINT 'Application logins are still recorded by usp_VerifySystemUserPassword,';
    PRINT 'and failed server logins are still captured by the Server Audit.';
END;
GO

USE GreenAcresEMS;
GO

-- ------------------------------------------------------------------------
-- vw_ServerLoginAudit
--
-- Reads the FAILED and SUCCESSFUL login events straight out of the audit
-- files. A logon trigger cannot see failed logins (the connection is
-- rejected before it fires), so this view is what completes the picture.
--
-- NOTE: sys.fn_get_audit_file requires CONTROL SERVER, so this view is
-- readable by sysadmins only. It is not granted to role_DBA because doing
-- so would not work - the permission is checked at the function, not the
-- view.
-- ------------------------------------------------------------------------
CREATE OR ALTER VIEW dbo.vw_ServerLoginAudit
AS
    SELECT TOP 1000
        event_time                  AS EventTime,
        action_id                   AS ActionID,
        succeeded                   AS Succeeded,
        server_principal_name       AS LoginName,
        client_ip                   AS ClientIP,
        application_name            AS ApplicationName,
        host_name                   AS HostName,
        statement                   AS StatementText
    FROM sys.fn_get_audit_file('C:\SQLAudit\GA_EMS_ServerAudit*.sqlaudit', DEFAULT, DEFAULT)
    WHERE action_id IN ('LGIS', 'LGIF')   -- LGIS = login succeeded, LGIF = failed
    ORDER BY event_time DESC;
GO

-- ------------------------------------------------------------------------
-- vw_LoginHistory
--
-- The in-database login history, joined to the staff record and department
-- so the DBA can answer "who was connected, from where, and when" without
-- opening an audit file.
-- ------------------------------------------------------------------------
CREATE OR ALTER VIEW dbo.vw_LoginHistory
AS
    SELECT
        ull.LogID,
        ull.LoginName,
        su.FullName,
        d.DepartmentName,
        su.UserRole,
        ull.LoginTime,
        ull.LogoutTime,
        DATEDIFF(MINUTE, ull.LoginTime, ISNULL(ull.LogoutTime, GETDATE()))
            AS SessionMinutes,
        ull.IsSuccessful,
        ull.IPAddress,
        ull.HostName,
        ull.FailureReason
    FROM dbo.UserLoginLog AS ull
    LEFT JOIN dbo.SystemUsers AS su ON su.SystemUserID = ull.SystemUserID
    LEFT JOIN dbo.Departments AS d  ON d.DepartmentID  = su.DepartmentID;
GO

-- Login history is audit evidence: DBA and Admin may read it, the
-- developer/reporting roles may not (they could otherwise profile who works
-- when, and confirm which accounts exist).
GRANT SELECT ON dbo.vw_LoginHistory TO role_DBA;
GRANT SELECT ON dbo.vw_LoginHistory TO role_Admin;
GO

DENY SELECT ON dbo.UserLoginLog TO role_PropMgmtDev;
DENY SELECT ON dbo.UserLoginLog TO role_ClientPortalDev;
DENY SELECT ON dbo.UserLoginLog TO role_Analyst;
DENY SELECT ON dbo.UserLoginLog TO role_ReadOnly;
GO

GRANT SELECT ON dbo.UserLoginLog TO role_DBA;
GO

PRINT 'Login auditing wired up: logon trigger + UserLoginLog + reporting views.';
GO

PRINT 'Auditing setup completed. Next: run the trigger script and auditing_testcases.sql.';
GO

-- 09_audit_triggers.sql
-- Green Acres Realty Sdn Bhd - EMS Database Security
-- Purpose:
--   Create one set-based history trigger for each important table.
--   Every changed row produces one AuditLog row containing the
--   original login, time, application, host and before/after JSON.
-- Run after:
--   1. Compiled SQL file.sql
--   2. 08_auditing.sql
-- Security note:
--   The SystemUsers trigger lists its columns EXPLICITLY (never i.* / d.*)
--   so that no credential column can ever be copied into the audit log -
--   not the legacy PasswordHash/PasswordSalt, and not the current
--   PasswordHashSecure/PasswordSaltSecure either. An audit trail that
--   contains password material is a credential store with weaker
--   protection than the table it came from.

USE GreenAcresEMS;
GO

IF OBJECT_ID('dbo.AuditLog', 'U') IS NULL
    THROW 50010, 'dbo.AuditLog is missing. Run 08_auditing.sql first.', 1;
GO


/* ========================================================================
   REQUIREMENT 11: TRIGGER (AUDITING & OPERATIONAL)
   ======================================================================== */
CREATE OR ALTER TRIGGER dbo.trg_Clients_Audit
ON dbo.Clients
WITH EXECUTE AS OWNER
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             OldValues, NewValues, ApplicationName, HostName)
        SELECT
            'Clients', 'UPDATE', CONVERT(NVARCHAR(50), i.ClientID),
            ORIGINAL_LOGIN(),
            (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM inserted AS i
        INNER JOIN deleted AS d ON d.ClientID = i.ClientID;
    END
    ELSE IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             NewValues, ApplicationName, HostName)
        SELECT
            'Clients', 'INSERT', CONVERT(NVARCHAR(50), i.ClientID),
            ORIGINAL_LOGIN(),
            (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM inserted AS i;
    END
    ELSE
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             OldValues, ApplicationName, HostName)
        SELECT
            'Clients', 'DELETE', CONVERT(NVARCHAR(50), d.ClientID),
            ORIGINAL_LOGIN(),
            (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM deleted AS d;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_Agents_Audit
ON dbo.Agents
WITH EXECUTE AS OWNER
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             OldValues, NewValues, ApplicationName, HostName)
        SELECT
            'Agents', 'UPDATE', CONVERT(NVARCHAR(50), i.AgentID),
            ORIGINAL_LOGIN(),
            (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM inserted AS i
        INNER JOIN deleted AS d ON d.AgentID = i.AgentID;
    END
    ELSE IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             NewValues, ApplicationName, HostName)
        SELECT
            'Agents', 'INSERT', CONVERT(NVARCHAR(50), i.AgentID),
            ORIGINAL_LOGIN(),
            (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM inserted AS i;
    END
    ELSE
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             OldValues, ApplicationName, HostName)
        SELECT
            'Agents', 'DELETE', CONVERT(NVARCHAR(50), d.AgentID),
            ORIGINAL_LOGIN(),
            (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM deleted AS d;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_Transactions_Audit
ON dbo.Transactions
WITH EXECUTE AS OWNER
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             OldValues, NewValues, ApplicationName, HostName)
        SELECT
            'Transactions', 'UPDATE',
            CONVERT(NVARCHAR(50), i.TransactionID), ORIGINAL_LOGIN(),
            (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM inserted AS i
        INNER JOIN deleted AS d ON d.TransactionID = i.TransactionID;
    END
    ELSE IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             NewValues, ApplicationName, HostName)
        SELECT
            'Transactions', 'INSERT',
            CONVERT(NVARCHAR(50), i.TransactionID), ORIGINAL_LOGIN(),
            (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM inserted AS i;
    END
    ELSE
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             OldValues, ApplicationName, HostName)
        SELECT
            'Transactions', 'DELETE',
            CONVERT(NVARCHAR(50), d.TransactionID), ORIGINAL_LOGIN(),
            (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM deleted AS d;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_LeaseAgreements_Audit
ON dbo.LeaseAgreements
WITH EXECUTE AS OWNER
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             OldValues, NewValues, ApplicationName, HostName)
        SELECT
            'LeaseAgreements', 'UPDATE',
            CONVERT(NVARCHAR(50), i.LeaseID), ORIGINAL_LOGIN(),
            (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM inserted AS i
        INNER JOIN deleted AS d ON d.LeaseID = i.LeaseID;
    END
    ELSE IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             NewValues, ApplicationName, HostName)
        SELECT
            'LeaseAgreements', 'INSERT',
            CONVERT(NVARCHAR(50), i.LeaseID), ORIGINAL_LOGIN(),
            (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM inserted AS i;
    END
    ELSE
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             OldValues, ApplicationName, HostName)
        SELECT
            'LeaseAgreements', 'DELETE',
            CONVERT(NVARCHAR(50), d.LeaseID), ORIGINAL_LOGIN(),
            (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM deleted AS d;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_CommissionPayments_Audit
ON dbo.CommissionPayments
WITH EXECUTE AS OWNER
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             OldValues, NewValues, ApplicationName, HostName)
        SELECT
            'CommissionPayments', 'UPDATE',
            CONVERT(NVARCHAR(50), i.CommissionID), ORIGINAL_LOGIN(),
            (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM inserted AS i
        INNER JOIN deleted AS d ON d.CommissionID = i.CommissionID;
    END
    ELSE IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             NewValues, ApplicationName, HostName)
        SELECT
            'CommissionPayments', 'INSERT',
            CONVERT(NVARCHAR(50), i.CommissionID), ORIGINAL_LOGIN(),
            (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM inserted AS i;
    END
    ELSE
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             OldValues, ApplicationName, HostName)
        SELECT
            'CommissionPayments', 'DELETE',
            CONVERT(NVARCHAR(50), d.CommissionID), ORIGINAL_LOGIN(),
            (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM deleted AS d;
    END;
END;
GO

-- Columns are listed one by one on purpose: every credential column
-- (PasswordHashSecure, PasswordSaltSecure, PasswordHashAlgorithm) is
-- deliberately excluded so hashes and salts never reach dbo.AuditLog.
CREATE OR ALTER TRIGGER dbo.trg_SystemUsers_Audit
ON dbo.SystemUsers
WITH EXECUTE AS OWNER
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             OldValues, NewValues, ApplicationName, HostName)
        SELECT
            'SystemUsers', 'UPDATE',
            CONVERT(NVARCHAR(50), i.SystemUserID), ORIGINAL_LOGIN(),
            (
                SELECT d.SystemUserID, d.DepartmentID, d.FullName,
                       d.LoginName, d.Email, d.UserRole, d.IsActive,
                       d.CreatedDate
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ),
            (
                SELECT i.SystemUserID, i.DepartmentID, i.FullName,
                       i.LoginName, i.Email, i.UserRole, i.IsActive,
                       i.CreatedDate
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ),
            APP_NAME(), HOST_NAME()
        FROM inserted AS i
        INNER JOIN deleted AS d ON d.SystemUserID = i.SystemUserID;
    END
    ELSE IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             NewValues, ApplicationName, HostName)
        SELECT
            'SystemUsers', 'INSERT',
            CONVERT(NVARCHAR(50), i.SystemUserID), ORIGINAL_LOGIN(),
            (
                SELECT i.SystemUserID, i.DepartmentID, i.FullName,
                       i.LoginName, i.Email, i.UserRole, i.IsActive,
                       i.CreatedDate
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ),
            APP_NAME(), HOST_NAME()
        FROM inserted AS i;
    END
    ELSE
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             OldValues, ApplicationName, HostName)
        SELECT
            'SystemUsers', 'DELETE',
            CONVERT(NVARCHAR(50), d.SystemUserID), ORIGINAL_LOGIN(),
            (
                SELECT d.SystemUserID, d.DepartmentID, d.FullName,
                       d.LoginName, d.Email, d.UserRole, d.IsActive,
                       d.CreatedDate
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ),
            APP_NAME(), HOST_NAME()
        FROM deleted AS d;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_MaintenanceRequests_Audit
ON dbo.MaintenanceRequests
WITH EXECUTE AS OWNER
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             OldValues, NewValues, ApplicationName, HostName)
        SELECT
            'MaintenanceRequests', 'UPDATE',
            CONVERT(NVARCHAR(50), i.RequestID), ORIGINAL_LOGIN(),
            (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM inserted AS i
        INNER JOIN deleted AS d ON d.RequestID = i.RequestID;
    END
    ELSE IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             NewValues, ApplicationName, HostName)
        SELECT
            'MaintenanceRequests', 'INSERT',
            CONVERT(NVARCHAR(50), i.RequestID), ORIGINAL_LOGIN(),
            (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM inserted AS i;
    END
    ELSE
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             OldValues, ApplicationName, HostName)
        SELECT
            'MaintenanceRequests', 'DELETE',
            CONVERT(NVARCHAR(50), d.RequestID), ORIGINAL_LOGIN(),
            (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM deleted AS d;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_Properties_Audit
ON dbo.Properties
WITH EXECUTE AS OWNER
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             OldValues, NewValues, ApplicationName, HostName)
        SELECT
            'Properties', 'UPDATE',
            CONVERT(NVARCHAR(50), i.PropertyID), ORIGINAL_LOGIN(),
            (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM inserted AS i
        INNER JOIN deleted AS d ON d.PropertyID = i.PropertyID;
    END
    ELSE IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             NewValues, ApplicationName, HostName)
        SELECT
            'Properties', 'INSERT',
            CONVERT(NVARCHAR(50), i.PropertyID), ORIGINAL_LOGIN(),
            (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM inserted AS i;
    END
    ELSE
    BEGIN
        INSERT dbo.AuditLog
            (TableName, OperationType, RecordID, ChangedBy,
             OldValues, ApplicationName, HostName)
        SELECT
            'Properties', 'DELETE',
            CONVERT(NVARCHAR(50), d.PropertyID), ORIGINAL_LOGIN(),
            (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            APP_NAME(), HOST_NAME()
        FROM deleted AS d;
    END;
END;
GO

SELECT
    tr.name AS TriggerName,
    OBJECT_SCHEMA_NAME(tr.parent_id) AS TableSchema,
    OBJECT_NAME(tr.parent_id) AS TableName,
    CASE WHEN tr.is_disabled = 0 THEN 'Enabled' ELSE 'Disabled' END AS Status
FROM sys.triggers AS tr
WHERE tr.name IN (
    'trg_Clients_Audit',
    'trg_Agents_Audit',
    'trg_Transactions_Audit',
    'trg_LeaseAgreements_Audit',
    'trg_CommissionPayments_Audit',
    'trg_SystemUsers_Audit',
    'trg_MaintenanceRequests_Audit',
    'trg_Properties_Audit'
)
ORDER BY TableName;
GO

PRINT 'Eight row-history audit triggers created successfully.';
GO



-- B1. New Transaction -> keep Property.Status in sync
--     'Sale' closes the property out as Sold; 'Rent' marks it
--     Rented. Saves every dev team from having to remember to
--     do this manually in application code.
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

-- B2. New Transaction -> auto-generate the CommissionPayments
--     row using the agent's current CommissionRate (snapshot),
--     so DBAs/finance don't have to insert it separately.
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

-- B3. Lease ends (Expired/Terminated) -> free up the Property
--     and notify the client. Only reverts status if no other
--     Active lease exists on the same property.
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

-- B4. Maintenance request marked Completed -> auto-stamp
--     CompletedDate and notify the requesting client.
--     Direct trigger recursion is off by default in SQL Server,
--     so the self-UPDATE below will not re-fire this trigger.
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

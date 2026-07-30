/* ========================================================================
   DML.sql - Green Acres Realty Sdn Bhd, Estate Management System (EMS)
   CT069-3-3 Database Security Assignment

   Data, operations and tests: seed load, encryption and hashing, backups,
   restore rehearsal, and all 77 test cases.

   RUN DDL.sql FIRST - every object used here is created there.
   Connect as sysadmin: the encryption step reads through Dynamic Data
   Masking, so a login without UNMASK would encrypt the masked value.

   Sections 1-3 run with the table triggers disabled, because DDL.sql
   creates them before this file loads any data - left on, the
   auto-commission trigger would double every commission row, the
   property-status trigger would overwrite the seeded Status values, and
   the audit triggers would bury the real evidence under ~500 rows.
   Section 4 switches them back on and proves the load was clean.
   ======================================================================== */

USE GreenAcresEMS;
GO


/* ========================================================================
   SECTION 1: BULK SEED LOAD
   Triggers are switched off for the duration of the load and the data
   protection steps (Sections 1 to 3), then switched back on in Section 4. See
   the note in the file header for exactly what would break otherwise.
   ======================================================================== */
ALTER TABLE dbo.Properties DISABLE TRIGGER ALL;
ALTER TABLE dbo.Clients DISABLE TRIGGER ALL;
ALTER TABLE dbo.Agents DISABLE TRIGGER ALL;
ALTER TABLE dbo.Transactions DISABLE TRIGGER ALL;
ALTER TABLE dbo.MaintenanceRequests DISABLE TRIGGER ALL;
ALTER TABLE dbo.SystemUsers DISABLE TRIGGER ALL;
ALTER TABLE dbo.LeaseAgreements DISABLE TRIGGER ALL;
ALTER TABLE dbo.CommissionPayments DISABLE TRIGGER ALL;
GO
-- Confirm every trigger on the seeded tables really is off before we load.
-- Expected: all 12 triggers listed as 'Disabled'.
SELECT
    tr.name                   AS TriggerName,
    OBJECT_NAME(tr.parent_id) AS TableName,
    CASE WHEN tr.is_disabled = 1 THEN 'Disabled' ELSE 'STILL ENABLED' END AS Status
FROM sys.triggers AS tr
WHERE tr.parent_class = 1
ORDER BY TableName, TriggerName;
GO

-- INSERTING VALUES residential, commercial, industrial and land properties.

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

-- Data includes individual and corporate clients for EMS testing, encryption,
-- masking and reporting.

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

-- including contact details, license numbers and commission rates for EMS
-- operational, reporting and security testing.

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

-- Added 50 realistic maintenance request records covering plumbing, electrical,
-- structural and facility maintenance.

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
  
-- representing operational, administrative and technical divisions used for EMS
-- user and role management.

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

-- 10. LeaseAgreements - Added realistic Malaysian lease agreement records
-- linked only to rental transactions from the Transactions table.

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

-- 11. CommissionPayments - linked to existing transactions and agents.

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

-- 12. MaintenanceStaff - covering in-house and contractor-based maintenance
-- teams.

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
GO

/* ========================================================================
   SECTION 2: DATA PROTECTION LOAD - ENCRYPTION
   The ciphertext columns themselves were created by DDL.sql; this is where they
   are populated from the plain values Section 1 just loaded.
   ======================================================================== */
-- Populate the ciphertext columns from the existing plain values.
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

-- The encrypted lease-document path.
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

-- Proof the load worked: ciphertext present on every row.
-- Expected: 50 encrypted rows for Clients, 17 for LeaseAgreements.
SELECT
    'Clients' AS TableName,
    COUNT(*)  AS TotalRows,
    SUM(CASE WHEN NRIC_Encrypted          IS NOT NULL THEN 1 ELSE 0 END) AS NRIC_Enc,
    SUM(CASE WHEN ContactNumber_Encrypted IS NOT NULL THEN 1 ELSE 0 END) AS Contact_Enc,
    SUM(CASE WHEN Email_Encrypted         IS NOT NULL THEN 1 ELSE 0 END) AS Email_Enc,
    SUM(CASE WHEN Address_Encrypted       IS NOT NULL THEN 1 ELSE 0 END) AS Address_Enc
FROM dbo.Clients
UNION ALL
SELECT
    'LeaseAgreements',
    COUNT(*),
    SUM(CASE WHEN AgreementDocPath_Encrypted IS NOT NULL THEN 1 ELSE 0 END),
    NULL, NULL, NULL
FROM dbo.LeaseAgreements;
GO


/* ========================================================================
   SECTION 3: CREDENTIAL LOAD - SALTS AND PASSWORD HASHES
   A fresh 32-byte cryptographic salt per account, then a SHA2_512 hash of the
   onboarding password combined with that salt.
   ======================================================================== */
UPDATE dbo.SystemUsers
SET PasswordSaltSecure = CRYPT_GEN_RANDOM(32)
WHERE PasswordSaltSecure IS NULL;
GO


-- Every account is seeded with the SAME temporary password and is expected to
-- change it at first login (the PasswordMustChange column, added by DDL.sql, is
-- what enforces this).
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

-- Proof: no readable password anywhere, and every account has its own salt.
SELECT
    COUNT(*)                            AS TotalAccounts,
    COUNT(DISTINCT PasswordSaltSecure)  AS DistinctSalts,
    COUNT(DISTINCT PasswordHashSecure)  AS DistinctHashes,
    MIN(DATALENGTH(PasswordSaltSecure)) AS SaltBytes,
    MIN(DATALENGTH(PasswordHashSecure)) AS HashBytes,
    SUM(CASE WHEN PasswordMustChange = 1 THEN 1 ELSE 0 END) AS AwaitingFirstReset
FROM dbo.SystemUsers;
GO


/* ========================================================================
   SECTION 4: RE-ENABLE THE TRIGGERS
   From this point on the database behaves exactly as it will in production:
   every INSERT, UPDATE and DELETE on a sensitive table is captured in
   dbo.AuditLog, and the operational triggers maintain property status,
   commissions and notifications automatically.
   ======================================================================== */
ALTER TABLE dbo.Properties ENABLE TRIGGER ALL;
ALTER TABLE dbo.Clients ENABLE TRIGGER ALL;
ALTER TABLE dbo.Agents ENABLE TRIGGER ALL;
ALTER TABLE dbo.Transactions ENABLE TRIGGER ALL;
ALTER TABLE dbo.MaintenanceRequests ENABLE TRIGGER ALL;
ALTER TABLE dbo.SystemUsers ENABLE TRIGGER ALL;
ALTER TABLE dbo.LeaseAgreements ENABLE TRIGGER ALL;
ALTER TABLE dbo.CommissionPayments ENABLE TRIGGER ALL;
GO
-- Expected: all 12 triggers 'Enabled'.
SELECT
    tr.name                   AS TriggerName,
    OBJECT_NAME(tr.parent_id) AS TableName,
    CASE WHEN tr.is_disabled = 0 THEN 'Enabled' ELSE 'STILL DISABLED' END AS Status
FROM sys.triggers AS tr
WHERE tr.parent_class = 1
ORDER BY TableName, TriggerName;
GO

-- The seed load must NOT have produced audit rows - that is the whole reason
-- the triggers were disabled.
SELECT COUNT(*) AS AuditRowsFromSeedLoad_ShouldBeZero FROM dbo.AuditLog;
GO

-- Commission data must come only from the seed file, not from the auto-
-- commission trigger firing during the load.
-- Expected: TransactionsWithCommission = 50, DuplicateCommissions = 0.
SELECT
    (SELECT COUNT(DISTINCT TransactionID) FROM dbo.CommissionPayments) AS TransactionsWithCommission,
    (SELECT COUNT(*) FROM (
        SELECT TransactionID
        FROM dbo.CommissionPayments
        GROUP BY TransactionID
        HAVING COUNT(*) > 1
     ) AS dupes) AS DuplicateCommissions;
GO


/* ========================================================================
   SECTION 5: BACKUP AND RECOVERY OPERATIONS
   Backups act on data, not on structure, so they belong in this file - and they
   must run AFTER the load, or the .bak would capture an empty database.
   ======================================================================== */

USE master;
GO

-- Create the backup directory on disk (requires xp_cmdshell OR do this manually
-- in Windows Explorer).
EXEC master.dbo.xp_create_subdir 'C:\EMS_Backups';
GO

-- Separate folder for key material.
EXEC master.dbo.xp_create_subdir 'C:\EMS_Backups\Keys';
GO


/* ========================================================================
   REQUIREMENT 8 (part 1): BACKING UP THE KEY MATERIAL
   Restore the .bak on another instance without the certificate and every
   encrypted column is permanently unreadable, so the certificate, its private
   key and the database master key are exported too - and must be stored
   separately from the .bak files.

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
   Captures only what changed since the last FULL backup, so the daily window
   stays short.
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
   An untested backup is only a hope.
   ======================================================================== */
USE master;
GO

-- Discover where this instance keeps its data files, so the MOVE below works on
-- any machine instead of a hard-coded C:\Program Files\...
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

-- Step 1 of 3: restore the FULL backup, leaving the copy offline (NORECOVERY)
-- so the differential can follow.
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

-- Step 2 of 3: apply the DIFFERENTIAL, still NORECOVERY.
RESTORE DATABASE GreenAcresEMS_Restore
FROM DISK = 'C:\EMS_Backups\GreenAcresEMS_DIFF.bak'
WITH NORECOVERY, STATS = 10;
GO

-- Step 3 of 3: apply the LOG and bring the database online.
RESTORE LOG GreenAcresEMS_Restore
FROM DISK = 'C:\EMS_Backups\GreenAcresEMS_LOG.trn'
WITH RECOVERY, STATS = 10;
GO

PRINT 'Restore rehearsal complete: GreenAcresEMS_Restore is online.';
GO

-- Post-restore verification: does the recovered copy actually hold the data?
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
SELECT TOP 3
    ClientID,
    FullName,
    NRIC_Encrypted AS StillEncryptedAfterRestore
FROM GreenAcresEMS_Restore.dbo.Clients;
GO


/* ========================================================================
   POINT-IN-TIME RECOVERY (the "someone deleted the wrong rows" scenario)
   FULL recovery model plus log backups let us roll forward to a specific
   second, stopping just before a mistake; documented rather than executed
   because STOPAT needs a real timestamp and step 3 takes the live database
   offline. Run one block at a time.

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
   ======================================================================== */

-- COPY_ONLY backup: an ad-hoc backup (before a risky deployment, say) that does
-- NOT reset the differential base, so the scheduled backup chain above keeps
-- working normally.
BACKUP DATABASE GreenAcresEMS
TO DISK = 'C:\EMS_Backups\GreenAcresEMS_COPYONLY.bak'
WITH COPY_ONLY, INIT, CHECKSUM, COMPRESSION,
     NAME = 'GreenAcresEMS-Ad-hoc copy-only backup',
     DESCRIPTION = 'Taken before a change; does not break the differential chain';
GO

-- Corruption watch: this table should always be EMPTY.
SELECT * FROM msdb.dbo.suspect_pages;
GO

-- Confirm the recovery model is still FULL.
SELECT
    name             AS DatabaseName,
    recovery_model_desc,
    log_reuse_wait_desc
FROM sys.databases
WHERE name IN ('GreenAcresEMS', 'GreenAcresEMS_Restore');
GO


PRINT 'Backup and recovery objects/steps set up successfully.';
GO

/* ========================================================================
   SECTION 6: BUILD VERIFICATION QUERIES
   Screenshot-friendly confirmation that the objects DDL.sql created are present
   and switched on.
   ======================================================================== */

USE GreenAcresEMS;
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

-- The eight row-history audit triggers.
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

-- Full object inventory, one row per object type, for the report.
SELECT 'Tables'            AS ObjectType, COUNT(*) AS Total FROM sys.tables
UNION ALL SELECT 'Views',                 COUNT(*) FROM sys.views
UNION ALL SELECT 'Stored Procedures',     COUNT(*) FROM sys.procedures
UNION ALL SELECT 'Table Triggers',        COUNT(*) FROM sys.triggers WHERE parent_class = 1
UNION ALL SELECT 'Database Roles',        COUNT(*) FROM sys.database_principals WHERE type = 'R' AND name LIKE 'role[_]%'
UNION ALL SELECT 'Masked Columns',        COUNT(*) FROM sys.masked_columns
UNION ALL SELECT 'Symmetric Keys',        COUNT(*) FROM sys.symmetric_keys WHERE name NOT LIKE '##%'
UNION ALL SELECT 'Certificates',          COUNT(*) FROM sys.certificates;
GO

PRINT 'Data load, protection, backup and verification complete.';
PRINT 'Section 7 below runs the full test suite.';
GO


/* ========================================================================
   SECTION 7: TEST SUITE
   77 test cases in six blocks.
   ======================================================================== */

USE GreenAcresEMS;
GO


/* ========================================================================
   SECTION A: AUDITING & OPERATIONAL TRIGGERS
   Member: Sarvein Goal: Prove the audit triggers (log every
   INSERT/UPDATE/DELETE) and the operational triggers (auto-update statuses,
   auto-create commission/notification rows) work correctly.
   ======================================================================== */

-- A1: INSERT audit test - insert a new Client.
-- Expected: a new AuditLog row with OperationType 'INSERT', NewValues filled
-- in and OldValues NULL.
INSERT INTO dbo.Clients (FullName, NRIC, ContactNumber, Email, Address, ClientType)
VALUES ('Test Trigger Client', '999999999999', '0100000000', 'test.trigger@example.com', 'Test Address', 'Individual');

DECLARE @TestClientID INT = SCOPE_IDENTITY();

SELECT TOP 1 * FROM dbo.AuditLog
WHERE TableName = 'Clients' AND OperationType = 'INSERT' AND RecordID = CAST(@TestClientID AS NVARCHAR(50))
ORDER BY AuditID DESC;
GO


-- A2: UPDATE audit test - update the Email of the Client from A1.
-- Expected: an AuditLog row with OperationType 'UPDATE', OldValues showing the
-- previous email and NewValues the new one.
DECLARE @TestClientID INT = (SELECT TOP 1 ClientID FROM dbo.Clients WHERE FullName = 'Test Trigger Client');

UPDATE dbo.Clients
SET Email = 'updated.trigger@example.com'
WHERE ClientID = @TestClientID;

SELECT TOP 1 * FROM dbo.AuditLog
WHERE TableName = 'Clients' AND OperationType = 'UPDATE' AND RecordID = CAST(@TestClientID AS NVARCHAR(50))
ORDER BY AuditID DESC;
GO


-- A3: DELETE audit test - delete the test Client.
-- Expected: an AuditLog row with OperationType 'DELETE', OldValues filled in
-- and NewValues NULL.
DECLARE @TestClientID INT = (SELECT TOP 1 ClientID FROM dbo.Clients WHERE FullName = 'Test Trigger Client');

DELETE FROM dbo.Clients WHERE ClientID = @TestClientID;

SELECT TOP 1 * FROM dbo.AuditLog
WHERE TableName = 'Clients' AND OperationType = 'DELETE' AND RecordID = CAST(@TestClientID AS NVARCHAR(50))
ORDER BY AuditID DESC;
GO


-- A4: Multi-row audit test - one UPDATE touching many Agent rows.
-- Expected: one AuditLog row PER row changed, not one for the statement -
-- AgentsUpdated should equal AuditRowsAdded and Result should say PASS.
DECLARE @BeforeCount INT = (SELECT COUNT(*) FROM dbo.AuditLog WHERE TableName = 'Agents' AND OperationType = 'UPDATE');
DECLARE @AffectedRows INT = (SELECT COUNT(*) FROM dbo.Agents WHERE CommissionRate < 2.00);

UPDATE dbo.Agents SET CommissionRate = CommissionRate  -- no real change, just enough to fire the trigger
WHERE CommissionRate < 2.00;

DECLARE @AfterCount INT = (SELECT COUNT(*) FROM dbo.AuditLog WHERE TableName = 'Agents' AND OperationType = 'UPDATE');

SELECT @AffectedRows AS AgentsUpdated, (@AfterCount - @BeforeCount) AS AuditRowsAdded,
       CASE WHEN @AffectedRows = (@AfterCount - @BeforeCount) THEN 'PASS' ELSE 'FAIL' END AS Result;
GO


-- A5: Operational trigger - a 'Sale' transaction marks the Property Sold.
-- Expected: that Property's Status automatically becomes 'Sold'.
DECLARE @PropID INT = (SELECT TOP 1 PropertyID FROM dbo.Properties WHERE Status = 'Available');
DECLARE @ClientID INT = (SELECT TOP 1 ClientID FROM dbo.Clients);
DECLARE @AgentID INT = (SELECT TOP 1 AgentID FROM dbo.Agents);

INSERT INTO dbo.Transactions (PropertyID, ClientID, AgentID, TransactionType, Amount, PaymentStatus)
VALUES (@PropID, @ClientID, @AgentID, 'Sale', 500000.00, 'Completed');

SELECT PropertyID, Status FROM dbo.Properties WHERE PropertyID = @PropID;
-- Expected Status = 'Sold'
GO


-- A6: Operational trigger - a Transaction auto-creates its Commission row.
-- Expected: a matching CommissionPayments row exists with CommissionAmount =
-- Amount x the agent's rate / 100, and Result says PASS.
DECLARE @LastTransID INT = (SELECT MAX(TransactionID) FROM dbo.Transactions);

SELECT t.TransactionID, t.Amount, a.CommissionRate, cp.CommissionAmount,
       ROUND(t.Amount * a.CommissionRate / 100.0, 2) AS ExpectedAmount,
       CASE WHEN cp.CommissionAmount = ROUND(t.Amount * a.CommissionRate / 100.0, 2)
            THEN 'PASS' ELSE 'FAIL' END AS Result
FROM dbo.Transactions t
JOIN dbo.Agents a ON a.AgentID = t.AgentID
JOIN dbo.CommissionPayments cp ON cp.TransactionID = t.TransactionID
WHERE t.TransactionID = @LastTransID;
GO


-- A7: Operational trigger - terminating a Lease frees up the Property.
-- Expected: the linked Property returns to 'Available' unless it was already
-- Sold, and exactly 1 new Notification is created.
DECLARE @LeaseID INT = (SELECT TOP 1 LeaseID FROM dbo.LeaseAgreements WHERE LeaseStatus = 'Active');
DECLARE @LeasePropID INT = (SELECT PropertyID FROM dbo.LeaseAgreements WHERE LeaseID = @LeaseID);
DECLARE @NotifCountBefore INT = (SELECT COUNT(*) FROM dbo.Notifications WHERE RelatedTable = 'LeaseAgreements' AND RelatedRecordID = @LeaseID);

UPDATE dbo.LeaseAgreements SET LeaseStatus = 'Terminated' WHERE LeaseID = @LeaseID;

SELECT
    (SELECT Status FROM dbo.Properties WHERE PropertyID = @LeasePropID) AS PropertyStatusAfter,
    (SELECT COUNT(*) FROM dbo.Notifications WHERE RelatedTable = 'LeaseAgreements' AND RelatedRecordID = @LeaseID) - @NotifCountBefore AS NewNotifications;
-- Expected: PropertyStatusAfter = 'Available' (unless it was 'Sold'),
-- NewNotifications = 1
GO


-- A8: Operational trigger - completing a MaintenanceRequest stamps the date.
-- Expected: CompletedDate is filled in automatically and 1 new Notification is
-- created.
DECLARE @ReqID INT = (
    SELECT TOP 1 RequestID FROM dbo.MaintenanceRequests
    WHERE Status <> 'Completed' AND RequestedByClientID IS NOT NULL
);

IF @ReqID IS NOT NULL
BEGIN
    DECLARE @NotifCountBefore2 INT = (SELECT COUNT(*) FROM dbo.Notifications WHERE RelatedTable = 'MaintenanceRequests' AND RelatedRecordID = @ReqID);

    UPDATE dbo.MaintenanceRequests SET Status = 'Completed' WHERE RequestID = @ReqID;

    SELECT RequestID, Status, CompletedDate,
           (SELECT COUNT(*) FROM dbo.Notifications WHERE RelatedTable = 'MaintenanceRequests' AND RelatedRecordID = @ReqID) - @NotifCountBefore2 AS NewNotifications
    FROM dbo.MaintenanceRequests WHERE RequestID = @ReqID;
END
ELSE
    PRINT 'No eligible MaintenanceRequests row found (all completed or none with a client) - skip test.';
GO


-- A9: Masking and encryption do not break the audit trigger.
-- Expected: NewValues still captures the encrypted column as Base64 with no
-- error, because the trigger runs WITH EXECUTE AS OWNER.
INSERT INTO dbo.Clients (FullName, NRIC, ContactNumber, Email, Address, ClientType)
VALUES ('Masking Test Client', '888888888888', '0111111111', 'masking.test@example.com', 'Masking Test Address', 'Individual');

SELECT TOP 1 NewValues FROM dbo.AuditLog
WHERE TableName = 'Clients' AND OperationType = 'INSERT'
ORDER BY AuditID DESC;

-- cleanup so this test can be re-run safely
DELETE FROM dbo.Clients WHERE FullName = 'Masking Test Client';
GO


-- A10: Summary - everything the audit log has captured so far
SELECT TableName, OperationType, COUNT(*) AS EventCount
FROM dbo.AuditLog
GROUP BY TableName, OperationType
ORDER BY TableName, OperationType;
GO


/* ========================================================================
   SECTION B: DATA PROTECTION (MASKING / ENCRYPTION / HASHING)
   Member: Irfan Goal: Prove that sensitive data is masked for normal users,
   properly encrypted at rest, and passwords are stored as salted hashes instead
   of plain text.
   ======================================================================== */

-- B1: List every masked column that was set up
-- Expected: One row per masked column across all the listed tables.
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


-- B2: Confirm encrypted Client columns look unreadable
-- Expected: The *_Encrypted columns show random binary bytes, not the plain
-- NRIC/ContactNumber/Email/Address values.
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


-- B3: Decrypt Client data using the symmetric key
-- Expected: Once the key is opened, the Decrypted* columns show the original
-- readable values again.
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


-- B4: Confirm the lease document path is encrypted
-- Expected: AgreementDocPath_Encrypted shows binary, not the plain path.
SELECT TOP 10
    LeaseID,
    TransactionID,
    AgreementDocPath,
    AgreementDocPath_Encrypted
FROM dbo.LeaseAgreements;
GO


-- B5: Decrypt the lease document path
-- Expected: DecryptedAgreementDocPath matches the original plain path.
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


-- B6: Confirm passwords are never stored as plain text
-- Expected: PasswordSaltSecure and PasswordHashSecure show unreadable binary
-- values, never the actual password.
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


-- B7: Update a password and verify login works correctly
-- Expected: Correct password -> "Login Successful".
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


-- B8: Final summary - which data protection features actually exist
-- Expected: Every SecurityFeature row shows a count greater than 0.
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


-- B9: The old, weaker credential columns are GONE
-- Expected: 0 rows. PasswordHash (SHA2_256) and PasswordSalt (plain-text salt)
-- were dropped once the salted SHA2_512 columns took over, so there is no
-- second, weaker credential store left to attack.
SELECT name AS LegacyCredentialColumnStillPresent
FROM sys.columns
WHERE object_id = OBJECT_ID('dbo.SystemUsers')
  AND name IN ('PasswordHash', 'PasswordSalt');
GO


-- B10: Controlled decryption THROUGH the stored procedure
-- Expected: Readable NRIC / ContactNumber / Email / Address for ClientID 1. The
-- procedure is WITH EXECUTE AS OWNER, so it - not the caller - opens the
-- symmetric key.
EXEC dbo.usp_GetClientSensitiveData
    @ClientID = 1,
    @Reason   = 'Test case B10 - verifying controlled decryption path';
GO

-- The access itself is audit evidence: this call must appear in AuditLog as a
-- SELECT/DECRYPT_READ event naming the real login.
-- Expected: at least one row, ChangedBy = your login, and the NewValues JSON
-- contains "DECRYPT_READ" plus the reason.
SELECT TOP 5
    AuditID, EventTime, TableName, OperationType,
    RecordID, ChangedBy, NewValues
FROM dbo.AuditLog
WHERE TableName = 'Clients'
  AND OperationType = 'SELECT'
ORDER BY AuditID DESC;
GO


-- B11: Decrypting the lease document path through its procedure
-- Expected: The readable 'docs/leases/LA-TR002.pdf' style path.
DECLARE @AnyLeaseID INT = (SELECT MIN(LeaseID) FROM dbo.LeaseAgreements);
EXEC dbo.usp_GetLeaseDocumentPath @LeaseID = @AnyLeaseID;
GO


-- B12: A developer role CANNOT reach the decryption door
-- Expected: 'PASS' for both.
EXECUTE AS USER = 'vijay.menon';
    BEGIN TRY
        EXEC dbo.usp_GetClientSensitiveData @ClientID = 1;
        PRINT 'FAIL: ClientPortalDev decrypted client PII.';
    END TRY
    BEGIN CATCH
        PRINT 'PASS: Decryption procedure denied -> ' + ERROR_MESSAGE();
    END CATCH;
REVERT;
GO

EXECUTE AS USER = 'vijay.menon';
    BEGIN TRY
        OPEN SYMMETRIC KEY EMS_ClientDataSymmetricKey
            DECRYPTION BY CERTIFICATE EMS_DataProtectionCertificate;
        PRINT 'FAIL: ClientPortalDev opened the symmetric key directly.';
        CLOSE SYMMETRIC KEY EMS_ClientDataSymmetricKey;
    END TRY
    BEGIN CATCH
        PRINT 'PASS: Key access denied -> ' + ERROR_MESSAGE();
    END CATCH;
REVERT;
GO


-- B13: New data added later is encrypted too
-- Expected: The new client starts with NULL ciphertext, and after
-- usp_EncryptClientPII the ciphertext columns are populated.
EXEC dbo.usp_ManageClient
    @FullName      = 'B13 Encryption Coverage Test',
    @NRIC          = '900101101234',
    @ContactNumber = '012-3330000',
    @Email         = 'b13.test@example.com',
    @Address       = 'Test Address, Kuala Lumpur';
GO

DECLARE @NewClientID INT =
    (SELECT MAX(ClientID) FROM dbo.Clients
     WHERE FullName = 'B13 Encryption Coverage Test');

SELECT 'Before' AS Stage, ClientID, FullName, NRIC_Encrypted
FROM dbo.Clients WHERE ClientID = @NewClientID;

EXEC dbo.usp_EncryptClientPII @ClientID = @NewClientID;

SELECT 'After' AS Stage, ClientID, FullName, NRIC_Encrypted
FROM dbo.Clients WHERE ClientID = @NewClientID;

-- Tidy up so repeated runs do not pile up test rows.
DELETE FROM dbo.Clients WHERE ClientID = @NewClientID;
GO


-- B14: The masking limit we documented, proved
-- Expected: MaskedRead shows a masked/random value while RealTotal returns a
-- genuine figure.
EXECUTE AS USER = 'jason.lim';          -- role_ReadOnly, no UNMASK
    SELECT TOP 3
        'MaskedRead' AS TestPart,
        MonthlyRent  AS MaskedValue
    FROM vw_ActiveLeases;
REVERT;
GO

EXECUTE AS USER = 'nurul.huda';         -- role_ReadOnly, no UNMASK
    BEGIN TRY
        SELECT 'RealTotal' AS TestPart,
               SUM(MonthlyRent) AS AggregateOverMaskedColumn
        FROM vw_ActiveLeases;
    END TRY
    BEGIN CATCH
        PRINT 'Aggregate blocked -> ' + ERROR_MESSAGE();
    END CATCH;
REVERT;
GO


-- B15: Analyst UNMASK is explicit and column-level (SQL 2022+)
-- Expected: On SQL Server 2022 or newer, role_Analyst holds UNMASK on financial
-- columns ONLY - never on a PII column.
SELECT
    dp.permission_name,
    OBJECT_NAME(dp.major_id) AS TableName,
    c.name                   AS ColumnName,
    pr.name                  AS GrantedTo
FROM sys.database_permissions AS dp
JOIN sys.database_principals AS pr ON pr.principal_id = dp.grantee_principal_id
LEFT JOIN sys.columns AS c
       ON c.object_id = dp.major_id
      AND c.column_id = dp.minor_id
WHERE dp.permission_name = 'UNMASK'
ORDER BY pr.name, TableName, ColumnName;
GO


/* ========================================================================
   SECTION C: ACCESS CONTROL (ROLES / USERS / VIEWS / PROCEDURES)
   Member: Rama Goal: Prove that each database role only has the permissions it
   should have - no more, no less (principle of least privilege).
   ======================================================================== */

-- C1: Confirm all roles exist and have members
-- Expected: 6 roles listed (role_...), each with at least 1 member.
SELECT r.name AS RoleName, m.name AS MemberName
FROM sys.database_role_members rm
JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
JOIN sys.database_principals m ON m.principal_id = rm.member_principal_id
WHERE r.name LIKE 'role_%'
ORDER BY RoleName, MemberName;
GO


-- C2: Confirm every SystemUsers.UserRole has a matching database role
-- Expected: RoleStatus = 'EXISTS' for every distinct UserRole value.
SELECT DISTINCT
    su.UserRole,
    'role_' + su.UserRole AS ExpectedRoleName,
    CASE WHEN dp.name IS NOT NULL THEN 'EXISTS' ELSE 'MISSING' END AS RoleStatus
FROM dbo.SystemUsers su
LEFT JOIN sys.database_principals dp
    ON dp.name = 'role_' + su.UserRole
    AND dp.type = 'R';
GO


-- C3: role_ReadOnly CAN read a safe view
-- Expected: Rows returned successfully from vw_PropertyListing.
EXECUTE AS USER = 'jason.lim';          -- jason.lim is in role_ReadOnly
    SELECT TOP 5 PropertyID, PropertyName, City, Status
    FROM vw_PropertyListing;
REVERT;
GO


-- C4: role_ReadOnly is BLOCKED from a sensitive base table
-- Expected: Permission denied error (this proves least privilege works).
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


-- C5: role_Analyst sees MASKED personal data (linked to Irfan's masking)
-- Expected: hakim.zulkifli (no UNMASK permission) sees masked NRIC,
-- ContactNumber and Email values, not the real ones.
EXECUTE AS USER = 'hakim.zulkifli';    -- role_Analyst
    SELECT TOP 5 ClientID, FullName, NRIC, ContactNumber, Email
    FROM vw_ClientDirectory;
REVERT;
GO


-- C6: role_Admin sees UNMASKED personal data (UNMASK permission granted)
-- Expected: farid.rahman sees the real NRIC and Email values.
EXECUTE AS USER = 'farid.rahman';      -- role_Admin
    SELECT TOP 5 ClientID, FullName, NRIC, Email
    FROM dbo.Clients;
REVERT;
GO


-- C7: role_DBA has full access, including unmasked data
-- Expected: arun.kumar sees real values in both Clients and CommissionPayments.
EXECUTE AS USER = 'arun.kumar';        -- role_DBA
    SELECT TOP 5 ClientID, FullName, NRIC, Email FROM dbo.Clients;
    SELECT TOP 3 CommissionID, CommissionAmount FROM dbo.CommissionPayments;
REVERT;
GO


-- C8: role_PropMgmtDev can insert a property THROUGH the procedure
-- Expected: usp_ManageProperty runs successfully.
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


-- C9: role_PropMgmtDev is BLOCKED from writing directly to CommissionPayments
-- Expected: Direct INSERT is denied (they must go through approved procedures
-- only).
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


-- C10: role_ClientPortalDev can create a client THROUGH the procedure
-- Expected: New client row is inserted successfully.
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


-- C11: Stored procedure rejects bad input
-- Expected: usp_UpdatePropertyStatus raises an error for a status value that
-- isn't allowed (e.g.
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


-- C12: role_Analyst can read reporting/summary views
-- Expected: Both views return data rows successfully.
EXECUTE AS USER = 'hakim.zulkifli';   -- role_Analyst
    SELECT * FROM vw_MonthlySalesSummary;
    SELECT TOP 5 AgentName, TotalSales, TotalTransactionValue
    FROM vw_AgentPerformance
    ORDER BY TotalTransactionValue DESC;
REVERT;
GO


-- C13: role_Analyst CANNOT run a write procedure
-- Expected: EXECUTE permission on usp_ManageProperty is denied.
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


-- C14: usp_ProvisionUser successfully adds a new user
-- Expected: Login, database user, and role membership are all created.
EXEC dbo.usp_ProvisionUser
    @LoginName = 'test.newstaff',
    @Password  = 'Test@NewStaff#2026',
    @RoleName  = 'role_Analyst';
GO


-- C15: usp_DeprovisionUser successfully removes that user
-- Expected: test.newstaff is removed from roles, database user dropped, and
-- login dropped - nothing left behind.
EXEC dbo.usp_DeprovisionUser @LoginName = 'test.newstaff';
GO


-- C16: usp_ProvisionUser rejects a missing/NULL password
-- Expected: 'PASS: NULL parameter rejected -> ...' is printed.
BEGIN TRY
    EXEC dbo.usp_ProvisionUser
        @LoginName = 'test.incomplete',
        @Password  = NULL,             -- password not supplied on purpose
        @RoleName  = 'role_ReadOnly';
    PRINT 'FAIL: NULL parameter was accepted.';
END TRY
BEGIN CATCH
    PRINT 'PASS: NULL parameter rejected -> ' + ERROR_MESSAGE();
END CATCH;
GO


-- C17: usp_ProvisionUser resists SQL injection
-- Expected: 'PASS' - the login name is rejected by the character whitelist
-- before any dynamic SQL is built, and dbo.Clients is untouched.
DECLARE @ClientsBefore INT = (SELECT COUNT(*) FROM dbo.Clients);

BEGIN TRY
    EXEC dbo.usp_ProvisionUser
        @LoginName = 'evil];DROP TABLE dbo.Clients--',
        @Password  = 'Injected@Password2026',
        @RoleName  = 'role_ReadOnly';
    PRINT 'FAIL: injected login name was accepted.';
END TRY
BEGIN CATCH
    PRINT 'PASS: injection rejected -> ' + ERROR_MESSAGE();
END CATCH;

-- The table must still be there with the same number of rows.
IF OBJECT_ID('dbo.Clients', 'U') IS NULL
    PRINT 'FAIL: dbo.Clients was dropped!';
ELSE IF (SELECT COUNT(*) FROM dbo.Clients) = @ClientsBefore
    PRINT 'PASS: dbo.Clients intact, row count unchanged.';
ELSE
    PRINT 'FAIL: dbo.Clients row count changed.';
GO


-- C18: A short password is rejected
-- Expected: 'PASS' - the procedure enforces a 12-character minimum before it
-- ever reaches CREATE LOGIN.
BEGIN TRY
    EXEC dbo.usp_ProvisionUser
        @LoginName = 'test.shortpw',
        @Password  = 'abc123',
        @RoleName  = 'role_ReadOnly';
    PRINT 'FAIL: short password was accepted.';
END TRY
BEGIN CATCH
    PRINT 'PASS: short password rejected -> ' + ERROR_MESSAGE();
END CATCH;
GO


-- C19: Provisioning is a DBA duty, not a business-Admin duty
-- Expected: 'PASS' - farid.rahman (role_Admin) has no EXECUTE on
-- usp_ProvisionUser.
EXECUTE AS USER = 'farid.rahman';      -- role_Admin
    BEGIN TRY
        EXEC dbo.usp_ProvisionUser
            @LoginName = 'test.escalation',
            @Password  = 'Escalate@Test2026',
            @RoleName  = 'role_DBA';
        PRINT 'FAIL: role_Admin provisioned a DBA account.';
    END TRY
    BEGIN CATCH
        PRINT 'PASS: provisioning denied to role_Admin -> ' + ERROR_MESSAGE();
    END CATCH;
REVERT;
GO


-- C20: Full permission matrix dump for the report
-- Expected: One row per explicit GRANT/DENY per role.
SELECT
    pr.name                             AS RoleName,
    dp.state_desc                       AS GrantOrDeny,
    dp.permission_name                  AS Permission,
    CASE dp.class
        WHEN 0 THEN 'DATABASE'
        WHEN 1 THEN ISNULL(OBJECT_SCHEMA_NAME(dp.major_id) + '.', '')
                    + ISNULL(OBJECT_NAME(dp.major_id), '(object)')
        WHEN 25 THEN 'CERTIFICATE'
        WHEN 24 THEN 'SYMMETRIC KEY'
        ELSE dp.class_desc
    END                                 AS SecurableName,
    CASE
        WHEN dp.class = 1 AND o.type_desc IS NOT NULL THEN o.type_desc
        ELSE dp.class_desc
    END                                 AS SecurableType,
    c.name                              AS ColumnName
FROM sys.database_permissions AS dp
JOIN sys.database_principals  AS pr ON pr.principal_id = dp.grantee_principal_id
LEFT JOIN sys.objects        AS o  ON o.object_id = dp.major_id AND dp.class = 1
LEFT JOIN sys.columns        AS c  ON c.object_id = dp.major_id
                                  AND c.column_id = dp.minor_id
                                  AND dp.minor_id > 0
WHERE pr.type = 'R'
  AND pr.name LIKE 'role[_]%'
ORDER BY pr.name, SecurableName, dp.permission_name;
GO


-- AUDIT EVIDENCE TESTS (TEST 1-12) Green Acres Realty Sdn Bhd - EMS Database
-- Security CT069-3-3 Database Security Assignment Purpose: Screenshot-friendly
-- test cases for Documentation Section 4. Run DDL.sql, then Sections 1-6 of
-- this file, before these tests.

USE GreenAcresEMS;
GO

-- TEST 1: AuditLog table exists
-- Expected: One row showing dbo.AuditLog.
SELECT
    CASE
        WHEN OBJECT_ID('dbo.AuditLog', 'U') IS NOT NULL THEN 'PASS'
        ELSE 'FAIL'
    END AS TestResult,
    'dbo' AS SchemaName,
    'AuditLog' AS TableName,
    (
        SELECT create_date
        FROM sys.tables
        WHERE object_id = OBJECT_ID('dbo.AuditLog', 'U')
    ) AS CreatedDate;
GO

-- TEST 2: Audit triggers exist on important tables
-- Expected: 8 trigger rows, all enabled.
SELECT
    tr.name AS TriggerName,
    OBJECT_NAME(tr.parent_id) AS TableName,
    CASE WHEN tr.is_disabled = 0 THEN 'Enabled' ELSE 'Disabled' END AS TriggerStatus
FROM sys.triggers tr
WHERE tr.name LIKE 'trg_%_Audit'
ORDER BY TableName, TriggerName;

SELECT
    COUNT(*) AS EnabledAuditTriggers,
    CASE WHEN COUNT(*) = 8 THEN 'PASS' ELSE 'FAIL' END AS TestResult
FROM sys.triggers
WHERE name LIKE 'trg_%_Audit'
  AND is_disabled = 0;
GO

-- TEST 3: UPDATE client data and prove AuditLog records it
-- Expected: 1. Client Email changes.
DECLARE @AuditClientID INT;
DECLARE @OriginalEmail NVARCHAR(100);
DECLARE @DemoEmail NVARCHAR(100);

SELECT TOP (1)
    @AuditClientID = ClientID,
    @OriginalEmail = Email
FROM dbo.Clients
ORDER BY ClientID;

IF @AuditClientID IS NULL
    THROW 50100, 'TEST 3 cannot run because dbo.Clients is empty.', 1;

SET @DemoEmail = CONCAT('audit.demo.', @AuditClientID, '@example.com');

SELECT
    @AuditClientID AS ClientID,
    @OriginalEmail AS EmailBefore,
    @DemoEmail AS EmailDuringTest;

UPDATE dbo.Clients
SET Email = @DemoEmail
WHERE ClientID = @AuditClientID;

SELECT TOP (1)
    'PASS' AS TestResult,
    AuditID,
    EventTime,
    TableName,
    OperationType,
    RecordID,
    ChangedBy,
    ApplicationName,
    HostName,
    OldValues,
    NewValues
FROM dbo.AuditLog
WHERE TableName = 'Clients'
  AND OperationType = 'UPDATE'
  AND RecordID = CONVERT(NVARCHAR(50), @AuditClientID)
ORDER BY AuditID DESC;

UPDATE dbo.Clients
SET Email = @OriginalEmail
WHERE ClientID = @AuditClientID;
GO

-- TEST 4: INSERT transaction and prove trigger audit works
-- Expected: 1. New transaction is inserted.
DECLARE @PropertyID INT =
    (SELECT TOP (1) PropertyID FROM dbo.Properties WHERE Status = 'Available' ORDER BY PropertyID);
DECLARE @ClientID INT =
    (SELECT TOP (1) ClientID FROM dbo.Clients ORDER BY ClientID);
DECLARE @AgentID INT =
    (SELECT TOP (1) AgentID FROM dbo.Agents ORDER BY AgentID);
DECLARE @TransactionID INT;

IF @PropertyID IS NULL OR @ClientID IS NULL OR @AgentID IS NULL
    THROW 50101, 'TEST 4 needs an available property, a client and an agent.', 1;

BEGIN TRANSACTION;

INSERT INTO dbo.Transactions
    (PropertyID, ClientID, AgentID, TransactionType, Amount, PaymentStatus, PaymentMethod)
VALUES
    (@PropertyID, @ClientID, @AgentID, 'Sale', 888000.00, 'Pending', 'Bank Transfer');

SET @TransactionID = SCOPE_IDENTITY();

SELECT TOP (1)
    'PASS' AS TestResult,
    AuditID,
    EventTime,
    TableName,
    OperationType,
    RecordID,
    ChangedBy,
    NewValues
FROM dbo.AuditLog
WHERE TableName = 'Transactions'
  AND OperationType = 'INSERT'
  AND RecordID = CONVERT(NVARCHAR(50), @TransactionID)
ORDER BY AuditID DESC;

ROLLBACK TRANSACTION;
GO

-- TEST 5: ReadOnly user cannot read AuditLog
-- Expected: PASS message with permission denied.
IF USER_ID('jason.lim') IS NULL
BEGIN
    SELECT
        'NOT RUN' AS TestResult,
        'Database user jason.lim does not exist.' AS Details;
END
ELSE
BEGIN
    EXECUTE AS USER = 'jason.lim';
    BEGIN TRY
        SELECT TOP (1) * FROM dbo.AuditLog;
        SELECT
            'FAIL' AS TestResult,
            'ReadOnly user can read AuditLog.' AS Details;
    END TRY
    BEGIN CATCH
        SELECT
            'PASS' AS TestResult,
            ERROR_MESSAGE() AS Details;
    END CATCH;
    REVERT;
END;
GO

-- TEST 6: SQL Server Audit is enabled
-- Expected: Server audit and database audit specification both show enabled.
USE master;
GO

SELECT
    name AS ServerAuditName,
    is_state_enabled AS IsEnabled,
    CASE WHEN is_state_enabled = 1 THEN 'PASS' ELSE 'FAIL' END AS TestResult,
    type_desc AS AuditTarget
FROM sys.server_audits
WHERE name = 'GA_EMS_ServerAudit';
GO

SELECT
    name AS ServerAuditSpecification,
    is_state_enabled AS IsEnabled,
    CASE WHEN is_state_enabled = 1 THEN 'PASS' ELSE 'FAIL' END AS TestResult
FROM sys.server_audit_specifications
WHERE name = 'GA_EMS_ServerAuditSpec';
GO

USE GreenAcresEMS;
GO

SELECT
    name AS DatabaseAuditSpecification,
    is_state_enabled AS IsEnabled,
    CASE WHEN is_state_enabled = 1 THEN 'PASS' ELSE 'FAIL' END AS TestResult
FROM sys.database_audit_specifications
WHERE name = 'GA_EMS_DatabaseAuditSpec';
GO

-- TEST 7: Read SQL Server Audit file
-- Expected: Audit rows appear after SELECT/UPDATE/permission tests.
SELECT TOP 50
    event_time,
    action_id,
    succeeded,
    server_principal_name,
    database_name,
    schema_name,
    object_name,
    statement
FROM sys.fn_get_audit_file('C:\SQLAudit\*.sqlaudit', DEFAULT, DEFAULT)
WHERE database_name = 'GreenAcresEMS'
ORDER BY event_time DESC;
GO

-- TEST 8: Audit specifications contain the required actions
-- Expected: Result grids show login, principal, permission, role, schema,
-- sensitive-object and audit-evidence actions.
USE master;
GO

SELECT
    sas.name AS SpecificationName,
    sad.audit_action_name AS AuditedAction
FROM sys.server_audit_specifications AS sas
INNER JOIN sys.server_audit_specification_details AS sad
    ON sad.server_specification_id = sas.server_specification_id
WHERE sas.name = 'GA_EMS_ServerAuditSpec'
ORDER BY sad.audit_action_name;
GO

USE GreenAcresEMS;
GO

SELECT
    das.name AS SpecificationName,
    dad.audit_action_name AS AuditedAction,
    dad.class_desc AS SecurableClass,
    OBJECT_SCHEMA_NAME(dad.major_id) AS ObjectSchema,
    OBJECT_NAME(dad.major_id) AS ObjectName
FROM sys.database_audit_specifications AS das
INNER JOIN sys.database_audit_specification_details AS dad
    ON dad.database_specification_id = das.database_specification_id
WHERE das.name = 'GA_EMS_DatabaseAuditSpec'
ORDER BY dad.audit_action_name, ObjectName;
GO

-- TEST 9: Multi-row updates create one history row per changed row
-- Expected: RowsAffected = AuditRowsCreated and TestResult = PASS.
DECLARE @AuditCountBefore INT =
    (SELECT COUNT(*) FROM dbo.AuditLog
     WHERE TableName = 'Agents' AND OperationType = 'UPDATE');
DECLARE @ExpectedRows INT = (SELECT COUNT(*) FROM dbo.Agents);

UPDATE dbo.Agents
SET CommissionRate = CommissionRate;

DECLARE @AuditCountAfter INT =
    (SELECT COUNT(*) FROM dbo.AuditLog
     WHERE TableName = 'Agents' AND OperationType = 'UPDATE');
DECLARE @AuditRowsCreated INT = @AuditCountAfter - @AuditCountBefore;

SELECT
    @ExpectedRows AS RowsAffected,
    @AuditRowsCreated AS AuditRowsCreated,
    CASE
        WHEN @ExpectedRows = @AuditRowsCreated THEN 'PASS'
        ELSE 'FAIL'
    END AS TestResult;
GO

-- TEST 10: Generate permission, role, principal and schema events.
-- Expected: the audit specification captures each one; the test objects are
-- removed before the batch completes.
DROP TABLE IF EXISTS dbo.AuditMatrixTestTable;

IF USER_ID('AuditMatrixTestUser') IS NOT NULL
BEGIN
    IF IS_ROLEMEMBER('role_ReadOnly', 'AuditMatrixTestUser') = 1
        ALTER ROLE role_ReadOnly DROP MEMBER AuditMatrixTestUser;
    DROP USER AuditMatrixTestUser;
END;

CREATE USER AuditMatrixTestUser WITHOUT LOGIN;
GRANT SELECT ON dbo.Clients TO AuditMatrixTestUser;

IF DATABASE_PRINCIPAL_ID('role_ReadOnly') IS NOT NULL
BEGIN
    ALTER ROLE role_ReadOnly ADD MEMBER AuditMatrixTestUser;
    ALTER ROLE role_ReadOnly DROP MEMBER AuditMatrixTestUser;
END;

CREATE TABLE dbo.AuditMatrixTestTable (
    TestID INT NOT NULL PRIMARY KEY
);

DROP TABLE dbo.AuditMatrixTestTable;
REVOKE SELECT ON dbo.Clients FROM AuditMatrixTestUser;
DROP USER AuditMatrixTestUser;

WAITFOR DELAY '00:00:02';

SELECT TOP (50)
    event_time,
    action_id,
    succeeded,
    server_principal_name,
    database_principal_name,
    object_name,
    statement
FROM sys.fn_get_audit_file('C:\SQLAudit\*.sqlaudit', DEFAULT, DEFAULT)
WHERE database_name = 'GreenAcresEMS'
  AND (
      statement LIKE '%AuditMatrixTest%'
      OR object_name = 'AuditMatrixTestTable'
  )
ORDER BY event_time DESC;
GO

-- TEST 11: History retention moves old rows to the archive
-- Expected: ArchivedRows = 1 and TestResult = PASS.
BEGIN TRANSACTION;

INSERT dbo.AuditLog
    (EventTime, TableName, OperationType, RecordID, ChangedBy, NewValues)
VALUES
    (DATEADD(DAY, -400, GETDATE()), 'RetentionTest', 'INSERT',
     'RETENTION-TEST', ORIGINAL_LOGIN(), N'{"test":true}');

EXEC dbo.usp_ArchiveAuditLog @RetainDays = 365;

SELECT
    COUNT(*) AS ArchivedRows,
    CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END AS TestResult
FROM dbo.AuditLogArchive
WHERE TableName = 'RetentionTest'
  AND RecordID = 'RETENTION-TEST';

ROLLBACK TRANSACTION;
GO

-- TEST 12: Login audit evidence (LGIF = failed login, LGIS = successful).
-- Expected: LGIF rows after you open a second SSMS connection with SQL Server
-- Authentication, enter a real login with a wrong password, then re-run this.
USE master;
GO

SELECT TOP (50)
    event_time,
    action_id,
    succeeded,
    server_principal_name,
    server_instance_name,
    statement
FROM sys.fn_get_audit_file('C:\SQLAudit\*.sqlaudit', DEFAULT, DEFAULT)
WHERE action_id IN ('LGIF', 'LGIS')
ORDER BY event_time DESC;
GO

PRINT 'Auditing test cases completed.';
GO


/* ========================================================================
   SECTION D: BACKUP, RECOVERY & AVAILABILITY
   Goal: Prove the Availability side of CIA.
   ======================================================================== */

USE master;
GO

-- D1: The recovery model still allows point-in-time recovery
-- Expected: recovery_model_desc = FULL.
SELECT
    name AS DatabaseName,
    recovery_model_desc,
    log_reuse_wait_desc,
    state_desc
FROM sys.databases
WHERE name IN ('GreenAcresEMS', 'GreenAcresEMS_Restore');
GO


-- D2: All three backup types were actually taken
-- Expected: One row each for Full, Differential and Transaction Log, all for
-- GreenAcresEMS, all with is_damaged = 0.
SELECT
    CASE bs.type
        WHEN 'D' THEN 'Full'
        WHEN 'I' THEN 'Differential'
        WHEN 'L' THEN 'Transaction Log'
        ELSE bs.type
    END                                              AS BackupType,
    bs.backup_start_date,
    bs.backup_finish_date,
    CAST(bs.backup_size / 1048576.0 AS DECIMAL(10,2)) AS BackupSize_MB,
    bs.is_damaged,
    bs.has_backup_checksums,
    bs.is_copy_only,
    bmf.physical_device_name
FROM msdb.dbo.backupset AS bs
JOIN msdb.dbo.backupmediafamily AS bmf
     ON bmf.media_set_id = bs.media_set_id
WHERE bs.database_name = 'GreenAcresEMS'
ORDER BY bs.backup_start_date DESC;
GO


-- D3: The backup files are readable and not corrupt
-- Expected: "The backup set on file 1 is valid." for each file.
RESTORE VERIFYONLY FROM DISK = 'C:\EMS_Backups\GreenAcresEMS_FULL.bak' WITH CHECKSUM;
GO
RESTORE VERIFYONLY FROM DISK = 'C:\EMS_Backups\GreenAcresEMS_DIFF.bak' WITH CHECKSUM;
GO
RESTORE VERIFYONLY FROM DISK = 'C:\EMS_Backups\GreenAcresEMS_LOG.trn'  WITH CHECKSUM;
GO


-- D4: The KEY MATERIAL was backed up too
-- Expected: All three files exist (FileExists = 1).
DECLARE @Info TABLE (
    Label       NVARCHAR(60),
    FilePath    NVARCHAR(300),
    FileExists  INT,
    IsDirectory INT,
    ParentDirExists INT
);

INSERT INTO @Info (FileExists, IsDirectory, ParentDirExists)
EXEC master.dbo.xp_fileexist 'C:\EMS_Backups\Keys\EMS_DataProtectionCertificate.cer';
UPDATE @Info SET Label = 'Certificate (public .cer)',
                 FilePath = 'C:\EMS_Backups\Keys\EMS_DataProtectionCertificate.cer'
WHERE Label IS NULL;

INSERT INTO @Info (FileExists, IsDirectory, ParentDirExists)
EXEC master.dbo.xp_fileexist 'C:\EMS_Backups\Keys\EMS_DataProtectionCertificate.pvk';
UPDATE @Info SET Label = 'Certificate private key (.pvk)',
                 FilePath = 'C:\EMS_Backups\Keys\EMS_DataProtectionCertificate.pvk'
WHERE Label IS NULL;

INSERT INTO @Info (FileExists, IsDirectory, ParentDirExists)
EXEC master.dbo.xp_fileexist 'C:\EMS_Backups\Keys\EMS_MasterKey.key';
UPDATE @Info SET Label = 'Database Master Key (.key)',
                 FilePath = 'C:\EMS_Backups\Keys\EMS_MasterKey.key'
WHERE Label IS NULL;

SELECT Label AS KeyMaterial, FilePath, FileExists
FROM @Info;
GO


-- D5: The restore rehearsal produced a usable database
-- Expected: LiveRows = RestoredRows for every table.
IF DB_ID('GreenAcresEMS_Restore') IS NULL
BEGIN
    PRINT 'SKIP: GreenAcresEMS_Restore does not exist - run the restore section first.';
END
ELSE
BEGIN
    SELECT 'Properties' AS TableName,
           (SELECT COUNT(*) FROM GreenAcresEMS.dbo.Properties)         AS LiveRows,
           (SELECT COUNT(*) FROM GreenAcresEMS_Restore.dbo.Properties) AS RestoredRows
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
           (SELECT COUNT(*) FROM GreenAcresEMS_Restore.dbo.CommissionPayments)
    UNION ALL
    SELECT 'AuditLog',
           (SELECT COUNT(*) FROM GreenAcresEMS.dbo.AuditLog),
           (SELECT COUNT(*) FROM GreenAcresEMS_Restore.dbo.AuditLog);
END;
GO


-- D6: The audit trail survived the restore
-- Expected: The restored copy still carries its AuditLog history.
IF DB_ID('GreenAcresEMS_Restore') IS NOT NULL
BEGIN
    SELECT TOP 5
        AuditID, EventTime, TableName, OperationType, ChangedBy
    FROM GreenAcresEMS_Restore.dbo.AuditLog
    ORDER BY AuditID DESC;
END;
GO


-- D7: Encrypted data is STILL encrypted in the restored copy
-- Expected: Ciphertext, not readable text - and no way to decrypt it there,
-- because the restored database has no certificate of its own.
IF DB_ID('GreenAcresEMS_Restore') IS NOT NULL
BEGIN
    SELECT TOP 3
        ClientID,
        FullName,
        NRIC_Encrypted AS CiphertextAfterRestore
    FROM GreenAcresEMS_Restore.dbo.Clients;
END;
GO


-- D8: No corrupt pages anywhere
-- Expected: ZERO rows. Any row here means SQL Server has met a damaged page and
-- the backup chain is about to be needed for real.
SELECT * FROM msdb.dbo.suspect_pages;
GO


-- D9: Integrity check of the live database
-- Expected: "CHECKDB found 0 allocation errors and 0 consistency errors in
-- database 'GreenAcresEMS'."
DBCC CHECKDB ('GreenAcresEMS') WITH NO_INFOMSGS, ALL_ERRORMSGS;
GO


-- D10: How much data would we lose right now?
-- Expected: MinutesSinceLastLogBackup should be small.
SELECT
    MAX(CASE WHEN type = 'D' THEN backup_finish_date END) AS LastFullBackup,
    MAX(CASE WHEN type = 'I' THEN backup_finish_date END) AS LastDiffBackup,
    MAX(CASE WHEN type = 'L' THEN backup_finish_date END) AS LastLogBackup,
    DATEDIFF(MINUTE, MAX(CASE WHEN type = 'L' THEN backup_finish_date END), GETDATE())
        AS MinutesSinceLastLogBackup
FROM msdb.dbo.backupset
WHERE database_name = 'GreenAcresEMS';
GO


PRINT 'Backup and recovery test cases completed.';
GO


/* ========================================================================
   SECTION E: LOGIN AUDITING (UserLoginLog + LOGON TRIGGER)
   Goal: Prove that dbo.UserLoginLog is real, populated audit evidence rather
   than an empty table, and that it is protected from the roles it is meant to
   watch.
   ======================================================================== */

USE GreenAcresEMS;
GO

-- E1: The logon trigger exists and is enabled
-- Expected: One row, is_disabled = 0. If the row is missing, the build script
-- could not impersonate 'sa' and said so.
SELECT
    name        AS TriggerName,
    is_disabled AS IsDisabled,
    create_date
FROM sys.server_triggers
WHERE name = 'trg_ServerLogon_AuditLogin';
GO


-- E2: A successful application login is recorded
-- Expected: 'Login Successful' from the procedure, then a matching UserLoginLog
-- row with IsSuccessful = 1. (B7 already cleared irfan.hakim's forced-reset
-- flag; if this returns 'Password Change Required', run B7 first.)
EXEC dbo.usp_VerifySystemUserPassword
    @LoginName     = 'irfan.hakim',
    @PlainPassword = 'IrfanSecure@2026';
GO

SELECT TOP 5 LogID, LoginName, LoginTime, IsSuccessful, HostName, FailureReason
FROM dbo.UserLoginLog
ORDER BY LogID DESC;
GO


-- E3: A FAILED application login is recorded, with a reason
-- Expected: 'Invalid Login' from the procedure, and a new UserLoginLog row with
-- IsSuccessful = 0 and FailureReason = 'Incorrect password'.
EXEC dbo.usp_VerifySystemUserPassword
    @LoginName     = 'irfan.hakim',
    @PlainPassword = 'DefinitelyTheWrongPassword';
GO

SELECT TOP 5 LogID, LoginName, LoginTime, IsSuccessful, FailureReason
FROM dbo.UserLoginLog
ORDER BY LogID DESC;
GO


-- E4: An attempt on an unknown account is logged, but the error message gives
-- nothing away
-- Expected: The caller sees the same generic 'Invalid Login', while
-- UserLoginLog records 'Unknown or inactive account'.
EXEC dbo.usp_VerifySystemUserPassword
    @LoginName     = 'no.such.person',
    @PlainPassword = 'Whatever@2026';
GO

SELECT TOP 3 LogID, LoginName, IsSuccessful, FailureReason
FROM dbo.UserLoginLog
WHERE LoginName = 'no.such.person'
ORDER BY LogID DESC;
GO


-- E5: Brute-force detection
-- Expected: After the failures above, 'no.such.person' and/or 'irfan.hakim'
-- appear once the threshold is reached.
EXEC dbo.usp_ReportSuspiciousLogins
    @WindowMinutes = 60,
    @FailThreshold = 1;
GO


-- E6: Session length is tracked (login -> logout)
-- Expected: The chosen row shows a LogoutTime and a SessionMinutes value
-- instead of an open-ended session.
DECLARE @OpenLogID INT =
    (SELECT MAX(LogID) FROM dbo.UserLoginLog
     WHERE IsSuccessful = 1 AND LogoutTime IS NULL);

IF @OpenLogID IS NULL
    PRINT 'SKIP: no open successful session to close - run E2 first.';
ELSE
BEGIN
    EXEC dbo.usp_RecordLogout @LogID = @OpenLogID;

    SELECT LogID, LoginName, LoginTime, LogoutTime, SessionMinutes
    FROM dbo.vw_LoginHistory
    WHERE LogID = @OpenLogID;
END;
GO


-- E7: Login history joins cleanly to staff and department
-- Expected: FullName and DepartmentName are filled in for rows belonging to
-- known EMS staff.
SELECT TOP 10
    LogID, LoginName, FullName, DepartmentName, UserRole,
    LoginTime, IsSuccessful
FROM dbo.vw_LoginHistory
ORDER BY LogID DESC;
GO


-- E8: Login history is NOT readable by the watched roles
-- Expected: 'PASS' for both.
EXECUTE AS USER = 'hakim.zulkifli';    -- role_Analyst
    BEGIN TRY
        SELECT TOP 1 * FROM dbo.UserLoginLog;
        PRINT 'FAIL: Analyst read the login log.';
    END TRY
    BEGIN CATCH
        PRINT 'PASS: Login log denied -> ' + ERROR_MESSAGE();
    END CATCH;
REVERT;
GO

EXECUTE AS USER = 'jason.lim';         -- role_ReadOnly
    BEGIN TRY
        SELECT TOP 1 * FROM dbo.vw_LoginHistory;
        PRINT 'FAIL: ReadOnly read the login history view.';
    END TRY
    BEGIN CATCH
        PRINT 'PASS: Login history denied -> ' + ERROR_MESSAGE();
    END CATCH;
REVERT;
GO


-- E9: Forced password reset on the onboarding password
-- Expected: 'Password Change Required' - the password is CORRECT but the
-- account is still on the shared onboarding secret, so the login is not
-- completed until it is replaced.
SELECT TOP 5 LoginName, PasswordMustChange, PasswordLastUpdated
FROM dbo.SystemUsers
ORDER BY SystemUserID;
GO

DECLARE @TestLogin NVARCHAR(100) =
    (SELECT MIN(LoginName) FROM dbo.SystemUsers WHERE PasswordMustChange = 1);

IF @TestLogin IS NULL
    PRINT 'SKIP: every account has already changed its onboarding password.';
ELSE
BEGIN
    PRINT 'Testing forced reset for: ' + @TestLogin;
    EXEC dbo.usp_VerifySystemUserPassword
        @LoginName     = @TestLogin,
        @PlainPassword = 'TempPassword@2026';

    EXEC dbo.usp_UpdateSystemUserPassword
        @LoginName        = @TestLogin,
        @NewPlainPassword = 'ChangedByTestE9@2026';

    EXEC dbo.usp_VerifySystemUserPassword
        @LoginName     = @TestLogin,
        @PlainPassword = 'ChangedByTestE9@2026';
END;
GO


-- E10: Failed SERVER logins come from the audit file, not the logon trigger
-- Expected: LGIF rows for any wrong-password connection attempt.
SELECT TOP 20
    event_time,
    action_id,
    succeeded,
    server_principal_name,
    client_ip,
    application_name
FROM sys.fn_get_audit_file('C:\SQLAudit\GA_EMS_ServerAudit*.sqlaudit', DEFAULT, DEFAULT)
WHERE action_id IN ('LGIF', 'LGIS')
ORDER BY event_time DESC;
GO


PRINT 'Login auditing test cases completed.';
GO


/* ========================================================================
   END OF TEST_CASES.SQL
   ======================================================================== */

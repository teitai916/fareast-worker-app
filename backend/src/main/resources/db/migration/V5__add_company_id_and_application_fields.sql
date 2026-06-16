-- V5: Add company_id to users, add fields to site_applications, seed test companies
-- PostgreSQL syntax

-- 1. Add company_id to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS company_id BIGINT;
ALTER TABLE users DROP CONSTRAINT IF EXISTS fk_user_company;
ALTER TABLE users ADD CONSTRAINT fk_user_company FOREIGN KEY (company_id) REFERENCES companies(id);

-- 2. Add daily_wage and contract_attachment to site_applications
ALTER TABLE site_applications ADD COLUMN IF NOT EXISTS daily_wage DECIMAL(10,2);
ALTER TABLE site_applications ADD COLUMN IF NOT EXISTS contract_attachment VARCHAR(500);

-- 3. Insert 3 virtual contractor companies (id will be 1,2,3 if table is empty)
INSERT INTO companies (name, contact_person, contact_phone, address)
VALUES ('遠東建築工程有限公司', '陳經理', '13800000011', '香港九龍觀塘觀塘道100號');
INSERT INTO companies (name, contact_person, contact_phone, address)
VALUES ('宏達工程有限公司', '李經理', '13800000012', '香港新界荃灣青山公路200號');
INSERT INTO companies (name, contact_person, contact_phone, address)
VALUES ('建輝工程有限公司', '王經理', '13800000013', '香港香港島西營盤皇后大道西300號');

-- 4. Link contractor users to companies (use subquery to be safe)
UPDATE users SET company_id = (SELECT id FROM companies WHERE name = '遠東建築工程有限公司' LIMIT 1) WHERE phone = '13800000001';
UPDATE users SET company_id = (SELECT id FROM companies WHERE name = '宏達工程有限公司' LIMIT 1) WHERE phone = '13800000002';
UPDATE users SET company_id = (SELECT id FROM companies WHERE name = '建輝工程有限公司' LIMIT 1) WHERE phone = '13800000003';

-- 5. Make sure these 3 users have role CONTRACTOR (if not already)
UPDATE users SET role = 'CONTRACTOR' WHERE phone IN ('13800000001', '13800000002', '13800000003');

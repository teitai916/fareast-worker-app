-- V9: Create sample contractor users and bind to companies
-- Bidirectional binding:
--   users.company_id  -> 判头用户属于哪家公司
--   companies.user_id  -> 哪個判头用戶對應這家公司

-- 1. Make sure users table has company_id column
ALTER TABLE users ADD COLUMN IF NOT EXISTS company_id BIGINT;

-- 2. Add user_id column to companies table (bidirectional binding)
ALTER TABLE companies ADD COLUMN IF NOT EXISTS user_id BIGINT UNIQUE;

-- 3. Insert sample contractor users (password: 123456, BCrypt hashed)
-- These are the contractor accounts managing each company
INSERT INTO users (phone, password, name, role, status, created_at, updated_at, company_id)
VALUES
  ('13800000011', '$2a$10$7QyHspKzZxQxZxQxQxuQxQxQxQxQxQxQxQxQxQxQxQxQxQxQxQ', '陈志强', 'CONTRACTOR', 'ACTIVE', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,
   (SELECT id FROM companies WHERE name LIKE '%盛%' OR id = 1 LIMIT 1)),
  ('13800000012', '$2a$10$7QyHspKzZxQxZxQxQxuQxQxQxQxQxQxQxQxQxQxQxQxQxQxQxQ', '李明辉', 'CONTRACTOR', 'ACTIVE', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,
   (SELECT id FROM companies WHERE name LIKE '%昌%' OR id = 2 LIMIT 1)),
  ('13800000013', '$2a$10$7QyHspKzZxQxZxQxQxuQxQxQxQxQxQxQxQxQxQxQxQxQxQxQxQ', '黄建业', 'CONTRACTOR', 'ACTIVE', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,
   (SELECT id FROM companies WHERE name LIKE '%泰%' OR id = 3 LIMIT 1))
ON CONFLICT (phone) DO UPDATE SET company_id = EXCLUDED.company_id;

-- 4. Fill companies.user_id (bidirectional)
-- Now that users are created, link them back to companies
UPDATE companies SET user_id = (
  SELECT u.id FROM users u WHERE u.company_id = companies.id LIMIT 1
) WHERE user_id IS NULL;

-- 5. Also set contact_phone for companies if not already set
UPDATE companies SET contact_phone = '13800000011' WHERE id = 1 OR name LIKE '%盛%';
UPDATE companies SET contact_phone = '13800000012' WHERE id = 2 OR name LIKE '%昌%';
UPDATE companies SET contact_phone = '13800000013' WHERE id = 3 OR name LIKE '%泰%';

-- 6. Add foreign keys
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'fk_user_company' AND table_name = 'users'
    ) THEN
        ALTER TABLE users ADD CONSTRAINT fk_user_company FOREIGN KEY (company_id) REFERENCES companies(id);
    END IF;
END
$$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'fk_company_user' AND table_name = 'companies'
    ) THEN
        ALTER TABLE companies ADD CONSTRAINT fk_company_user FOREIGN KEY (user_id) REFERENCES users(id);
    END IF;
END
$$;

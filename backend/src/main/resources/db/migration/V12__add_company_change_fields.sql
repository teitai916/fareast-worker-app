-- 添加 daily_salary 和 contract_attachment 列到 worker_company_change_requests 表
ALTER TABLE worker_company_change_requests ADD COLUMN IF NOT EXISTS daily_salary DECIMAL(10,2);
ALTER TABLE worker_company_change_requests ADD COLUMN IF NOT EXISTS contract_attachment VARCHAR(500);

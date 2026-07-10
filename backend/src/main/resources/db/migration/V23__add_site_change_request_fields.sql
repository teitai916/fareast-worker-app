-- V23: 为 site_change_requests 表添加 Entity 中新字段
-- 对应 SiteChangeRequest.java 中的 companyId, dailyWage, contractAttachment

ALTER TABLE site_change_requests ADD COLUMN IF NOT EXISTS company_id BIGINT;
ALTER TABLE site_change_requests ADD COLUMN IF NOT EXISTS daily_wage DECIMAL(10,2);
ALTER TABLE site_change_requests ADD COLUMN IF NOT EXISTS contract_attachment VARCHAR(500);

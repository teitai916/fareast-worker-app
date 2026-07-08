-- V23: Add birth_date field to worker_profiles
-- 出生日期（註冊時強制填寫）

ALTER TABLE worker_profiles ADD COLUMN IF NOT EXISTS birth_date DATE;

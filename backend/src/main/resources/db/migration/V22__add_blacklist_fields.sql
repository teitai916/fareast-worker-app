-- V22: 为 blacklist_records 表添加实体中新增的字段
-- 对应 BlacklistRecord.java 中的 "新增字段" 标记

ALTER TABLE blacklist_records ADD COLUMN IF NOT EXISTS name VARCHAR(100);
ALTER TABLE blacklist_records ADD COLUMN IF NOT EXISTS worker_registration_num VARCHAR(50);
ALTER TABLE blacklist_records ADD COLUMN IF NOT EXISTS age INTEGER;
ALTER TABLE blacklist_records ADD COLUMN IF NOT EXISTS company_id BIGINT;
ALTER TABLE blacklist_records ADD COLUMN IF NOT EXISTS status BOOLEAN DEFAULT TRUE;

-- V22: Add emergency contact fields to worker_profiles
-- 緊急聯絡人（非必填）

ALTER TABLE worker_profiles ADD COLUMN IF NOT EXISTS emergency_contact_name VARCHAR(255);
ALTER TABLE worker_profiles ADD COLUMN IF NOT EXISTS emergency_contact_phone VARCHAR(50);

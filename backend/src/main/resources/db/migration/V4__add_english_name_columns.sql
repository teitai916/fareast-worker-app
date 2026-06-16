-- V4: Add english_name to users, chinese_name and english_name to worker_profiles
-- PostgreSQL syntax

ALTER TABLE users ADD COLUMN IF NOT EXISTS english_name VARCHAR(255);

ALTER TABLE worker_profiles ADD COLUMN IF NOT EXISTS chinese_name VARCHAR(255);
ALTER TABLE worker_profiles ADD COLUMN IF NOT EXISTS english_name VARCHAR(255);

-- V7: Add type column to companies table (idempotent)
ALTER TABLE companies ADD COLUMN IF NOT EXISTS type VARCHAR(50) NOT NULL DEFAULT 'CONTRACTOR';

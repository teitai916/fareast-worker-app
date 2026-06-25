-- V16: Add bluetooth_beacon_id column to attendances table
ALTER TABLE attendances ADD COLUMN IF NOT EXISTS bluetooth_beacon_id VARCHAR(100);

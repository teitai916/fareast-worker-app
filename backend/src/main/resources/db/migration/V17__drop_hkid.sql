-- V17: Drop hkid column from worker_profiles (sensitive information)
ALTER TABLE worker_profiles DROP COLUMN IF EXISTS hkid;

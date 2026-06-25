-- V21: Add certificate attachment columns to worker_profiles
ALTER TABLE worker_profiles ADD COLUMN IF NOT EXISTS safety_card_attachment VARCHAR(500);
ALTER TABLE worker_profiles ADD COLUMN IF NOT EXISTS worker_reg_cert_attachment VARCHAR(500);

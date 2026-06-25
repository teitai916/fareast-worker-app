-- V19: Rename photo_url to check_in_photo_url and add check_out_photo_url
ALTER TABLE attendances RENAME COLUMN photo_url TO check_in_photo_url;
ALTER TABLE attendances ADD COLUMN IF NOT EXISTS check_out_photo_url VARCHAR(500);

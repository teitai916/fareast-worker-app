-- V18: Add photo_url column to attendances for check-in photo capture
ALTER TABLE attendances ADD COLUMN IF NOT EXISTS photo_url VARCHAR(500);

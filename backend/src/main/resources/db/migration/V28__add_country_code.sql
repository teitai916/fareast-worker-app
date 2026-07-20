ALTER TABLE users ADD COLUMN IF NOT EXISTS country_code VARCHAR(5) DEFAULT '+852';
COMMENT ON COLUMN users.country_code IS '手机国际区号，如 +852、+86';

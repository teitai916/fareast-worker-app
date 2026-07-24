-- V31: 工人多地盘支持
-- 创建 worker_sites 表，支持工人加入多个地盘并自由切换

CREATE TABLE IF NOT EXISTS worker_sites (
    id BIGSERIAL PRIMARY KEY,
    worker_id BIGINT NOT NULL,
    site_id BIGINT NOT NULL,
    is_current BOOLEAN NOT NULL DEFAULT false,
    daily_wage DECIMAL(10, 2),
    contract_attachment VARCHAR(500),
    joined_at TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_worker_sites_worker FOREIGN KEY (worker_id) REFERENCES worker_profiles(id),
    CONSTRAINT fk_worker_sites_site FOREIGN KEY (site_id) REFERENCES sites(id),
    CONSTRAINT uq_worker_site UNIQUE (worker_id, site_id)
);

CREATE INDEX IF NOT EXISTS idx_worker_sites_worker_id ON worker_sites(worker_id);
CREATE INDEX IF NOT EXISTS idx_worker_sites_site_id ON worker_sites(site_id);

-- 迁移现有数据：将 worker_profiles 中有 current_site_id 的工人，自动创建 worker_sites 记录
INSERT INTO worker_sites (worker_id, site_id, is_current, daily_wage, contract_attachment, joined_at)
SELECT id, current_site_id, true, daily_wage, contract_attachment, NOW()
FROM worker_profiles
WHERE current_site_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM worker_sites ws WHERE ws.worker_id = worker_profiles.id AND ws.site_id = worker_profiles.current_site_id
  );

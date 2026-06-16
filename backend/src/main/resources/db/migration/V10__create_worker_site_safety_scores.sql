-- 创建工人地盘安全分表
-- 按地盘维度记录每个工人在每个地盘的安全分，总分15分
CREATE TABLE worker_site_safety_scores (
    id BIGSERIAL PRIMARY KEY,
    worker_id BIGINT NOT NULL,
    site_id BIGINT NOT NULL,
    safety_score INT NOT NULL DEFAULT 15,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_wsss_worker FOREIGN KEY (worker_id) REFERENCES worker_profiles(id) ON DELETE CASCADE,
    CONSTRAINT fk_wsss_site FOREIGN KEY (site_id) REFERENCES sites(id) ON DELETE CASCADE,
    CONSTRAINT uk_wsss_worker_site UNIQUE (worker_id, site_id)
);

-- 创建索引
CREATE INDEX idx_wsss_worker_id ON worker_site_safety_scores(worker_id);
CREATE INDEX idx_wsss_site_id ON worker_site_safety_scores(site_id);

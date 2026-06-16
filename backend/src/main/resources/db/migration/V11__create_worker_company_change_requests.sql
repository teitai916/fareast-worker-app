-- 创建工人更换公司申请表
-- 工人发起更换公司后，无需选择地盘，而是选择新公司
-- 推送給新公司的判头来审批
CREATE TABLE worker_company_change_requests (
    id BIGSERIAL PRIMARY KEY,
    worker_id BIGINT NOT NULL,
    from_company_id BIGINT NOT NULL,
    to_company_id BIGINT NOT NULL,
    reason TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    requested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP,
    processed_by BIGINT,
    reject_reason TEXT,
    CONSTRAINT fk_wccr_worker FOREIGN KEY (worker_id) REFERENCES worker_profiles(id) ON DELETE CASCADE,
    CONSTRAINT fk_wccr_from_company FOREIGN KEY (from_company_id) REFERENCES companies(id) ON DELETE CASCADE,
    CONSTRAINT fk_wccr_to_company FOREIGN KEY (to_company_id) REFERENCES companies(id) ON DELETE CASCADE,
    CONSTRAINT uk_wccr_worker_status UNIQUE (worker_id, status)
);

-- 创建索引
CREATE INDEX idx_wccr_worker_id ON worker_company_change_requests(worker_id);
CREATE INDEX idx_wccr_to_company_id ON worker_company_change_requests(to_company_id);
CREATE INDEX idx_wccr_status ON worker_company_change_requests(status);

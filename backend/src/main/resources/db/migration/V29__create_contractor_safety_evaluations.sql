-- 分判商安全考核评分表
CREATE TABLE IF NOT EXISTS contractor_safety_evaluations (
    id BIGSERIAL PRIMARY KEY,
    site_id BIGINT NOT NULL REFERENCES sites(id),
    company_id BIGINT NOT NULL REFERENCES companies(id),
    trade_of_work VARCHAR(100),
    period VARCHAR(20) NOT NULL DEFAULT 'QUARTERLY',
    period_year INT NOT NULL,
    period_quarter INT,

    -- 21项评分（安全投放资源表现 8项 + 地盘实地安环表现 10项 + 安全表现 3项）
    score_1 INT,   -- 管理层安全态度
    score_2 INT,   -- 具備足夠能力的安全人員
    score_3 INT,   -- 提供安全訓練、指示及監督
    score_4 INT,   -- 地盤安全設施之提供及維持
    score_5 INT,   -- 合作性
    score_6 INT,   -- 提供予屬下員工及使用個人保護裝置
    score_7 INT,   -- 安全意外率
    score_8 INT,   -- 安全表現
    score_9 INT,   -- 提供適當安装方法/程序, 或專業分判施工方案
    score_10 INT,  -- 聘請安全督導員
    score_11 INT,  -- 起重機械/裝置證書
    score_12 INT,  -- 高空工作
    score_13 INT,  -- 個人防護裝備使用情況
    score_14 INT,  -- 施工/物料擺放位置整潔
    score_15 INT,  -- 依照施工方案進行工序
    score_16 INT,  -- 改善態度
    score_17 INT,  -- 參與早會及安全施工程序會議
    score_18 INT,  -- 提供合適的工具
    score_19 INT,  -- 合約安全守則
    score_20 INT,  -- 法例(包括工作守則)
    score_21 INT,  -- 工傷事故記錄
    score_22 INT,  -- 敦促改善通知書(部份II)/停工通知書 (發出日期)

    -- 计算字段
    total_score INT,              -- 总分(0-210)
    percentage DECIMAL(5,2),      -- 百分比
    non_compliant_level VARCHAR(20) DEFAULT 'NONE', -- NONE / WARNING / SEVERE

    -- 审核状态
    status VARCHAR(20) NOT NULL DEFAULT 'DRAFT',  -- DRAFT / SUBMITTED / APPROVED / NOTIFIED

    -- 流程记录
    submitted_by BIGINT REFERENCES users(id),
    submitted_at TIMESTAMP,
    assigned_to BIGINT REFERENCES users(id),
    approved_by BIGINT REFERENCES users(id),
    approved_at TIMESTAMP,
    approval_comment TEXT,
    notified_at TIMESTAMP,

    -- 佐证附件
    evidence_attachments TEXT,    -- JSON数组，存储附件URL

    -- 备注
    remarks TEXT,

    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_cse_site_id ON contractor_safety_evaluations(site_id);
CREATE INDEX IF NOT EXISTS idx_cse_company_id ON contractor_safety_evaluations(company_id);
CREATE INDEX IF NOT EXISTS idx_cse_status ON contractor_safety_evaluations(status);
CREATE INDEX IF NOT EXISTS idx_cse_submitted_by ON contractor_safety_evaluations(submitted_by);
CREATE INDEX IF NOT EXISTS idx_cse_assigned_to ON contractor_safety_evaluations(assigned_to);
CREATE INDEX IF NOT EXISTS idx_cse_period ON contractor_safety_evaluations(period_year, period_quarter);

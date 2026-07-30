-- V34: 通用考核评分模板
CREATE TABLE IF NOT EXISTS evaluation_templates (
    id                  SERIAL PRIMARY KEY,
    code                VARCHAR(50)  NOT NULL UNIQUE,
    name                VARCHAR(100) NOT NULL,
    target_type         VARCHAR(20)  NOT NULL DEFAULT 'CONTRACTOR',
    max_score_per_item  INT NOT NULL DEFAULT 10,
    is_active           BOOLEAN DEFAULT TRUE,
    created_at          TIMESTAMP DEFAULT NOW(),
    updated_at          TIMESTAMP DEFAULT NOW()
);

-- 安全考核初始模板
INSERT INTO evaluation_templates (code, name, target_type, max_score_per_item) VALUES
('SAFETY_2025', '分判商安全考核評分', 'CONTRACTOR', 10)
ON CONFLICT (code) DO NOTHING;

CREATE TABLE IF NOT EXISTS evaluation_score_items (
    id                  SERIAL PRIMARY KEY,
    template_id         INT NOT NULL REFERENCES evaluation_templates(id),
    score_index         INT NOT NULL,
    category            VARCHAR(100) NOT NULL,
    name_zh             VARCHAR(200) NOT NULL,
    sort_order          INT DEFAULT 0,
    guide_tier_1        VARCHAR(200),
    guide_tier_1_range  VARCHAR(20),
    guide_tier_2        VARCHAR(200),
    guide_tier_2_range  VARCHAR(20),
    guide_tier_3        VARCHAR(200),
    guide_tier_3_range  VARCHAR(20),
    guide_tier_4        VARCHAR(200),
    guide_tier_4_range  VARCHAR(20),
    created_at          TIMESTAMP DEFAULT NOW(),
    updated_at          TIMESTAMP DEFAULT NOW(),
    UNIQUE(template_id, score_index)
);

-- 安全考核 22 项初始数据
DO $$
DECLARE
    template_id_val INT;
BEGIN
    SELECT id INTO template_id_val FROM evaluation_templates WHERE code = 'SAFETY_2025';
    IF template_id_val IS NOT NULL THEN
        INSERT INTO evaluation_score_items (template_id, score_index, category, name_zh, sort_order, guide_tier_1, guide_tier_1_range, guide_tier_2, guide_tier_2_range, guide_tier_3, guide_tier_3_range, guide_tier_4, guide_tier_4_range)
        VALUES
        (template_id_val, 1,  '安全投放資源表現', '管理层安全态度', 1,                         'Fully supporting', '9-10', 'Supporting', '6-8', 'Not supporting', '0-5', NULL, NULL),
        (template_id_val, 2,  '安全投放資源表現', '具備足夠能力的安全人員', 2,                  'Suitably trained', '8-10', 'Training arranged', '6-7', 'No safety & environmental training', '0-5', NULL, NULL),
        (template_id_val, 3,  '安全投放資源表現', '提供安全訓練、指示及監督', 3,                 'With good result', '8-10', 'Provision given', '6-7', 'No provision', '0-5', NULL, NULL),
        (template_id_val, 4,  '安全投放資源表現', '地盤安全設施之提供及維持', 4,                 'Pro-active', '8-10', 'Provision given', '6-7', 'No provision', '0-5', NULL, NULL),
        (template_id_val, 5,  '安全投放資源表現', '合作性', 5,                                    'Co-operating actively', '8-10', 'Co-operating', '6-7', 'Not co-operating', '0-5', NULL, NULL),
        (template_id_val, 6,  '安全投放資源表現', '提供予屬下員工及使用個人保護裝置', 6,           'Always use at own will', '9-10', 'In use most of the time', '6-8', 'Always not in use', '0-5', NULL, NULL),
        (template_id_val, 7,  '安全投放資源表現', '安全意外率', 7,                                 '0% → 10 分', '10', '每 1% 扣 1 分', '9-0', NULL, NULL, NULL, NULL),
        (template_id_val, 8,  '安全投放資源表現', '安全表現', 8,                                   'Never violate safety rules', '10', 'Seldom violate safety rules', '6-9', 'Always violate safety rules', '0-5', NULL, NULL),
        (template_id_val, 9,  '地盤實地安環表現', '提供適當安装方法/程序, 或專業分判施工方案', 1,  NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
        (template_id_val, 10, '地盤實地安環表現', '聘請安全督導員作為安全代表，跟進地盤事項', 2,   NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
        (template_id_val, 11, '地盤實地安環表現', '使用的起重機械/起重裝置持有有效的證書及沒有違反安全操作守則', 3, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
        (template_id_val, 12, '地盤實地安環表現', '高空工作', 4,                                   NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
        (template_id_val, 13, '地盤實地安環表現', '個人防護裝備使用情況', 5,                      NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
        (template_id_val, 14, '地盤實地安環表現', '施工/物料擺放位置整潔', 6,                     NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
        (template_id_val, 15, '地盤實地安環表現', '依照施工方案進行工序', 7,                      NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
        (template_id_val, 16, '地盤實地安環表現', '改善態度', 8,                                   '勸喻後立即改善', '7-10', '勸喻後一天內改善', '4-6', '態度毫不積極', '1-3', NULL, NULL),
        (template_id_val, 17, '地盤實地安環表現', '參與早會及安全施工程序會議', 9,                  '早會出席率高於 70%', '7-10', '早會出席率 50%-70%', '4-6', '早會出席率低於 50%', '1-3', NULL, NULL),
        (template_id_val, 18, '地盤實地安環表現', '提供合適的工具(包括梯台及功夫櫈)給予工人使用', 10, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
        (template_id_val, 19, '安全表現', '合約安全守則', 1,                                        '沒有收到警告/罰款信', '7-10', '1-2 封警告/罰款信', '4-6', '3 封或以上的警告/罰款信', '1-3', NULL, NULL),
        (template_id_val, 20, '安全表現', '法例(包括工作守則)', 2,                                  '沒有檢控', '10', '1 宗檢控或以上', '0', NULL, NULL, NULL, NULL),
        (template_id_val, 21, '安全表現', '工傷事故記錄', 3,                                        '沒有工傷記錄', '10', '1 宗', '5', '3 宗或以上工傷記錄', '0', NULL, NULL),
        (template_id_val, 22, '安全表現', '敦促改善通知書(部份II)/停工通知書 (發出日期)', 4,         '沒有收到政府文件', '10', '1-2 封', '5', '3 封或以上', '0', '1 封停工令', '0')
        ON CONFLICT (template_id, score_index) DO NOTHING;
    END IF;
END $$;

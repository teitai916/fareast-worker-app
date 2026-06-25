-- 删除 worker_profiles 表中的 safety_score 字段
-- 安全分已统一迁移至 worker_site_safety_scores 表按地盤維度管理（15分制）
ALTER TABLE worker_profiles DROP COLUMN IF EXISTS safety_score;

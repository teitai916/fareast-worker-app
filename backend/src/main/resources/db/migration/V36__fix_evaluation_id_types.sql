-- V36: 修正 evaluation_templates 和 evaluation_score_items 的 id 类型
-- init_templates.sql 手动建表使用 SERIAL (INTEGER)，但 JPA Entity 使用 Long (BIGINT)
-- 需要同步列类型

ALTER TABLE evaluation_templates ALTER COLUMN id TYPE BIGINT;
ALTER TABLE evaluation_score_items ALTER COLUMN id TYPE BIGINT;
ALTER TABLE evaluation_score_items ALTER COLUMN template_id TYPE BIGINT;

-- V35: 關聯評分記錄到模板
ALTER TABLE contractor_safety_evaluations 
ADD COLUMN IF NOT EXISTS template_code VARCHAR(50) DEFAULT 'SAFETY_2025';

COMMENT ON COLUMN contractor_safety_evaluations.template_code IS '評分模板編碼，關聯 evaluation_templates.code';

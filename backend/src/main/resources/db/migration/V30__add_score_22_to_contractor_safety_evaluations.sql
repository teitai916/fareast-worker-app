-- 補齊 V29 實際執行時缺失的 score_22 欄位
-- （V29 後來增加 score_22，但 DB 先以舊版 V29 建立，故用本遷移補足）
ALTER TABLE contractor_safety_evaluations
    ADD COLUMN IF NOT EXISTS score_22 INT;

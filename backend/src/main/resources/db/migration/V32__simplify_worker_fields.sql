-- V32: 简化工人地盘管理
-- 1. 去掉 worker_profiles.current_site_id（由 worker_sites 管理多地盘）
-- 2. 重命名 current_company_id 为 company_id（工人所属公司，非"当前"概念）
-- 3. 去掉 worker_sites.is_current（当前地盘由客户端本地状态管理）

ALTER TABLE worker_profiles DROP COLUMN IF EXISTS current_site_id;
ALTER TABLE worker_profiles RENAME COLUMN current_company_id TO company_id;
ALTER TABLE worker_sites DROP COLUMN IF EXISTS is_current;

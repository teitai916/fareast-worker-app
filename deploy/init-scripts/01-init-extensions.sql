-- =============================================
-- 远东工友 App — 数据库初始化脚本
-- 此脚本在 PostgreSQL 容器首次启动时自动执行
-- Flyway 会在此之后运行版本化迁移脚本
-- =============================================

-- 启用 UUID 扩展（用于 Flyway 迁移中的 gen_random_uuid()）
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 启用 pgcrypto（如需要加密功能）
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

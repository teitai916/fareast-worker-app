-- ==========================================
-- 分判商考核评分模块 — 测试用户 SQL
-- 密码统一: 123456
-- BCrypt Hash: $2b$10$TNAWq9fO/Sa7NFVJ0h0bZ.iP32CkzINMcWOguPvXP4D7Y116e3mQK
-- ==========================================

-- 1. 创建测试地盘（如果不存在）
INSERT INTO sites (name, address, company_id, latitude, longitude, created_at, updated_at)
SELECT '香港会议展览中心', '香港湾仔博览道1号', c.id, 22.2830, 114.1730, NOW(), NOW()
FROM companies c WHERE c.name = '远东建筑工程有限公司' LIMIT 1;
INSERT INTO sites (name, address, company_id, latitude, longitude, created_at, updated_at)
SELECT '九龙东综合发展', '香港九龙观塘', c.id, 22.3120, 114.2250, NOW(), NOW()
FROM companies c WHERE c.name = '宏达工程有限公司' LIMIT 1;
INSERT INTO sites (name, address, company_id, latitude, longitude, created_at, updated_at)
SELECT '港岛西住宅项目', '香港西营盘', c.id, 22.2860, 114.1430, NOW(), NOW()
FROM companies c WHERE c.name = '建辉工程有限公司' LIMIT 1;

-- 2. 创建测试公司（如果 V5 的3家公司不存在则创建）
INSERT INTO companies (name, contact_person, contact_phone, type, created_at, updated_at)
SELECT '远东建筑工程有限公司', '陈经理', '13800000011', 'CONTRACTOR', NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM companies WHERE name = '远东建筑工程有限公司');
INSERT INTO companies (name, contact_person, contact_phone, type, created_at, updated_at)
SELECT '宏达工程有限公司', '李经理', '13800000012', 'CONTRACTOR', NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM companies WHERE name = '宏达工程有限公司');
INSERT INTO companies (name, contact_person, contact_phone, type, created_at, updated_at)
SELECT '建辉工程有限公司', '王经理', '13800000013', 'CONTRACTOR', NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM companies WHERE name = '建辉工程有限公司');

-- 3. 修复 V9 种子用户的密码（原 hash 是伪造的，登录会失败）
UPDATE users SET password = '$2b$10$TNAWq9fO/Sa7NFVJ0h0bZ.iP32CkzINMcWOguPvXP4D7Y116e3mQK'
WHERE phone IN ('13800000011', '13800000012', '13800000013');

-- 4. 创建测试用户

-- SUPER_ADMIN: 超级管理员（全权限）
INSERT INTO users (phone, password, name, role, status, created_at, updated_at)
VALUES ('10000000001', '$2b$10$TNAWq9fO/Sa7NFVJ0h0bZ.iP32CkzINMcWOguPvXP4D7Y116e3mQK', '超级管理员', 'SUPER_ADMIN', 'ACTIVE', NOW(), NOW())
ON CONFLICT (phone) DO UPDATE SET role = 'SUPER_ADMIN', password = '$2b$10$TNAWq9fO/Sa7NFVJ0h0bZ.iP32CkzINMcWOguPvXP4D7Y116e3mQK', status = 'ACTIVE';

-- SAFETY_OFFICER: 安全人员（填报评分）
INSERT INTO users (phone, password, name, role, status, created_at, updated_at)
VALUES ('10000000002', '$2b$10$TNAWq9fO/Sa7NFVJ0h0bZ.iP32CkzINMcWOguPvXP4D7Y116e3mQK', '安全员张工', 'SAFETY_OFFICER', 'ACTIVE', NOW(), NOW())
ON CONFLICT (phone) DO UPDATE SET role = 'SAFETY_OFFICER', password = '$2b$10$TNAWq9fO/Sa7NFVJ0h0bZ.iP32CkzINMcWOguPvXP4D7Y116e3mQK', status = 'ACTIVE';

-- PROJECT_MANAGER: 项目经理（审批评分）
INSERT INTO users (phone, password, name, role, status, created_at, updated_at)
VALUES ('10000000003', '$2b$10$TNAWq9fO/Sa7NFVJ0h0bZ.iP32CkzINMcWOguPvXP4D7Y116e3mQK', '项目经理李总', 'PROJECT_MANAGER', 'ACTIVE', NOW(), NOW())
ON CONFLICT (phone) DO UPDATE SET role = 'PROJECT_MANAGER', password = '$2b$10$TNAWq9fO/Sa7NFVJ0h0bZ.iP32CkzINMcWOguPvXP4D7Y116e3mQK', status = 'ACTIVE';

-- SITE_MANAGER: 地盘经理
INSERT INTO users (phone, password, name, role, status, created_at, updated_at)
VALUES ('10000000004', '$2b$10$TNAWq9fO/Sa7NFVJ0h0bZ.iP32CkzINMcWOguPvXP4D7Y116e3mQK', '地盘经理王工', 'SITE_MANAGER', 'ACTIVE', NOW(), NOW())
ON CONFLICT (phone) DO UPDATE SET role = 'SITE_MANAGER', password = '$2b$10$TNAWq9fO/Sa7NFVJ0h0bZ.iP32CkzINMcWOguPvXP4D7Y116e3mQK', status = 'ACTIVE';

-- INSTALL_MANAGER: 安装经理
INSERT INTO users (phone, password, name, role, status, created_at, updated_at)
VALUES ('10000000005', '$2b$10$TNAWq9fO/Sa7NFVJ0h0bZ.iP32CkzINMcWOguPvXP4D7Y116e3mQK', '安装经理赵工', 'INSTALL_MANAGER', 'ACTIVE', NOW(), NOW())
ON CONFLICT (phone) DO UPDATE SET role = 'INSTALL_MANAGER', password = '$2b$10$TNAWq9fO/Sa7NFVJ0h0bZ.iP32CkzINMcWOguPvXP4D7Y116e3mQK', status = 'ACTIVE';

-- NOTIFIED_PARTY: 知会人员
INSERT INTO users (phone, password, name, role, status, created_at, updated_at)
VALUES ('10000000006', '$2b$10$TNAWq9fO/Sa7NFVJ0h0bZ.iP32CkzINMcWOguPvXP4D7Y116e3mQK', '知会人员陈总', 'NOTIFIED_PARTY', 'ACTIVE', NOW(), NOW())
ON CONFLICT (phone) DO UPDATE SET role = 'NOTIFIED_PARTY', password = '$2b$10$TNAWq9fO/Sa7NFVJ0h0bZ.iP32CkzINMcWOguPvXP4D7Y116e3mQK', status = 'ACTIVE';

-- 3. 为内部管理人员添加地盘关联（如果已有地盘数据）
-- 先检查是否存在地盘，若存在则将 manager 角色关联到所有地盘
DO $$
DECLARE
    s RECORD;
    u RECORD;
BEGIN
    -- 为 SITE_MANAGER / PROJECT_MANAGER / INSTALL_MANAGER / SAFETY_OFFICER 关联所有地盘
    FOR s IN SELECT id FROM sites LOOP
        FOR u IN SELECT id FROM users WHERE role IN ('SITE_MANAGER', 'PROJECT_MANAGER', 'INSTALL_MANAGER', 'SAFETY_OFFICER') LOOP
            INSERT INTO staff_sites (user_id, site_id, is_current, joined_at)
            VALUES (u.id, s.id, false, NOW())
            ON CONFLICT DO NOTHING;
        END LOOP;
    END LOOP;

    -- 为 SUPER_ADMIN 关联所有地盘（如果尚未关联）
    FOR s IN SELECT id FROM sites LOOP
        FOR u IN SELECT id FROM users WHERE role = 'SUPER_ADMIN' LOOP
            INSERT INTO staff_sites (user_id, site_id, is_current, joined_at)
            VALUES (u.id, s.id, false, NOW())
            ON CONFLICT DO NOTHING;
        END LOOP;
    END LOOP;
END $$;

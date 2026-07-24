-- V33: 扣分项目表（分类+项目合一）
-- 后续通过 DB 客户端直接 INSERT 即可扩展分类和项目

CREATE TABLE IF NOT EXISTS deduction_items (
    id BIGSERIAL PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL,
    item_name VARCHAR(200) NOT NULL,
    points INT NOT NULL DEFAULT 1,
    sort_order INT DEFAULT 0
);

-- 预置電力安全数据
INSERT INTO deduction_items (category_name, item_name, points, sort_order) VALUES
('電力安全', '破壞配電箱及裝置', 3, 1),
('電力安全', '使用不合規格的手提式電動工具', 3, 2),
('電力安全', '使用的手提式電動工具上没有已在指定期限內由合資格電工檢查的標箴', 2, 3),
('電力安全', '不良電線管理(如電線放在地面或水中)', 2, 4),
('電力安全', '違反工作許可證條件', 3, 5),
('電力安全', '未有授權下進入限制区域', 2, 6),
('電力安全', '於非指定位置充電', 1, 7),
('電力安全', '其他', 2, 8);

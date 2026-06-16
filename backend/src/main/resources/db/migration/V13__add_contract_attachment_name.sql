-- V13: 添加合同附件文件名字段到工人变更公司申请表
ALTER TABLE worker_company_change_requests ADD COLUMN contract_attachment_name VARCHAR(500);

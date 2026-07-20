package com.fareast.worker.model.entity;

public enum NotificationType {
    APPLICATION_SUBMITTED,        // 工人提交申请，通知判头
    APPLICATION_APPROVED,         // 判头批准申请，通知工人
    APPLICATION_REJECTED,         // 判头拒绝申请，通知工人
    SITE_CHANGE_APPROVED,         // 地盘更换批准
    SITE_CHANGE_REJECTED,         // 地盘更换拒绝
    EVALUATION_SUBMITTED,         // 安全考核提交，通知项目经理
    EVALUATION_APPROVED,          // 安全考核通过，通知安全人员
    EVALUATION_NOTIFIED           // 安全考核知会，通知分判商和知会人员
}

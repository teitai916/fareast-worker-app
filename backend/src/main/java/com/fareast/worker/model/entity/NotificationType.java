package com.fareast.worker.model.entity;

public enum NotificationType {
    APPLICATION_SUBMITTED,   // 工人提交申请，通知判头
    APPLICATION_APPROVED,    // 判头批准申请，通知工人
    APPLICATION_REJECTED,    // 判头拒绝申请，通知工人
    SITE_CHANGE_APPROVED,    // 地盘更换批准
    SITE_CHANGE_REJECTED     // 地盘更换拒绝
}

package com.fareast.worker.controller;

import com.fareast.worker.model.dto.ApiResponse;
import com.fareast.worker.model.entity.Notification;
import com.fareast.worker.service.NotificationService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/notifications")
public class NotificationController {

    @Autowired
    private NotificationService notificationService;

    /**
     * GET /notifications
     * 获取当前用户的通知列表
     * 可选参数: ?unreadOnly=true
     */
    @GetMapping
    public ApiResponse<List<Map<String, Object>>> getNotifications(
            @AuthenticationPrincipal String userId,
            @RequestParam(defaultValue = "false") Boolean unreadOnly) {
        List<Map<String, Object>> list = notificationService.getNotifications(
                Long.valueOf(userId), unreadOnly);
        return ApiResponse.success(list);
    }

    /**
     * GET /notifications/unread-count
     * 获取当前用户未读通知数量
     */
    @GetMapping("/unread-count")
    public ApiResponse<Long> getUnreadCount(@AuthenticationPrincipal String userId) {
        Long count = notificationService.getUnreadCount(Long.valueOf(userId));
        return ApiResponse.success(count);
    }

    /**
     * PUT /notifications/{id}/read
     * 标记单条通知为已读
     */
    @PutMapping("/{id}/read")
    public ApiResponse<Void> markAsRead(
            @AuthenticationPrincipal String userId,
            @PathVariable Long id) {
        notificationService.markAsRead(id, Long.valueOf(userId));
        return ApiResponse.success(null);
    }

    /**
     * PUT /notifications/read-all
     * 标记所有通知为已读
     */
    @PutMapping("/read-all")
    public ApiResponse<Void> markAllAsRead(@AuthenticationPrincipal String userId) {
        notificationService.markAllAsRead(Long.valueOf(userId));
        return ApiResponse.success(null);
    }
}

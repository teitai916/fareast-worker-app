package com.fareast.worker.service;

import com.fareast.worker.model.entity.Notification;
import com.fareast.worker.model.entity.NotificationType;
import com.fareast.worker.model.entity.User;
import com.fareast.worker.repository.NotificationRepository;
import com.fareast.worker.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
public class NotificationService {

    @Autowired
    private NotificationRepository notificationRepository;

    @Autowired
    private UserRepository userRepository;

    /**
     * 发送通知
     */
    public Notification send(Long userId, NotificationType type, String title, String content,
                           Long relatedId, String relatedType) {
        Notification n = new Notification();
        n.setUserId(userId);
        n.setType(type);
        n.setTitle(title);
        n.setContent(content);
        n.setRelatedId(relatedId);
        n.setRelatedType(relatedType);
        n.setIsRead(false);
        return notificationRepository.save(n);
    }

    /**
     * 获取用户的通知列表
     */
    public List<Map<String, Object>> getNotifications(Long userId, Boolean unreadOnly) {
        List<Notification> list;
        if (Boolean.TRUE.equals(unreadOnly)) {
            list = notificationRepository.findByUserIdAndIsReadOrderByCreatedAtDesc(userId, false);
        } else {
            list = notificationRepository.findByUserIdOrderByCreatedAtDesc(userId);
        }
        return list.stream().map(this::toMap).collect(Collectors.toList());
    }

    /**
     * 获取未读通知数量
     */
    public Long getUnreadCount(Long userId) {
        return notificationRepository.countByUserIdAndIsRead(userId, false);
    }

    /**
     * 标记单条通知为已读
     */
    @Transactional
    public void markAsRead(Long notificationId, Long userId) {
        Notification n = notificationRepository.findById(notificationId)
                .orElseThrow(() -> new RuntimeException("通知不存在"));
        if (!n.getUserId().equals(userId)) {
            throw new RuntimeException("无权操作此通知");
        }
        n.setIsRead(true);
        n.setReadAt(LocalDateTime.now());
        notificationRepository.save(n);
    }

    /**
     * 标记所有通知为已读
     */
    @Transactional
    public void markAllAsRead(Long userId) {
        List<Notification> unread = notificationRepository.findByUserIdAndIsReadOrderByCreatedAtDesc(userId, false);
        LocalDateTime now = LocalDateTime.now();
        unread.forEach(n -> {
            n.setIsRead(true);
            n.setReadAt(now);
        });
        notificationRepository.saveAll(unread);
    }

    private Map<String, Object> toMap(Notification n) {
        java.util.Map<String, Object> m = new java.util.HashMap<>();
        m.put("id", n.getId());
        m.put("type", n.getType().name());
        m.put("title", n.getTitle());
        m.put("content", n.getContent());
        m.put("relatedId", n.getRelatedId());
        m.put("relatedType", n.getRelatedType());
        m.put("isRead", n.getIsRead());
        m.put("createdAt", n.getCreatedAt() == null ? null : n.getCreatedAt().toString());
        return m;
    }
}

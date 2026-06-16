package com.fareast.worker.service.impl;

import com.fareast.worker.exception.BusinessException;
import com.fareast.worker.model.entity.NotificationType;
import com.fareast.worker.model.entity.Site;
import com.fareast.worker.model.entity.SiteChangeRequest;
import com.fareast.worker.model.entity.User;
import com.fareast.worker.model.entity.WorkerProfile;
import com.fareast.worker.model.entity.WorkerSiteSafetyScore;
import com.fareast.worker.model.enums.AuditStatus;
import com.fareast.worker.model.enums.UserRole;
import com.fareast.worker.repository.SiteChangeRequestRepository;
import com.fareast.worker.repository.SiteRepository;
import com.fareast.worker.repository.UserRepository;
import com.fareast.worker.repository.WorkerProfileRepository;
import com.fareast.worker.repository.WorkerSiteSafetyScoreRepository;
import com.fareast.worker.service.NotificationService;
import com.fareast.worker.service.SiteService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Slf4j
@Service
public class SiteServiceImpl implements SiteService {

    @Autowired
    private WorkerProfileRepository workerProfileRepository;

    @Autowired
    private SiteRepository siteRepository;

    @Autowired
    private SiteChangeRequestRepository siteChangeRequestRepository;

    @Autowired
    private NotificationService notificationService;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private WorkerSiteSafetyScoreRepository workerSiteSafetyScoreRepository;

    @Override
    public java.util.List<Site> getAllSites() {
        return siteRepository.findAll();
    }

    @Override
    public Site getCurrentSite(Long userId) {
        WorkerProfile profile = workerProfileRepository.findByUserId(userId)
                .orElseThrow(() -> new BusinessException(404, "工人資料不存在"));

        if (profile.getCurrentSiteId() == null) {
            throw new BusinessException(404, "目前未分配地盤");
        }

        return siteRepository.findById(profile.getCurrentSiteId())
                .orElseThrow(() -> new BusinessException(404, "地盤信息不存在"));
    }

    @Override
    public Site getSiteById(Long siteId) {
        return siteRepository.findById(siteId)
                .orElseThrow(() -> new BusinessException(404, "地盤不存在"));
    }

    @Override
    @Transactional
    public void requestSiteChange(Long userId, Long targetSiteId, String reason,
                                 java.math.BigDecimal dailyWage, String contractAttachment) {
        WorkerProfile profile = workerProfileRepository.findByUserId(userId)
                .orElseThrow(() -> new BusinessException(404, "工人資料不存在"));

        Site targetSite = siteRepository.findById(targetSiteId)
                .orElseThrow(() -> new BusinessException(404, "目標地盤不存在"));

        // 获取当前工人所属公司ID
        Long targetCompanyId = profile.getCurrentCompanyId();
        if (targetCompanyId == null) {
            throw new BusinessException(400, "工人未關聯公司，無法提交申請");
        }

        java.util.List<SiteChangeRequest> existingRequests = siteChangeRequestRepository.findByWorkerId(profile.getId());
        boolean hasPending = existingRequests.stream()
                .anyMatch(r -> r.getStatus() == AuditStatus.PENDING);
        if (hasPending) {
            throw new BusinessException(400, "已有待審批的轉地盤申請");
        }

        SiteChangeRequest request = SiteChangeRequest.builder()
                .workerId(profile.getId())
                .fromSiteId(profile.getCurrentSiteId())
                .toSiteId(targetSiteId)
                .companyId(targetCompanyId)
                .reason(reason)
                .dailyWage(dailyWage)
                .contractAttachment(contractAttachment)
                .status(AuditStatus.PENDING)
                .requestedAt(LocalDateTime.now())
                .build();

        siteChangeRequestRepository.save(request);
        log.info("轉地盤申請已提交: workerId={}, fromSiteId={}, toSiteId={}",
                profile.getId(), profile.getCurrentSiteId(), targetSiteId);

        // 發送通知給目標公司的所有判頭
        try {
            List<User> contractors = userRepository.findByCompanyIdAndRole(targetCompanyId, UserRole.CONTRACTOR);
            String workerName = profile.getChineseName() != null ? profile.getChineseName() : "工人";
            String siteName = targetSite.getName();
            for (User contractor : contractors) {
                notificationService.send(
                        contractor.getId(),
                        NotificationType.APPLICATION_SUBMITTED,
                        "更換地盤申請",
                        workerName + " 申請更換地盤至 " + siteName,
                        request.getId(),
                        "SITE_CHANGE_REQUEST"
                );
            }
            log.info("已發送通知給 {} 位判頭", contractors.size());
        } catch (Exception e) {
            log.error("發送通知失敗: {}", e.getMessage());
            // 通知失敗不影響主流程
        }
    }

    @Override
    @Transactional
    public void reviewChangeRequest(Long reviewerId, Long requestId,
                                    boolean approved, String reviewRemark) {
        SiteChangeRequest request = siteChangeRequestRepository.findById(requestId)
                .orElseThrow(() -> new BusinessException(404, "更換地盤申請不存在"));

        if (request.getStatus() != AuditStatus.PENDING) {
            throw new BusinessException(400, "該申請已被處理");
        }

        // 验证审核人是目标工地所属公司的判头
        User reviewer = userRepository.findById(reviewerId)
                .orElseThrow(() -> new BusinessException(404, "用戶不存在"));
        Long reviewerCompanyId = reviewer.getCompanyId();
        if (reviewerCompanyId == null || !reviewerCompanyId.equals(request.getCompanyId())) {
            throw new BusinessException(403, "無權審核此申請");
        }

        if (approved) {
            request.setStatus(AuditStatus.APPROVED);
            // 更新工人的当前工地
            WorkerProfile profile = workerProfileRepository.findById(request.getWorkerId())
                    .orElseThrow(() -> new BusinessException(404, "工人資料不存在"));
            Long oldSiteId = profile.getCurrentSiteId();
            profile.setCurrentSiteId(request.getToSiteId());
            if (request.getDailyWage() != null) {
                profile.setDailyWage(request.getDailyWage());
            }
            if (request.getContractAttachment() != null) {
                profile.setContractAttachment(request.getContractAttachment());
            }
            workerProfileRepository.saveAndFlush(profile);  // 使用 saveAndFlush 确保立即写入数据库
            log.info("更換地盤申請已批准: requestId={}, workerId={}, oldSiteId={}, newSiteId={}",
                    request.getId(), request.getWorkerId(), oldSiteId, request.getToSiteId());
            
            // 初始化工人在新地盤的安全分（总分15分）
            _initWorkerSiteSafetyScore(request.getWorkerId(), request.getToSiteId());
            
            // 验证是否更新成功
            WorkerProfile verifyProfile = workerProfileRepository.findByUserId(request.getWorkerId()).orElse(null);
            if (verifyProfile != null) {
                log.info("驗證結果: workerId={}, currentSiteId={}", 
                        request.getWorkerId(), verifyProfile.getCurrentSiteId());
            }
        } else {
            request.setStatus(AuditStatus.REJECTED);
            log.info("更換地盤申請已拒絕: requestId={}, workerId={}",
                    request.getId(), request.getWorkerId());
        }

        request.setProcessedBy(reviewerId);
        request.setProcessedAt(LocalDateTime.now());
        request.setRejectReason(reviewRemark);
        siteChangeRequestRepository.save(request);

        // 發送通知給工人
        try {
            WorkerProfile workerProfile = workerProfileRepository.findById(request.getWorkerId())
                    .orElseThrow(() -> new BusinessException(404, "工人資料不存在"));
            User worker = userRepository.findById(workerProfile.getUserId())
                    .orElseThrow(() -> new BusinessException(404, "工人不存在"));
            String workerPhone = worker.getPhone();
            String siteName = siteRepository.findById(request.getToSiteId())
                    .map(Site::getName)
                    .orElse("未知地盤");

            NotificationType type;
            String title;
            String content;

            if (approved) {
                type = NotificationType.SITE_CHANGE_APPROVED;
                title = "更換地盤申請已批准";
                content = "您的更換地盤申請已批准，新地盤：" + siteName;
            } else {
                type = NotificationType.SITE_CHANGE_REJECTED;
                title = "更換地盤申請已拒絕";
                content = "您的更換地盤申請已拒絕" +
                        (reviewRemark != null && !reviewRemark.isEmpty() ? "，原因：" + reviewRemark : "");
            }

            notificationService.send(
                    workerProfile.getUserId(),
                    type,
                    title,
                    content,
                    request.getId(),
                    "SITE_CHANGE_REQUEST"
            );
            log.info("已發送審核結果通知給工人: userId={}, workerId={}", workerProfile.getUserId(), request.getWorkerId());
        } catch (Exception e) {
            log.error("發送通知失敗: {}", e.getMessage());
            // 通知失敗不影響主流程
        }
    }

    @Override
    @Transactional
    public void cancelSiteChange(Long userId) {
        WorkerProfile profile = workerProfileRepository.findByUserId(userId)
                .orElseThrow(() -> new BusinessException(404, "工人資料不存在"));

        java.util.List<SiteChangeRequest> requests = siteChangeRequestRepository.findByWorkerId(profile.getId());
        SiteChangeRequest pending = requests.stream()
                .filter(r -> r.getStatus() == AuditStatus.PENDING)
                .findFirst()
                .orElseThrow(() -> new BusinessException(400, "沒有待審批的轉地盤申請"));

        siteChangeRequestRepository.delete(pending);
        log.info("轉地盤申請已取消: requestId={}, workerId={}", pending.getId(), profile.getId());
    }

    @Override
    public Page<SiteChangeRequest> getChangeHistory(Long userId, int page, int size) {
        WorkerProfile profile = workerProfileRepository.findByUserId(userId)
                .orElseThrow(() -> new BusinessException(404, "工人資料不存在"));

        return siteChangeRequestRepository.findByWorkerId(profile.getId(), PageRequest.of(page, size));
    }

    /// 初始化工人在指定地盤的安全分（总分15分）
    private void _initWorkerSiteSafetyScore(Long workerId, Long siteId) {
        try {
            // 检查是否已存在记录
            java.util.Optional<WorkerSiteSafetyScore> existingOpt =
                    workerSiteSafetyScoreRepository.findByWorkerIdAndSiteId(workerId, siteId);
            
            if (existingOpt.isPresent()) {
                // 已存在记录，重置为15分
                WorkerSiteSafetyScore existing = existingOpt.get();
                existing.setSafetyScore(15);
                workerSiteSafetyScoreRepository.save(existing);
                log.info("工人在地盤的安全分已重置為15分: workerId={}, siteId={}", workerId, siteId);
            } else {
                // 不存在记录，创建新记录
                WorkerSiteSafetyScore newScore = WorkerSiteSafetyScore.builder()
                        .workerId(workerId)
                        .siteId(siteId)
                        .safetyScore(15)
                        .build();
                workerSiteSafetyScoreRepository.save(newScore);
                log.info("工人在地盤的安全分已初始化為15分: workerId={}, siteId={}", workerId, siteId);
            }
        } catch (Exception e) {
            log.error("初始化工人地盤安全分失敗: workerId={}, siteId={}, error={}", 
                    workerId, siteId, e.getMessage());
            // 初始化失敗不影響主流程
        }
    }
}

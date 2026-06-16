package com.fareast.worker.controller;

import com.fareast.worker.exception.BusinessException;
import com.fareast.worker.model.dto.ApiResponse;
import com.fareast.worker.model.entity.Company;
import com.fareast.worker.model.entity.Notification;
import com.fareast.worker.model.entity.NotificationType;
import com.fareast.worker.model.entity.Site;
import com.fareast.worker.model.entity.SiteApplication;
import com.fareast.worker.model.entity.SiteChangeRequest;
import com.fareast.worker.model.entity.User;
import com.fareast.worker.model.entity.WorkerProfile;
import com.fareast.worker.model.entity.WorkerSiteSafetyScore;
import com.fareast.worker.model.entity.WorkerCompanyChangeRequest;
import com.fareast.worker.model.enums.AuditStatus;
import com.fareast.worker.repository.AttendanceRepository;
import com.fareast.worker.repository.CompanyRepository;
import com.fareast.worker.repository.SiteApplicationRepository;
import com.fareast.worker.repository.SiteChangeRequestRepository;
import com.fareast.worker.repository.SiteRepository;
import com.fareast.worker.repository.UserRepository;
import com.fareast.worker.repository.WorkerProfileRepository;
import com.fareast.worker.repository.WorkerCompanyChangeRequestRepository;
import com.fareast.worker.repository.WorkerSiteSafetyScoreRepository;
import com.fareast.worker.service.NotificationService;
import com.fareast.worker.service.SiteService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

@Slf4j
@RestController
@RequestMapping("/contractor")
@PreAuthorize("hasRole('CONTRACTOR')")
public class ContractorController {

    @Autowired
    private SiteApplicationRepository siteApplicationRepository;

    @Autowired
    private WorkerProfileRepository workerProfileRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private CompanyRepository companyRepository;

    @Autowired
    private SiteRepository siteRepository;

    @Autowired
    private NotificationService notificationService;

    @Autowired
    private SiteChangeRequestRepository siteChangeRequestRepository;

    @Autowired
    private WorkerCompanyChangeRequestRepository workerCompanyChangeRequestRepository;

    @Autowired
    private SiteService siteService;

    @Autowired
    private WorkerSiteSafetyScoreRepository workerSiteSafetyScoreRepository;

    @Autowired
    private AttendanceRepository attendanceRepository;

    /** Convert SiteApplication to Map (safe for JSON) */
    private Map<String, Object> toAppMap(SiteApplication a) {
        Map<String, Object> m = new HashMap<>();
        m.put("id", a.getId());
        m.put("workerId", a.getWorkerId());
        m.put("siteId", a.getSiteId());
        m.put("companyId", a.getCompanyId());
        m.put("status", a.getStatus().name());
        m.put("remark", a.getRemark());
        m.put("reviewedBy", a.getReviewedBy());
        m.put("reviewedAt", a.getReviewedAt() == null ? null : a.getReviewedAt().toString());
        m.put("reviewRemark", a.getReviewRemark());
        m.put("createdAt", a.getCreatedAt() == null ? null : a.getCreatedAt().toString());
        m.put("dailyWage", a.getDailyWage());
        m.put("contractAttachment", a.getContractAttachment());

        // Worker info
        userRepository.findById(a.getWorkerId()).ifPresent(u -> {
            m.put("workerPhone", u.getPhone());
            m.put("workerName", u.getName());
            m.put("workerEnglishName", u.getEnglishName());
        });
        // Site info
        siteRepository.findById(a.getSiteId()).ifPresent(s -> {
            m.put("siteName", s.getName());
            m.put("siteAddress", s.getAddress());
        });
        return m;
    }

    /**
     * GET /contractor/applications
     * 判头查看自己公司的所有申请
     */
    @GetMapping("/applications")
    public ApiResponse<List<Map<String, Object>>> getApplications(
            @AuthenticationPrincipal String userId) {
        Long uid = Long.valueOf(userId);
        User user = userRepository.findById(uid)
                .orElseThrow(() -> new BusinessException(404, "用戶不存在"));
        Long companyId = user.getCompanyId();
        if (companyId == null) {
            return ApiResponse.success(List.of());
        }
        List<SiteApplication> apps = siteApplicationRepository.findByCompanyIdOrderByCreatedAtDesc(companyId);
        List<Map<String, Object>> data = apps.stream().map(this::toAppMap).collect(Collectors.toList());
        return ApiResponse.success(data);
    }

    /**
     * GET /contractor/applications/pending-count
     * 判头获取待审核申请数量
     */
    @GetMapping("/applications/pending-count")
    public ApiResponse<Map<String, Object>> getPendingCount(
            @AuthenticationPrincipal String userId) {
        Long uid = Long.valueOf(userId);
        User user = userRepository.findById(uid)
                .orElseThrow(() -> new BusinessException(404, "用戶不存在"));
        Long companyId = user.getCompanyId();
        long count = 0;
        if (companyId != null) {
            count += siteApplicationRepository.countByCompanyIdAndStatus(
                    companyId, AuditStatus.PENDING);
            count += siteChangeRequestRepository.countByCompanyIdAndStatus(
                    companyId, AuditStatus.PENDING);
            count += workerCompanyChangeRequestRepository.countByToCompanyIdAndStatus(
                    companyId, AuditStatus.PENDING);
        }
        Map<String, Object> result = new HashMap<>();
        result.put("count", count);
        return ApiResponse.success(result);
    }

    /**
     * POST /contractor/review-application
     * 判头审核申请：批准或拒绝
     * Body: { applicationId: 1, approved: true, reviewRemark: "..." }
     */
    @PostMapping("/review-application")
    @Transactional
    public ApiResponse<Map<String, Object>> reviewApplication(
            @AuthenticationPrincipal String userId,
            @RequestBody Map<String, Object> body) {
        Long uid = Long.valueOf(userId);
        Long applicationId = Long.valueOf(body.get("applicationId").toString());
        boolean approved = Boolean.TRUE.equals(body.get("approved"));
        String reviewRemark = (String) body.getOrDefault("reviewRemark", "");

        SiteApplication app = siteApplicationRepository.findById(applicationId)
                .orElseThrow(() -> new BusinessException(404, "申請不存在"));

        // Check if already reviewed
        if (app.getStatus() != AuditStatus.PENDING) {
            throw new BusinessException(400, "該申請已被處理");
        }

        // Verify the reviewer is from the correct company
        User reviewer = userRepository.findById(uid)
                .orElseThrow(() -> new BusinessException(404, "用戶不存在"));
        if (reviewer.getCompanyId() == null || !reviewer.getCompanyId().equals(app.getCompanyId())) {
            throw new BusinessException(403, "無權審核此申請");
        }

        if (approved) {
            app.setStatus(AuditStatus.APPROVED);
            // Update worker profile
            WorkerProfile profile = workerProfileRepository.findByUserId(app.getWorkerId())
                    .orElseThrow(() -> new BusinessException(404, "工人資料不存在"));
            profile.setCurrentSiteId(app.getSiteId());
            profile.setCurrentCompanyId(app.getCompanyId());
            if (app.getDailyWage() != null) {
                profile.setDailyWage(app.getDailyWage());
            }
            if (app.getContractAttachment() != null) {
                profile.setContractAttachment(app.getContractAttachment());
            }
            workerProfileRepository.save(profile);
            log.info("申請已批准，工人已加入地盤: applicationId={}, workerId={}, siteId={}",
                    app.getId(), app.getWorkerId(), app.getSiteId());
            
            // 初始化工人在地盤的安全分（总分15分）
            _initWorkerSiteSafetyScore(profile.getId(), app.getSiteId());
        } else {
            app.setStatus(AuditStatus.REJECTED);
            log.info("申請已拒絕: applicationId={}, workerId={}", app.getId(), app.getWorkerId());
        }

        app.setReviewedBy(uid);
        app.setReviewedAt(LocalDateTime.now());
        app.setReviewRemark(reviewRemark);
        siteApplicationRepository.save(app);

        // 发送通知给工人
        User worker = userRepository.findById(app.getWorkerId())
                .orElseThrow(() -> new BusinessException(404, "用戶不存在"));
        String siteName = siteRepository.findById(app.getSiteId())
                .map(Site::getName)
                .orElse("未知地盘");

        if (approved) {
            notificationService.send(
                    app.getWorkerId(),
                    NotificationType.APPLICATION_APPROVED,
                    "地盤申請已批准",
                    "您的地盤【" + siteName + "】申請已獲批准，可以入盤工作。",
                    app.getId(),
                    "SITE_APPLICATION"
            );
        } else {
            notificationService.send(
                    app.getWorkerId(),
                    NotificationType.APPLICATION_REJECTED,
                    "地盤申請被拒絕",
                    "您的地盤【" + siteName + "】申請被拒絕。" + (reviewRemark.isEmpty() ? "" : "原因：" + reviewRemark),
                    app.getId(),
                    "SITE_APPLICATION"
            );
        }

        Map<String, Object> result = new HashMap<>();
        result.put("status", app.getStatus().name());
        result.put("applicationId", app.getId());
        return ApiResponse.success(result);
    }

    /**
     * GET /contractor/company
     * 判头查看自己公司信息
     */
    @GetMapping("/company")
    public ApiResponse<Map<String, Object>> getMyCompany(
            @AuthenticationPrincipal String userId) {
        Long uid = Long.valueOf(userId);
        User user = userRepository.findById(uid)
                .orElseThrow(() -> new BusinessException(404, "用戶不存在"));
        Long companyId = user.getCompanyId();
        if (companyId == null) {
            throw new BusinessException(400, "您尚未關聯公司");
        }
        Company company = companyRepository.findById(companyId)
                .orElseThrow(() -> new BusinessException(404, "公司不存在"));
        Map<String, Object> m = new HashMap<>();
        m.put("id", company.getId());
        m.put("name", company.getName());
        m.put("address", company.getAddress());
        m.put("contactPerson", company.getContactPerson());
        m.put("contactPhone", company.getContactPhone());
        return ApiResponse.success(m);
    }

    /**
     * GET /contractor/workers
     * 判头查看自己公司下已批准的工人列表
     */
    @GetMapping("/workers")
    public ApiResponse<List<Map<String, Object>>> getMyWorkers(
            @AuthenticationPrincipal String userId) {
        Long uid = Long.valueOf(userId);
        User user = userRepository.findById(uid)
                .orElseThrow(() -> new BusinessException(404, "用戶不存在"));
        Long companyId = user.getCompanyId();
        if (companyId == null) {
            return ApiResponse.success(List.of());
        }
        List<WorkerProfile> profiles = workerProfileRepository.findByCurrentCompanyId(companyId);
        List<Map<String, Object>> data = profiles.stream().map(p -> {
            Map<String, Object> m = new HashMap<>();
            m.put("profileId", p.getId());
            m.put("userId", p.getUserId());
            m.put("workerNumber", p.getWorkerNumber());
            m.put("currentSiteId", p.getCurrentSiteId());
            m.put("dailyWage", p.getDailyWage());
            // User info
            userRepository.findById(p.getUserId()).ifPresent(u -> {
                m.put("phone", u.getPhone());
                m.put("name", u.getName());
                m.put("englishName", u.getEnglishName());
            });
            // Site info
            if (p.getCurrentSiteId() != null) {
                siteRepository.findById(p.getCurrentSiteId()).ifPresent(s -> {
                    m.put("siteName", s.getName());
                });
            }
            return m;
        }).collect(Collectors.toList());
        return ApiResponse.success(data);
    }

    /** Convert SiteChangeRequest to Map (safe for JSON) */
    private Map<String, Object> toChangeMap(SiteChangeRequest r) {
        Map<String, Object> m = new HashMap<>();
        m.put("id", r.getId());
        m.put("workerId", r.getWorkerId());
        m.put("fromSiteId", r.getFromSiteId());
        m.put("toSiteId", r.getToSiteId());
        m.put("companyId", r.getCompanyId());
        m.put("status", r.getStatus().name());
        m.put("reason", r.getReason());
        m.put("dailyWage", r.getDailyWage());
        m.put("contractAttachment", r.getContractAttachment());
        m.put("requestedAt", r.getRequestedAt() == null ? null : r.getRequestedAt().toString());
        m.put("processedAt", r.getProcessedAt() == null ? null : r.getProcessedAt().toString());
        m.put("processedBy", r.getProcessedBy());
        m.put("rejectReason", r.getRejectReason());

        // Worker info
        userRepository.findById(r.getWorkerId()).ifPresent(u -> {
            m.put("workerPhone", u.getPhone());
            m.put("workerName", u.getName());
            m.put("workerEnglishName", u.getEnglishName());
        });
        // From site info
        if (r.getFromSiteId() != null) {
            siteRepository.findById(r.getFromSiteId()).ifPresent(s -> {
                m.put("fromSiteName", s.getName());
            });
        }
        // To site info
        siteRepository.findById(r.getToSiteId()).ifPresent(s -> {
            m.put("toSiteName", s.getName());
            m.put("toSiteAddress", s.getAddress());
        });
        return m;
    }

    /**
     * GET /contractor/change-requests
     * 判头查看自己公司下的更换地盘申请
     */
    @GetMapping("/change-requests")
    public ApiResponse<List<Map<String, Object>>> getChangeRequests(
            @AuthenticationPrincipal String userId) {
        Long uid = Long.valueOf(userId);
        User user = userRepository.findById(uid)
                .orElseThrow(() -> new BusinessException(404, "用戶不存在"));
        Long companyId = user.getCompanyId();
        if (companyId == null) {
            return ApiResponse.success(List.of());
        }
        List<SiteChangeRequest> requests =
                siteChangeRequestRepository.findByCompanyIdOrderByRequestedAtDesc(
                        companyId);
        List<Map<String, Object>> data =
                requests.stream().map(this::toChangeMap).collect(Collectors.toList());
        return ApiResponse.success(data);
    }

    /**
     * POST /contractor/review-change
     * 判头审核更换地盘申请：批准或拒绝
     */
    @PostMapping("/review-change")
    @Transactional
    public ApiResponse<Map<String, Object>> reviewChangeRequest(
            @AuthenticationPrincipal String userId,
            @RequestBody Map<String, Object> body) {
        Long uid = Long.valueOf(userId);
        Long requestId = Long.valueOf(body.get("requestId").toString());
        boolean approved = Boolean.TRUE.equals(body.get("approved"));
        String reviewRemark = (String) body.getOrDefault("reviewRemark", "");

        siteService.reviewChangeRequest(uid, requestId, approved, reviewRemark);

        Map<String, Object> result = new HashMap<>();
        result.put("success", true);
        return ApiResponse.success(result);
    }

    /**
     * GET /contractor/sites
     * 通过公司工人所在的 current_site_id 获取地盘列表
     */
    @GetMapping("/sites")
    public ApiResponse<List<Map<String, Object>>> getMySites(
            @AuthenticationPrincipal String userId) {
        Long uid = Long.valueOf(userId);
        User user = userRepository.findById(uid)
                .orElseThrow(() -> new BusinessException(404, "用戶不存在"));
        Long companyId = user.getCompanyId();
        if (companyId == null) {
            return ApiResponse.success(List.of());
        }

        // 查询本公司下所有工人，收集他们所在的地盘ID（去重）
        List<WorkerProfile> profiles = workerProfileRepository.findByCurrentCompanyId(companyId);
        Set<Long> siteIds = profiles.stream()
                .map(WorkerProfile::getCurrentSiteId)
                .filter(Objects::nonNull)
                .collect(Collectors.toSet());

        // 同时补充该公司名下的所有地盘（工人在的 + 公司拥有的）
        siteRepository.findByCompanyId(companyId).forEach(s -> siteIds.add(s.getId()));

        // 根据地盘ID查询地盘详情
        List<Site> sites = siteRepository.findAllById(siteIds);
        List<Map<String, Object>> data = sites.stream().map(s -> {
            Map<String, Object> m = new HashMap<>();
            m.put("id", s.getId());
            m.put("name", s.getName());
            m.put("address", s.getAddress());
            m.put("managerName", s.getManagerName());
            m.put("managerPhone", s.getManagerPhone());
            return m;
        }).collect(Collectors.toList());
        return ApiResponse.success(data);
    }

    /**
     * GET /contractor/site-workers
     * 判头查看指定地盘下的工人列表（含今日考勤状态）
     */
    @GetMapping("/site-workers")
    public ApiResponse<Map<String, Object>> getSiteWorkers(
            @AuthenticationPrincipal String userId,
            @RequestParam(required = false) Long siteId) {
        Long uid = Long.valueOf(userId);
        User user = userRepository.findById(uid)
                .orElseThrow(() -> new BusinessException(404, "用戶不存在"));
        Long companyId = user.getCompanyId();
        if (companyId == null) {
            return ApiResponse.success(Map.of("workers", List.of(), "stats", Map.of("total", 0, "checkedIn", 0, "absent", 0)));
        }

        // 查询该判头公司下的工人
        List<WorkerProfile> profiles;
        if (siteId != null) {
            // 按地盘查，但只取属于该公司的工人
            profiles = workerProfileRepository.findByCurrentSiteId(siteId).stream()
                    .filter(p -> companyId.equals(p.getCurrentCompanyId()))
                    .collect(Collectors.toList());
        } else {
            profiles = workerProfileRepository.findByCurrentCompanyId(companyId);
        }

        LocalDate today = LocalDate.now();
        int total = profiles.size();
        int checkedIn = 0;
        int absent = 0;

        List<Map<String, Object>> workers = profiles.stream().map(p -> {
            Map<String, Object> m = new HashMap<>();
            m.put("profileId", p.getId());
            m.put("userId", p.getUserId());
            m.put("workerNumber", p.getWorkerNumber());
            m.put("currentSiteId", p.getCurrentSiteId());
            m.put("dailyWage", p.getDailyWage());
            // 从 worker_site_safety_scores 表获取地盤维度的安全分（15分制）
            Integer siteScore = null;
            if (p.getCurrentSiteId() != null) {
                Optional<WorkerSiteSafetyScore> scoreOpt = workerSiteSafetyScoreRepository
                        .findByWorkerIdAndSiteId(p.getId(), p.getCurrentSiteId());
                if (scoreOpt.isPresent()) {
                    siteScore = scoreOpt.get().getSafetyScore();
                } else {
                    siteScore = 15; // 默认15分
                }
            }
            m.put("safetyScore", siteScore);
            m.put("cardLocked", p.getCardLocked() != null && p.getCardLocked());
            m.put("blacklisted", p.getBlacklisted() != null && p.getBlacklisted());

            // User info
            userRepository.findById(p.getUserId()).ifPresent(u -> {
                m.put("phone", u.getPhone());
                m.put("name", u.getName());
                m.put("englishName", u.getEnglishName());
            });

            // Site info
            if (p.getCurrentSiteId() != null) {
                siteRepository.findById(p.getCurrentSiteId()).ifPresent(s -> {
                    m.put("siteName", s.getName());
                });
            }

            // 今日考勤状态
            Optional<com.fareast.worker.model.entity.Attendance> attOpt =
                    attendanceRepository.findByWorkerIdAndDate(p.getId(), today);
            if (attOpt.isPresent()) {
                com.fareast.worker.model.entity.Attendance att = attOpt.get();
                if (att.getCheckOutTime() != null) {
                    m.put("attendanceStatus", "已完成"); // 入场+离场都打卡了
                    m.put("checkedIn", true);
                    m.put("checkedOut", true);
                } else {
                    m.put("attendanceStatus", "已打卡"); // 只入场打卡
                    m.put("checkedIn", true);
                    m.put("checkedOut", false);
                }
            } else {
                m.put("attendanceStatus", "未打卡");
                m.put("checkedIn", false);
                m.put("checkedOut", false);
            }

            return m;
        }).collect(Collectors.toList());

        // 统计
        for (Map<String, Object> w : workers) {
            Boolean isCheckedIn = (Boolean) w.get("checkedIn");
            if (Boolean.TRUE.equals(isCheckedIn)) {
                checkedIn++;
            } else {
                absent++;
            }
        }

        Map<String, Object> stats = new HashMap<>();
        stats.put("total", total);
        stats.put("checkedIn", checkedIn);
        stats.put("absent", absent);

        Map<String, Object> result = new HashMap<>();
        result.put("workers", workers);
        result.put("stats", stats);
        return ApiResponse.success(result);
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

    // ─── 判頭：查看更換公司申請 ───

    @GetMapping("/company-change-requests")
    public ApiResponse<List<Map<String, Object>>> getCompanyChangeRequests(
            @AuthenticationPrincipal String userId) {
        Long uid = Long.valueOf(userId);
        User user = userRepository.findById(uid)
                .orElseThrow(() -> new BusinessException(404, "用戶不存在"));
        Long companyId = user.getCompanyId();
        if (companyId == null) {
            return ApiResponse.success(List.of());
        }
    List<WorkerCompanyChangeRequest> requests =
            workerCompanyChangeRequestRepository.findByToCompanyIdOrderByRequestedAtDesc(
                    companyId);
        
        List<Map<String, Object>> data = requests.stream().map(this::toCompanyChangeRequestMap).collect(Collectors.toList());
        return ApiResponse.success(data);
    }

    // ─── 判頭：審核更換公司申請 ───

    @PostMapping("/review-company-change")
    @Transactional
    public ApiResponse<Void> reviewCompanyChange(
            @AuthenticationPrincipal String userId,
            @RequestBody Map<String, Object> body) {
        Long uid = Long.valueOf(userId);
        User user = userRepository.findById(uid)
                .orElseThrow(() -> new BusinessException(404, "用戶不存在"));
        
        // 驗證必填字段
        if (!body.containsKey("requestId") || body.get("requestId") == null) {
            throw new BusinessException(400, "缺少申請ID");
        }
        if (!body.containsKey("approved") || body.get("approved") == null) {
            throw new BusinessException(400, "缺少審核結果");
        }
        
        Long requestId = Long.valueOf(body.get("requestId").toString());
        boolean approved = Boolean.valueOf(body.get("approved").toString());
        String reviewRemark = body.containsKey("reviewRemark") ? body.get("reviewRemark").toString() : null;
        
        // 查詢申請
        java.util.Optional<WorkerCompanyChangeRequest> reqOpt =
                workerCompanyChangeRequestRepository.findById(requestId);
        if (reqOpt.isEmpty()) {
            throw new BusinessException(404, "申請不存在");
        }
        
        WorkerCompanyChangeRequest req = reqOpt.get();
        
        // 驗證狀態
        if (req.getStatus() != AuditStatus.PENDING) {
            throw new BusinessException(400, "申請已審核，不能重複操作");
        }
        
        // 驗證權限：只能審核發給自己公司的申請
        if (!req.getToCompanyId().equals(user.getCompanyId())) {
            throw new BusinessException(403, "無權限審核此申請");
        }
        
        if (approved) {
            req.setStatus(AuditStatus.APPROVED);
            // 更新工人的當前公司
            WorkerProfile profile = workerProfileRepository.findById(req.getWorkerId())
                    .orElseThrow(() -> new BusinessException(404, "工人資料不存在"));
            Long fromCompanyId = profile.getCurrentCompanyId();
            profile.setCurrentCompanyId(req.getToCompanyId());
            // 同步日薪
            if (req.getDailySalary() != null) {
                profile.setDailyWage(req.getDailySalary());
            }
            // 同步合约附件
            if (req.getContractAttachment() != null) {
                profile.setContractAttachment(req.getContractAttachment());
            }
            workerProfileRepository.saveAndFlush(profile);
            log.info("更換公司申請已批准: requestId={}, workerId={}, fromCompanyId={}, toCompanyId={}, dailySalary={}",
                    req.getId(), req.getWorkerId(), fromCompanyId, req.getToCompanyId(), req.getDailySalary());
        } else {
            req.setStatus(AuditStatus.REJECTED);
            req.setRejectReason(reviewRemark);
            log.info("更換公司申請已拒絕: requestId={}, workerId={}", req.getId(), req.getWorkerId());
        }
        
        req.setProcessedAt(java.time.LocalDateTime.now());
        req.setProcessedBy(uid);
        workerCompanyChangeRequestRepository.save(req);
        
        // 發送通知給工人
        try {
            WorkerProfile workerProfile = workerProfileRepository.findById(req.getWorkerId())
                    .orElseThrow(() -> new BusinessException(404, "工人資料不存在"));
            String companyName = companyRepository.findById(req.getToCompanyId())
                    .map(Company::getName)
                    .orElse("未知公司");
            
            NotificationType type;
            String title;
            String content;
            
            if (approved) {
                type = NotificationType.APPLICATION_APPROVED; // 復用通知類型
                title = "更換公司申請已批准";
                content = "您的更換公司申請已批准，新公司：" + companyName;
            } else {
                type = NotificationType.APPLICATION_REJECTED; // 復用通知類型
                title = "更換公司申請已拒絕";
                content = "您的更換公司申請已拒絕" +
                        (reviewRemark != null && !reviewRemark.isEmpty() ? "，原因：" + reviewRemark : "");
            }
            
            notificationService.send(
                    workerProfile.getUserId(),
                    type,
                    title,
                    content,
                    req.getId(),
                    "WORKER_COMPANY_CHANGE_REQUEST"
            );
            log.info("已發送審核結果通知給工人: userId={}, workerId={}", 
                    workerProfile.getUserId(), req.getWorkerId());
        } catch (Exception e) {
            log.error("發送通知失敗: {}", e.getMessage());
            // 通知失敗不影響主流程
        }
        
        return ApiResponse.success(null);
    }

    // ─── 更換公司申請 Map 轉換 ───

    private Map<String, Object> toCompanyChangeRequestMap(WorkerCompanyChangeRequest r) {
        Map<String, Object> m = new HashMap<>();
        m.put("id", r.getId());
        m.put("workerId", r.getWorkerId());
        m.put("fromCompanyId", r.getFromCompanyId());
        // 查詢來源公司名稱
        String fromCompanyName = companyRepository.findById(r.getFromCompanyId())
                .map(Company::getName)
                .orElse("未知公司");
        m.put("fromCompanyName", fromCompanyName);
        m.put("toCompanyId", r.getToCompanyId());
        // 查詢目標公司名稱
        String toCompanyName = companyRepository.findById(r.getToCompanyId())
                .map(Company::getName)
                .orElse("未知公司");
        m.put("toCompanyName", toCompanyName);
        m.put("reason", r.getReason());
        m.put("status", r.getStatus().name());
        m.put("requestedAt", r.getRequestedAt() == null ? null : r.getRequestedAt().toString());
        m.put("processedAt", r.getProcessedAt() == null ? null : r.getProcessedAt().toString());
        m.put("processedBy", r.getProcessedBy());
        m.put("rejectReason", r.getRejectReason());
        
        // 查詢工人信息
        workerProfileRepository.findById(r.getWorkerId()).ifPresent(p -> {
            userRepository.findById(p.getUserId()).ifPresent(u -> {
                m.put("workerName", u.getName());
                m.put("workerPhone", u.getPhone());
                m.put("workerEnglishName", u.getEnglishName());
            });
        });
        
        return m;
    }
}

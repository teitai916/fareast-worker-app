package com.fareast.worker.controller;

import com.fareast.worker.exception.BusinessException;
import com.fareast.worker.model.dto.ApiResponse;
import com.fareast.worker.model.entity.*;
import com.fareast.worker.model.enums.AuditStatus;
import com.fareast.worker.model.enums.UserRole;
import com.fareast.worker.repository.*;
import com.fareast.worker.service.AdminService;
import com.fareast.worker.service.InternalAttendanceService;
import com.fareast.worker.service.NotificationService;
import com.fareast.worker.service.WeatherWarningService;
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
@RequestMapping("/internal")
@PreAuthorize("hasAnyRole('SITE_MANAGER','PROJECT_MANAGER','INSTALL_MANAGER','SAFETY_OFFICER','SUPER_ADMIN')")
public class InternalController {

    @Autowired
    private AdminService adminService;

    @Autowired
    private WorkerProfileRepository workerProfileRepository;

    @Autowired
    private SiteRepository siteRepository;

    @Autowired
    private CompanyRepository companyRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private StaffSiteRepository staffSiteRepository;

    @Autowired
    private StaffSiteApplicationRepository staffSiteApplicationRepository;

    @Autowired
    private NotificationService notificationService;

    @Autowired
    private InternalAttendanceService internalAttendanceService;

    @Autowired
    private BlacklistRecordRepository blacklistRecordRepository;

    @Autowired
    private WorkerSiteSafetyScoreRepository workerSiteSafetyScoreRepository;

    @Autowired
    private WeatherWarningService weatherWarningService;

    // ==================== Home ====================

    /**
     * GET /internal/home
     * 首页数据：用户信息、当前地盘、已加入地盘列表、待审核申请、今日考勤
     */
    @GetMapping("/home")
    public ApiResponse<Map<String, Object>> getHome(@AuthenticationPrincipal String userId) {
        Long uid = Long.valueOf(userId);
        User user = userRepository.findById(uid)
                .orElseThrow(() -> new BusinessException(404, "用戶不存在"));

        Map<String, Object> result = new HashMap<>();

        // 用户信息
        Map<String, Object> userMap = new HashMap<>();
        userMap.put("id", user.getId());
        userMap.put("name", user.getName());
        userMap.put("phone", user.getPhone());
        userMap.put("role", user.getRole().name());
        result.put("user", userMap);

        // SUPER_ADMIN 自动拥有所有地盘
        if (user.getRole() == UserRole.SUPER_ADMIN) {
            _ensureSuperAdminSites(uid);
        }

        // 已加入的地盘列表
        List<StaffSite> mySites = staffSiteRepository.findByUserId(uid);
        List<Map<String, Object>> siteList = mySites.stream().map(ss -> {
            Map<String, Object> m = new HashMap<>();
            m.put("siteId", ss.getSiteId());
            m.put("isCurrent", ss.getIsCurrent());
            siteRepository.findById(ss.getSiteId()).ifPresent(site -> {
                m.put("name", site.getName());
                m.put("address", site.getAddress());
            });
            return m;
        }).collect(Collectors.toList());
        result.put("mySites", siteList);

        // 当前地盘
        StaffSite currentSs = mySites.stream()
                .filter(ss -> Boolean.TRUE.equals(ss.getIsCurrent()))
                .findFirst().orElse(null);
        Map<String, Object> currentSite = null;
        if (currentSs != null) {
            Optional<Site> siteOpt = siteRepository.findById(currentSs.getSiteId());
            if (siteOpt.isPresent()) {
                Site s = siteOpt.get();
                currentSite = new HashMap<>();
                currentSite.put("id", s.getId());
                currentSite.put("name", s.getName());
                currentSite.put("address", s.getAddress());
                currentSite.put("companyId", s.getCompanyId());
            }
        }
        result.put("currentSite", currentSite);
        result.put("hasSite", currentSite != null);

        // 待审核申请
        List<StaffSiteApplication> pendingApps = staffSiteApplicationRepository
                .findByUserIdAndStatus(uid, AuditStatus.PENDING);
        boolean hasPendingApplication = !pendingApps.isEmpty();
        result.put("hasPendingApplication", hasPendingApplication);
        if (hasPendingApplication) {
            Map<String, Object> appMap = new HashMap<>();
            StaffSiteApplication app = pendingApps.get(0);
            appMap.put("id", app.getId());
            appMap.put("siteId", app.getSiteId());
            siteRepository.findById(app.getSiteId()).ifPresent(site ->
                    appMap.put("siteName", site.getName()));
            appMap.put("status", app.getStatus().name());
            appMap.put("createdAt", app.getCreatedAt() != null ? app.getCreatedAt().toString() : null);
            result.put("pendingApplication", appMap);
        } else {
            result.put("pendingApplication", null);
        }

        // 可用地盘列表（还未加入的）
        Set<Long> joinedSiteIds = mySites.stream().map(StaffSite::getSiteId).collect(Collectors.toSet());
        List<Map<String, Object>> availableSites = siteRepository.findAll().stream()
                .filter(s -> !joinedSiteIds.contains(s.getId()))
                .map(this::toSiteMap)
                .collect(Collectors.toList());
        result.put("availableSites", availableSites);

        // 今日考勤
        Map<String, Object> todayAtt = _getTodayAttendance(uid);
        result.put("todayAttendance", todayAtt);

        return ApiResponse.success(result);
    }

    /**
     * SUPER_ADMIN 自动加入所有地盘
     */
    private void _ensureSuperAdminSites(Long userId) {
        List<Site> allSites = siteRepository.findAll();
        for (Site site : allSites) {
            Optional<StaffSite> existing = staffSiteRepository.findByUserIdAndSiteId(userId, site.getId());
            if (existing.isEmpty()) {
                StaffSite ss = StaffSite.builder()
                        .userId(userId)
                        .siteId(site.getId())
                        .isCurrent(allSites.indexOf(site) == 0) // 第一个设为当前
                        .joinedAt(LocalDateTime.now())
                        .build();
                staffSiteRepository.save(ss);
            }
        }
        // 如果没有当前地盘，设第一个为当前
        Optional<StaffSite> current = staffSiteRepository.findByUserIdAndIsCurrentTrue(userId);
        if (current.isEmpty()) {
            List<StaffSite> sites = staffSiteRepository.findByUserId(userId);
            if (!sites.isEmpty()) {
                StaffSite first = sites.get(0);
                first.setIsCurrent(true);
                staffSiteRepository.save(first);
            }
        }
    }

    // ==================== Apply Site ====================

    /**
     * POST /internal/apply-site
     * 申请加入地盘
     */
    @PostMapping("/apply-site")
    @Transactional
    public ApiResponse<Map<String, Object>> applySite(
            @AuthenticationPrincipal String userId,
            @RequestBody Map<String, Object> body) {
        Long uid = Long.valueOf(userId);
        User user = userRepository.findById(uid)
                .orElseThrow(() -> new BusinessException(404, "用戶不存在"));

        if (!body.containsKey("siteId") || body.get("siteId") == null) {
            return ApiResponse.error("請選擇地盤");
        }
        Long siteId = Long.valueOf(body.get("siteId").toString());

        // 检查是否已加入
        Optional<StaffSite> existing = staffSiteRepository.findByUserIdAndSiteId(uid, siteId);
        if (existing.isPresent()) {
            return ApiResponse.error("您已加入此地盤");
        }

        // 检查是否有待审核申请
        boolean hasPending = staffSiteApplicationRepository.existsByUserIdAndSiteIdAndStatus(
                uid, siteId, AuditStatus.PENDING);
        if (hasPending) {
            return ApiResponse.error("您已申請此地盤，請等待審批");
        }

        // SUPER_ADMIN 直接加入，无需审批
        if (user.getRole() == UserRole.SUPER_ADMIN) {
            _addSiteAndSetCurrent(uid, siteId);
            Map<String, Object> result = new HashMap<>();
            result.put("autoApproved", true);
            result.put("siteId", siteId);
            return ApiResponse.success(result);
        }

        // 查该地盘是否有 SITE_MANAGER 已加入
        boolean hasManager = staffSiteRepository.findByUserId(uid).stream()
                .anyMatch(ss -> {
                    Optional<User> u = userRepository.findById(ss.getUserId());
                    return u.isPresent() && u.get().getRole() == UserRole.SITE_MANAGER;
                });
        // 更准确的：查 staff_sites 中 site_id 下是否存在 SITE_MANAGER 角色的用户
        boolean hasSiteManager = _hasSiteManagerForSite(siteId);

        if (hasSiteManager) {
            // 需要审批
            StaffSiteApplication app = StaffSiteApplication.builder()
                    .userId(uid)
                    .siteId(siteId)
                    .status(AuditStatus.PENDING)
                    .createdAt(LocalDateTime.now())
                    .build();
            app = staffSiteApplicationRepository.save(app);

            // 通知该地盘的 SITE_MANAGER
            _notifySiteManagers(siteId, user, siteId);

            Map<String, Object> result = new HashMap<>();
            result.put("applicationId", app.getId());
            result.put("status", "PENDING");
            result.put("autoApproved", false);
            return ApiResponse.success(result);
        } else {
            // 无 SITE_MANAGER，自动通过
            _addSiteAndSetCurrent(uid, siteId);
            Map<String, Object> result = new HashMap<>();
            result.put("autoApproved", true);
            result.put("siteId", siteId);
            return ApiResponse.success(result);
        }
    }

    private boolean _hasSiteManagerForSite(Long siteId) {
        List<StaffSite> siteStaff = staffSiteRepository.findByUserId(siteId); // not right
        // Actually need to find all staff_sites for ALL users that reference this site
        // Let me do a different approach
        List<User> allUsers = userRepository.findAll();
        for (User u : allUsers) {
            if (u.getRole() == UserRole.SITE_MANAGER) {
                Optional<StaffSite> ss = staffSiteRepository.findByUserIdAndSiteId(u.getId(), siteId);
                if (ss.isPresent()) {
                    return true;
                }
            }
        }
        return false;
    }

    private void _notifySiteManagers(Long siteId, User applicant, Long targetSiteId) {
        Site site = siteRepository.findById(siteId).orElse(null);
        String siteName = site != null ? site.getName() : "未知地盤";
        List<User> allUsers = userRepository.findAll();
        for (User u : allUsers) {
            if (u.getRole() == UserRole.SITE_MANAGER) {
                Optional<StaffSite> ss = staffSiteRepository.findByUserIdAndSiteId(u.getId(), siteId);
                if (ss.isPresent()) {
                    notificationService.send(
                            u.getId(),
                            com.fareast.worker.model.entity.NotificationType.APPLICATION_SUBMITTED,
                            "新地盤申請",
                            "工作人員 " + applicant.getName() + " 申請加入地盤【" + siteName + "】，請審批。",
                            targetSiteId,
                            "STAFF_SITE_APPLICATION");
                }
            }
        }
    }

    private void _addSiteAndSetCurrent(Long userId, Long siteId) {
        // 取消所有 is_current
        List<StaffSite> mySites = staffSiteRepository.findByUserId(userId);
        for (StaffSite ss : mySites) {
            if (Boolean.TRUE.equals(ss.getIsCurrent())) {
                ss.setIsCurrent(false);
                staffSiteRepository.save(ss);
            }
        }

        StaffSite newSs = StaffSite.builder()
                .userId(userId)
                .siteId(siteId)
                .isCurrent(true)
                .joinedAt(LocalDateTime.now())
                .build();
        staffSiteRepository.save(newSs);
        log.info("工作人員加入地盤: userId={}, siteId={}", userId, siteId);
    }

    // ==================== Cancel Application ====================

    @PostMapping("/cancel-site-application")
    public ApiResponse<Void> cancelSiteApplication(@AuthenticationPrincipal String userId) {
        Long uid = Long.valueOf(userId);
        List<StaffSiteApplication> pending = staffSiteApplicationRepository
                .findByUserIdAndStatus(uid, AuditStatus.PENDING);
        if (pending.isEmpty()) {
            throw new BusinessException(400, "沒有待審核的申請");
        }
        staffSiteApplicationRepository.delete(pending.get(0));
        return ApiResponse.success(null);
    }

    // ==================== My Sites ====================

    @GetMapping("/my-sites")
    public ApiResponse<List<Map<String, Object>>> getMySites(@AuthenticationPrincipal String userId) {
        Long uid = Long.valueOf(userId);
        List<StaffSite> mySites = staffSiteRepository.findByUserId(uid);
        List<Map<String, Object>> result = mySites.stream().map(ss -> {
            Map<String, Object> m = new HashMap<>();
            m.put("siteId", ss.getSiteId());
            m.put("isCurrent", ss.getIsCurrent());
            m.put("joinedAt", ss.getJoinedAt() != null ? ss.getJoinedAt().toString() : null);
            siteRepository.findById(ss.getSiteId()).ifPresent(site -> {
                m.put("name", site.getName());
                m.put("address", site.getAddress());
            });
            return m;
        }).collect(Collectors.toList());
        return ApiResponse.success(result);
    }

    // ==================== Switch Site ====================

    @PutMapping("/switch-site/{siteId}")
    @Transactional
    public ApiResponse<Void> switchSite(
            @AuthenticationPrincipal String userId,
            @PathVariable Long siteId) {
        Long uid = Long.valueOf(userId);

        // SUPER_ADMIN 可切到任何地盘
        User user = userRepository.findById(uid)
                .orElseThrow(() -> new BusinessException(404, "用戶不存在"));
        if (user.getRole() != UserRole.SUPER_ADMIN) {
            Optional<StaffSite> ss = staffSiteRepository.findByUserIdAndSiteId(uid, siteId);
            if (ss.isEmpty()) {
                throw new BusinessException(400, "您未加入此地盤");
            }
        }

        // 取消所有 is_current
        List<StaffSite> mySites = staffSiteRepository.findByUserId(uid);
        for (StaffSite s : mySites) {
            if (Boolean.TRUE.equals(s.getIsCurrent())) {
                s.setIsCurrent(false);
                staffSiteRepository.save(s);
            }
        }

        // SUPER_ADMIN 未加入时自动加入
        Optional<StaffSite> target = staffSiteRepository.findByUserIdAndSiteId(uid, siteId);
        if (target.isPresent()) {
            target.get().setIsCurrent(true);
            staffSiteRepository.save(target.get());
        } else {
            StaffSite newSs = StaffSite.builder()
                    .userId(uid)
                    .siteId(siteId)
                    .isCurrent(true)
                    .joinedAt(LocalDateTime.now())
                    .build();
            staffSiteRepository.save(newSs);
        }

        log.info("工作人員切換地盤: userId={}, siteId={}", uid, siteId);
        return ApiResponse.success(null);
    }

    // ==================== Locked Workers ====================

    @GetMapping("/workers/locked")
    public ApiResponse<List<Map<String, Object>>> getLockedWorkers() {
        List<WorkerProfile> locked = workerProfileRepository.findByCardLockedTrue();
        List<Map<String, Object>> result = locked.stream().map(this::toWorkerMap).collect(Collectors.toList());
        return ApiResponse.success(result);
    }

    // ==================== Worker Lookup by Number ====================

    @GetMapping("/workers/by-number/{workerNumber}")
    public ApiResponse<Map<String, Object>> getWorkerByNumber(@PathVariable String workerNumber) {
        WorkerProfile profile = workerProfileRepository.findByWorkerNumber(workerNumber)
                .orElseThrow(() -> new BusinessException(404, "未找到該工人編號: " + workerNumber));
        Map<String, Object> result = toWorkerMap(profile);

        // 查詢地盤維度安全分（15分制，來自 worker_site_safety_scores）
        Long siteId = profile.getCurrentSiteId();
        if (siteId != null) {
            java.util.Optional<WorkerSiteSafetyScore> siteScoreOpt =
                    workerSiteSafetyScoreRepository.findByWorkerIdAndSiteId(profile.getId(), siteId);
            if (siteScoreOpt.isPresent()) {
                result.put("siteSafetyScore", siteScoreOpt.get().getSafetyScore());
            } else {
                result.put("siteSafetyScore", 15);
            }
        } else {
            result.put("siteSafetyScore", 15);
        }
        result.put("siteSafetyTotal", 15);

        return ApiResponse.success(result);
    }

    // ==================== Deduct & Lock (existing) ====================

    @PostMapping("/workers/{id}/deduct")
    public ApiResponse<Map<String, Object>> deductScore(
            @AuthenticationPrincipal String userId,
            @PathVariable Long id,
            @RequestBody Map<String, Object> body) {
        Integer points = Integer.valueOf(body.get("points").toString());
        String reason = (String) body.getOrDefault("reason", "");
        
        // 记录扣分日志（仅记录，不再扣 personal 100分制）
        adminService.deductScore(id, points, reason, Long.valueOf(userId));

        WorkerProfile profile = workerProfileRepository.findById(id).orElse(null);

        // 同時扣除地盤維度安全分（worker_site_safety_scores, 15分制）
        if (profile != null && profile.getCurrentSiteId() != null) {
            java.util.Optional<WorkerSiteSafetyScore> siteScoreOpt =
                    workerSiteSafetyScoreRepository.findByWorkerIdAndSiteId(id, profile.getCurrentSiteId());
            WorkerSiteSafetyScore siteScore;
            if (siteScoreOpt.isPresent()) {
                siteScore = siteScoreOpt.get();
                int newSiteScore = Math.max(0, siteScore.getSafetyScore() - points);
                siteScore.setSafetyScore(newSiteScore);
            } else {
                siteScore = WorkerSiteSafetyScore.builder()
                        .workerId(id)
                        .siteId(profile.getCurrentSiteId())
                        .safetyScore(Math.max(0, 15 - points))
                        .build();
            }
            workerSiteSafetyScoreRepository.save(siteScore);
            log.info("地盤安全分已扣减: workerId={}, siteId={}, deducted={}, newScore={}",
                    id, profile.getCurrentSiteId(), points, siteScore.getSafetyScore());
        }

        // 檢查是否需要自動鎖卡和加入黑名單（只檢查地盤安全分為 0）
        boolean scoreIsZero = false;
        if (profile != null && profile.getCurrentSiteId() != null) {
            java.util.Optional<WorkerSiteSafetyScore> siteScoreOpt2 =
                    workerSiteSafetyScoreRepository.findByWorkerIdAndSiteId(id, profile.getCurrentSiteId());
            if (siteScoreOpt2.isPresent() && siteScoreOpt2.get().getSafetyScore() != null
                    && siteScoreOpt2.get().getSafetyScore() == 0) {
                scoreIsZero = true;
            }
        }
        boolean autoLocked = false;
        boolean autoBlacklisted = false;
        if (profile != null && scoreIsZero
                && !Boolean.TRUE.equals(profile.getCardLocked())) {
            profile.setCardLocked(true);
            workerProfileRepository.save(profile);
            autoLocked = true;
            log.info("安全分為0，自動鎖卡: workerId={}", id);
        }
        // 安全分為0，自動加入黑名單
        if (profile != null && scoreIsZero
                && !Boolean.TRUE.equals(profile.getBlacklisted())) {
            profile.setBlacklisted(true);
            profile.setBlacklistReason(reason);
            workerProfileRepository.save(profile);
            // 同步寫入 blacklist_records
            BlacklistRecord record = BlacklistRecord.builder()
                    .workerId(profile.getId())
                    .name(profile.getChineseName())
                    .workerRegistrationNum(profile.getWorkerRegistrationNum())
                    .companyId(profile.getCurrentCompanyId())
                    .status(true)
                    .reason(reason)
                    .build();
            blacklistRecordRepository.save(record);
            autoBlacklisted = true;
            log.info("安全分為0，自動加入黑名單: workerId={}", id);
        }

        Map<String, Object> result = new HashMap<>();
        // 返回地盤安全分（15分制）
        if (profile != null && profile.getCurrentSiteId() != null) {
            java.util.Optional<WorkerSiteSafetyScore> siteScoreOpt3 =
                    workerSiteSafetyScoreRepository.findByWorkerIdAndSiteId(id, profile.getCurrentSiteId());
            result.put("safetyScore", siteScoreOpt3.map(WorkerSiteSafetyScore::getSafetyScore).orElse(15));
        } else {
            result.put("safetyScore", 15);
        }
        result.put("cardLocked", profile != null ? profile.getCardLocked() : false);
        result.put("autoLocked", autoLocked);
        result.put("autoBlacklisted", autoBlacklisted);

        // 保存重複的 siteScore 返回部分，已在上面合併
        return ApiResponse.success(result);
    }

    @PostMapping("/workers/{id}/toggle-lock")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN','SAFETY_ADMIN')")
    public ApiResponse<Void> toggleLock(
            @PathVariable Long id,
            @RequestBody Map<String, Object> body) {
        boolean lock = Boolean.TRUE.equals(body.get("lock"));
        log.info("toggleLock 请求: workerId={}, lock={}", id, lock);
        if (lock) {
            adminService.lockCard(id);
        } else {
            adminService.unlockCard(id);
        }
        return ApiResponse.success(null);
    }

    // ==================== Blacklist (existing) ====================

    @PostMapping("/blacklist/add")
    public ApiResponse<Void> addBlacklist(
            @AuthenticationPrincipal String userId,
            @RequestBody Map<String, Object> body) {
        Long workerId = Long.valueOf(body.get("workerId").toString());
        String reason = (String) body.get("reason");
        adminService.addBlacklist(workerId, reason, Long.valueOf(userId));
        return ApiResponse.success(null);
    }

    /**
     * POST /internal/workers/blacklist-by-phone
     * 按手机号搜索工人 → 加入黑名单（更新blacklist_records + worker_profiles）
     */
    @PostMapping("/workers/blacklist-by-phone")
    @Transactional
    public ApiResponse<Map<String, Object>> blacklistByPhone(
            @AuthenticationPrincipal String userId,
            @RequestBody Map<String, Object> body) {
        Long uid = Long.valueOf(userId);
        String phone = (String) body.get("phone");
        if (phone == null || phone.trim().isEmpty()) {
            throw new BusinessException(400, "請輸入手機號碼");
        }

        // 按手机号查找用户
        String phoneTrimmed = phone.trim();
        log.info("blacklistByPhone 查询手机号: '{}'", phoneTrimmed);
        User targetUser = userRepository.findByPhone(phoneTrimmed)
                .orElseThrow(() -> new BusinessException(404, "未找到該手機號碼的工人"));

        // 查找 WorkerProfile
        WorkerProfile profile = workerProfileRepository.findByUserId(targetUser.getId())
                .orElseThrow(() -> new BusinessException(404, "該用戶不是工人"));

        if (Boolean.TRUE.equals(profile.getBlacklisted())) {
            throw new BusinessException(400, "該工人已在黑名單中");
        }

        String reason = (String) body.getOrDefault("reason", "");
        String safetyCardNumber = (String) body.get("safetyCardNumber");
        String safetyCardAttachment = (String) body.get("safetyCardAttachment");
        String workerName = _getWorkerName(profile);

        // 1. 更新 blacklist_records 表
        Optional<BlacklistRecord> existingRecord = blacklistRecordRepository.findByWorkerId(profile.getId());
        if (existingRecord.isPresent()) {
            // 已有记录 → 更新 status 为 true
            BlacklistRecord record = existingRecord.get();
            record.setStatus(true);
            // 同时记录 added_by 和 reason（标记本次操作）
            record.setAddedBy(uid);
            record.setReason(reason);
            record.setAddedAt(LocalDateTime.now());
            blacklistRecordRepository.save(record);
            log.info("更新黑名單記錄: workerId={}, id={}", profile.getId(), record.getId());
        } else {
            // 无记录 → 新增
            // 取公司名称
            String companyName = null;
            if (profile.getCurrentCompanyId() != null) {
                Optional<Company> companyOpt = companyRepository.findById(profile.getCurrentCompanyId());
                if (companyOpt.isPresent()) {
                    companyName = companyOpt.get().getName();
                }
            }

            BlacklistRecord newRecord = BlacklistRecord.builder()
                    .workerId(profile.getId())
                    .reason(reason)
                    .addedBy(uid)
                    .addedAt(LocalDateTime.now())
                    .name(workerName)
                    .workerRegistrationNum(profile.getWorkerRegistrationNum())
                    .age(null)  // 年龄未收集
                    .companyId(profile.getCurrentCompanyId())
                    .status(true)
                    .build();
            blacklistRecordRepository.save(newRecord);
            log.info("新增黑名單記錄: workerId={}, name={}", profile.getId(), workerName);
        }

        // 2. 设置 worker_profiles.blacklisted = true + card_locked = true
        profile.setBlacklisted(true);
        profile.setCardLocked(true);

        // 3. 更新平安卡信息
        if (safetyCardNumber != null && !safetyCardNumber.trim().isEmpty()) {
            profile.setSafetyCard(safetyCardNumber.trim());
        }
        if (safetyCardAttachment != null && !safetyCardAttachment.trim().isEmpty()) {
            profile.setContractAttachment(safetyCardAttachment.trim());
        }
        workerProfileRepository.save(profile);

        Map<String, Object> result = new HashMap<>();
        result.put("workerNumber", profile.getWorkerNumber());
        result.put("chineseName", workerName);
        result.put("phone", phone);
        result.put("safetyCardNumber", profile.getSafetyCard());
        result.put("blacklisted", true);
        result.put("cardLocked", true);

        log.info("通過手機號加入黑名單: phone={}, workerId={}, reason={}", phone, profile.getId(), reason);
        return ApiResponse.success(result);
    }

    // ==================== Helper ====================

    private Map<String, Object> toSiteMap(Site s) {
        if (s == null) return null;
        Map<String, Object> m = new HashMap<>();
        m.put("id", s.getId());
        m.put("name", s.getName());
        m.put("address", s.getAddress());
        m.put("companyId", s.getCompanyId());
        return m;
    }

    private Map<String, Object> toWorkerMap(WorkerProfile w) {
        Map<String, Object> m = new HashMap<>();
        m.put("id", w.getId());
        m.put("userId", w.getUserId());
        m.put("workerNumber", w.getWorkerNumber());

        // 优先取 WorkerProfile 的中文名，没有则从 User 表取
        String workerName = w.getChineseName();
        if (workerName == null || workerName.trim().isEmpty()) {
            User user = userRepository.findById(w.getUserId()).orElse(null);
            if (user != null) {
                workerName = user.getName();
            }
        }
        m.put("chineseName", workerName);
        m.put("englishName", w.getEnglishName());
        m.put("safetyScore", 0); // 已廢棄，安全分在地盤維度管理
        m.put("cardLocked", w.getCardLocked());
        m.put("blacklisted", w.getBlacklisted());
        m.put("currentSiteId", w.getCurrentSiteId());
        m.put("currentCompanyId", w.getCurrentCompanyId());

        if (w.getCurrentSiteId() != null) {
            siteRepository.findById(w.getCurrentSiteId()).ifPresent(site ->
                    m.put("siteName", site.getName()));
        }
        if (w.getCurrentCompanyId() != null) {
            companyRepository.findById(w.getCurrentCompanyId()).ifPresent(company ->
                    m.put("companyName", company.getName()));
        }
        return m;
    }

    private Map<String, Object> _getTodayAttendance(Long userId) {
        try {
            return internalAttendanceService.getDailyRecord(userId, LocalDate.now());
        } catch (Exception e) {
            log.warn("獲取内部人員今日考勤失敗: userId={}", userId, e);
            return null;
        }
    }

    private String _getWorkerName(WorkerProfile profile) {
        String name = profile.getChineseName();
        if (name == null || name.trim().isEmpty()) {
            User user = userRepository.findById(profile.getUserId()).orElse(null);
            if (user != null) name = user.getName();
        }
        return name != null ? name : "未知";
    }

    // ==================== Attendance API ====================

    @PostMapping("/check-in")
    @Transactional
    public ApiResponse<Map<String, Object>> checkIn(
            @AuthenticationPrincipal String userId,
            @RequestBody Map<String, Object> body) {
        Long uid = Long.valueOf(userId);
        String checkInType = (String) body.getOrDefault("checkInType", "MANUAL");
        Long siteId = body.get("siteId") != null ? Long.valueOf(body.get("siteId").toString()) : null;

        // 如果未指定siteId，用当前地盘
        if (siteId == null) {
            StaffSite currentSs = staffSiteRepository.findByUserIdAndIsCurrentTrue(uid).orElse(null);
            if (currentSs == null) {
                return ApiResponse.error("請先選擇一個地盤");
            }
            siteId = currentSs.getSiteId();
        }

        Attendance att = internalAttendanceService.checkIn(uid, siteId, checkInType);
        Map<String, Object> data = new HashMap<>();
        data.put("id", att.getId());
        data.put("checkInTime", att.getCheckInTime());
        data.put("checkOutTime", att.getCheckOutTime());
        data.put("date", att.getDate());
        data.put("siteId", att.getSiteId());
        if (att.getSiteId() != null) {
            siteRepository.findById(att.getSiteId()).ifPresent(site ->
                    data.put("siteName", site.getName()));
        }
        return ApiResponse.success(data);
    }

    @GetMapping("/attendance/daily")
    public ApiResponse<Map<String, Object>> getDailyRecord(
            @AuthenticationPrincipal String userId,
            @RequestParam String date) {
        Long uid = Long.valueOf(userId);
        LocalDate localDate = LocalDate.parse(date);
        Map<String, Object> record = internalAttendanceService.getDailyRecord(uid, localDate);
        return ApiResponse.success(record);
    }

    @GetMapping("/attendance/monthly")
    public ApiResponse<java.util.List<Integer>> getMonthlyDays(
            @AuthenticationPrincipal String userId,
            @RequestParam int year,
            @RequestParam int month) {
        Long uid = Long.valueOf(userId);
        java.util.List<Integer> days = internalAttendanceService.getMonthlyDays(uid, year, month);
        return ApiResponse.success(days);
    }

    /**
     * GET /internal/weather-warnings
     * 获取当前生效的天气警告（台风/暴雨/酷热/工作暑热）
     */
    @GetMapping("/weather-warnings")
    public ApiResponse<Map<String, Object>> getWeatherWarnings() {
        Map<String, Object> result = new HashMap<>();
        result.put("warnsum", weatherWarningService.getWarnsum());
        result.put("hsww", weatherWarningService.getHsww());
        return ApiResponse.success(result);
    }

    // ==================== Companies ====================

    /** 获取所有公司列表（供内部人和安全人员使用） */
    @GetMapping("/companies")
    public ApiResponse<List<Map<String, Object>>> getCompanies() {
        List<Company> companies = companyRepository.findAll();
        List<Map<String, Object>> result = companies.stream().map(c -> {
            Map<String, Object> m = new HashMap<>();
            m.put("id", c.getId());
            m.put("name", c.getName());
            m.put("type", c.getType().name());
            return m;
        }).collect(Collectors.toList());
        return ApiResponse.success(result);
    }

    /** 获取所有地盘列表 */
    @GetMapping("/sites")
    public ApiResponse<List<Map<String, Object>>> getSites() {
        List<Site> sites = siteRepository.findAll();
        List<Map<String, Object>> result = sites.stream().map(s -> {
            Map<String, Object> m = new HashMap<>();
            m.put("id", s.getId());
            m.put("name", s.getName());
            m.put("address", s.getAddress());
            m.put("companyId", s.getCompanyId());
            return m;
        }).collect(Collectors.toList());
        return ApiResponse.success(result);
    }
}

package com.fareast.worker.controller;

import com.fareast.worker.model.dto.ApiResponse;
import com.fareast.worker.model.dto.PageResponse;
import com.fareast.worker.model.dto.WorkerRegisterRequest;
import com.fareast.worker.model.entity.User;
import com.fareast.worker.model.entity.SafetyDeduction;
import com.fareast.worker.model.entity.Site;
import com.fareast.worker.model.entity.SiteApplication;
import com.fareast.worker.model.entity.SiteChangeRequest;
import com.fareast.worker.model.entity.WorkerProfile;
import com.fareast.worker.model.entity.WorkerSiteSafetyScore;
import com.fareast.worker.model.entity.WorkerCompanyChangeRequest;
import com.fareast.worker.model.entity.Company;
import com.fareast.worker.model.entity.BlacklistRecord;
import com.fareast.worker.model.entity.Notification;
import com.fareast.worker.model.entity.NotificationType;
import com.fareast.worker.model.enums.CompanyType;
import com.fareast.worker.model.enums.UserRole;
import com.fareast.worker.model.enums.AuditStatus;
import com.fareast.worker.exception.BusinessException;
import org.springframework.transaction.annotation.Transactional;
import com.fareast.worker.repository.SiteApplicationRepository;
import com.fareast.worker.repository.SiteChangeRequestRepository;
import com.fareast.worker.repository.SiteRepository;
import com.fareast.worker.repository.UserRepository;
import com.fareast.worker.repository.WorkerProfileRepository;
import com.fareast.worker.repository.BlacklistRecordRepository;
import com.fareast.worker.repository.CompanyRepository;
import com.fareast.worker.repository.WorkerCompanyChangeRequestRepository;
import org.springframework.web.multipart.MultipartFile;
import com.fareast.worker.repository.WorkerSiteSafetyScoreRepository;
import com.fareast.worker.service.NotificationService;
import com.fareast.worker.service.SiteService;
import com.fareast.worker.service.WorkerService;
import jakarta.validation.Valid;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import org.springframework.http.MediaType;

@Slf4j
@RestController
@RequestMapping("/worker")
@PreAuthorize("hasRole('WORKER')")
public class WorkerController {

    @Autowired
    private WorkerService workerService;

    @Autowired
    private SiteService siteService;

    @Autowired
    private SiteApplicationRepository siteApplicationRepository;

    @Autowired
    private SiteChangeRequestRepository siteChangeRequestRepository;

    @Autowired
    private SiteRepository siteRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private WorkerProfileRepository workerProfileRepository;

    @Autowired
    private BlacklistRecordRepository blacklistRecordRepository;

    @Autowired
    private NotificationService notificationService;

    @Autowired
    private CompanyRepository companyRepository;

    @Autowired
    private WorkerSiteSafetyScoreRepository workerSiteSafetyScoreRepository;

    @Autowired
    private WorkerCompanyChangeRequestRepository workerCompanyChangeRequestRepository;

    /** Convert WorkerProfile to a safe Map (no lazy associations) */
    private Map<String, Object> toProfileMap(WorkerProfile p) {
        Map<String, Object> m = new HashMap<>();
        m.put("id", p.getId());
        m.put("userId", p.getUserId());
        m.put("workerNumber", p.getWorkerNumber());
        m.put("faceRegistered", p.getFaceRegistered() != null && p.getFaceRegistered());
        m.put("faceImageUrl", p.getFaceImageUrl());
        m.put("safetyScore", p.getSafetyScore());
        m.put("blacklisted", p.getBlacklisted() != null && p.getBlacklisted());
        m.put("cardLocked", p.getCardLocked() != null && p.getCardLocked());
        m.put("currentSiteId", p.getCurrentSiteId());
        m.put("currentCompanyId", p.getCurrentCompanyId());
        m.put("hkId", p.getHkid());
        m.put("chineseName", p.getChineseName());
        m.put("englishName", p.getEnglishName());
        m.put("safetyCard", p.getSafetyCard());
        m.put("workerRegistrationNum", p.getWorkerRegistrationNum());
        m.put("dailyWage", p.getDailyWage());
        m.put("contractAttachment", p.getContractAttachment());
        m.put("blacklistReason", p.getBlacklistReason());
        
        // 查詢公司名稱
        if (p.getCurrentCompanyId() != null) {
            try {
                Company company = companyRepository.findById(p.getCurrentCompanyId()).orElse(null);
                if (company != null) {
                    m.put("companyName", company.getName());
                }
            } catch (Exception ignored) {}
        }
        
        return m;
    }

    /** Convert Site to a safe Map */
    private Map<String, Object> toSiteMap(Site s) {
        if (s == null)
            return null;
        Map<String, Object> m = new HashMap<>();
        m.put("id", s.getId());
        m.put("name", s.getName());
        m.put("address", s.getAddress());
        m.put("companyId", s.getCompanyId());
        m.put("managerName", s.getManagerName());
        m.put("managerPhone", s.getManagerPhone());
        m.put("latitude", s.getLatitude());
        m.put("longitude", s.getLongitude());
        return m;
    }

    @GetMapping("/profile")
    public ApiResponse<Map<String, Object>> getProfile(@AuthenticationPrincipal String userId) {
        WorkerProfile profile = workerService.getProfile(Long.valueOf(userId));
        User user = userRepository.findById(Long.valueOf(userId))
                .orElseThrow(() -> new BusinessException(404, "用戶不存在"));
        Map<String, Object> data = toProfileMap(profile);
        data.put("phone", user.getPhone());
        data.put("name", user.getName());
        data.put("englishName", user.getEnglishName());
        return ApiResponse.success(data);
    }

    @PutMapping("/profile")
    public ApiResponse<Map<String, Object>> updateProfile(
            @AuthenticationPrincipal String userId,
            @RequestBody Map<String, Object> body) {
        WorkerProfile profile = workerService.getProfile(Long.valueOf(userId));
        User user = userRepository.findById(Long.valueOf(userId))
                .orElseThrow(() -> new BusinessException(404, "用戶不存在"));

        if (body.containsKey("chineseName")) {
            String v = (String) body.get("chineseName");
            profile.setChineseName(v);
            user.setName(v);
        }
        if (body.containsKey("englishName")) {
            String v = (String) body.get("englishName");
            profile.setEnglishName(v);
            user.setEnglishName(v);
        }
        if (body.containsKey("hkId"))
            profile.setHkid((String) body.get("hkId"));
        if (body.containsKey("safetyCard"))
            profile.setSafetyCard((String) body.get("safetyCard"));
        if (body.containsKey("workerRegistrationNum"))
            profile.setWorkerRegistrationNum((String) body.get("workerRegistrationNum"));
        if (body.containsKey("dailyWage")) {
            Object dw = body.get("dailyWage");
            if (dw != null)
                profile.setDailyWage(new java.math.BigDecimal(dw.toString()));
        }

        workerProfileRepository.save(profile);
        userRepository.save(user);
        return ApiResponse.success(toProfileMap(profile));
    }

    @PostMapping("/register")
    public ApiResponse<Map<String, Object>> register(@Valid @RequestBody WorkerRegisterRequest request) {
        Map<String, Object> result = workerService.registerWorker(request);
        return ApiResponse.success(result);
    }

    @PostMapping("/face-register")
    public ApiResponse<Map<String, Object>> faceRegister(
            @AuthenticationPrincipal String userId,
            @RequestParam("faceImage") org.springframework.web.multipart.MultipartFile faceImage) {
        Map<String, Object> result = workerService.registerFace(Long.valueOf(userId), faceImage);
        return ApiResponse.success(result);
    }

    @GetMapping("/safety-score")
    public ApiResponse<Map<String, Object>> getSafetyScore(@AuthenticationPrincipal String userId) {
        WorkerProfile profile = workerService.getProfile(Long.valueOf(userId));
        return ApiResponse.success(Map.of("score", profile.getSafetyScore()));
    }

    @GetMapping("/deductions")
    public ApiResponse<PageResponse<SafetyDeduction>> getDeductions(
            @AuthenticationPrincipal String userId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size) {
        Page<SafetyDeduction> deductions = workerService.getDeductions(Long.valueOf(userId), page, size);
        PageResponse<SafetyDeduction> pageResponse = PageResponse.<SafetyDeduction>builder()
                .content(deductions.getContent())
                .page(deductions.getNumber())
                .size(deductions.getSize())
                .totalElements(deductions.getTotalElements())
                .totalPages(deductions.getTotalPages())
                .first(deductions.isFirst())
                .last(deductions.isLast())
                .build();
        return ApiResponse.success(pageResponse);
    }

    /**
     * Worker home page data.
     */
    @GetMapping("/home")
    public ApiResponse<Map<String, Object>> getWorkerHome(@AuthenticationPrincipal String userId) {
        Long uid = Long.valueOf(userId);
        WorkerProfile profile = workerService.getProfile(uid);

        Map<String, Object> currentSiteMap = null;
        if (profile.getCurrentSiteId() != null) {
            try {
                Site s = siteService.getSiteById(profile.getCurrentSiteId());
                currentSiteMap = toSiteMap(s);
            } catch (Exception ignored) {
            }
        }

        List<SiteApplication> pendingApps = siteApplicationRepository
                .findByWorkerIdAndStatus(uid, AuditStatus.PENDING);
        boolean hasPendingApplication = !pendingApps.isEmpty();

        // 【新增】检查是否有待审核的公司变更申请
        java.util.Optional<WorkerCompanyChangeRequest> pendingCompanyChange = workerCompanyChangeRequestRepository
                .findByWorkerIdAndStatus(profile.getId(), AuditStatus.PENDING);
        boolean hasPendingCompanyChange = pendingCompanyChange.isPresent();

        List<Map<String, Object>> availableSites = siteService.getAllSites().stream()
                .map(this::toSiteMap)
                .collect(Collectors.toList());

        Map<String, Object> result = new HashMap<>();
        result.put("profile", toProfileMap(profile));
        result.put("currentSite", currentSiteMap);
        // 【修改】合并地盘变更和公司变更的 pending 状态
        result.put("hasPendingApplication", hasPendingApplication || hasPendingCompanyChange);
        result.put("hasPendingCompanyChange", hasPendingCompanyChange);
        if (hasPendingCompanyChange) {
            result.put("pendingCompanyChange", toCompanyChangeRequestMap(pendingCompanyChange.get()));
        }
        result.put("pendingApplication", hasPendingApplication ? toAppMap(pendingApps.get(0)) : null);
        result.put("availableSites", availableSites);
        return ApiResponse.success(result);
    }

    private Map<String, Object> toAppMap(SiteApplication a) {
        Map<String, Object> m = new HashMap<>();
        m.put("id", a.getId());
        m.put("workerId", a.getWorkerId());
        m.put("siteId", a.getSiteId());
        // 查詢地盤名稱
        String siteName = siteRepository.findById(a.getSiteId())
                .map(Site::getName)
                .orElse("未知地盤");
        m.put("siteName", siteName);
        m.put("companyId", a.getCompanyId());
        m.put("dailyWage", a.getDailyWage());
        m.put("contractAttachment", a.getContractAttachment());
        m.put("status", a.getStatus().name());
        m.put("remark", a.getRemark());
        m.put("reviewRemark", a.getReviewRemark());
        m.put("createdAt", a.getCreatedAt() == null ? null : a.getCreatedAt().toString());
        return m;
    }

    private Map<String, Object> toChangeRequestMap(SiteChangeRequest r) {
        Map<String, Object> m = new HashMap<>();
        m.put("id", r.getId());
        m.put("workerId", r.getWorkerId());
        m.put("fromSiteId", r.getFromSiteId());
        // 查詢來源地盤名稱
        String fromSiteName = r.getFromSiteId() != null
                ? siteRepository.findById(r.getFromSiteId()).map(Site::getName).orElse("未知地盤")
                : "無";
        m.put("fromSiteName", fromSiteName);
        m.put("toSiteId", r.getToSiteId());
        // 查詢目標地盤名稱
        String toSiteName = siteRepository.findById(r.getToSiteId())
                .map(Site::getName)
                .orElse("未知地盤");
        m.put("toSiteName", toSiteName);
        m.put("companyId", r.getCompanyId());
        m.put("reason", r.getReason());
        m.put("dailyWage", r.getDailyWage());
        m.put("contractAttachment", r.getContractAttachment());
        m.put("status", r.getStatus().name());
        m.put("requestedAt", r.getRequestedAt() == null ? null : r.getRequestedAt().toString());
        m.put("processedAt", r.getProcessedAt() == null ? null : r.getProcessedAt().toString());
        m.put("processedBy", r.getProcessedBy());
        m.put("rejectReason", r.getRejectReason());
        return m;
    }

    @PostMapping("/apply-site")
    public ApiResponse<Map<String, Object>> applySite(
            @AuthenticationPrincipal String userId,
            @RequestBody Map<String, Object> body) {
        Long uid = Long.valueOf(userId);

        // 1. 必填字段验证
        if (!body.containsKey("siteId") || body.get("siteId") == null)
            return ApiResponse.error("请选择地盘");
        if (!body.containsKey("companyId") || body.get("companyId") == null)
            return ApiResponse.error("请选择所属判头公司");
        if (!body.containsKey("dailyWage") || body.get("dailyWage") == null)
            return ApiResponse.error("请填写每日薪酬");
        if (!body.containsKey("contractAttachment") || body.get("contractAttachment") == null
                || body.get("contractAttachment").toString().isEmpty())
            return ApiResponse.error("请上传雇佣合同附件");

        Long siteId = Long.valueOf(body.get("siteId").toString());
        Long companyId = Long.valueOf(body.get("companyId").toString());
        String remark = (String) body.getOrDefault("remark", "");

        WorkerProfile profile = workerService.getProfile(uid);

        // 2. 黑名单检查
        List<BlacklistRecord> blacklist = blacklistRecordRepository.findByWorkerIdAndRemovedAtIsNull(uid);
        if (blacklist != null && !blacklist.isEmpty()) {
            return ApiResponse.error("您已被列入黑名单，无法申请加入地盘");
        }

        if (profile.getCurrentSiteId() != null) {
            return ApiResponse.error("您已有地盘，请先离开当前地盘");
        }

        boolean alreadyApplied = siteApplicationRepository.existsByWorkerIdAndSiteIdAndStatusIn(
                uid, siteId, List.of(AuditStatus.PENDING, AuditStatus.APPROVED));
        if (alreadyApplied) {
            return ApiResponse.error("您已申請或已加入工地，請勿重复申請");
        }

        // 3. 验证 companyId 对应的 Company 存在且类型为 CONTRACTOR
        Company company = companyRepository.findById(companyId)
                .orElseThrow(() -> new BusinessException(404, "判頭公司不存在"));
        if (company.getType() != CompanyType.CONTRACTOR) {
            return ApiResponse.error("所选公司不是判头公司");
        }

        Site site = siteService.getSiteById(siteId);

        // 4. 创建申请，包含 dailyWage 和 contractAttachment
        java.math.BigDecimal dailyWage = new java.math.BigDecimal(body.get("dailyWage").toString());
        String contractAttachment = body.get("contractAttachment").toString();

        SiteApplication application = SiteApplication.builder()
                .workerId(uid)
                .siteId(siteId)
                .companyId(companyId)
                .dailyWage(dailyWage)
                .contractAttachment(contractAttachment)
                .status(AuditStatus.PENDING)
                .remark(remark)
                .build();
        application = siteApplicationRepository.save(application);

        // 发送审核通知给所有关联该公司的判头用户
        List<User> contractors = userRepository.findAll().stream()
                .filter(u -> u.getCompanyId() != null && u.getCompanyId().equals(companyId)
                        && u.getRole() == UserRole.CONTRACTOR)
                .collect(java.util.stream.Collectors.toList());
        String workerName = profile.getChineseName() != null ? profile.getChineseName() : profile.getUser().getName();
        for (User contractor : contractors) {
            notificationService.send(
                    contractor.getId(),
                    NotificationType.APPLICATION_SUBMITTED,
                    "新地盤申請",
                    "工人 " + workerName + " 申請加入地盤【" + site.getName() + "】，請審核。",
                    application.getId(),
                    "SITE_APPLICATION");
        }

        return ApiResponse.success(toAppMap(application));
    }

    @PostMapping("/face-register-base64")
    public ApiResponse<Map<String, Object>> faceRegisterBase64(
            @AuthenticationPrincipal String userId,
            @RequestBody Map<String, String> body) {
        String base64 = body.get("image");
        Map<String, Object> result = workerService.registerFaceBase64(Long.valueOf(userId), base64);
        return ApiResponse.success(result);
    }

    @PostMapping("/verify-face")
    public ApiResponse<Map<String, Object>> verifyFace(
            @AuthenticationPrincipal String userId,
            @RequestBody Map<String, String> body) {
        String base64 = body.get("image");
        Map<String, Object> result = workerService.verifyFace(Long.valueOf(userId), base64);
        return ApiResponse.success(result);
    }

    @GetMapping("/my-applications")
    public ApiResponse<List<Map<String, Object>>> getMyApplications(@AuthenticationPrincipal String userId) {
        List<SiteApplication> apps = siteApplicationRepository.findByWorkerId(Long.valueOf(userId));
        List<Map<String, Object>> data = apps.stream().map(this::toAppMap).collect(Collectors.toList());
        return ApiResponse.success(data);
    }

    @GetMapping("/my-change-requests")
    public ApiResponse<List<Map<String, Object>>> getMyChangeRequests(@AuthenticationPrincipal String userId) {
        List<SiteChangeRequest> requests = siteChangeRequestRepository.findByWorkerId(Long.valueOf(userId));
        List<Map<String, Object>> data = requests.stream().map(this::toChangeRequestMap).collect(Collectors.toList());
        return ApiResponse.success(data);
    }

    /**
     * GET /worker/site-safety-score
     * 获取工人在当前地盘的安全分（按地盘维度，总分15分）
     */
    @GetMapping("/site-safety-score")
    public ApiResponse<Map<String, Object>> getSiteSafetyScore(@AuthenticationPrincipal String userId) {
        Long uid = Long.valueOf(userId);
        WorkerProfile profile = workerService.getProfile(uid);

        Map<String, Object> result = new HashMap<>();

        // 如果没有当前地盘，返回个人安全分（按15分制换算）
        if (profile.getCurrentSiteId() == null) {
            int personalScore = (int) Math.round((profile.getSafetyScore() / 100.0) * 15);
            result.put("safetyScore", personalScore);
            result.put("totalScore", 15);
            result.put("siteId", null);
            result.put("message", "暂无当前地盘，显示个人安全分");
            return ApiResponse.success(result);
        }

        // 获取地盘维度的安全分
        Long siteId = profile.getCurrentSiteId();
        java.util.Optional<WorkerSiteSafetyScore> scoreOpt = workerSiteSafetyScoreRepository
                .findByWorkerIdAndSiteId(profile.getId(), siteId);

        int safetyScore;
        if (scoreOpt.isPresent()) {
            safetyScore = scoreOpt.get().getSafetyScore();
        } else {
            // 如果没有记录，初始化为15分
            WorkerSiteSafetyScore newScore = WorkerSiteSafetyScore.builder()
                    .workerId(profile.getId())
                    .siteId(siteId)
                    .safetyScore(15)
                    .build();
            workerSiteSafetyScoreRepository.save(newScore);
            safetyScore = 15;
            log.info("工人在地盘的安全分已初始化为15分: workerId={}, siteId={}", profile.getId(), siteId);
        }

        result.put("safetyScore", safetyScore);
        result.put("totalScore", 15);
        result.put("siteId", siteId);
        result.put("message", "成功获取地盘安全分");
        return ApiResponse.success(result);
    }

    // ─── 工人更换公司申请（JSON） ───

    @PostMapping(value = "/request-company-change", consumes = "application/json")
    @Transactional
    public ApiResponse<Void> requestCompanyChangeJson(
            @AuthenticationPrincipal String userId,
            @RequestBody Map<String, Object> body) {
        Long uid = Long.valueOf(userId);
        WorkerProfile profile = workerService.getProfile(uid);

        // 必填字段验证
        if (!body.containsKey("toCompanyId") || body.get("toCompanyId") == null) {
            throw new BusinessException(400, "請選擇目標公司");
        }
        Long toCompanyId = Long.valueOf(body.get("toCompanyId").toString());

        // 验证目标公司存在
        Company toCompany = companyRepository.findById(toCompanyId)
                .orElseThrow(() -> new BusinessException(404, "目標公司不存在"));

        // 【修改】如果有待审核申请，先自动撤销旧的，再创建新的
        java.util.Optional<WorkerCompanyChangeRequest> existingOpt = workerCompanyChangeRequestRepository
                .findByWorkerIdAndStatus(profile.getId(), AuditStatus.PENDING);
        if (existingOpt.isPresent()) {
            WorkerCompanyChangeRequest old = existingOpt.get();
            log.info("撤销旧更換公司申請: requestId={}, workerId={}", old.getId(), profile.getId());
            workerCompanyChangeRequestRepository.delete(old);
        }

        // 创建更换公司申请
        WorkerCompanyChangeRequest requestEntity = WorkerCompanyChangeRequest.builder()
                .workerId(profile.getId())
                .fromCompanyId(profile.getCurrentCompanyId())
                .toCompanyId(toCompanyId)
                .reason(body.containsKey("reason") && body.get("reason") != null
                        ? body.get("reason").toString()
                        : "工人主动申请")
                .contractAttachment(body.containsKey("contractAttachment") && body.get("contractAttachment") != null
                        ? body.get("contractAttachment").toString()
                        : null)
                .contractAttachmentName(body.containsKey("contractAttachmentName") && body.get("contractAttachmentName") != null
                        ? body.get("contractAttachmentName").toString()
                        : null)
                .dailySalary(body.containsKey("dailySalary") && body.get("dailySalary") != null
                        ? new java.math.BigDecimal(body.get("dailySalary").toString())
                        : null)
                .status(AuditStatus.PENDING)
                .requestedAt(java.time.LocalDateTime.now())
                .build();
        requestEntity = workerCompanyChangeRequestRepository.save(requestEntity);
        log.info("工人提交更換公司申請(JSON): requestId={}, workerId={}, fromCompanyId={}, toCompanyId={}",
                requestEntity.getId(), profile.getId(), profile.getCurrentCompanyId(), toCompanyId);

        // 发送通知给目标公司的所有判头
        sendCompanyChangeNotification(toCompany, profile, requestEntity);

        return ApiResponse.success(null);
    }

    // ─── 工人更换公司申请（multipart/form-data，直接接收文件） ───

    @PostMapping(value = "/request-company-change", consumes = "multipart/form-data")
    @Transactional
    public ApiResponse<Void> requestCompanyChangeMultipart(
            @AuthenticationPrincipal String userId,
            @RequestParam("toCompanyId") Long toCompanyId,
            @RequestParam(value = "reason", required = false) String reason,
            @RequestParam(value = "dailySalary", required = false) java.math.BigDecimal dailySalary,
            @RequestParam(value = "contractAttachment", required = false) MultipartFile contractFile) {
        Long uid = Long.valueOf(userId);
        WorkerProfile profile = workerService.getProfile(uid);

        // 验证目标公司存在
        Company toCompany = companyRepository.findById(toCompanyId)
                .orElseThrow(() -> new BusinessException(404, "目標公司不存在"));

        // 【修改】如果有待审核申请，先自动撤销旧的，再创建新的
        java.util.Optional<WorkerCompanyChangeRequest> existingOpt = workerCompanyChangeRequestRepository
                .findByWorkerIdAndStatus(profile.getId(), AuditStatus.PENDING);
        if (existingOpt.isPresent()) {
            WorkerCompanyChangeRequest old = existingOpt.get();
            log.info("撤销旧更換公司申請: requestId={}, workerId={}", old.getId(), profile.getId());
            workerCompanyChangeRequestRepository.delete(old);
        }

        // 处理上传的文件
        String contractAttachment = null;
        String contractAttachmentName = null;
        if (contractFile != null && !contractFile.isEmpty()) {
            contractAttachmentName = contractFile.getOriginalFilename();
            try {
                String uploadDir = System.getProperty("user.dir") + "/uploads/contracts/";
                java.io.File dir = new java.io.File(uploadDir);
                if (!dir.exists()) dir.mkdirs();
                String fileName = java.util.UUID.randomUUID().toString() + "_" + contractFile.getOriginalFilename();
                java.io.File destFile = new java.io.File(uploadDir + fileName);
                contractFile.transferTo(destFile);
                contractAttachment = "/api/v1/uploads/contracts/" + fileName;
                log.info("文件上传成功: {}", contractAttachment);
            } catch (Exception e) {
                log.error("文件上传失败", e);
                throw new BusinessException(500, "文件上傳失敗: " + e.getMessage());
            }
        }

        // 创建更换公司申请
        WorkerCompanyChangeRequest requestEntity = WorkerCompanyChangeRequest.builder()
                .workerId(profile.getId())
                .fromCompanyId(profile.getCurrentCompanyId())
                .toCompanyId(toCompanyId)
                .reason(reason != null ? reason : "工人主动申请")
                .contractAttachment(contractAttachment)
                .contractAttachmentName(contractAttachmentName)
                .dailySalary(dailySalary)
                .status(AuditStatus.PENDING)
                .requestedAt(java.time.LocalDateTime.now())
                .build();
        requestEntity = workerCompanyChangeRequestRepository.save(requestEntity);
        log.info("工人提交更換公司申請(multipart): requestId={}, workerId={}, fromCompanyId={}, toCompanyId={}",
                requestEntity.getId(), profile.getId(), profile.getCurrentCompanyId(), toCompanyId);

        // 发送通知给目标公司的所有判头
        sendCompanyChangeNotification(toCompany, profile, requestEntity);

        return ApiResponse.success(null);
    }

    // ─── 通知辅助方法 ───
    private void sendCompanyChangeNotification(Company toCompany, WorkerProfile profile, WorkerCompanyChangeRequest requestEntity) {
        List<User> contractors = userRepository.findByCompanyIdAndRole(toCompany.getId(), UserRole.CONTRACTOR);
        for (User contractor : contractors) {
            notificationService.send(
                    contractor.getId(),
                    NotificationType.APPLICATION_SUBMITTED,
                    "更換公司申請",
                    profile.getWorkerNumber() + " 申請更換至 " + toCompany.getName(),
                    requestEntity.getId(),
                    "WORKER_COMPANY_CHANGE_REQUEST");
        }
    }

    @GetMapping("/my-company-change-requests")
    public ApiResponse<List<Map<String, Object>>> getMyCompanyChangeRequests(@AuthenticationPrincipal String userId) {
        Long uid = Long.valueOf(userId);
        WorkerProfile profile = workerService.getProfile(uid);
        List<WorkerCompanyChangeRequest> requests = workerCompanyChangeRequestRepository
                .findByWorkerIdOrderByRequestedAtDesc(profile.getId());
        List<Map<String, Object>> data = requests.stream().map(this::toCompanyChangeRequestMap)
                .collect(Collectors.toList());
        return ApiResponse.success(data);
    }

    @DeleteMapping("/cancel-company-change")
    public ApiResponse<Void> cancelCompanyChange(@AuthenticationPrincipal String userId) {
        Long uid = Long.valueOf(userId);
        WorkerProfile profile = workerService.getProfile(uid);

        java.util.Optional<WorkerCompanyChangeRequest> existingOpt = workerCompanyChangeRequestRepository
                .findByWorkerIdAndStatus(profile.getId(), AuditStatus.PENDING);
        if (existingOpt.isEmpty()) {
            throw new BusinessException(400, "沒有待審核的更換公司申請");
        }

        workerCompanyChangeRequestRepository.delete(existingOpt.get());
        log.info("工人撤銷更換公司申請: requestId={}, workerId={}", existingOpt.get().getId(), profile.getId());

        return ApiResponse.success(null);
    }

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
        m.put("dailySalary", r.getDailySalary());
        m.put("contractAttachment", r.getContractAttachment());
        m.put("contractAttachmentName", r.getContractAttachmentName());
        return m;
    }
}

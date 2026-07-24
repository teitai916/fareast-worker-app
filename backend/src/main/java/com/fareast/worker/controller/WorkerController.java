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
import com.fareast.worker.model.entity.WorkerSite;
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
import com.fareast.worker.repository.WorkerSiteRepository;
import com.fareast.worker.service.NotificationService;
import com.fareast.worker.service.SiteService;
import com.fareast.worker.service.WorkerService;
import com.fareast.worker.service.WeatherWarningService;
import jakarta.validation.Valid;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.Page;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import org.springframework.http.MediaType;

@Slf4j
@RestController
@RequestMapping("/worker")
@PreAuthorize("hasRole('WORKER')")
public class WorkerController {

    /** 允许上传的文件扩展名 */
    private static final Set<String> ALLOWED_EXTENSIONS = Set.of("jpg", "jpeg", "png", "pdf");

    /** 允许的 MIME 类型（防扩展名伪造） */
    private static final Map<String, String> ALLOWED_MIME_TYPES = Map.of(
        "jpg", "image/jpeg",
        "jpeg", "image/jpeg",
        "png", "image/png",
        "pdf", "application/pdf"
    );

    @Autowired
    private WorkerService workerService;

    @Value("${file.upload-dir}")
    private String uploadDir;

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
    private WorkerSiteRepository workerSiteRepository;

    @Autowired
    private WorkerCompanyChangeRequestRepository workerCompanyChangeRequestRepository;

    @Autowired
    private WeatherWarningService weatherWarningService;

    /** Convert WorkerProfile to a safe Map (no lazy associations) */
    private Map<String, Object> toProfileMap(WorkerProfile p) {
        Map<String, Object> m = new HashMap<>();
        m.put("id", p.getId());
        m.put("userId", p.getUserId());
        m.put("workerNumber", p.getWorkerNumber());
        m.put("faceRegistered", true); // 人脸识别已移除，默认通过
        // 安全分已移至 worker_site_safety_scores 表管理
        m.put("safetyScore", null); // 前端不再使用此字段，使用 siteSafetyScore
        
        boolean isBlacklisted = p.getBlacklisted() != null && p.getBlacklisted();
        boolean isCardLocked = p.getCardLocked() != null && p.getCardLocked();
        
        m.put("blacklisted", isBlacklisted);
        m.put("cardLocked", isCardLocked);
        m.put("companyId", p.getCompanyId());
        m.put("chineseName", p.getChineseName());
        m.put("englishName", p.getEnglishName());
        m.put("safetyCard", p.getSafetyCard());
        m.put("safetyCardAttachment", p.getSafetyCardAttachment());
        m.put("workerRegistrationNum", p.getWorkerRegistrationNum());
        m.put("workerRegCertAttachment", p.getWorkerRegCertAttachment());
        m.put("dailyWage", p.getDailyWage());
        m.put("contractAttachment", p.getContractAttachment());
        m.put("blacklistReason", p.getBlacklistReason());
        m.put("emergencyContactName", p.getEmergencyContactName());
        m.put("emergencyContactPhone", p.getEmergencyContactPhone());
        m.put("birthDate", p.getBirthDate() != null ? p.getBirthDate().toString() : null);
        
        // 查詢公司名稱
        if (p.getCompanyId() != null) {
            try {
                Company company = companyRepository.findById(p.getCompanyId()).orElse(null);
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
        m.put("bluetoothBeaconId", s.getBluetoothBeaconId());
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
        if (body.containsKey("safetyCard"))
            profile.setSafetyCard((String) body.get("safetyCard"));
        if (body.containsKey("safetyCardAttachment"))
            profile.setSafetyCardAttachment((String) body.get("safetyCardAttachment"));
        if (body.containsKey("workerRegistrationNum"))
            profile.setWorkerRegistrationNum((String) body.get("workerRegistrationNum"));
        if (body.containsKey("workerRegCertAttachment"))
            profile.setWorkerRegCertAttachment((String) body.get("workerRegCertAttachment"));
        if (body.containsKey("dailyWage")) {
            Object dw = body.get("dailyWage");
            if (dw != null)
                profile.setDailyWage(new java.math.BigDecimal(dw.toString()));
        }
        if (body.containsKey("emergencyContactName"))
            profile.setEmergencyContactName((String) body.get("emergencyContactName"));
        if (body.containsKey("emergencyContactPhone"))
            profile.setEmergencyContactPhone((String) body.get("emergencyContactPhone"));

        // 驗證證書資料 4 項必填（若前台傳了任何一個證書相關欄位，則全部必填）
        boolean hasSafetyCard = profile.getSafetyCard() != null && !profile.getSafetyCard().trim().isEmpty();
        boolean hasSafetyCardAtt = profile.getSafetyCardAttachment() != null && !profile.getSafetyCardAttachment().trim().isEmpty();
        boolean hasRegNum = profile.getWorkerRegistrationNum() != null && !profile.getWorkerRegistrationNum().trim().isEmpty();
        boolean hasRegAtt = profile.getWorkerRegCertAttachment() != null && !profile.getWorkerRegCertAttachment().trim().isEmpty();

        // 只要填了任何一项证件资料，四项必须全部填写
        boolean anyFilled = hasSafetyCard || hasSafetyCardAtt || hasRegNum || hasRegAtt;
        if (anyFilled && !(hasSafetyCard && hasSafetyCardAtt && hasRegNum && hasRegAtt)) {
            throw new BusinessException(400, "請完善平安卡及工人註冊證資料（編號+附件需全部填寫）");
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

    /*
     * 人脸识别功能已注释（App Store 合规要求）
    @PostMapping("/face-register")
    public ApiResponse<Map<String, Object>> faceRegister(
            @AuthenticationPrincipal String userId,
            @RequestParam("faceImage") org.springframework.web.multipart.MultipartFile faceImage) {
        Map<String, Object> result = workerService.registerFace(Long.valueOf(userId), faceImage);
        return ApiResponse.success(result);
    }
    */

    @GetMapping("/safety-score")
    public ApiResponse<Map<String, Object>> getSafetyScore(@AuthenticationPrincipal String userId) {
        // 安全分已移至按地盤維度管理，返回當前地盤安全分
        return getSiteSafetyScore(userId, null);
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

        // 已加入的地盘列表（从 worker_sites 表读取）
        List<WorkerSite> workerSites = workerSiteRepository.findByWorkerId(profile.getId());
        List<Map<String, Object>> mySites = workerSites.stream().map(ws -> {
            Map<String, Object> m = new HashMap<>();
            m.put("siteId", ws.getSiteId());
            m.put("dailyWage", ws.getDailyWage());
            m.put("contractAttachment", ws.getContractAttachment());
            m.put("joinedAt", ws.getJoinedAt() != null ? ws.getJoinedAt().toString() : null);
            siteRepository.findById(ws.getSiteId()).ifPresent(site -> {
                m.put("name", site.getName());
                m.put("address", site.getAddress());
            });
            return m;
        }).collect(Collectors.toList());

        // 当前地盘取 mySites 第一条（前端可自行决定显示哪个）
        Map<String, Object> currentSiteMap = mySites.isEmpty() ? null : mySites.get(0);

        List<SiteApplication> pendingApps = siteApplicationRepository
                .findByWorkerIdAndStatus(uid, AuditStatus.PENDING);
        boolean hasPendingApplication = !pendingApps.isEmpty();

        // 检查是否有待审核的公司变更申请
        java.util.Optional<WorkerCompanyChangeRequest> pendingCompanyChange = workerCompanyChangeRequestRepository
                .findByWorkerIdAndStatus(profile.getId(), AuditStatus.PENDING);
        boolean hasPendingCompanyChange = pendingCompanyChange.isPresent();

        // 可用地盘列表（排除已加入的和已申请待审核的）
        Set<Long> joinedSiteIds = workerSites.stream().map(WorkerSite::getSiteId).collect(Collectors.toSet());
        // 也排除待审核申请中的地盘
        Set<Long> appliedSiteIds = pendingApps.stream().map(SiteApplication::getSiteId).collect(Collectors.toSet());
        joinedSiteIds.addAll(appliedSiteIds);
        List<Map<String, Object>> availableSites = siteService.getAllSites().stream()
                .filter(s -> !joinedSiteIds.contains(s.getId()))
                .map(this::toSiteMap)
                .collect(Collectors.toList());

        Map<String, Object> result = new HashMap<>();
        result.put("profile", toProfileMap(profile));
        result.put("currentSite", currentSiteMap);
        result.put("mySites", mySites);
        result.put("hasPendingApplication", hasPendingApplication || hasPendingCompanyChange);
        result.put("hasPendingCompanyChange", hasPendingCompanyChange);
        if (hasPendingCompanyChange) {
            result.put("pendingCompanyChange", toCompanyChangeRequestMap(pendingCompanyChange.get()));
        }
        result.put("pendingApplication", hasPendingApplication ? toAppMap(pendingApps.get(0)) : null);
        result.put("availableSites", availableSites);
        return ApiResponse.success(result);
    }

    // ==================== 多地盘切换 ====================

    /**
     * GET /worker/my-sites
     * 获取工人已加入的地盘列表（当前地盘由客户端本地管理）
     */
    @GetMapping("/my-sites")
    public ApiResponse<List<Map<String, Object>>> getMySites(@AuthenticationPrincipal String userId) {
        Long uid = Long.valueOf(userId);
        WorkerProfile profile = workerService.getProfile(uid);
        List<WorkerSite> workerSites = workerSiteRepository.findByWorkerId(profile.getId());
        List<Map<String, Object>> result = workerSites.stream().map(ws -> {
            Map<String, Object> m = new HashMap<>();
            m.put("siteId", ws.getSiteId());
            m.put("dailyWage", ws.getDailyWage());
            m.put("contractAttachment", ws.getContractAttachment());
            m.put("joinedAt", ws.getJoinedAt() != null ? ws.getJoinedAt().toString() : null);
            siteRepository.findById(ws.getSiteId()).ifPresent(site -> {
                m.put("name", site.getName());
                m.put("address", site.getAddress());
            });
            return m;
        }).collect(Collectors.toList());
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

    /**
     * 黑名单交叉比對：按姓名和工人注册证号跨工人比对 blacklist_records
     * 任一匹配（且 removed_at IS NULL）则返回错误提示，null 表示通过
     */
    private String checkBlacklistCross(WorkerProfile profile) {
        // 1. 姓名比对（优先取 WorkerProfile.chineseName，其次 User.name）
        String name = profile.getChineseName();
        if (name == null || name.trim().isEmpty()) {
            User user = userRepository.findById(profile.getUserId()).orElse(null);
            if (user != null) name = user.getName();
        }
        if (name != null && !name.trim().isEmpty()) {
            List<BlacklistRecord> byName = blacklistRecordRepository.findByNameAndStatusTrue(name.trim());
            if (byName != null && !byName.isEmpty()) {
                return "您的申請不批准，請聯絡所屬公司判頭";
            }
        }

        // 2. 工人注册证号比对
        String regNum = profile.getWorkerRegistrationNum();
        if (regNum != null && !regNum.trim().isEmpty()) {
            List<BlacklistRecord> byReg = blacklistRecordRepository
                    .findByWorkerRegistrationNumAndStatusTrue(regNum.trim());
            if (byReg != null && !byReg.isEmpty()) {
                return "您的申請不批准，請聯絡所屬公司判頭";
            }
        }

        return null; // 校验通过
    }

    @PostMapping("/apply-site")
    public ApiResponse<Map<String, Object>> applySite(
            @AuthenticationPrincipal String userId,
            @RequestBody Map<String, Object> body) {
        Long uid = Long.valueOf(userId);

        // 1. 必填字段验证
        if (!body.containsKey("siteId") || body.get("siteId") == null)
            return ApiResponse.error("请选择地盘");
        if (!body.containsKey("dailyWage") || body.get("dailyWage") == null)
            return ApiResponse.error("请填写每日薪酬");
        if (!body.containsKey("contractAttachment") || body.get("contractAttachment") == null
                || body.get("contractAttachment").toString().isEmpty())
            return ApiResponse.error("请上传雇佣合同附件");

        Long siteId = Long.valueOf(body.get("siteId").toString());
        String remark = (String) body.getOrDefault("remark", "");

        WorkerProfile profile = workerService.getProfile(uid);

        // companyId 可选：优先取请求中的，其次取工人当前公司
        Long companyId = body.get("companyId") != null
                ? Long.valueOf(body.get("companyId").toString())
                : profile.getCompanyId();
        if (companyId == null) {
            return ApiResponse.error("请选择所属判头公司");
        }

        // 1.5 證書資料驗證（平安卡編號+附件、註冊證編號+附件，4 項必填）
        if (profile.getSafetyCard() == null || profile.getSafetyCard().trim().isEmpty()
                || profile.getSafetyCardAttachment() == null || profile.getSafetyCardAttachment().trim().isEmpty()
                || profile.getWorkerRegistrationNum() == null || profile.getWorkerRegistrationNum().trim().isEmpty()
                || profile.getWorkerRegCertAttachment() == null || profile.getWorkerRegCertAttachment().trim().isEmpty()) {
            return ApiResponse.error("請先在個人資料完善平安卡及工人註冊證資料");
        }

        // 2. 黑名单检查
        List<BlacklistRecord> blacklist = blacklistRecordRepository.findByWorkerIdAndRemovedAtIsNull(uid);
        if (blacklist != null && !blacklist.isEmpty()) {
            return ApiResponse.error("您已被列入黑名单，无法申请加入地盘");
        }

        // 2.5 黑名单交叉比對（姓名/注册证号跨工人匹配）
        String crossMsg = checkBlacklistCross(profile);
        if (crossMsg != null) {
            return ApiResponse.error(crossMsg);
        }

        // 多地盘支持：检查是否已申请（PENDING）或已加入该地盘（worker_sites）
        boolean alreadyApplied = siteApplicationRepository.existsByWorkerIdAndSiteIdAndStatus(
                uid, siteId, AuditStatus.PENDING);
        boolean alreadyInSite = workerSiteRepository.findByWorkerIdAndSiteId(profile.getId(), siteId).isPresent();
        if (alreadyApplied || alreadyInSite) {
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

    /*
     * 人脸识别功能已注释（App Store 合规要求）
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
    */

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
     * 获取工人在指定地盘的安全分（按地盘维度，总分15分）
     */
    @GetMapping("/site-safety-score")
    public ApiResponse<Map<String, Object>> getSiteSafetyScore(
            @AuthenticationPrincipal String userId,
            @RequestParam(required = false) Long siteId) {
        Long uid = Long.valueOf(userId);
        WorkerProfile profile = workerService.getProfile(uid);

        Map<String, Object> result = new HashMap<>();

        // 如果没有指定地盘，返回第一条 worker_sites 中的地盘（或默认15分）
        if (siteId == null) {
            List<WorkerSite> sites = workerSiteRepository.findByWorkerId(profile.getId());
            if (sites.isEmpty()) {
                result.put("safetyScore", 15);
                result.put("totalScore", 15);
                result.put("siteId", null);
                result.put("message", "暂无当前地盘");
                return ApiResponse.success(result);
            }
            siteId = sites.get(0).getSiteId();
        }

        // 验证工人是否在该地盘
        java.util.Optional<WorkerSite> wsOpt = workerSiteRepository.findByWorkerIdAndSiteId(profile.getId(), siteId);
        if (wsOpt.isEmpty()) {
            result.put("safetyScore", 15);
            result.put("totalScore", 15);
            result.put("siteId", siteId);
            result.put("message", "未加入该地盘");
            return ApiResponse.success(result);
        }

        // 获取地盘维度的安全分
        java.util.Optional<WorkerSiteSafetyScore> scoreOpt = workerSiteSafetyScoreRepository
                .findByWorkerIdAndSiteId(profile.getId(), siteId);

        int safetyScore;
        if (scoreOpt.isPresent()) {
            safetyScore = scoreOpt.get().getSafetyScore();
        } else {
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

    /**
     * GET /worker/weather-warnings
     * 获取当前生效的天气警告（台风/暴雨/酷热/工作暑热）
     */
    @GetMapping("/weather-warnings")
    public ApiResponse<Map<String, Object>> getWeatherWarnings() {
        Map<String, Object> result = new HashMap<>();
        result.put("warnsum", weatherWarningService.getWarnsum());
        result.put("hsww", weatherWarningService.getHsww());
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
                .fromCompanyId(profile.getCompanyId())
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
                requestEntity.getId(), profile.getId(), profile.getCompanyId(), toCompanyId);

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
            // 文件类型白名单校验（与 UploadController 一致）
            String originalFilename = contractFile.getOriginalFilename();
            String ext = "";
            if (originalFilename != null && originalFilename.contains(".")) {
                ext = originalFilename.substring(originalFilename.lastIndexOf(".") + 1).toLowerCase();
            }
            if (ext.isEmpty() || !ALLOWED_EXTENSIONS.contains(ext)) {
                throw new BusinessException(400, "不支持的文件格式，仅允许上传 PDF、JPG、PNG 文件");
            }
            String expectedMime = ALLOWED_MIME_TYPES.get(ext);
            String actualMime = contractFile.getContentType();
            // 允许 application/octet-stream（泛型二进制，常见于 HTTP 客户端上传）
            if (actualMime != null && !actualMime.isEmpty()
                    && !expectedMime.equalsIgnoreCase(actualMime)
                    && !"application/octet-stream".equalsIgnoreCase(actualMime)) {
                throw new BusinessException(400, "文件内容与扩展名不匹配，仅允许上传 PDF、JPG、PNG 文件");
            }

            contractAttachmentName = originalFilename;
            try {
                String contractDir = uploadDir + "/contracts/";
                java.io.File dir = new java.io.File(contractDir);
                if (!dir.exists()) dir.mkdirs();
                String fileName = java.util.UUID.randomUUID().toString() + "_" + contractFile.getOriginalFilename();
                java.io.File destFile = new java.io.File(contractDir + fileName);
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
                .fromCompanyId(profile.getCompanyId())
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
                requestEntity.getId(), profile.getId(), profile.getCompanyId(), toCompanyId);

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

package com.fareast.worker.service;

import java.math.BigDecimal;

import com.fareast.worker.exception.BusinessException;
import com.fareast.worker.model.dto.CreateEvaluationRequest;
import com.fareast.worker.model.dto.EvaluationResponse;
import com.fareast.worker.model.entity.*;
import com.fareast.worker.model.enums.UserRole;
import com.fareast.worker.repository.*;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

@Slf4j
@Service
public class ContractorSafetyEvaluationService {

    @Autowired
    private ContractorSafetyEvaluationRepository evaluationRepository;

    @Autowired
    private SiteRepository siteRepository;

    @Autowired
    private CompanyRepository companyRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private StaffSiteRepository staffSiteRepository;

    @Autowired
    private NotificationService notificationService;

    // ==================== 创建和编辑 ====================

    /** 安全人员创建草稿 */
    @Transactional
    public ContractorSafetyEvaluation createEvaluation(CreateEvaluationRequest req, Long userId) {
        // 校验同一地盘+公司+季度是否已存在
        List<ContractorSafetyEvaluation> existing = evaluationRepository
                .findByCompanyAndSiteAndPeriod(req.getCompanyId(), req.getSiteId(),
                        req.getPeriodYear(), req.getPeriodQuarter());
        if (!existing.isEmpty()) {
            throw new BusinessException(400, "該分判商在此地盤該季度已存在評分記錄，請勿重複創建");
        }

        ContractorSafetyEvaluation e = applyScores(req, new ContractorSafetyEvaluation());
        e.setSubmittedBy(userId);
        e.setStatus("DRAFT");
        ContractorSafetyEvaluation saved = evaluationRepository.save(e);
        log.info("安全考核草稿已创建: id={}, companyId={}, siteId={}", saved.getId(), saved.getCompanyId(), saved.getSiteId());
        return saved;
    }

    /** 安全人员修改草稿 */
    @Transactional
    public ContractorSafetyEvaluation updateEvaluation(Long id, CreateEvaluationRequest req, Long userId) {
        ContractorSafetyEvaluation e = evaluationRepository.findById(id)
                .orElseThrow(() -> new BusinessException(404, "評分記錄不存在"));

        if (!"DRAFT".equals(e.getStatus())) {
            throw new BusinessException(400, "只有草稿狀態的評分可以修改");
        }
        if (!e.getSubmittedBy().equals(userId)) {
            throw new BusinessException(403, "只能修改自己創建的評分");
        }

        applyScores(req, e);
        ContractorSafetyEvaluation saved = evaluationRepository.save(e);
        log.info("安全考核草稿已更新: id={}", saved.getId());
        return saved;
    }

    /** 安全人员删除草稿 */
    @Transactional
    public void deleteEvaluation(Long id, Long userId) {
        ContractorSafetyEvaluation e = evaluationRepository.findById(id)
                .orElseThrow(() -> new BusinessException(404, "評分記錄不存在"));

        if (!"DRAFT".equals(e.getStatus())) {
            throw new BusinessException(400, "只有草稿狀態的評分可以刪除");
        }
        if (!e.getSubmittedBy().equals(userId)) {
            throw new BusinessException(403, "只能刪除自己創建的評分");
        }

        evaluationRepository.delete(e);
        log.info("安全考核草稿已刪除: id={}", id);
    }

    // ==================== 提交流程 ====================

    /** 安全人员提交审核 */
    @Transactional
    public ContractorSafetyEvaluation submitEvaluation(Long id, Long assignedTo, Long userId) {
        ContractorSafetyEvaluation e = evaluationRepository.findById(id)
                .orElseThrow(() -> new BusinessException(404, "評分記錄不存在"));

        if (!"DRAFT".equals(e.getStatus())) {
            throw new BusinessException(400, "只有草稿狀態的評分可以提交");
        }
        if (!e.getSubmittedBy().equals(userId)) {
            throw new BusinessException(403, "只能提交自己創建的評分");
        }

        // 校验审批人是否存在且角色正确
        User approver = userRepository.findById(assignedTo)
                .orElseThrow(() -> new BusinessException(404, "指定的審批人不存在"));
        if (approver.getRole() != UserRole.SITE_MANAGER
                && approver.getRole() != UserRole.PROJECT_MANAGER
                && approver.getRole() != UserRole.INSTALL_MANAGER) {
            throw new BusinessException(400, "指定的審批人角色不正確，需為地盤經理、項目經理或安裝經理");
        }

        // 计算评分
        e.calculateScore();

        // 檢查是否需要升級為 SEVERE（年度連續兩季低於80%或當季低於60%）
        int prevQuarter = e.getPeriodQuarter() == 1 ? 4 : e.getPeriodQuarter() - 1;
        int prevYear = e.getPeriodQuarter() == 1 ? e.getPeriodYear() - 1 : e.getPeriodYear();
        BigDecimal prevPercentage = evaluationRepository
                .findByCompanyAndSiteAndPeriod(e.getCompanyId(), e.getSiteId(), prevYear, prevQuarter)
                .stream().findFirst().map(ContractorSafetyEvaluation::getPercentage).orElse(null);
        e.checkSevere(prevPercentage);

        e.setAssignedTo(assignedTo);
        e.setStatus("SUBMITTED");
        e.setSubmittedAt(LocalDateTime.now());

        ContractorSafetyEvaluation saved = evaluationRepository.save(e);

        // 通知审批人
        Site site = siteRepository.findById(e.getSiteId()).orElse(null);
        Company company = companyRepository.findById(e.getCompanyId()).orElse(null);
        User submitter = userRepository.findById(userId).orElse(null);
        String siteName = site != null ? site.getName() : "未知地盤";
        String companyName = company != null ? company.getName() : "未知公司";
        String submitterName = submitter != null ? submitter.getName() : "未知";

        notificationService.send(assignedTo,
                NotificationType.EVALUATION_SUBMITTED,
                "安全考核待審批",
                submitterName + " 提交了【" + siteName + "】分判商【" + companyName + "】的安全考核評分（"
                        + e.getPercentage() + "%），請審批。",
                saved.getId(), "CONTRACTOR_SAFETY_EVALUATION");

        log.info("安全考核已提交審核: id={}, assignedTo={}", saved.getId(), assignedTo);
        return saved;
    }

    /** 安全人员撤回审核 */
    @Transactional
    public ContractorSafetyEvaluation withdrawEvaluation(Long id, Long userId) {
        ContractorSafetyEvaluation e = evaluationRepository.findById(id)
                .orElseThrow(() -> new BusinessException(404, "評分記錄不存在"));

        if (!"SUBMITTED".equals(e.getStatus())) {
            throw new BusinessException(400, "只有待審批狀態的評分可以撤回");
        }
        if (!e.getSubmittedBy().equals(userId)) {
            throw new BusinessException(403, "只能撤回自己提交的評分");
        }

        e.setStatus("DRAFT");
        e.setAssignedTo(null);
        e.setSubmittedAt(null);
        ContractorSafetyEvaluation saved = evaluationRepository.save(e);
        log.info("安全考核已撤回: id={}", saved.getId());
        return saved;
    }

    // ==================== 审批流程 ====================

    /** 项目经理/安装经理审批通过 */
    @Transactional
    public ContractorSafetyEvaluation approveEvaluation(Long id, String comment, Long userId) {
        ContractorSafetyEvaluation e = evaluationRepository.findById(id)
                .orElseThrow(() -> new BusinessException(404, "評分記錄不存在"));

        if (!"SUBMITTED".equals(e.getStatus())) {
            throw new BusinessException(400, "只有待審批狀態的評分可以審批");
        }
        if (!e.getAssignedTo().equals(userId)) {
            throw new BusinessException(403, "該評分未指定您為審批人");
        }

        e.setStatus("APPROVED");
        e.setApprovedBy(userId);
        e.setApprovedAt(LocalDateTime.now());
        e.setApprovalComment(comment);

        ContractorSafetyEvaluation saved = evaluationRepository.save(e);

        // 通知安全人员
        User submitter = userRepository.findById(e.getSubmittedBy()).orElse(null);
        Site site = siteRepository.findById(e.getSiteId()).orElse(null);
        Company company = companyRepository.findById(e.getCompanyId()).orElse(null);
        String siteName = site != null ? site.getName() : "未知地盤";
        String companyName = company != null ? company.getName() : "未知公司";

        if (submitter != null) {
            notificationService.send(e.getSubmittedBy(),
                    NotificationType.EVALUATION_APPROVED,
                    "安全考核已通過",
                    "您提交的【" + siteName + "】分判商【" + companyName + "】安全考核評分已通過審批。",
                    saved.getId(), "CONTRACTOR_SAFETY_EVALUATION");
        }

        log.info("安全考核已審批通過: id={}, approvedBy={}", saved.getId(), userId);
        return saved;
    }

    /** 项目经理/安装经理驳回 */
    @Transactional
    public ContractorSafetyEvaluation rejectEvaluation(Long id, String comment, Long userId) {
        ContractorSafetyEvaluation e = evaluationRepository.findById(id)
                .orElseThrow(() -> new BusinessException(404, "評分記錄不存在"));

        if (!"SUBMITTED".equals(e.getStatus())) {
            throw new BusinessException(400, "只有待審批狀態的評分可以駁回");
        }
        if (!e.getAssignedTo().equals(userId)) {
            throw new BusinessException(403, "該評分未指定您為審批人");
        }

        e.setStatus("DRAFT");
        e.setAssignedTo(null);
        e.setSubmittedAt(null);
        e.setApprovalComment(comment);

        ContractorSafetyEvaluation saved = evaluationRepository.save(e);

        // 通知安全人员
        User submitter = userRepository.findById(e.getSubmittedBy()).orElse(null);
        Site site = siteRepository.findById(e.getSiteId()).orElse(null);
        Company company = companyRepository.findById(e.getCompanyId()).orElse(null);
        String siteName = site != null ? site.getName() : "未知地盤";
        String companyName = company != null ? company.getName() : "未知公司";

        if (submitter != null) {
            notificationService.send(e.getSubmittedBy(),
                    NotificationType.EVALUATION_APPROVED,
                    "安全考核已駁回",
                    "您提交的【" + siteName + "】分判商【" + companyName + "】安全考核評分已被駁回。"
                            + (comment != null ? "原因：" + comment : ""),
                    saved.getId(), "CONTRACTOR_SAFETY_EVALUATION");
        }

        log.info("安全考核已駁回: id={}, rejectedBy={}", saved.getId(), userId);
        return saved;
    }

    // ==================== 知会 ====================

    /** 审批通过后知会分判商和知会人员 */
    @Transactional
    public ContractorSafetyEvaluation notifyEvaluation(Long id) {
        ContractorSafetyEvaluation e = evaluationRepository.findById(id)
                .orElseThrow(() -> new BusinessException(404, "評分記錄不存在"));

        if (!"APPROVED".equals(e.getStatus())) {
            throw new BusinessException(400, "只有已通過審批的評分可以知會");
        }

        Site site = siteRepository.findById(e.getSiteId()).orElse(null);
        Company company = companyRepository.findById(e.getCompanyId()).orElse(null);
        String siteName = site != null ? site.getName() : "未知地盤";
        String companyName = company != null ? company.getName() : "未知公司";
        String scoreInfo = "總分：" + e.getTotalScore() + "/210，百分比：" + e.getPercentage() + "%";

        // 知会被评分分判商的所有用户
        List<User> companyUsers = userRepository.findByCompanyIdAndRole(e.getCompanyId(), UserRole.CONTRACTOR);
        for (User u : companyUsers) {
            notificationService.send(u.getId(),
                    NotificationType.EVALUATION_NOTIFIED,
                    "安全考核評分通知",
                    "貴公司在【" + siteName + "】的" + e.getPeriodYear() + "年第" + e.getPeriodQuarter()
                            + "季度安全考核評分結果：" + scoreInfo + "。",
                    e.getId(), "CONTRACTOR_SAFETY_EVALUATION");
        }

        // 知会所有 NOTIFIED_PARTY 角色用户
        List<User> notifiedParties = userRepository.findByRole(UserRole.NOTIFIED_PARTY);
        for (User u : notifiedParties) {
            notificationService.send(u.getId(),
                    NotificationType.EVALUATION_NOTIFIED,
                    "安全考核評分知會",
                    "【" + siteName + "】分判商【" + companyName + "】的" + e.getPeriodYear()
                            + "年第" + e.getPeriodQuarter() + "季度安全考核評分結果：" + scoreInfo + "。",
                    e.getId(), "CONTRACTOR_SAFETY_EVALUATION");
        }

        e.setStatus("NOTIFIED");
        e.setNotifiedAt(LocalDateTime.now());
        ContractorSafetyEvaluation saved = evaluationRepository.save(e);
        log.info("安全考核已通知: id={}, notifiedCompanies={}, notifiedParties={}",
                saved.getId(), companyUsers.size(), notifiedParties.size());
        return saved;
    }

    // ==================== 查询 ====================

    /** 获取可选审批人列表 */
    public List<Map<String, Object>> getAvailableApprovers() {
        List<UserRole> approverRoles = Arrays.asList(UserRole.SITE_MANAGER, UserRole.PROJECT_MANAGER, UserRole.INSTALL_MANAGER);
        List<User> users = new ArrayList<>();
        for (UserRole role : approverRoles) {
            users.addAll(userRepository.findByRole(role));
        }
        return users.stream()
                .filter(u -> u.getStatus() == com.fareast.worker.model.enums.UserStatus.ACTIVE)
                .map(u -> {
                    Map<String, Object> m = new HashMap<>();
                    m.put("id", u.getId());
                    m.put("name", u.getName());
                    m.put("role", u.getRole().name());
                    return m;
                }).collect(Collectors.toList());
    }

    /** 根据用户角色获取评分列表 */
    public List<EvaluationResponse> getEvaluations(Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new BusinessException(404, "用戶不存在"));

        List<ContractorSafetyEvaluation> evaluations;

        switch (user.getRole()) {
            case SUPER_ADMIN:
                // 超级管理员：查看所有
                evaluations = evaluationRepository.findAll();
                break;

            case SAFETY_OFFICER:
                // 安全人员：查看自己创建的
                evaluations = evaluationRepository.findBySubmittedByOrderByCreatedAtDesc(userId);
                break;

            case SITE_MANAGER:
            case PROJECT_MANAGER:
            case INSTALL_MANAGER:
                // 内部管理人员：查看自己关联地盘 + 被指定为审批人的
                List<StaffSite> mySites = staffSiteRepository.findByUserId(userId);
                List<Long> siteIds = mySites.stream().map(StaffSite::getSiteId).collect(Collectors.toList());
                List<ContractorSafetyEvaluation> siteEvals = new ArrayList<>();
                for (Long siteId : siteIds) {
                    siteEvals.addAll(evaluationRepository.findBySiteIdOrderByCreatedAtDesc(siteId));
                }
                List<ContractorSafetyEvaluation> assignedEvals = evaluationRepository.findByAssignedToOrderByCreatedAtDesc(userId);
                // 合并去重
                Set<Long> ids = new HashSet<>();
                evaluations = new ArrayList<>();
                for (ContractorSafetyEvaluation eval : siteEvals) {
                    if (ids.add(eval.getId())) evaluations.add(eval);
                }
                for (ContractorSafetyEvaluation eval : assignedEvals) {
                    if (ids.add(eval.getId())) evaluations.add(eval);
                }
                break;

            case NOTIFIED_PARTY:
                // 知会人员：查看已审批通过的评分
                evaluations = evaluationRepository.findByStatusOrderByCreatedAtDesc("APPROVED");
                List<ContractorSafetyEvaluation> notifiedEvals = evaluationRepository.findByStatusOrderByCreatedAtDesc("NOTIFIED");
                evaluations.addAll(notifiedEvals);
                break;

            case CONTRACTOR:
                // 分判商：查看自己公司所属地盘的评分（需关联company）
                Company company = companyRepository.findByUserId(userId).orElse(null);
                if (company != null) {
                    evaluations = evaluationRepository.findByCompanyIdOrderByCreatedAtDesc(company.getId());
                } else {
                    evaluations = List.of();
                }
                break;

            default:
                evaluations = List.of();
        }

        return evaluations.stream()
                .map(this::toResponse)
                .collect(Collectors.toList());
    }

    /** 获取评分详情 */
    public EvaluationResponse getEvaluationDetail(Long id, Long userId) {
        ContractorSafetyEvaluation e = evaluationRepository.findById(id)
                .orElseThrow(() -> new BusinessException(404, "評分記錄不存在"));

        // 权限校验在Controller层
        return toResponse(e);
    }

    /** 获取不合格清单 */
    public List<EvaluationResponse> getNonCompliantList(Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new BusinessException(404, "用戶不存在"));

        List<ContractorSafetyEvaluation> evaluations;

        switch (user.getRole()) {
            case SUPER_ADMIN:
                evaluations = evaluationRepository.findByNonCompliantLevelNotAndStatusOrderByCreatedAtDesc(
                        "NONE", "APPROVED");
                // 也包含NOTIFIED状态的
                List<ContractorSafetyEvaluation> notifiedEvals = evaluationRepository
                        .findByNonCompliantLevelNotAndStatusOrderByCreatedAtDesc("NONE", "NOTIFIED");
                evaluations.addAll(notifiedEvals);
                break;

            case SITE_MANAGER:
            case PROJECT_MANAGER:
            case INSTALL_MANAGER:
            case SAFETY_OFFICER:
                // 内部人员：只看自己关联地盘的
                List<StaffSite> mySites = staffSiteRepository.findByUserId(userId);
                List<Long> siteIds = mySites.stream().map(StaffSite::getSiteId).collect(Collectors.toList());
                evaluations = new ArrayList<>();
                for (Long siteId : siteIds) {
                    List<ContractorSafetyEvaluation> siteEvals = evaluationRepository.findBySiteIdOrderByCreatedAtDesc(siteId);
                    evaluations.addAll(siteEvals.stream()
                            .filter(ev -> !"NONE".equals(ev.getNonCompliantLevel())
                                    && ("APPROVED".equals(ev.getStatus()) || "NOTIFIED".equals(ev.getStatus())))
                            .collect(Collectors.toList()));
                }
                break;

            case CONTRACTOR:
                // 分判商：只看自己公司的
                Company company = companyRepository.findByUserId(userId).orElse(null);
                if (company != null) {
                    evaluations = evaluationRepository.findByCompanyIdOrderByCreatedAtDesc(company.getId()).stream()
                            .filter(ev -> !"NONE".equals(ev.getNonCompliantLevel())
                                    && ("APPROVED".equals(ev.getStatus()) || "NOTIFIED".equals(ev.getStatus())))
                            .collect(Collectors.toList());
                } else {
                    evaluations = List.of();
                }
                break;

            default:
                evaluations = List.of();
        }

        return evaluations.stream()
                .map(this::toResponse)
                .collect(Collectors.toList());
    }

    // ==================== 辅助方法 ====================

    /** 将请求中的评分应用到实体 */
    private ContractorSafetyEvaluation applyScores(CreateEvaluationRequest req, ContractorSafetyEvaluation e) {
        e.setSiteId(req.getSiteId());
        e.setCompanyId(req.getCompanyId());
        e.setTradeOfWork(req.getTradeOfWork());
        e.setPeriod(req.getPeriod() != null ? req.getPeriod() : "QUARTERLY");
        e.setPeriodYear(req.getPeriodYear());
        e.setPeriodQuarter(req.getPeriodQuarter());
        e.setScore1(req.getScore1());
        e.setScore2(req.getScore2());
        e.setScore3(req.getScore3());
        e.setScore4(req.getScore4());
        e.setScore5(req.getScore5());
        e.setScore6(req.getScore6());
        e.setScore7(req.getScore7());
        e.setScore8(req.getScore8());
        e.setScore9(req.getScore9());
        e.setScore10(req.getScore10());
        e.setScore11(req.getScore11());
        e.setScore12(req.getScore12());
        e.setScore13(req.getScore13());
        e.setScore14(req.getScore14());
        e.setScore15(req.getScore15());
        e.setScore16(req.getScore16());
        e.setScore17(req.getScore17());
        e.setScore18(req.getScore18());
        e.setScore19(req.getScore19());
        e.setScore20(req.getScore20());
        e.setScore21(req.getScore21());
        e.setScore22(req.getScore22());
        e.setEvidenceAttachments(req.getEvidenceAttachments());
        e.setRemarks(req.getRemarks());
        e.calculateScore();
        return e;
    }

    /** 将实体转换为响应DTO，附带关联名称 */
    private EvaluationResponse toResponse(ContractorSafetyEvaluation e) {
        EvaluationResponse resp = EvaluationResponse.from(e);

        // 填充关联名称
        siteRepository.findById(e.getSiteId()).ifPresent(site -> resp.setSiteName(site.getName()));
        companyRepository.findById(e.getCompanyId()).ifPresent(company -> resp.setCompanyName(company.getName()));

        if (e.getSubmittedBy() != null) {
            userRepository.findById(e.getSubmittedBy()).ifPresent(u -> resp.setSubmittedByName(u.getName()));
        }
        if (e.getAssignedTo() != null) {
            userRepository.findById(e.getAssignedTo()).ifPresent(u -> resp.setAssignedToName(u.getName()));
        }
        if (e.getApprovedBy() != null) {
            userRepository.findById(e.getApprovedBy()).ifPresent(u -> resp.setApprovedByName(u.getName()));
        }

        return resp;
    }
}

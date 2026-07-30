package com.fareast.worker.controller;

import com.fareast.worker.exception.BusinessException;
import com.fareast.worker.model.dto.ApiResponse;
import com.fareast.worker.model.dto.CreateEvaluationRequest;
import com.fareast.worker.model.dto.EvaluationResponse;
import com.fareast.worker.model.entity.ContractorSafetyEvaluation;
import com.fareast.worker.model.entity.EvaluationScoreItem;
import com.fareast.worker.model.entity.EvaluationTemplate;
import com.fareast.worker.model.entity.User;
import com.fareast.worker.model.enums.UserRole;
import com.fareast.worker.repository.EvaluationScoreItemRepository;
import com.fareast.worker.repository.EvaluationTemplateRepository;
import com.fareast.worker.repository.UserRepository;
import com.fareast.worker.service.ContractorSafetyEvaluationService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;

import java.util.*;
import java.util.stream.Collectors;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@Slf4j
@RestController
@RequestMapping("/safety/evaluations")
public class ContractorSafetyEvaluationController {

    @Autowired
    private ContractorSafetyEvaluationService evaluationService;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private EvaluationTemplateRepository templateRepo;

    @Autowired
    private EvaluationScoreItemRepository itemRepo;

    // ==================== 安全人员操作 ====================

    /** 创建评分草稿 */
    @PostMapping
    @PreAuthorize("hasRole('SAFETY_OFFICER')")
    public ApiResponse<EvaluationResponse> createEvaluation(
            @AuthenticationPrincipal String userId,
            @RequestBody CreateEvaluationRequest req) {
        ContractorSafetyEvaluation e = evaluationService.createEvaluation(req, Long.valueOf(userId));
        return ApiResponse.success(evaluationService.getEvaluationDetail(e.getId(), Long.valueOf(userId)));
    }

    /** 修改评分草稿 */
    @PutMapping("/{id}")
    @PreAuthorize("hasRole('SAFETY_OFFICER')")
    public ApiResponse<EvaluationResponse> updateEvaluation(
            @AuthenticationPrincipal String userId,
            @PathVariable Long id,
            @RequestBody CreateEvaluationRequest req) {
        ContractorSafetyEvaluation e = evaluationService.updateEvaluation(id, req, Long.valueOf(userId));
        return ApiResponse.success(evaluationService.getEvaluationDetail(e.getId(), Long.valueOf(userId)));
    }

    /** 删除评分草稿 */
    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('SAFETY_OFFICER')")
    public ApiResponse<Void> deleteEvaluation(
            @AuthenticationPrincipal String userId,
            @PathVariable Long id) {
        evaluationService.deleteEvaluation(id, Long.valueOf(userId));
        return ApiResponse.success(null);
    }

    /** 提交审核（指定审批人） */
    @PostMapping("/{id}/submit")
    @PreAuthorize("hasRole('SAFETY_OFFICER')")
    public ApiResponse<EvaluationResponse> submitEvaluation(
            @AuthenticationPrincipal String userId,
            @PathVariable Long id,
            @RequestBody Map<String, Object> body) {
        Long assignedTo = Long.valueOf(body.get("assignedTo").toString());
        ContractorSafetyEvaluation e = evaluationService.submitEvaluation(id, assignedTo, Long.valueOf(userId));
        return ApiResponse.success(evaluationService.getEvaluationDetail(e.getId(), Long.valueOf(userId)));
    }

    /** 撤回审核 */
    @PostMapping("/{id}/withdraw")
    @PreAuthorize("hasRole('SAFETY_OFFICER')")
    public ApiResponse<EvaluationResponse> withdrawEvaluation(
            @AuthenticationPrincipal String userId,
            @PathVariable Long id) {
        ContractorSafetyEvaluation e = evaluationService.withdrawEvaluation(id, Long.valueOf(userId));
        return ApiResponse.success(evaluationService.getEvaluationDetail(e.getId(), Long.valueOf(userId)));
    }

    // ==================== 审批人操作 ====================

    /** 审批通过 */
    @PostMapping("/{id}/approve")
    @PreAuthorize("hasAnyRole('SITE_MANAGER','PROJECT_MANAGER','INSTALL_MANAGER')")
    public ApiResponse<EvaluationResponse> approveEvaluation(
            @AuthenticationPrincipal String userId,
            @PathVariable Long id,
            @RequestBody Map<String, Object> body) {
        String comment = (String) body.getOrDefault("comment", "");
        ContractorSafetyEvaluation e = evaluationService.approveEvaluation(id, comment, Long.valueOf(userId));
        return ApiResponse.success(evaluationService.getEvaluationDetail(e.getId(), Long.valueOf(userId)));
    }

    /** 驳回 */
    @PostMapping("/{id}/reject")
    @PreAuthorize("hasAnyRole('SITE_MANAGER','PROJECT_MANAGER','INSTALL_MANAGER')")
    public ApiResponse<EvaluationResponse> rejectEvaluation(
            @AuthenticationPrincipal String userId,
            @PathVariable Long id,
            @RequestBody Map<String, Object> body) {
        String comment = (String) body.getOrDefault("comment", "");
        ContractorSafetyEvaluation e = evaluationService.rejectEvaluation(id, comment, Long.valueOf(userId));
        return ApiResponse.success(evaluationService.getEvaluationDetail(e.getId(), Long.valueOf(userId)));
    }

    // ==================== 知会操作 ====================

    /** 审批通过后执行知会（可由审批人或超级管理员触发） */
    @PostMapping("/{id}/notify")
    @PreAuthorize("hasAnyRole('SITE_MANAGER','PROJECT_MANAGER','INSTALL_MANAGER','SUPER_ADMIN')")
    public ApiResponse<EvaluationResponse> notifyEvaluation(
            @PathVariable Long id) {
        ContractorSafetyEvaluation e = evaluationService.notifyEvaluation(id);
        return ApiResponse.success(evaluationService.getEvaluationDetail(e.getId(), e.getSubmittedBy()));
    }

    // ==================== 查询操作 ====================

    /** 获取可选审批人列表 */
    @GetMapping("/approvers")
    @PreAuthorize("hasRole('SAFETY_OFFICER')")
    public ApiResponse<List<Map<String, Object>>> getApprovers() {
        return ApiResponse.success(evaluationService.getAvailableApprovers());
    }

    /** 获取评分列表（按角色过滤） */
    @GetMapping
    @PreAuthorize("isAuthenticated()")
    public ApiResponse<List<EvaluationResponse>> getEvaluations(
            @AuthenticationPrincipal String userId) {
        return ApiResponse.success(evaluationService.getEvaluations(Long.valueOf(userId)));
    }

    /** 获取评分详情 */
    @GetMapping("/{id}")
    @PreAuthorize("isAuthenticated()")
    public ApiResponse<EvaluationResponse> getEvaluationDetail(
            @AuthenticationPrincipal String userId,
            @PathVariable Long id) {
        return ApiResponse.success(evaluationService.getEvaluationDetail(id, Long.valueOf(userId)));
    }

    /** 获取不合格分判商清单 */
    @GetMapping("/non-compliant")
    @PreAuthorize("isAuthenticated()")
    public ApiResponse<List<EvaluationResponse>> getNonCompliantList(
            @AuthenticationPrincipal String userId) {
        return ApiResponse.success(evaluationService.getNonCompliantList(Long.valueOf(userId)));
    }

    /** 获取评分模板明细 */
    @GetMapping("/templates/{code}/items")
    @PreAuthorize("isAuthenticated()")
    public ApiResponse<Map<String, Object>> getTemplateItems(@PathVariable String code) {
        EvaluationTemplate template = templateRepo.findByCode(code)
                .orElseThrow(() -> new RuntimeException("模板不存在: " + code));

        List<EvaluationScoreItem> items = itemRepo.findByTemplateIdOrderByScoreIndexAsc(template.getId());
        int itemCount = items.size();
        int maxScore = itemCount * template.getMaxScorePerItem();

        List<Map<String, Object>> itemList = items.stream().map(item -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("scoreIndex", item.getScoreIndex());
            m.put("category", item.getCategory());
            m.put("nameZh", item.getNameZh());
            m.put("sortOrder", item.getSortOrder());

            List<Map<String, String>> guides = new ArrayList<>();
            addGuide(guides, item.getGuideTier1(), item.getGuideTier1Range());
            addGuide(guides, item.getGuideTier2(), item.getGuideTier2Range());
            addGuide(guides, item.getGuideTier3(), item.getGuideTier3Range());
            addGuide(guides, item.getGuideTier4(), item.getGuideTier4Range());
            m.put("guides", guides);
            return m;
        }).collect(Collectors.toList());

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("template", Map.of(
                "code", template.getCode(),
                "name", template.getName(),
                "maxScorePerItem", template.getMaxScorePerItem(),
                "itemCount", itemCount,
                "maxScore", maxScore
        ));
        result.put("items", itemList);
        return ApiResponse.success(result);
    }

    private void addGuide(List<Map<String, String>> guides, String desc, String range) {
        if (desc != null && !desc.isBlank()) {
            guides.add(Map.of("desc", desc, "range", range != null ? range : ""));
        }
    }
}

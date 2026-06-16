package com.fareast.worker.controller;

import com.fareast.worker.model.dto.ApiResponse;
import com.fareast.worker.model.dto.PageResponse;
import com.fareast.worker.model.entity.Site;
import com.fareast.worker.model.entity.SiteChangeRequest;
import com.fareast.worker.repository.SiteRepository;
import com.fareast.worker.service.SiteService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/site")
@PreAuthorize("hasRole('WORKER')")
public class SiteController {

    @Autowired
    private SiteService siteService;

    @Autowired
    private SiteRepository siteRepository;

    @GetMapping("/current")
    public ApiResponse<Site> getCurrentSite(@AuthenticationPrincipal String userId) {
        Site site = siteService.getCurrentSite(Long.valueOf(userId));
        return ApiResponse.success(site);
    }

    @GetMapping("/detail/{siteId}")
    public ApiResponse<Site> getSiteDetail(@PathVariable Long siteId) {
        Site site = siteService.getSiteById(siteId);
        return ApiResponse.success(site);
    }

    @PostMapping("/change")
    public ApiResponse<Void> changeSite(
            @AuthenticationPrincipal String userId,
            @RequestBody Map<String, Object> requestBody) {
        Long targetSiteId = Long.valueOf(requestBody.get("targetSiteId").toString());
        String reason = (String) requestBody.get("reason");
        String dailyWageStr = requestBody.get("dailyWage") != null ? requestBody.get("dailyWage").toString() : null;
        String contractAttachment = requestBody.get("contractAttachment") != null
                ? (String) requestBody.get("contractAttachment") : null;
        java.math.BigDecimal dailyWage = null;
        if (dailyWageStr != null && !dailyWageStr.isEmpty()) {
            dailyWage = new java.math.BigDecimal(dailyWageStr);
        }
        siteService.requestSiteChange(Long.valueOf(userId), targetSiteId, reason, dailyWage, contractAttachment);
        return ApiResponse.success(null);
    }

    @PostMapping("/cancel-change")
    public ApiResponse<Void> cancelChange(@AuthenticationPrincipal String userId) {
        siteService.cancelSiteChange(Long.valueOf(userId));
        return ApiResponse.success(null);
    }

    @GetMapping("/history")
    public ApiResponse<PageResponse<Map<String, Object>>> getHistory(
            @AuthenticationPrincipal String userId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size) {
        Page<SiteChangeRequest> history = siteService.getChangeHistory(Long.valueOf(userId), page, size);
        
        List<Map<String, Object>> content = history.getContent().stream().map(r -> {
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
        }).collect(Collectors.toList());
        
        PageResponse<Map<String, Object>> pageResponse = PageResponse.<Map<String, Object>>builder()
                .content(content)
                .page(history.getNumber())
                .size(history.getSize())
                .totalElements(history.getTotalElements())
                .totalPages(history.getTotalPages())
                .first(history.isFirst())
                .last(history.isLast())
                .build();
        return ApiResponse.success(pageResponse);
    }

    /**
     * GET /site/list
     * 获取所有地盘列表（工人申请更换地盘时选择用）
     */
    @GetMapping("/list")
    public ApiResponse<List<Map<String, Object>>> getSiteList() {
        List<Site> sites = siteService.getAllSites();
        List<Map<String, Object>> data = sites.stream().map(s -> {
            Map<String, Object> m = new java.util.HashMap<>();
            m.put("id", s.getId());
            m.put("name", s.getName());
            m.put("address", s.getAddress());
            m.put("companyId", s.getCompanyId());
            m.put("managerName", s.getManagerName());
            m.put("managerPhone", s.getManagerPhone());
            return m;
        }).collect(Collectors.toList());
        return ApiResponse.success(data);
    }
}

package com.fareast.worker.controller;

import com.fareast.worker.model.dto.ApiResponse;
import com.fareast.worker.model.dto.PageResponse;
import com.fareast.worker.model.entity.MaterialRequest;
import com.fareast.worker.service.MaterialService;
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

import java.util.Map;

@RestController
@RequestMapping("/materials")
public class MaterialController {

    @Autowired
    private MaterialService materialService;

    @PostMapping("/request")
    @PreAuthorize("hasRole('WORKER')")
    public ApiResponse<MaterialRequest> requestMaterial(
            @AuthenticationPrincipal String userId,
            @RequestBody Map<String, Object> requestBody) {
        Long siteId = requestBody.get("siteId") != null ? Long.valueOf(requestBody.get("siteId").toString()) : null;
        String itemName = (String) requestBody.get("itemName");
        Integer quantity = Integer.valueOf(requestBody.get("quantity").toString());
        MaterialRequest materialRequest = materialService.createRequest(Long.valueOf(userId), siteId, itemName, quantity);
        return ApiResponse.success(materialRequest);
    }

    @GetMapping("/my-requests")
    @PreAuthorize("hasRole('WORKER')")
    public ApiResponse<PageResponse<MaterialRequest>> getMyRequests(
            @AuthenticationPrincipal String userId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size) {
        Page<MaterialRequest> requests = materialService.getMyRequests(Long.valueOf(userId), page, size);
        PageResponse<MaterialRequest> pageResponse = PageResponse.<MaterialRequest>builder()
                .content(requests.getContent())
                .page(requests.getNumber())
                .size(requests.getSize())
                .totalElements(requests.getTotalElements())
                .totalPages(requests.getTotalPages())
                .first(requests.isFirst())
                .last(requests.isLast())
                .build();
        return ApiResponse.success(pageResponse);
    }

    @GetMapping("/site-requests/{siteId}")
    @PreAuthorize("hasAnyRole('CONTRACTOR','SITE_MANAGER','PROJECT_MANAGER','INSTALL_MANAGER')")
    public ApiResponse<PageResponse<MaterialRequest>> getSiteRequests(
            @PathVariable Long siteId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size) {
        Page<MaterialRequest> requests = materialService.getSiteRequests(siteId, page, size);
        PageResponse<MaterialRequest> pageResponse = PageResponse.<MaterialRequest>builder()
                .content(requests.getContent())
                .page(requests.getNumber())
                .size(requests.getSize())
                .totalElements(requests.getTotalElements())
                .totalPages(requests.getTotalPages())
                .first(requests.isFirst())
                .last(requests.isLast())
                .build();
        return ApiResponse.success(pageResponse);
    }

    @PostMapping("/process/{requestId}")
    @PreAuthorize("hasAnyRole('SITE_MANAGER','PROJECT_MANAGER','INSTALL_MANAGER')")
    public ApiResponse<Void> processRequest(
            @AuthenticationPrincipal String userId,
            @PathVariable Long requestId,
            @RequestBody Map<String, Object> requestBody) {
        String status = (String) requestBody.get("status");
        String remark = (String) requestBody.get("remark");
        materialService.processRequest(requestId, status, remark, Long.valueOf(userId));
        return ApiResponse.success(null);
    }
}

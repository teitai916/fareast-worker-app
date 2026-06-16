package com.fareast.worker.controller;

import com.fareast.worker.model.dto.ApiResponse;
import com.fareast.worker.model.entity.BlacklistRecord;
import com.fareast.worker.model.entity.Company;
import com.fareast.worker.model.entity.Site;
import com.fareast.worker.model.entity.WorkerProfile;
import com.fareast.worker.service.AdminService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/admin")
@PreAuthorize("hasAnyRole('SITE_MANAGER','PROJECT_MANAGER')")
public class AdminController {

    @Autowired
    private AdminService adminService;

    @GetMapping("/companies")
    public ApiResponse<List<Company>> getCompanies() {
        List<Company> companies = adminService.getAllCompanies();
        return ApiResponse.success(companies);
    }

    @GetMapping("/sites/{companyId}")
    public ApiResponse<List<Site>> getSitesByCompany(@PathVariable Long companyId) {
        List<Site> sites = adminService.getSitesByCompany(companyId);
        return ApiResponse.success(sites);
    }

    @GetMapping("/workers/{siteId}")
    public ApiResponse<List<WorkerProfile>> getWorkersBySite(@PathVariable Long siteId) {
        List<WorkerProfile> workers = adminService.getWorkersBySite(siteId);
        return ApiResponse.success(workers);
    }

    @GetMapping("/worker/{workerId}")
    public ApiResponse<WorkerProfile> getWorkerDetail(@PathVariable Long workerId) {
        WorkerProfile worker = adminService.getWorkerDetail(workerId);
        return ApiResponse.success(worker);
    }

    @GetMapping("/blacklist")
    public ApiResponse<List<BlacklistRecord>> getBlacklist() {
        List<BlacklistRecord> blacklist = adminService.getBlacklist();
        return ApiResponse.success(blacklist);
    }

    @PostMapping("/blacklist/add")
    public ApiResponse<BlacklistRecord> addBlacklist(
            @AuthenticationPrincipal String userId,
            @RequestBody Map<String, Object> requestBody) {
        Long workerId = Long.valueOf(requestBody.get("workerId").toString());
        String reason = (String) requestBody.get("reason");
        BlacklistRecord record = adminService.addBlacklist(workerId, reason, Long.valueOf(userId));
        return ApiResponse.success(record);
    }

    @PostMapping("/blacklist/remove/{recordId}")
    public ApiResponse<Void> removeBlacklist(
            @AuthenticationPrincipal String userId,
            @PathVariable Long recordId) {
        adminService.removeBlacklist(recordId, Long.valueOf(userId));
        return ApiResponse.success(null);
    }

    @PostMapping("/lock-card")
    public ApiResponse<Void> lockCard(@RequestBody Map<String, Object> requestBody) {
        Long workerId = Long.valueOf(requestBody.get("workerId").toString());
        adminService.lockCard(workerId);
        return ApiResponse.success(null);
    }

    @PostMapping("/unlock-card")
    public ApiResponse<Void> unlockCard(@RequestBody Map<String, Object> requestBody) {
        Long workerId = Long.valueOf(requestBody.get("workerId").toString());
        adminService.unlockCard(workerId);
        return ApiResponse.success(null);
    }

    @PostMapping("/deduct-score")
    public ApiResponse<Void> deductScore(
            @AuthenticationPrincipal String userId,
            @RequestBody Map<String, Object> requestBody) {
        Long workerId = Long.valueOf(requestBody.get("workerId").toString());
        Integer points = Integer.valueOf(requestBody.get("points").toString());
        String reason = (String) requestBody.get("reason");
        adminService.deductScore(workerId, points, reason, Long.valueOf(userId));
        return ApiResponse.success(null);
    }
}

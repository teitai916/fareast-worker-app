package com.fareast.worker.controller;

import com.fareast.worker.model.dto.ApiResponse;
import com.fareast.worker.model.entity.Company;
import com.fareast.worker.model.enums.CompanyType;
import com.fareast.worker.repository.CompanyRepository;
import com.fareast.worker.service.CompanyService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/company")
@PreAuthorize("hasRole('WORKER')")
public class CompanyController {

    @Autowired
    private CompanyService companyService;

    @Autowired
    private CompanyRepository companyRepository;

    @GetMapping("/current")
    public ApiResponse<Company> getCurrentCompany(@AuthenticationPrincipal String userId) {
        Company company = companyService.getCurrentCompany(Long.valueOf(userId));
        return ApiResponse.success(company);
    }

    @PostMapping("/change")
    public ApiResponse<Void> changeCompany(
            @AuthenticationPrincipal String userId,
            @RequestBody Map<String, Object> requestBody) {
        Long targetCompanyId = Long.valueOf(requestBody.get("targetCompanyId").toString());
        String reason = (String) requestBody.get("reason");
        companyService.requestCompanyChange(Long.valueOf(userId), targetCompanyId, reason);
        return ApiResponse.success(null);
    }

    @PostMapping("/cancel-change")
    public ApiResponse<Void> cancelChange(@AuthenticationPrincipal String userId) {
        companyService.cancelCompanyChange(Long.valueOf(userId));
        return ApiResponse.success(null);
    }

    /**
     * GET /company/contractor-list
     * 获取所有判头公司列表（工人申请地盘时选择所属公司用）
     */
    @GetMapping("/contractor-list")
    public ApiResponse<List<Map<String, Object>>> getContractorList() {
        List<Company> companies = companyRepository.findAll().stream()
                .filter(c -> c.getType() == CompanyType.CONTRACTOR)
                .collect(Collectors.toList());
        List<Map<String, Object>> data = companies.stream().map(c -> {
            Map<String, Object> m = new java.util.HashMap<>();
            m.put("id", c.getId());
            m.put("name", c.getName());
            m.put("contactPerson", c.getContactPerson());
            m.put("contactPhone", c.getContactPhone());
            return m;
        }).collect(Collectors.toList());
        return ApiResponse.success(data);
    }
}

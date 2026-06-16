package com.fareast.worker.service;

import com.fareast.worker.model.entity.Company;

public interface CompanyService {

    Company getCurrentCompany(Long userId);

    void requestCompanyChange(Long userId, Long targetCompanyId, String reason);

    void cancelCompanyChange(Long userId);
}

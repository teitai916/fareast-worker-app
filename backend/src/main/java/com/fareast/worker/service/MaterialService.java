package com.fareast.worker.service;

import com.fareast.worker.model.entity.MaterialRequest;
import org.springframework.data.domain.Page;

public interface MaterialService {

    MaterialRequest createRequest(Long workerId, Long siteId, String itemName, Integer quantity);

    Page<MaterialRequest> getMyRequests(Long workerId, int page, int size);

    Page<MaterialRequest> getSiteRequests(Long siteId, int page, int size);

    void processRequest(Long requestId, String status, String remark, Long processedBy);
}

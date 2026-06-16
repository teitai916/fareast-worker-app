package com.fareast.worker.service.impl;

import com.fareast.worker.exception.BusinessException;
import com.fareast.worker.model.entity.MaterialRequest;
import com.fareast.worker.repository.MaterialRequestRepository;
import com.fareast.worker.service.MaterialService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.List;

@Slf4j
@Service
public class MaterialServiceImpl implements MaterialService {

    @Autowired
    private MaterialRequestRepository materialRequestRepository;

    @Override
    @Transactional
    public MaterialRequest createRequest(Long workerId, Long siteId, String itemName, Integer quantity) {
        MaterialRequest request = MaterialRequest.builder()
                .workerId(workerId)
                .siteId(siteId)
                .itemName(itemName)
                .quantity(quantity)
                .status("PENDING")
                .requestedAt(LocalDateTime.now())
                .build();

        MaterialRequest saved = materialRequestRepository.save(request);
        log.info("物料申請已提交: requestId={}, workerId={}, itemName={}, quantity={}",
                saved.getId(), workerId, itemName, quantity);
        return saved;
    }

    @Override
    public Page<MaterialRequest> getMyRequests(Long workerId, int page, int size) {
        List<MaterialRequest> allRequests = materialRequestRepository.findByWorkerId(workerId);

        // Sort by requestedAt descending
        allRequests.sort(Comparator.comparing(MaterialRequest::getRequestedAt).reversed());

        // Manual pagination
        int start = page * size;
        int end = Math.min(start + size, allRequests.size());

        List<MaterialRequest> pageContent = start < allRequests.size()
                ? allRequests.subList(start, end)
                : List.of();

        return new PageImpl<>(pageContent, PageRequest.of(page, size), allRequests.size());
    }

    @Override
    public Page<MaterialRequest> getSiteRequests(Long siteId, int page, int size) {
        List<MaterialRequest> allRequests = materialRequestRepository.findBySiteId(siteId);

        // Sort by requestedAt descending
        allRequests.sort(Comparator.comparing(MaterialRequest::getRequestedAt).reversed());

        // Manual pagination
        int start = page * size;
        int end = Math.min(start + size, allRequests.size());

        List<MaterialRequest> pageContent = start < allRequests.size()
                ? allRequests.subList(start, end)
                : List.of();

        return new PageImpl<>(pageContent, PageRequest.of(page, size), allRequests.size());
    }

    @Override
    @Transactional
    public void processRequest(Long requestId, String status, String remark, Long processedBy) {
        MaterialRequest request = materialRequestRepository.findById(requestId)
                .orElseThrow(() -> new BusinessException(404, "物料申請不存在"));

        request.setStatus(status);
        request.setRemark(remark);
        request.setProcessedBy(processedBy);
        request.setProcessedAt(LocalDateTime.now());

        materialRequestRepository.save(request);
        log.info("物料申請已處理: requestId={}, status={}, processedBy={}", requestId, status, processedBy);
    }
}

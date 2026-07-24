package com.fareast.worker.service.impl;

import com.fareast.worker.exception.BusinessException;
import com.fareast.worker.model.entity.*;
import com.fareast.worker.model.enums.AuditStatus;
import com.fareast.worker.repository.*;
import com.fareast.worker.service.ContractorService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

@Slf4j
@Service
public class ContractorServiceImpl implements ContractorService {

    @Autowired
    private SiteRepository siteRepository;

    @Autowired
    private WorkerProfileRepository workerProfileRepository;

    @Autowired
    private AttendanceRepository attendanceRepository;

    @Autowired
    private SiteChangeRequestRepository siteChangeRequestRepository;

    @Autowired
    private CompanyChangeRequestRepository companyChangeRequestRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private WorkerSiteRepository workerSiteRepository;

    @Override
    public List<Site> getSites(Long companyId) {
        if (companyId == null) {
            return siteRepository.findAll();
        }
        return siteRepository.findByCompanyId(companyId);
    }

    @Override
    public List<WorkerProfile> getSiteWorkers(Long siteId) {
        siteRepository.findById(siteId)
                .orElseThrow(() -> new BusinessException(404, "地盤不存在"));
        List<WorkerSite> wsList = workerSiteRepository.findBySiteId(siteId);
        List<Long> workerIds = wsList.stream().map(WorkerSite::getWorkerId).collect(Collectors.toList());
        if (workerIds.isEmpty()) return Collections.emptyList();
        return workerProfileRepository.findAllById(workerIds);
    }

    @Override
    public List<Attendance> getWorkerAttendance(Long workerId, LocalDate startDate, LocalDate endDate) {
        return attendanceRepository.findByWorkerIdAndDateBetween(workerId, startDate, endDate);
    }

    @Override
    public Map<String, Object> getAuditList() {
        List<SiteChangeRequest> allRequests = siteChangeRequestRepository.findAll();
        List<Map<String, Object>> pendingItems = new ArrayList<>();

        for (SiteChangeRequest req : allRequests) {
            if (req.getStatus() == AuditStatus.PENDING) {
                Map<String, Object> item = new HashMap<>();
                item.put("id", req.getId());
                item.put("type", "SITE_CHANGE");
                item.put("workerId", req.getWorkerId());
                item.put("fromSiteId", req.getFromSiteId());
                item.put("toSiteId", req.getToSiteId());
                item.put("reason", req.getReason());
                item.put("requestedAt", req.getRequestedAt());

                workerProfileRepository.findById(req.getWorkerId()).ifPresent(wp -> {
                    userRepository.findById(wp.getUserId()).ifPresent(u -> {
                        item.put("workerName", u.getName());
                        item.put("workerPhone", u.getPhone());
                    });
                });

                siteRepository.findById(req.getFromSiteId()).ifPresent(s ->
                        item.put("fromSiteName", s.getName()));
                siteRepository.findById(req.getToSiteId()).ifPresent(s ->
                        item.put("toSiteName", s.getName()));

                pendingItems.add(item);
            }
        }

        Map<String, Object> result = new HashMap<>();
        result.put("pendingCount", pendingItems.size());
        result.put("items", pendingItems);
        return result;
    }

    @Override
    @Transactional
    public void processApproval(Long requestId, String type, Boolean approved) {
        if ("SITE_CHANGE".equalsIgnoreCase(type)) {
            SiteChangeRequest request = siteChangeRequestRepository.findById(requestId)
                    .orElseThrow(() -> new BusinessException(404, "轉地盤申請不存在"));

            if (request.getStatus() != AuditStatus.PENDING) {
                throw new BusinessException(400, "該申請已被處理");
            }

            if (Boolean.TRUE.equals(approved)) {
                request.setStatus(AuditStatus.APPROVED);
                WorkerProfile profile = workerProfileRepository.findById(request.getWorkerId())
                        .orElseThrow(() -> new BusinessException(404, "工人資料不存在"));
                // 写入 worker_sites
                java.util.Optional<WorkerSite> existingWs = workerSiteRepository
                        .findByWorkerIdAndSiteId(profile.getId(), request.getToSiteId());
                if (existingWs.isEmpty()) {
                    WorkerSite newWs = WorkerSite.builder()
                            .workerId(profile.getId())
                            .siteId(request.getToSiteId())
                            .joinedAt(LocalDateTime.now())
                            .build();
                    workerSiteRepository.save(newWs);
                }
                log.info("轉地盤申請已批准: requestId={}, workerId={}, targetSiteId={}",
                        requestId, request.getWorkerId(), request.getToSiteId());
            } else {
                request.setStatus(AuditStatus.REJECTED);
                request.setRejectReason("已拒絕");
                log.info("轉地盤申請已拒絕: requestId={}", requestId);
            }

            request.setProcessedAt(LocalDateTime.now());
            siteChangeRequestRepository.save(request);
        } else if ("COMPANY_CHANGE".equalsIgnoreCase(type)) {
            CompanyChangeRequest request = companyChangeRequestRepository.findById(requestId)
                    .orElseThrow(() -> new BusinessException(404, "轉公司申請不存在"));

            if (Boolean.TRUE.equals(approved)) {
                request.setStatus(AuditStatus.APPROVED);
                WorkerProfile profile = workerProfileRepository.findById(request.getWorkerId())
                        .orElseThrow(() -> new BusinessException(404, "工人資料不存在"));
                profile.setCompanyId(request.getToCompanyId());
                workerProfileRepository.save(profile);
            } else {
                request.setStatus(AuditStatus.REJECTED);
            }

            request.setProcessedAt(LocalDateTime.now());
            companyChangeRequestRepository.save(request);
        } else {
            throw new BusinessException(400, "不支持的審批類型: " + type);
        }
    }
}

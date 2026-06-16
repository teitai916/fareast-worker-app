package com.fareast.worker.service.impl;

import com.fareast.worker.exception.BusinessException;
import com.fareast.worker.model.entity.Company;
import com.fareast.worker.model.entity.CompanyChangeRequest;
import com.fareast.worker.model.entity.WorkerProfile;
import com.fareast.worker.model.enums.AuditStatus;
import com.fareast.worker.repository.CompanyChangeRequestRepository;
import com.fareast.worker.repository.CompanyRepository;
import com.fareast.worker.repository.WorkerProfileRepository;
import com.fareast.worker.service.CompanyService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Slf4j
@Service
public class CompanyServiceImpl implements CompanyService {

    @Autowired
    private WorkerProfileRepository workerProfileRepository;

    @Autowired
    private CompanyRepository companyRepository;

    @Autowired
    private CompanyChangeRequestRepository companyChangeRequestRepository;

    @Override
    public Company getCurrentCompany(Long userId) {
        WorkerProfile profile = workerProfileRepository.findByUserId(userId)
                .orElseThrow(() -> new BusinessException(404, "工人資料不存在"));

        if (profile.getCurrentCompanyId() == null) {
            throw new BusinessException(404, "目前未分配公司");
        }

        return companyRepository.findById(profile.getCurrentCompanyId())
                .orElseThrow(() -> new BusinessException(404, "公司信息不存在"));
    }

    @Override
    @Transactional
    public void requestCompanyChange(Long userId, Long targetCompanyId, String reason) {
        WorkerProfile profile = workerProfileRepository.findByUserId(userId)
                .orElseThrow(() -> new BusinessException(404, "工人資料不存在"));

        // Verify target company exists
        Company targetCompany = companyRepository.findById(targetCompanyId)
                .orElseThrow(() -> new BusinessException(404, "目標公司不存在"));

        // Check for existing pending request
        List<CompanyChangeRequest> existingRequests = companyChangeRequestRepository.findAll();
        boolean hasPending = existingRequests.stream()
                .anyMatch(r -> r.getWorkerId().equals(profile.getId())
                        && r.getStatus() == AuditStatus.PENDING);
        if (hasPending) {
            throw new BusinessException(400, "已有待審批的轉公司申請");
        }

        // Create request
        CompanyChangeRequest request = CompanyChangeRequest.builder()
                .workerId(profile.getId())
                .fromCompanyId(profile.getCurrentCompanyId())
                .toCompanyId(targetCompanyId)
                .reason(reason)
                .status(AuditStatus.PENDING)
                .requestedAt(LocalDateTime.now())
                .build();

        companyChangeRequestRepository.save(request);
        log.info("轉公司申請已提交: workerId={}, fromCompanyId={}, toCompanyId={}",
                profile.getId(), profile.getCurrentCompanyId(), targetCompanyId);
    }

    @Override
    @Transactional
    public void cancelCompanyChange(Long userId) {
        WorkerProfile profile = workerProfileRepository.findByUserId(userId)
                .orElseThrow(() -> new BusinessException(404, "工人資料不存在"));

        List<CompanyChangeRequest> requests = companyChangeRequestRepository.findAll();
        CompanyChangeRequest pending = requests.stream()
                .filter(r -> r.getWorkerId().equals(profile.getId())
                        && r.getStatus() == AuditStatus.PENDING)
                .findFirst()
                .orElseThrow(() -> new BusinessException(400, "沒有待審批的轉公司申請"));

        companyChangeRequestRepository.delete(pending);
        log.info("轉公司申請已取消: requestId={}, workerId={}", pending.getId(), profile.getId());
    }
}

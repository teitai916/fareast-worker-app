package com.fareast.worker.service.impl;

import com.fareast.worker.exception.BusinessException;
import com.fareast.worker.model.entity.*;
import com.fareast.worker.repository.*;
import com.fareast.worker.service.AdminService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Slf4j
@Service
public class AdminServiceImpl implements AdminService {

    @Autowired
    private CompanyRepository companyRepository;

    @Autowired
    private SiteRepository siteRepository;

    @Autowired
    private WorkerProfileRepository workerProfileRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private BlacklistRecordRepository blacklistRecordRepository;

    @Autowired
    private SafetyDeductionRepository safetyDeductionRepository;

    @Override
    public List<Company> getAllCompanies() {
        return companyRepository.findAll();
    }

    @Override
    public List<Site> getSitesByCompany(Long companyId) {
        return siteRepository.findByCompanyId(companyId);
    }

    @Override
    public List<WorkerProfile> getWorkersBySite(Long siteId) {
        return workerProfileRepository.findByCurrentSiteId(siteId);
    }

    @Override
    public WorkerProfile getWorkerDetail(Long workerId) {
        WorkerProfile profile = workerProfileRepository.findById(workerId)
                .orElseThrow(() -> new BusinessException(404, "工人資料不存在"));
        // Eagerly load the user association
        profile.getUser();
        return profile;
    }

    @Override
    @Transactional
    public BlacklistRecord addBlacklist(Long workerId, String reason, Long adminId) {
        WorkerProfile profile = workerProfileRepository.findById(workerId)
                .orElseThrow(() -> new BusinessException(404, "工人資料不存在"));

        if (Boolean.TRUE.equals(profile.getBlacklisted())) {
            throw new BusinessException(400, "該工人已被列入黑名單");
        }

        profile.setBlacklisted(true);
        profile.setBlacklistReason(reason);
        workerProfileRepository.save(profile);

        // Create blacklist record
        BlacklistRecord record = BlacklistRecord.builder()
                .workerId(workerId)
                .reason(reason)
                .addedBy(adminId)
                .addedAt(LocalDateTime.now())
                .build();
        BlacklistRecord saved = blacklistRecordRepository.save(record);

        log.info("工人已被列入黑名單: workerId={}, reason={}, adminId={}", workerId, reason, adminId);
        return saved;
    }

    @Override
    @Transactional
    public void removeBlacklist(Long recordId, Long adminId) {
        BlacklistRecord record = blacklistRecordRepository.findById(recordId)
                .orElseThrow(() -> new BusinessException(404, "黑名單記錄不存在"));

        WorkerProfile profile = workerProfileRepository.findById(record.getWorkerId())
                .orElseThrow(() -> new BusinessException(404, "工人資料不存在"));

        profile.setBlacklisted(false);
        profile.setBlacklistReason(null);
        workerProfileRepository.save(profile);

        record.setRemovedAt(LocalDateTime.now());
        blacklistRecordRepository.save(record);

        log.info("工人已從黑名單移除: workerId={}, recordId={}", record.getWorkerId(), recordId);
    }

    @Override
    public List<BlacklistRecord> getBlacklist() {
        return blacklistRecordRepository.findAll();
    }

    @Override
    @Transactional
    public void lockCard(Long workerId) {
        WorkerProfile profile = workerProfileRepository.findById(workerId)
                .orElseThrow(() -> new BusinessException(404, "工人資料不存在"));

        if (Boolean.TRUE.equals(profile.getCardLocked())) {
            throw new BusinessException(400, "工卡已被鎖定");
        }

        profile.setCardLocked(true);
        workerProfileRepository.save(profile);
        log.info("工卡已鎖定: workerId={}", workerId);
    }

    @Override
    @Transactional
    public void unlockCard(Long workerId) {
        WorkerProfile profile = workerProfileRepository.findById(workerId)
                .orElseThrow(() -> new BusinessException(404, "工人資料不存在"));

        if (!Boolean.TRUE.equals(profile.getCardLocked())) {
            throw new BusinessException(400, "工卡未被鎖定");
        }

        profile.setCardLocked(false);
        workerProfileRepository.save(profile);
        log.info("工卡已解鎖: workerId={}", workerId);
    }

    @Override
    @Transactional
    public void deductScore(Long workerId, Integer points, String reason, Long adminId) {
        WorkerProfile profile = workerProfileRepository.findById(workerId)
                .orElseThrow(() -> new BusinessException(404, "工人資料不存在"));

        if (points <= 0) {
            throw new BusinessException(400, "扣分數值必須大於0");
        }

        // 安全分已遷移至 worker_site_safety_scores 表（15分制）
        // 此方法僅記錄 SafetyDeduction 扣分日誌，不再修改 worker_profiles.safety_score
        SafetyDeduction deduction = SafetyDeduction.builder()
                .workerId(workerId)
                .points(points)
                .reason(reason)
                .deductedBy(adminId)
                .deductedAt(LocalDateTime.now())
                .build();
        safetyDeductionRepository.save(deduction);

        log.info("安全扣分已記錄: workerId={}, points={}, reason={}（安全分由地盤維度管理）",
                workerId, points, reason);
    }
}

package com.fareast.worker.service;

import com.fareast.worker.model.entity.BlacklistRecord;
import com.fareast.worker.model.entity.Company;
import com.fareast.worker.model.entity.Site;
import com.fareast.worker.model.entity.WorkerProfile;

import java.util.List;

public interface AdminService {

    /**
     * Get all registered companies.
     */
    List<Company> getAllCompanies();

    /**
     * Get all sites belonging to a company.
     */
    List<Site> getSitesByCompany(Long companyId);

    /**
     * Get all workers assigned to a specific site.
     */
    List<WorkerProfile> getWorkersBySite(Long siteId);

    /**
     * Get detailed info about a worker (profile + user).
     */
    WorkerProfile getWorkerDetail(Long workerId);

    /**
     * Get all blacklist records.
     */
    List<BlacklistRecord> getBlacklist();

    /**
     * Add a worker to the blacklist.
     */
    BlacklistRecord addBlacklist(Long workerId, String reason, Long adminId);

    /**
     * Remove a worker from the blacklist by record ID.
     */
    void removeBlacklist(Long recordId, Long adminId);

    /**
     * Lock a worker's smart card.
     */
    void lockCard(Long workerId);

    /**
     * Unlock a worker's smart card.
     */
    void unlockCard(Long workerId);

    /**
     * Deduct safety score points from a worker.
     */
    void deductScore(Long workerId, Integer points, String reason, Long adminId);
}

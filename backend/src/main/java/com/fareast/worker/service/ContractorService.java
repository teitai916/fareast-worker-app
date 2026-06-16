package com.fareast.worker.service;

import com.fareast.worker.model.entity.Attendance;
import com.fareast.worker.model.entity.Site;
import com.fareast.worker.model.entity.WorkerProfile;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

public interface ContractorService {

    /**
     * Get all sites for a company.
     */
    List<Site> getSites(Long companyId);

    /**
     * Get all workers assigned to a specific site.
     */
    List<WorkerProfile> getSiteWorkers(Long siteId);

    /**
     * Get attendance records for a specific worker within a date range.
     */
    List<Attendance> getWorkerAttendance(Long workerId, LocalDate startDate, LocalDate endDate);

    /**
     * Get all pending audit requests.
     */
    Map<String, Object> getAuditList();

    /**
     * Approve or reject a request (site change, company change, etc.).
     */
    void processApproval(Long requestId, String type, Boolean approved);
}
